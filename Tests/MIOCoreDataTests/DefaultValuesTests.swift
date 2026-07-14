//
//  DefaultValuesTests.swift
//  MIOCoreDataTests
//
//  Covers model default values across the object lifecycle:
//  - populated into pending changes at init (insertNewObject / designated init)
//  - survive save, refault, and refresh — including refresh(mergeChanges:
//    false) on an unsaved inserted object, which once wiped them (regression)
//  - a mandatory attribute missing from a store row materializes its model
//    default on unfault (in-memory and incremental stores alike)
//
//  Self-contained: builds its model from inline XML; reuses the module's
//  CountingIncrementalStore for the store-row case.
//

#if !APPLE_CORE_DATA

import XCTest
import Foundation
import MIOCore
@testable import CoreDataSwift

// MARK: - Runtime classes

class CDDefEntity: CoreDataSwift.NSManagedObject {}

// MARK: - Test model

private let defModelXML = """
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<model type="com.apple.IDECoreDataModeler.DataModel" documentVersion="1.0">
    <entity name="CDDefEntity" representedClassName="CDDefEntity" syncable="YES">
        <attribute name="name" attributeType="String" optional="YES"/>
        <attribute name="counter" attributeType="Integer 32" defaultValueString="7"/>
        <attribute name="flag" attributeType="Boolean" defaultValueString="YES" optional="YES"/>
        <attribute name="score" attributeType="Double" defaultValueString="1.5" optional="YES"/>
    </entity>
</model>
"""

private let registerDefRuntimeClasses: Void = {
    _MIOCoreRegisterClass(type: CDDefEntity.self, forKey: "CDDefEntity")
    CoreDataSwift.NSPersistentStoreCoordinator.registerStoreClass(CountingIncrementalStore.self, forStoreType: CountingIncrementalStore.storeType)
}()

private func defModel() -> CoreDataSwift.NSManagedObjectModel {
    _ = registerDefRuntimeClasses
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("CDDefModel-\(ProcessInfo.processInfo.processIdentifier).xml")
    if FileManager.default.fileExists(atPath: url.path) == false {
        try! defModelXML.data(using: .utf8)!.write(to: url)
    }
    return CoreDataSwift.NSManagedObjectModel(contentsOf: url)!
}

// MARK: - Tests

final class DefaultValuesTests: XCTestCase
{
    var container: CoreDataSwift.NSPersistentContainer!
    var moc: CoreDataSwift.NSManagedObjectContext!

    private func makeContainer(storeType: String) {
        container = CoreDataSwift.NSPersistentContainer(name: "CDDefTest", managedObjectModel: defModel())
        let description = CoreDataSwift.NSPersistentStoreDescription()
        description.type = storeType
        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores { _, error in
            if let error = error { fatalError("Store failed to load: \(error)") }
        }
        moc = container.viewContext
    }

    override func setUp() {
        super.setUp()
        makeContainer(storeType: CoreDataSwift.NSInMemoryStoreType)
    }

    // MARK: Creation

    func testDefaultsPopulatedAtInsert() {
        let obj = CoreDataSwift.NSEntityDescription.insertNewObject(forEntityName: "CDDefEntity", into: moc)

        XCTAssertEqual(obj.value(forKey: "counter") as? Int32, 7)
        XCTAssertEqual(obj.value(forKey: "flag") as? Bool, true)
        XCTAssertEqual(obj.value(forKey: "score") as? Double, 1.5)
        XCTAssertEqual(obj.changedValues().count, 3, "defaults must be tracked so they persist on save")
    }

    func testDefaultsPopulatedWithNilContext() {
        let entity = container.managedObjectModel.entitiesByName["CDDefEntity"]!
        let obj = CDDefEntity(entity: entity, insertInto: nil)

        XCTAssertEqual(obj.value(forKey: "counter") as? Int32, 7)
    }

    // MARK: Lifecycle

    func testDefaultsSurviveSaveAndRefault() throws {
        let obj = CoreDataSwift.NSEntityDescription.insertNewObject(forEntityName: "CDDefEntity", into: moc)
        try moc.save()

        XCTAssertEqual(obj.value(forKey: "counter") as? Int32, 7, "after save")

        moc.refresh(obj, mergeChanges: true)
        XCTAssertEqual(obj.value(forKey: "counter") as? Int32, 7, "after refault")
    }

