//
//  RelationshipFaultRetryTests.swift
//  MIOCoreDataTests
//
//  A relationship fault that the store cannot fulfill must not turn into a
//  permanent nil. Before this was pinned, unfaultRelationshipNamed marked the
//  key resolved BEFORE asking the store and swallowed the store error with a
//  `try?`: one failed fetch (a transient DB error, a destination row the
//  store could not load) read as nil for the rest of the object's life, and a
//  mandatory to-one crashed its force-unwrapping accessor while the row was
//  perfectly valid in the database.
//
//  Contract pinned here:
//  - a store error leaves the relationship faulted and reads as nil / empty
//  - the next access asks the store again and resolves normally
//  - a genuine answer (NSNull for a to-one, an empty list for a to-many) IS
//    resolved: no re-ask on later reads
//  - committedValues(forKeys:) follows the same rule
//
//  Uses an incremental store whose relationship reads can be made to fail on
//  demand, so every store round-trip is observable.
//

#if !APPLE_CORE_DATA

import XCTest
import Foundation
import MIOCore
@testable import CoreDataSwift

// MARK: - Runtime classes

class CDRetryOwner: CoreDataSwift.NSManagedObject {}
class CDRetryTarget: CoreDataSwift.NSManagedObject {}

// MARK: - Store with failable relationship reads

enum FlakyRelationshipStoreError: Error { case storeUnavailable }

class FlakyRelationshipStore: CoreDataSwift.NSIncrementalStore
{
    static let storeType = "FlakyRelationshipStore"

    nonisolated(unsafe) var rows: [String:[String:Any]] = [:]            // object URI -> attribute values
    nonisolated(unsafe) var relationships: [String:[String:Any]] = [:]   // object URI -> key -> objectID | [objectID] | NSNull
    var failNextRelationshipReads = 0                                    // throw from this many upcoming relationship reads
    var relationshipReads = 0                                            // store round-trips for relationships
    var newValuesCount = 0                                               // store round-trips for object data

    override func loadMetadata() throws {
        self.metadata = [CoreDataSwift.NSStoreUUIDKey: UUID().uuidString, CoreDataSwift.NSStoreTypeKey: FlakyRelationshipStore.storeType]
    }

    override func execute(_ request: CoreDataSwift.NSPersistentStoreRequest, with context: CoreDataSwift.NSManagedObjectContext?) throws -> Any {
        return []
    }

    override func newValuesForObject(with objectID: CoreDataSwift.NSManagedObjectID, with context: CoreDataSwift.NSManagedObjectContext) throws -> CoreDataSwift.NSIncrementalStoreNode {
        newValuesCount += 1
        return CoreDataSwift.NSIncrementalStoreNode(objectID: objectID, withValues: rows[objectID.uriString] ?? [:], version: 1)
    }

    override func newValue(forRelationship relationship: CoreDataSwift.NSRelationshipDescription, forObjectWith objectID: CoreDataSwift.NSManagedObjectID, with context: CoreDataSwift.NSManagedObjectContext?) throws -> Any {
        relationshipReads += 1
        if failNextRelationshipReads > 0 {
            failNextRelationshipReads -= 1
            throw FlakyRelationshipStoreError.storeUnavailable
        }

        let value = relationships[objectID.uriString]?[relationship.name]
        if relationship.isToMany {
            return value as? [CoreDataSwift.NSManagedObjectID] ?? []
        }
        return value ?? NSNull()
    }
}

// MARK: - Test model

private let retryModelXML = """
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<model type="com.apple.IDECoreDataModeler.DataModel" documentVersion="1.0">
    <entity name="CDRetryOwner" representedClassName="CDRetryOwner" syncable="YES">
        <attribute name="name" attributeType="String" optional="YES"/>
        <relationship name="target" optional="YES" maxCount="1" deletionRule="Nullify" destinationEntity="CDRetryTarget"/>
        <relationship name="members" optional="YES" toMany="YES" deletionRule="Nullify" destinationEntity="CDRetryTarget"/>
    </entity>
    <entity name="CDRetryTarget" representedClassName="CDRetryTarget" syncable="YES">
        <attribute name="name" attributeType="String" optional="YES"/>
    </entity>
</model>
"""

private let registerRetryRuntimeClasses: Void = {
    _MIOCoreRegisterClass(type: CDRetryOwner.self, forKey: "CDRetryOwner")
    _MIOCoreRegisterClass(type: CDRetryTarget.self, forKey: "CDRetryTarget")
    CoreDataSwift.NSPersistentStoreCoordinator.registerStoreClass(FlakyRelationshipStore.self, forStoreType: FlakyRelationshipStore.storeType)
}()

private func retryModel() -> CoreDataSwift.NSManagedObjectModel {
    _ = registerRetryRuntimeClasses
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("CDRelationshipRetryModel-\(ProcessInfo.processInfo.processIdentifier).xml")
    if FileManager.default.fileExists(atPath: url.path) == false {
        try! retryModelXML.data(using: .utf8)!.write(to: url)
    }
    return CoreDataSwift.NSManagedObjectModel(contentsOf: url)!
}

// MARK: - Tests

final class RelationshipFaultRetryTests: XCTestCase
{
    var container: CoreDataSwift.NSPersistentContainer!
    var moc: CoreDataSwift.NSManagedObjectContext!
    var store: FlakyRelationshipStore!

