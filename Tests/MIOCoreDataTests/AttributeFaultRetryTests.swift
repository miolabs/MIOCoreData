//
//  AttributeFaultRetryTests.swift
//  MIOCoreDataTests
//
//  An object whose row the store cannot load must not turn into a permanent
//  empty snapshot. Before this was pinned, unfaultAttributes swallowed the
//  store error with a `try?` and the storedValues getter cleared the fault
//  anyway: one failed load (a transient DB error, a schema the store query
//  could not read) made every attribute read nil for the rest of the object's
//  life, and nothing in the log said why.
//
//  It also reached relationships: with the object still a fault, a
//  relationship resolved on it was wiped by the next attribute load's fresh
//  snapshot while its key stayed marked resolved — a permanent nil, the same
//  shape RelationshipFaultRetryTests pins for the relationship read itself.
//
//  Contract pinned here:
//  - a failed load leaves the object a fault and reads as nil / empty
//  - the next access asks the store again and loads normally
//  - no relationship is resolved on an object whose own load failed
//  - a successful load is served from the snapshot afterwards
//

#if !APPLE_CORE_DATA

import XCTest
import Foundation
import MIOCore
@testable import CoreDataSwift

// MARK: - Runtime classes

class CDAttrRetryOwner: CoreDataSwift.NSManagedObject {}
class CDAttrRetryTarget: CoreDataSwift.NSManagedObject {}

// MARK: - Store with failable object loads

enum FlakyObjectStoreError: Error { case storeUnavailable }

class FlakyObjectStore: CoreDataSwift.NSIncrementalStore
{
    static let storeType = "FlakyObjectStore"

    nonisolated(unsafe) var rows: [String:[String:Any]] = [:]            // object URI -> attribute values
    nonisolated(unsafe) var relationships: [String:[String:Any]] = [:]   // object URI -> key -> objectID | NSNull
    var failNextObjectLoads = 0                                          // throw from this many upcoming object loads
    var newValuesCount = 0                                               // store round-trips for object data
    var relationshipReads = 0                                            // store round-trips for relationships

    override func loadMetadata() throws {
        self.metadata = [CoreDataSwift.NSStoreUUIDKey: UUID().uuidString, CoreDataSwift.NSStoreTypeKey: FlakyObjectStore.storeType]
    }

    override func execute(_ request: CoreDataSwift.NSPersistentStoreRequest, with context: CoreDataSwift.NSManagedObjectContext?) throws -> Any {
        return []
    }

    override func newValuesForObject(with objectID: CoreDataSwift.NSManagedObjectID, with context: CoreDataSwift.NSManagedObjectContext) throws -> CoreDataSwift.NSIncrementalStoreNode {
        newValuesCount += 1
        if failNextObjectLoads > 0 {
            failNextObjectLoads -= 1
            throw FlakyObjectStoreError.storeUnavailable
        }
        return CoreDataSwift.NSIncrementalStoreNode(objectID: objectID, withValues: rows[objectID.uriString] ?? [:], version: 1)
    }

    override func newValue(forRelationship relationship: CoreDataSwift.NSRelationshipDescription, forObjectWith objectID: CoreDataSwift.NSManagedObjectID, with context: CoreDataSwift.NSManagedObjectContext?) throws -> Any {
        relationshipReads += 1
        return relationships[objectID.uriString]?[relationship.name] ?? NSNull()
    }
}

// MARK: - Test model

private let attrRetryModelXML = """
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<model type="com.apple.IDECoreDataModeler.DataModel" documentVersion="1.0">
    <entity name="CDAttrRetryOwner" representedClassName="CDAttrRetryOwner" syncable="YES">
        <attribute name="name" attributeType="String" optional="YES"/>
        <relationship name="target" optional="YES" maxCount="1" deletionRule="Nullify" destinationEntity="CDAttrRetryTarget"/>
    </entity>
    <entity name="CDAttrRetryTarget" representedClassName="CDAttrRetryTarget" syncable="YES">
        <attribute name="name" attributeType="String" optional="YES"/>
    </entity>
</model>
"""

private let registerAttrRetryRuntimeClasses: Void = {
    _MIOCoreRegisterClass(type: CDAttrRetryOwner.self, forKey: "CDAttrRetryOwner")
    _MIOCoreRegisterClass(type: CDAttrRetryTarget.self, forKey: "CDAttrRetryTarget")
    CoreDataSwift.NSPersistentStoreCoordinator.registerStoreClass(FlakyObjectStore.self, forStoreType: FlakyObjectStore.storeType)
}()

private func attrRetryModel() -> CoreDataSwift.NSManagedObjectModel {
    _ = registerAttrRetryRuntimeClasses
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("CDAttributeRetryModel-\(ProcessInfo.processInfo.processIdentifier).xml")
    if FileManager.default.fileExists(atPath: url.path) == false {
        try! attrRetryModelXML.data(using: .utf8)!.write(to: url)
    }
    return CoreDataSwift.NSManagedObjectModel(contentsOf: url)!
}