    func testDefaultsSurviveRefreshWithoutMergeOnUnsavedInsert() {
        // Regression: refresh(mergeChanges: false) discarded the pending
        // changes of an inserted object — where the defaults live — and a new
        // object has no store row to reload from, so it came back empty.
        let obj = CoreDataSwift.NSEntityDescription.insertNewObject(forEntityName: "CDDefEntity", into: moc)
        moc.refresh(obj, mergeChanges: false)

        XCTAssertEqual(obj.value(forKey: "counter") as? Int32, 7)
        XCTAssertEqual(obj.value(forKey: "flag") as? Bool, true)
        XCTAssertTrue(obj.isInserted, "the object must remain inserted")
    }

    func testDefaultsAvailableThroughExistingObject() throws {
        let obj = CoreDataSwift.NSEntityDescription.insertNewObject(forEntityName: "CDDefEntity", into: moc)
        obj.setValue("row", forKey: "name")
        try moc.save()

        let fetched = try moc.existingObject(with: obj.objectID)
        XCTAssertEqual(fetched.value(forKey: "counter") as? Int32, 7)
    }

    // MARK: Defaults apply at creation/insert — never later

    func testDefaultsAppliedByInsertWhenObjectBypassesDesignatedInit() throws {
        // Objects built with the plain init never ran the designated init's
        // _setDefaultValues: insert() applies the defaults, so reads return
        // the right value immediately — before any save
        let entity = container.managedObjectModel.entitiesByName["CDDefEntity"]!
        let obj = CDDefEntity()
        obj._objectID = CoreDataSwift.NSManagedObjectID(WithEntity: entity, referenceObject: nil)
        moc.insert(obj)

        XCTAssertEqual(obj.value(forKey: "counter") as? Int32, 7, "defaults must be readable right after insert")
        XCTAssertNoThrow(try moc.save())
    }

    func testInsertDoesNotClobberValuesSetBeforeInsert() throws {
        let entity = container.managedObjectModel.entitiesByName["CDDefEntity"]!
        let obj = CDDefEntity()
        obj._objectID = CoreDataSwift.NSManagedObjectID(WithEntity: entity, referenceObject: nil)
        obj._managedObjectContext = moc
        obj.setValue(Int32(99), forKey: "counter")
        moc.insert(obj)

        XCTAssertEqual(obj.value(forKey: "counter") as? Int32, 99, "insert must not overwrite caller-set values with defaults")
    }

    func testExplicitNilOnDefaultedMandatoryAttributeFailsValidation() {
        // Explicitly nulling a mandatory attribute is a code decision, not a
        // missing default: save must fail (defaults never re-apply after
        // creation)
        let obj = CoreDataSwift.NSEntityDescription.insertNewObject(forEntityName: "CDDefEntity", into: moc)
        obj.setValue(nil, forKey: "counter")

        XCTAssertThrowsError(try moc.save()) { error in
            guard case NSManagedObjectValidationError.missingMandatoryProperty = error else {
                XCTFail("Expected missingMandatoryProperty, got \(error)")
                return
            }
        }
    }

    // MARK: Store rows missing defaulted columns

    func testMandatoryDefaultMaterializedWhenIncrementalStoreRowMissesColumn() throws {
        makeContainer(storeType: CountingIncrementalStore.storeType)
        let store = container.persistentStoreCoordinator.persistentStores[0] as! CountingIncrementalStore

        let obj = CoreDataSwift.NSEntityDescription.insertNewObject(forEntityName: "CDDefEntity", into: moc)
        obj.setValue("row", forKey: "name")
        try moc.save()

        // Simulate a store row that never carried the defaulted columns
        // (e.g. a server response without them)
        store.rows[obj.objectID.uriString]?.removeValue(forKey: "counter")   // mandatory, default 7
        store.rows[obj.objectID.uriString]?.removeValue(forKey: "flag")      // optional, default true

        moc.refresh(obj, mergeChanges: false)

        XCTAssertEqual(obj.value(forKey: "counter") as? Int32, 7, "mandatory attribute materializes its model default")
        XCTAssertNil(obj.value(forKey: "flag"), "optional attribute missing from the row stays nil")
    }
}

#endif
