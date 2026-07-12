//
//  NSManagedObjectContextBehaviorTests.swift
//  MIOCoreDataTests
//
//  Covers NSManagedObjectContext behavior contracts:
//  - hasChanges reflects the inserted/updated/deleted tracking sets
//  - perform/performAndWait execute their block
//  - fetchOffset past the end returns [] instead of trapping,
//    and fetchOffset+fetchLimit slice the sorted results correctly
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

class CDContextBehaviorEntity: CoreDataSwift.NSManagedObject {}

// MARK: - Test model

private let contextBehaviorModelXML = """
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<model type="com.apple.IDECoreDataModeler.DataModel" documentVersion="1.0">
    <entity name="CDContextBehaviorEntity" representedClassName="CDContextBehaviorEntity" syncable="YES">
        <attribute name="name" attributeType="String" optional="YES"/>
        <attribute name="counter" attributeType="Integer 32" optional="YES"/>
    </entity>
</model>
"""

private let registerContextBehaviorRuntimeClasses: Void = {
    _MIOCoreRegisterClass(type: CDContextBehaviorEntity.self, forKey: "CDContextBehaviorEntity")
}()

private func contextBehaviorModel() -> CoreDataSwift.NSManagedObjectModel {
    _ = registerContextBehaviorRuntimeClasses
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("CDContextBehaviorModel-\(ProcessInfo.processInfo.processIdentifier).xml")
    if FileManager.default.fileExists(atPath: url.path) == false {
        try! contextBehaviorModelXML.data(using: .utf8)!.write(to: url)
    }
    return CoreDataSwift.NSManagedObjectModel(contentsOf: url)!
}

// MARK: - Tests

final class NSManagedObjectContextBehaviorTests: XCTestCase
{
    var container: CoreDataSwift.NSPersistentContainer!
    var moc: CoreDataSwift.NSManagedObjectContext!

    override func setUp() {
        super.setUp()

        container = CoreDataSwift.NSPersistentContainer(name: "CDContextBehaviorTest", managedObjectModel: contextBehaviorModel())
        let description = CoreDataSwift.NSPersistentStoreDescription()
        description.type = CoreDataSwift.NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores { _, error in
            if let error = error { fatalError("Store failed to load: \(error)") }
        }
        moc = container.viewContext
    }

    @discardableResult
    private func insertEntity(name: String? = nil, counter: Int32? = nil) -> CoreDataSwift.NSManagedObject {
        let obj = CoreDataSwift.NSEntityDescription.insertNewObject(forEntityName: "CDContextBehaviorEntity", into: moc)
        if let name = name { obj.setValue(name, forKey: "name") }
        if let counter = counter { obj.setValue(counter, forKey: "counter") }
        return obj
    }

    // MARK: hasChanges

    func testHasChangesTracksPendingWork() throws {
        XCTAssertFalse(moc.hasChanges)

        let obj = insertEntity(name: "dirty")
        XCTAssertTrue(moc.hasChanges, "Insert must mark the context as having changes")

        try moc.save()
        XCTAssertFalse(moc.hasChanges, "Save must clear pending changes")

        obj.setValue("dirtier", forKey: "name")
        XCTAssertTrue(moc.hasChanges, "Update must mark the context as having changes")

        try moc.save()
        XCTAssertFalse(moc.hasChanges)

        moc.delete(obj)
        XCTAssertTrue(moc.hasChanges, "Delete must mark the context as having changes")
    }

    // MARK: perform / performAndWait

    func testPerformExecutesBlock() {
        var performed = false
        moc.perform { performed = true }
        XCTAssertTrue(performed, "perform must execute its block")

        var waited = false
        moc.performAndWait { waited = true }
        XCTAssertTrue(waited, "performAndWait must execute its block")
    }

    // MARK: fetchOffset

    func testFetchOffsetBeyondResultsReturnsEmpty() throws {
        insertEntity(name: "only-one")

        let request = CoreDataSwift.NSFetchRequest<CoreDataSwift.NSManagedObject>(entityName: "CDContextBehaviorEntity")
        request.fetchOffset = 1000
        let results = try moc.fetch(request)
        XCTAssertEqual(results.count, 0)
    }

    func testFetchOffsetAndLimitSliceCorrectly() throws {
        for i in 0..<5 { insertEntity(name: "obj-\(i)", counter: Int32(i)) }

        let request = CoreDataSwift.NSFetchRequest<CoreDataSwift.NSManagedObject>(entityName: "CDContextBehaviorEntity")
        request.sortDescriptors = [MIOSortDescriptor(key: "counter", ascending: true)]
        request.fetchOffset = 2
        request.fetchLimit = 2
        let results = try moc.fetch(request)

        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results.first?.value(forKey: "counter") as? Int32, 2)
        XCTAssertEqual(results.last?.value(forKey: "counter") as? Int32, 3)
    }
}

#endif
