//
//  FaultingAndPrimitiveValueTests.swift
//  MIOCoreDataTests
//
//  Covers the faulting and primitive-value semantics:
//  - setValue does not refault the object (no store round-trip to read other
//    attributes afterwards)
//  - save keeps objects realized (committed changes merge into the snapshot)
//  - existingObject(with:) returns registered objects without refaulting them
//  - primitiveValue reflects pending changes, also on unsaved objects
//  - setPrimitiveValue is tracked, survives refaults, and gets saved
//  - refresh(mergeChanges: false) discards pending changes (Apple semantics),
//    refresh(mergeChanges: true) keeps them applied on top of a fresh snapshot
//
//  Uses an incremental store that counts newValuesForObject calls, so every
//  store round-trip is observable.
//

#if !APPLE_CORE_DATA

import XCTest
import Foundation
import MIOCore
@testable import CoreDataSwift

// MARK: - Runtime classes

class CDFaultingEntity: CoreDataSwift.NSManagedObject {}

// MARK: - Counting store

class CountingIncrementalStore: CoreDataSwift.NSIncrementalStore
{
    static let storeType = "CountingIncrementalStore"

    var rows: [String:[String:Any]] = [:]      // object URI -> attribute values
    var newValuesCount = 0                     // store round-trips for object data

    override func loadMetadata() throws {
        self.metadata = [CoreDataSwift.NSStoreUUIDKey: UUID().uuidString, CoreDataSwift.NSStoreTypeKey: CountingIncrementalStore.storeType]
    }

    override func execute(_ request: CoreDataSwift.NSPersistentStoreRequest, with context: CoreDataSwift.NSManagedObjectContext?) throws -> Any {
        if let save = request as? CoreDataSwift.NSSaveChangesRequest {
            for obj in save.insertedObjects ?? [] {
                rows[obj.objectID.uriString] = obj.changedValues()
            }
            for obj in save.updatedObjects ?? [] {
                rows[obj.objectID.uriString, default: [:]].merge(obj.changedValues()) { (_, new) in new }
            }
            for obj in save.deletedObjects ?? [] {
                rows.removeValue(forKey: obj.objectID.uriString)
            }
        }
        return []
    }

    override func newValuesForObject(with objectID: CoreDataSwift.NSManagedObjectID, with context: CoreDataSwift.NSManagedObjectContext) throws -> CoreDataSwift.NSIncrementalStoreNode {
        newValuesCount += 1
        return CoreDataSwift.NSIncrementalStoreNode(objectID: objectID, withValues: rows[objectID.uriString] ?? [:], version: 1)
    }
}

// MARK: - Test model

private let faultingModelXML = """
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<model type="com.apple.IDECoreDataModeler.DataModel" documentVersion="1.0">
    <entity name="CDFaultingEntity" representedClassName="CDFaultingEntity" syncable="YES">
        <attribute name="name" attributeType="String" optional="YES"/>
        <attribute name="counter" attributeType="Integer 32" optional="YES"/>
    </entity>
</model>
"""

private let registerFaultingRuntimeClasses: Void = {
    _MIOCoreRegisterClass(type: CDFaultingEntity.self, forKey: "CDFaultingEntity")
    CoreDataSwift.NSPersistentStoreCoordinator.registerStoreClass(CountingIncrementalStore.self, forStoreType: CountingIncrementalStore.storeType)
}()

private func faultingModel() -> CoreDataSwift.NSManagedObjectModel {
    _ = registerFaultingRuntimeClasses
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("CDFaultingModel-\(ProcessInfo.processInfo.processIdentifier).xml")
    if FileManager.default.fileExists(atPath: url.path) == false {
        try! faultingModelXML.data(using: .utf8)!.write(to: url)
    }
    return CoreDataSwift.NSManagedObjectModel(contentsOf: url)!
}

// MARK: - Tests

final class FaultingAndPrimitiveValueTests: XCTestCase
{
    var container: CoreDataSwift.NSPersistentContainer!
    var moc: CoreDataSwift.NSManagedObjectContext!
    var store: CountingIncrementalStore!

    override func setUp() {
        super.setUp()

        container = CoreDataSwift.NSPersistentContainer(name: "CDFaultingTest", managedObjectModel: faultingModel())
        let description = CoreDataSwift.NSPersistentStoreDescription()
        description.type = CountingIncrementalStore.storeType
        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores { _, error in
            if let error = error { fatalError("Store failed to load: \(error)") }
        }
        moc = container.viewContext
        store = (container.persistentStoreCoordinator.persistentStores[0] as! CountingIncrementalStore)
    }

    @discardableResult
    private func insertEntity(name: String, counter: Int32) -> CoreDataSwift.NSManagedObject {
        let obj = CoreDataSwift.NSEntityDescription.insertNewObject(forEntityName: "CDFaultingEntity", into: moc)
        obj.setValue(name, forKey: "name")
        obj.setValue(counter, forKey: "counter")
        return obj
    }

