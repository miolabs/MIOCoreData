//
//  RegistrationAndIdentityTests.swift
//  MIOCoreDataTests
//
//  Covers the context object registry (objectsByID keyed by URI string,
//  objectsByEntityName in-place set mutation, superentity registration) and
//  NSManagedObjectID.uriString caching/invalidation.
//
//  Self-contained: builds its model from inline XML and registers its own
//  runtime classes, so it does not depend on the TestModel target or the
//  process working directory.
//

#if !APPLE_CORE_DATA

import XCTest
import Foundation
import MIOCore
@testable import CoreDataSwift

// MARK: - Runtime classes

class CDRegTestEntity: CoreDataSwift.NSManagedObject {}
class CDRegTestBase: CoreDataSwift.NSManagedObject {}
class CDRegTestDerived: CDRegTestBase {}

// MARK: - Test model

private let registrationTestModelXML = """
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<model type="com.apple.IDECoreDataModeler.DataModel" documentVersion="1.0">
    <entity name="CDRegTestEntity" representedClassName="CDRegTestEntity" syncable="YES">
        <attribute name="name" attributeType="String" optional="YES"/>
        <attribute name="counter" attributeType="Integer 32" optional="YES"/>
    </entity>
    <entity name="CDRegTestBase" representedClassName="CDRegTestBase" isAbstract="YES" syncable="YES">
        <attribute name="name" attributeType="String" optional="YES"/>
    </entity>
    <entity name="CDRegTestDerived" representedClassName="CDRegTestDerived" parentEntity="CDRegTestBase" syncable="YES">
        <attribute name="extra" attributeType="String" optional="YES"/>
    </entity>
</model>
"""

private let registerRuntimeClasses: Void = {
    _MIOCoreRegisterClass(type: CDRegTestEntity.self, forKey: "CDRegTestEntity")
    _MIOCoreRegisterClass(type: CDRegTestBase.self, forKey: "CDRegTestBase")
    _MIOCoreRegisterClass(type: CDRegTestDerived.self, forKey: "CDRegTestDerived")
}()

private func registrationTestModel() -> CoreDataSwift.NSManagedObjectModel {
    _ = registerRuntimeClasses
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("CDRegTestModel-\(ProcessInfo.processInfo.processIdentifier).xml")
    if FileManager.default.fileExists(atPath: url.path) == false {
        try! registrationTestModelXML.data(using: .utf8)!.write(to: url)
    }
    return CoreDataSwift.NSManagedObjectModel(contentsOf: url)!
}

// MARK: - Tests

final class RegistrationAndIdentityTests: XCTestCase
{
    var container: CoreDataSwift.NSPersistentContainer!
    var moc: CoreDataSwift.NSManagedObjectContext!

    override func setUp() {
        super.setUp()

        container = CoreDataSwift.NSPersistentContainer(name: "CDRegTest", managedObjectModel: registrationTestModel())
        let description = CoreDataSwift.NSPersistentStoreDescription()
        description.type = CoreDataSwift.NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores { _, error in
            if let error = error { fatalError("Store failed to load: \(error)") }
        }
        moc = container.viewContext
    }

    private func entity(_ name: String) -> CoreDataSwift.NSEntityDescription {
        return container.managedObjectModel.entitiesByName[name]!
    }

    @discardableResult
    private func insertEntity(_ name: String) -> CoreDataSwift.NSManagedObject {
        return CoreDataSwift.NSEntityDescription.insertNewObject(forEntityName: name, into: moc)
    }

    // MARK: Registry

    func testInsertRegistersObjectByURIString() {
        let obj = insertEntity("CDRegTestEntity")

        XCTAssertTrue(moc.objectsByID[obj.objectID.uriString] === obj)
        XCTAssertTrue(moc.objectsByEntityName["CDRegTestEntity"]?.contains(obj) ?? false)
    }

    func testRegisterIsIdempotent() {
        let obj = insertEntity("CDRegTestEntity")
        moc._registerObject(obj)

        XCTAssertEqual(moc.objectsByID.count, 1)
        XCTAssertEqual(moc.objectsByEntityName["CDRegTestEntity"]?.count, 1)
    }

