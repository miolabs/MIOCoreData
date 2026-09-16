//
//  ObjectLifetimeTests.swift
//  MIOCoreDataTests
//
//  Covers the object registry lifetime policy and in-memory store
//  relationship persistence:
//  - retainsRegisteredObjects = true (default): the context keeps registered
//    objects alive
//  - retainsRegisteredObjects = false: clean objects are released once nothing
//    else holds them (and the registry compacts), while objects with pending
//    changes stay retained by the tracking sets
//  - in-memory store relationships survive a save + refault round-trip
//    (they are persisted as object IDs now, not live object references)
//
//  Self-contained: builds its model from inline XML.
//

#if !APPLE_CORE_DATA

import XCTest
import Foundation
import MIOCore
@testable import CoreDataSwift

// MARK: - Runtime classes

class CDLifeEntity: CoreDataSwift.NSManagedObject {}
class CDLifeParent: CoreDataSwift.NSManagedObject {}
class CDLifeChild: CoreDataSwift.NSManagedObject {}

// MARK: - Test model

private let lifeModelXML = """
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<model type="com.apple.IDECoreDataModeler.DataModel" documentVersion="1.0">
    <entity name="CDLifeEntity" representedClassName="CDLifeEntity" syncable="YES">
        <attribute name="name" attributeType="String" optional="YES"/>
    </entity>
    <entity name="CDLifeParent" representedClassName="CDLifeParent" syncable="YES">
        <attribute name="name" attributeType="String" optional="YES"/>
        <relationship name="children" destinationEntity="CDLifeChild" toMany="YES" optional="YES" inverseName="parent" inverseEntity="CDLifeChild" deletionRule="Nullify"/>
    </entity>
    <entity name="CDLifeChild" representedClassName="CDLifeChild" syncable="YES">
        <attribute name="name" attributeType="String" optional="YES"/>
        <relationship name="parent" destinationEntity="CDLifeParent" optional="YES" inverseName="children" inverseEntity="CDLifeParent" deletionRule="Nullify"/>
    </entity>
</model>
"""

private let registerLifeRuntimeClasses: Void = {
    _MIOCoreRegisterClass(type: CDLifeEntity.self, forKey: "CDLifeEntity")
    _MIOCoreRegisterClass(type: CDLifeParent.self, forKey: "CDLifeParent")
    _MIOCoreRegisterClass(type: CDLifeChild.self, forKey: "CDLifeChild")
}()

private func lifeModel() -> CoreDataSwift.NSManagedObjectModel {
    _ = registerLifeRuntimeClasses
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("CDLifeModel-\(ProcessInfo.processInfo.processIdentifier).xml")
    if FileManager.default.fileExists(atPath: url.path) == false {
        try! lifeModelXML.data(using: .utf8)!.write(to: url)
    }
    return CoreDataSwift.NSManagedObjectModel(contentsOf: url)!
}

// MARK: - Tests

final class ObjectLifetimeTests: XCTestCase
{
    var container: CoreDataSwift.NSPersistentContainer!
    var moc: CoreDataSwift.NSManagedObjectContext!

    override func setUp() {
        super.setUp()
        container = CoreDataSwift.NSPersistentContainer(name: "CDLifeTest", managedObjectModel: lifeModel())
        let description = CoreDataSwift.NSPersistentStoreDescription()
        description.type = CoreDataSwift.NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores { _, error in
            if let error = error { fatalError("\(error)") }
        }
        moc = container.viewContext
    }

    private func fetchCount() throws -> Int {
        let request = CoreDataSwift.NSFetchRequest<CoreDataSwift.NSManagedObject>(entityName: "CDLifeEntity")
        return try moc.fetch(request).count
    }

    // MARK: Registry lifetime

    func testRetainedRegistryKeepsObjectsAlive() throws {
        try autoreleasepool {
            var obj: CoreDataSwift.NSManagedObject? = CoreDataSwift.NSEntityDescription.insertNewObject(forEntityName: "CDLifeEntity", into: moc)
            obj!.setValue("kept", forKey: "name")
            try moc.save()
            obj = nil
        }

        // Default policy: the context itself keeps the object alive
        XCTAssertEqual(try fetchCount(), 1)
        XCTAssertEqual(moc.registeredObjects.count, 1)
    }

    func testWeakRegistryReleasesCleanObjects() throws {
        moc.retainsRegisteredObjects = false

        try autoreleasepool {
            var obj: CoreDataSwift.NSManagedObject? = CoreDataSwift.NSEntityDescription.insertNewObject(forEntityName: "CDLifeEntity", into: moc)
            obj!.setValue("released", forKey: "name")
            try moc.save()
            obj = nil   // after save the tracking sets no longer hold it
        }

        XCTAssertEqual(moc.registeredObjects.count, 0, "a clean object with no outside references must be released")
        XCTAssertEqual(try fetchCount(), 0, "the registry fetch path must compact dead entries")
    }

    func testWeakRegistryRetainsObjectsWithPendingChanges() throws {
        moc.retainsRegisteredObjects = false

        autoreleasepool {
            var obj: CoreDataSwift.NSManagedObject? = CoreDataSwift.NSEntityDescription.insertNewObject(forEntityName: "CDLifeEntity", into: moc)
            obj!.setValue("pending", forKey: "name")
            obj = nil   // NOT saved: insertedObjects still retains it
        }

        XCTAssertEqual(moc.registeredObjects.count, 1, "unsaved objects must survive the weak registry")
        XCTAssertEqual(try fetchCount(), 1)
    }

    func testTogglingRetainsRegisteredObjectsDropsStrongReferences() throws {
        try autoreleasepool {
            var obj: CoreDataSwift.NSManagedObject? = CoreDataSwift.NSEntityDescription.insertNewObject(forEntityName: "CDLifeEntity", into: moc)
            obj!.setValue("toggled", forKey: "name")
            try moc.save()
            obj = nil

            XCTAssertEqual(moc.registeredObjects.count, 1)
            moc.retainsRegisteredObjects = false   // didSet drops the strong refs
        }

        XCTAssertEqual(moc.registeredObjects.count, 0)
    }

    // MARK: In-memory store relationships

    func testInMemoryRelationshipsSurviveRefault() throws {
        let parent = CoreDataSwift.NSEntityDescription.insertNewObject(forEntityName: "CDLifeParent", into: moc)
        parent.setValue("parent", forKey: "name")
        let child = CoreDataSwift.NSEntityDescription.insertNewObject(forEntityName: "CDLifeChild", into: moc)
        child.setValue("child", forKey: "name")
        child.setValue(parent, forKey: "parent")
        try moc.save()

        moc.refresh(parent, mergeChanges: false)
        moc.refresh(child, mergeChanges: false)

        let children = parent.value(forKey: "children") as? Set<CoreDataSwift.NSManagedObject>
        XCTAssertEqual(children?.count, 1, "to-many relationship must reload from the in-memory store after a refault")
        XCTAssertTrue(children?.first === child)

        let childParent = child.value(forKey: "parent") as? CoreDataSwift.NSManagedObject
        XCTAssertTrue(childParent === parent, "to-one relationship must reload from the in-memory store after a refault")
    }
}

#endif