    // MARK: Faulting churn

    func testSaveKeepsObjectRealized() throws {
        let obj = insertEntity(name: "realized", counter: 1)
        try moc.save()

        XCTAssertFalse(obj.isFault, "A saved inserted object must stay realized")
        XCTAssertEqual(obj.value(forKey: "name") as? String, "realized")
        XCTAssertEqual(obj.value(forKey: "counter") as? Int32, 1)
        XCTAssertEqual(store.newValuesCount, 0, "Reading a just-saved object must not hit the store")
    }

    func testSetValueDoesNotRefaultObject() throws {
        let obj = insertEntity(name: "stable", counter: 1)
        try moc.save()

        moc.refresh(obj, mergeChanges: true)               // force a fault
        XCTAssertEqual(obj.value(forKey: "name") as? String, "stable")
        XCTAssertEqual(store.newValuesCount, 1, "First read after refault loads from the store once")

        obj.setValue(Int32(99), forKey: "counter")

        XCTAssertEqual(obj.value(forKey: "name") as? String, "stable")
        XCTAssertEqual(obj.value(forKey: "counter") as? Int32, 99)
        XCTAssertEqual(store.newValuesCount, 1, "setValue must not refault: reading other attributes afterwards must not reload from the store")
    }

    func testExistingObjectDoesNotRefaultRegisteredObjects() throws {
        let obj = insertEntity(name: "identity", counter: 1)
        try moc.save()

        let again = try moc.existingObject(with: obj.objectID)
        XCTAssertTrue(again === obj)

        XCTAssertEqual(again.value(forKey: "name") as? String, "identity")
        XCTAssertEqual(store.newValuesCount, 0, "existingObject must not refault an already-registered object")
    }

    // MARK: Primitive values

    func testPrimitiveValueReflectsPendingChanges() {
        let obj = insertEntity(name: "initial", counter: 1)

        // Unsaved object: primitives must read back pending values
        XCTAssertEqual(obj.primitiveValue(forKey: "name") as? String, "initial")

        obj.setValue("updated", forKey: "name")
        XCTAssertEqual(obj.primitiveValue(forKey: "name") as? String, "updated")
    }

    func testSetPrimitiveValueIsTrackedAndSaved() throws {
        let obj = insertEntity(name: "primitive", counter: 1)
        try moc.save()

        obj.setPrimitiveValue(Int32(9), forKey: "counter")

        XCTAssertEqual(obj.changedValues()["counter"] as? Int32, 9, "setPrimitiveValue must be tracked in changedValues")
        XCTAssertEqual(obj.committedValues(forKeys: ["counter"])["counter"] as? Int32, 1, "committedValues must still return the saved value")
        XCTAssertTrue(moc.hasChanges, "setPrimitiveValue must mark the object for the next save")

        try moc.save()

        XCTAssertEqual(obj.committedValues(forKeys: ["counter"])["counter"] as? Int32, 9)

        // Survives a refault: the value went to the store, not to a cache that gets wiped
        moc.refresh(obj, mergeChanges: true)
        XCTAssertEqual(obj.value(forKey: "counter") as? Int32, 9)
    }

    // MARK: refresh semantics

    func testRefreshWithoutMergeDiscardsPendingChanges() throws {
        let obj = insertEntity(name: "committed", counter: 1)
        try moc.save()

        obj.setValue("pending", forKey: "name")
        XCTAssertTrue(moc.hasChanges)

        moc.refresh(obj, mergeChanges: false)

        XCTAssertEqual(obj.changedValues().count, 0, "refresh(mergeChanges: false) must discard pending changes")
        XCTAssertFalse(moc.hasChanges)
        XCTAssertEqual(obj.value(forKey: "name") as? String, "committed", "The discarded value must reload from the store")
    }

    func testRefreshWithMergeKeepsPendingChanges() throws {
        let obj = insertEntity(name: "committed", counter: 1)
        try moc.save()

        obj.setValue("pending", forKey: "name")
        moc.refresh(obj, mergeChanges: true)

        XCTAssertEqual(obj.changedValues()["name"] as? String, "pending", "refresh(mergeChanges: true) must keep pending changes")
        XCTAssertEqual(obj.value(forKey: "name") as? String, "pending")
        XCTAssertEqual(obj.committedValues(forKeys: ["name"])["name"] as? String, "committed")
    }

    // MARK: Change-tracking flags

    func testTrackingFlagsClearAfterSave() throws {
        let obj = insertEntity(name: "flags", counter: 1)
        XCTAssertTrue(obj.isInserted)

        try moc.save()
        XCTAssertFalse(obj.isInserted, "isInserted must clear after a successful save")

        obj.setValue("flags-2", forKey: "name")
        XCTAssertTrue(obj.isUpdated)

        try moc.save()
        XCTAssertFalse(obj.isUpdated, "isUpdated must clear after a successful save")
    }
}

#endif