// MARK: - Tests

final class AttributeFaultRetryTests: XCTestCase
{
    var container: CoreDataSwift.NSPersistentContainer!
    var moc: CoreDataSwift.NSManagedObjectContext!
    var store: FlakyObjectStore!

    override func setUp() {
        super.setUp()

        container = CoreDataSwift.NSPersistentContainer(name: "CDAttributeRetryTest", managedObjectModel: attrRetryModel())
        let description = CoreDataSwift.NSPersistentStoreDescription()
        description.type = FlakyObjectStore.storeType
        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores { _, error in
            if let error = error { fatalError("Store failed to load: \(error)") }
        }
        moc = container.viewContext
        store = (container.persistentStoreCoordinator.persistentStores[0] as! FlakyObjectStore)
    }

    // MARK: Helpers

    private func entity(_ name: String) -> CoreDataSwift.NSEntityDescription {
        return container.managedObjectModel.entitiesByName[name]!
    }

    /// A store-backed object (permanent ID, row in the store) materialized as
    /// a fault in the context — the shape every fetched object has.
    private func storeObject(_ entityName: String, _ reference: String, values: [String:Any] = [:]) throws -> CoreDataSwift.NSManagedObject {
        let objID = store.newObjectID(for: entity(entityName), referenceObject: reference)
        store.rows[objID.uriString] = values
        return try moc.existingObject(with: objID)
    }

    // MARK: Attributes

    func testFailedLoadLeavesObjectFaultedAndNextReadAsksTheStoreAgain() throws {
        let owner = try storeObject("CDAttrRetryOwner", "owner-1", values: ["name": "owner"])

        store.failNextObjectLoads = 1
        XCTAssertNil(owner.value(forKey: "name"), "a failed load surfaces as nil for this read")
        XCTAssertEqual(store.newValuesCount, 1)
        XCTAssertTrue(owner.isFault, "a failed load must leave the object a fault, not an empty realized snapshot")

        XCTAssertEqual(owner.value(forKey: "name") as? String, "owner", "the next read must load the row")
        XCTAssertEqual(store.newValuesCount, 2)
        XCTAssertFalse(owner.isFault)

        _ = owner.value(forKey: "name")
        XCTAssertEqual(store.newValuesCount, 2, "a loaded object is served from the snapshot")
    }

    func testCommittedValuesRetriesAfterFailedLoad() throws {
        let owner = try storeObject("CDAttrRetryOwner", "owner-2", values: ["name": "owner"])

        store.failNextObjectLoads = 1
        XCTAssertNil(owner.committedValues(forKeys: nil)["name"])
        XCTAssertTrue(owner.isFault)

        XCTAssertEqual(owner.committedValues(forKeys: nil)["name"] as? String, "owner")
        XCTAssertEqual(store.newValuesCount, 2)
    }

    // MARK: Relationships on an object whose load failed

    func testRelationshipIsNotResolvedOnAnObjectWhoseLoadFailed() throws {
        let target = try storeObject("CDAttrRetryTarget", "target-3", values: ["name": "target"])
        let owner  = try storeObject("CDAttrRetryOwner", "owner-3", values: ["name": "owner"])
        store.relationships[owner.objectID.uriString] = ["target": target.objectID]

        store.failNextObjectLoads = 1
        XCTAssertNil(owner.value(forKey: "target"), "the owner could not be loaded: nil for this read")
        XCTAssertEqual(store.newValuesCount, 1, "one failed load per read, no second round-trip")
        XCTAssertEqual(store.relationshipReads, 0, "no relationship read on an object whose load failed")
        XCTAssertTrue(owner.hasFault(forRelationshipNamed: "target"))

        let resolved = owner.value(forKey: "target") as? CoreDataSwift.NSManagedObject
        XCTAssertTrue(resolved === target, "the next read loads the owner and resolves the relationship")
        XCTAssertFalse(owner.hasFault(forRelationshipNamed: "target"))
    }

    func testResolvedRelationshipSurvivesTheLoadThatFollowsAFailedOne() throws {
        let target = try storeObject("CDAttrRetryTarget", "target-4", values: ["name": "target"])
        let owner  = try storeObject("CDAttrRetryOwner", "owner-4", values: ["name": "owner"])
        store.relationships[owner.objectID.uriString] = ["target": target.objectID]

        // Failed load, then a relationship read, then an attribute read: the
        // attribute load must not wipe a relationship already marked resolved.
        store.failNextObjectLoads = 1
        _ = owner.value(forKey: "target")
        _ = owner.value(forKey: "target")
        XCTAssertEqual(owner.value(forKey: "name") as? String, "owner")

        let resolved = owner.value(forKey: "target") as? CoreDataSwift.NSManagedObject
        XCTAssertTrue(resolved === target, "the relationship must still read the real object")
    }
}

#endif