    override func setUp() {
        super.setUp()

        container = CoreDataSwift.NSPersistentContainer(name: "CDRelationshipRetryTest", managedObjectModel: retryModel())
        let description = CoreDataSwift.NSPersistentStoreDescription()
        description.type = FlakyRelationshipStore.storeType
        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores { _, error in
            if let error = error { fatalError("Store failed to load: \(error)") }
        }
        moc = container.viewContext
        store = (container.persistentStoreCoordinator.persistentStores[0] as! FlakyRelationshipStore)
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

    private func uris(_ objects: Set<CoreDataSwift.NSManagedObject>?) -> Set<String> {
        return Set( (objects ?? []).map { $0.objectID.uriString } )
    }

    // MARK: To-one

    func testStoreErrorLeavesToOneFaultedAndNextReadAsksTheStoreAgain() throws {
        let target = try storeObject("CDRetryTarget", "target-1", values: ["name": "target"])
        let owner  = try storeObject("CDRetryOwner", "owner-1", values: ["name": "owner"])
        store.relationships[owner.objectID.uriString] = ["target": target.objectID]

        store.failNextRelationshipReads = 1
        XCTAssertNil(owner.value(forKey: "target"), "a failed store read surfaces as nil")
        XCTAssertEqual(store.relationshipReads, 1)
        XCTAssertTrue(owner.hasFault(forRelationshipNamed: "target"), "a failed read must leave the relationship faulted, not resolved-as-nil")

        let resolved = owner.value(forKey: "target") as? CoreDataSwift.NSManagedObject
        XCTAssertEqual(store.relationshipReads, 2, "the next read must ask the store again")
        XCTAssertTrue(resolved === target, "once the store answers, the relationship resolves to the real object")
        XCTAssertFalse(owner.hasFault(forRelationshipNamed: "target"))

        _ = owner.value(forKey: "target")
        XCTAssertEqual(store.relationshipReads, 2, "a resolved relationship is served from the snapshot")
    }

    func testNilToOneAnswerIsResolvedWithoutRetry() throws {
        let owner = try storeObject("CDRetryOwner", "owner-2", values: ["name": "owner"])
        store.relationships[owner.objectID.uriString] = ["target": NSNull()]

        XCTAssertNil(owner.value(forKey: "target"))
        XCTAssertFalse(owner.hasFault(forRelationshipNamed: "target"), "a genuine nil is an answer, not a failure")

        XCTAssertNil(owner.value(forKey: "target"))
        XCTAssertEqual(store.relationshipReads, 1, "a genuine nil must not be re-asked on every read")
    }

    func testCommittedValuesRetriesAfterStoreError() throws {
        let target = try storeObject("CDRetryTarget", "target-3")
        let owner  = try storeObject("CDRetryOwner", "owner-3")
        store.relationships[owner.objectID.uriString] = ["target": target.objectID]

        store.failNextRelationshipReads = 1
        XCTAssertNil(owner.committedValues(forKeys: ["target"])["target"] as? CoreDataSwift.NSManagedObject)
        XCTAssertTrue(owner.hasFault(forRelationshipNamed: "target"))

        let resolved = owner.committedValues(forKeys: ["target"])["target"] as? CoreDataSwift.NSManagedObject
        XCTAssertTrue(resolved === target)
        XCTAssertEqual(store.relationshipReads, 2)
    }

    // MARK: To-many

    func testStoreErrorLeavesToManyFaultedAndNextReadAsksTheStoreAgain() throws {
        let m1 = try storeObject("CDRetryTarget", "member-1")
        let m2 = try storeObject("CDRetryTarget", "member-2")
        let owner = try storeObject("CDRetryOwner", "owner-4")
        store.relationships[owner.objectID.uriString] = ["members": [m1.objectID, m2.objectID]]

        store.failNextRelationshipReads = 1
        XCTAssertEqual(uris(owner.value(forKey: "members") as? Set<CoreDataSwift.NSManagedObject>), [], "a failed store read surfaces as an empty set")
        XCTAssertTrue(owner.hasFault(forRelationshipNamed: "members"))

        let members = owner.value(forKey: "members") as? Set<CoreDataSwift.NSManagedObject>
        XCTAssertEqual(uris(members), [m1.objectID.uriString, m2.objectID.uriString])
        XCTAssertEqual(store.relationshipReads, 2)
        XCTAssertFalse(owner.hasFault(forRelationshipNamed: "members"))
    }

    func testEmptyToManyAnswerIsResolvedWithoutRetry() throws {
        let owner = try storeObject("CDRetryOwner", "owner-6")
        // no "members" entry: the store answers an empty list

        XCTAssertEqual(uris(owner.value(forKey: "members") as? Set<CoreDataSwift.NSManagedObject>), [])
        XCTAssertFalse(owner.hasFault(forRelationshipNamed: "members"), "an empty list is an answer, not a failure")

        _ = owner.value(forKey: "members")
        XCTAssertEqual(store.relationshipReads, 1, "a genuine empty to-many must not be re-asked on every read")
    }

    // MARK: Attributes are untouched

    func testAttributeReadsNeverAskForRelationships() throws {
        let owner = try storeObject("CDRetryOwner", "owner-5", values: ["name": "owner"])

        XCTAssertEqual(owner.primitiveValue(forKey: "name") as? String, "owner")
        XCTAssertEqual(owner.value(forKey: "name") as? String, "owner")
        XCTAssertEqual(store.relationshipReads, 0)
        XCTAssertEqual(store.newValuesCount, 1, "attributes load once from the store")
        XCTAssertFalse(owner.hasFault(forRelationshipNamed: "name"), "an attribute key is marked resolved so the lookup is skipped next time")
    }
}

#endif