    func testUnregisterRemovesObjectFromAllRegistries() {
        let obj = insertEntity("CDRegTestEntity")
        moc._unregisterObject(obj)

        XCTAssertNil(moc.objectsByID[obj.objectID.uriString])
        XCTAssertEqual(moc.objectsByEntityName["CDRegTestEntity"]?.contains(obj), false)
    }

    func testSubentityRegistersUnderEveryHierarchyLevel() {
        let obj = insertEntity("CDRegTestDerived")

        XCTAssertTrue(moc.objectsByEntityName["CDRegTestDerived"]?.contains(obj) ?? false)
        XCTAssertTrue(moc.objectsByEntityName["CDRegTestBase"]?.contains(obj) ?? false)

        moc._unregisterObject(obj)
        XCTAssertEqual(moc.objectsByEntityName["CDRegTestDerived"]?.contains(obj), false)
        XCTAssertEqual(moc.objectsByEntityName["CDRegTestBase"]?.contains(obj), false)
    }

    func testBulkRegistrationKeepsRegistriesConsistent() {
        let total = 500
        var objects: [CoreDataSwift.NSManagedObject] = []
        for i in 0..<total {
            let obj = insertEntity("CDRegTestEntity")
            obj.setValue("name-\(i)", forKey: "name")
            objects.append(obj)
        }

        XCTAssertEqual(moc.objectsByID.count, total)
        XCTAssertEqual(moc.objectsByEntityName["CDRegTestEntity"]?.count, total)

        for obj in objects { moc._unregisterObject(obj) }
        XCTAssertEqual(moc.objectsByID.count, 0)
        XCTAssertEqual(moc.objectsByEntityName["CDRegTestEntity"]?.count, 0)
    }

    // MARK: existingObject identity

    func testExistingObjectReturnsRegisteredInstance() throws {
        let obj = insertEntity("CDRegTestEntity")
        obj.setValue("a", forKey: "name")
        try moc.save()

        let fetched = try moc.existingObject(with: obj.objectID)
        XCTAssertTrue(fetched === obj)
    }

    // MARK: uriString cache

    func testURIStringMatchesURIRepresentation() {
        let obj = insertEntity("CDRegTestEntity")
        XCTAssertEqual(obj.objectID.uriString, obj.objectID.uriRepresentation().absoluteString)
    }

    func testURIStringInvalidatedOnReferenceObjectChange() {
        let id = CoreDataSwift.NSManagedObjectID(WithEntity: entity("CDRegTestEntity"), referenceObject: nil)
        let before = id.uriString
        XCTAssertTrue(id.isTemporaryID)

        id._set_reference_object(referenceObject: "PERMANENT-REF")

        XCTAssertFalse(id.isTemporaryID)
        XCTAssertNotEqual(id.uriString, before)
        XCTAssertTrue(id.uriString.contains("PERMANENT-REF"))
        XCTAssertEqual(id.uriString, id.uriRepresentation().absoluteString)
    }

    func testURIStringInvalidatedWhenStoreAssignedOnSave() throws {
        let obj = insertEntity("CDRegTestEntity")
        let before = obj.objectID.uriString
        XCTAssertTrue(obj.objectID.isTemporaryID)

        try moc.save()

        // The in-memory store assigns itself to the ID during save; the cached
        // URI must pick up the store identifier.
        XCTAssertFalse(obj.objectID.isTemporaryID)
        XCTAssertNotEqual(obj.objectID.uriString, before)
        XCTAssertEqual(obj.objectID.uriString, obj.objectID.uriRepresentation().absoluteString)
    }

    // MARK: End to end

    func testInsertSaveFetchRoundtrip() throws {
        for (i, name) in ["a", "b", "c"].enumerated() {
            let obj = insertEntity("CDRegTestEntity")
            obj.setValue(name, forKey: "name")
            obj.setValue(Int32(i), forKey: "counter")
        }
        try moc.save()

        let request = CoreDataSwift.NSFetchRequest<CoreDataSwift.NSManagedObject>(entityName: "CDRegTestEntity")
        request.predicate = MIOPredicateWithFormat(format: "name == 'b'")
        let results = try moc.fetch(request)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.value(forKey: "name") as? String, "b")
    }
}

#endif
