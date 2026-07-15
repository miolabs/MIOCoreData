//
//  SortDescriptorTests.swift
//  MIOCoreDataTests
//
//  Covers Array.sortedArray(using:):
//  - multi-key sorting with mixed ascending/descending descriptors
//  - nil ordering matches the production database (Postgres): ascending puts
//    NULLs last, descending puts them first
//  - sort keys are extracted exactly once per element (decorate-sort),
//    not once per comparison
//
//  Self-contained: builds its model from inline XML.
//

#if !APPLE_CORE_DATA

import XCTest
import Foundation
import MIOCore
@testable import CoreDataSwift

// MARK: - Runtime classes

class CDSortEntity: CoreDataSwift.NSManagedObject {
    nonisolated(unsafe) static var kvcReads = 0

    override func value(forKey key: String) -> Any? {
        CDSortEntity.kvcReads += 1
        return super.value(forKey: key)
    }
}

// MARK: - Test model

private let sortModelXML = """
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<model type="com.apple.IDECoreDataModeler.DataModel" documentVersion="1.0">
    <entity name="CDSortEntity" representedClassName="CDSortEntity" syncable="YES">
        <attribute name="name" attributeType="String" optional="YES"/>
        <attribute name="group" attributeType="String" optional="YES"/>
        <attribute name="counter" attributeType="Integer 32" optional="YES"/>
    </entity>
</model>
"""

private let registerSortRuntimeClasses: Void = {
    _MIOCoreRegisterClass(type: CDSortEntity.self, forKey: "CDSortEntity")
}()

private func sortModel() -> CoreDataSwift.NSManagedObjectModel {
    _ = registerSortRuntimeClasses
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("CDSortModel-\(ProcessInfo.processInfo.processIdentifier).xml")
    if FileManager.default.fileExists(atPath: url.path) == false {
        try! sortModelXML.data(using: .utf8)!.write(to: url)
    }
    return CoreDataSwift.NSManagedObjectModel(contentsOf: url)!
}

// MARK: - Tests

final class SortDescriptorTests: XCTestCase
{
    var container: CoreDataSwift.NSPersistentContainer!
    var moc: CoreDataSwift.NSManagedObjectContext!

    override func setUp() {
        super.setUp()
        container = CoreDataSwift.NSPersistentContainer(name: "CDSortTest", managedObjectModel: sortModel())
        let description = CoreDataSwift.NSPersistentStoreDescription()
        description.type = CoreDataSwift.NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores { _, error in
            if let error = error { fatalError("\(error)") }
        }
        moc = container.viewContext
    }

    @discardableResult
    private func insertEntity(name: String? = nil, group: String? = nil, counter: Int32? = nil) -> CoreDataSwift.NSManagedObject {
        let obj = CoreDataSwift.NSEntityDescription.insertNewObject(forEntityName: "CDSortEntity", into: moc)
        if let name = name { obj.setValue(name, forKey: "name") }
        if let group = group { obj.setValue(group, forKey: "group") }
        if let counter = counter { obj.setValue(counter, forKey: "counter") }
        return obj
    }

    private func names(_ objs: [CoreDataSwift.NSManagedObject]) -> [String?] {
        return objs.map { $0.value(forKey: "name") as? String }
    }

    // MARK: Correctness

    func testMultiKeySortWithMixedDirections() {
        let objs = [
            insertEntity(name: "b2", group: "b", counter: 2),
            insertEntity(name: "a1", group: "a", counter: 1),
            insertEntity(name: "b9", group: "b", counter: 9),
            insertEntity(name: "a5", group: "a", counter: 5),
        ]

        let sorted = objs.sortedArray(using: [
            MIOSortDescriptor(key: "group", ascending: true),
            MIOSortDescriptor(key: "counter", ascending: false),
        ])

        XCTAssertEqual(names(sorted), ["a5", "a1", "b9", "b2"])
    }

    func testNilOrderingMatchesPostgres() {
        let objs = [
            insertEntity(name: "with-value", counter: 1),
            insertEntity(name: "nil-counter"),           // counter stays nil
            insertEntity(name: "with-bigger", counter: 5),
        ]

        // ASC: NULLS LAST (Postgres default for ascending)
        let ascending = objs.sortedArray(using: [MIOSortDescriptor(key: "counter", ascending: true)])
        XCTAssertEqual(names(ascending), ["with-value", "with-bigger", "nil-counter"])

        // DESC: NULLS FIRST (Postgres default for descending)
        let descending = objs.sortedArray(using: [MIOSortDescriptor(key: "counter", ascending: false)])
        XCTAssertEqual(names(descending), ["nil-counter", "with-bigger", "with-value"])
    }

    func testSortThroughRegistryFetch() throws {
        for i in [3, 1, 2] { insertEntity(name: "n\(i)", counter: Int32(i)) }

        let request = CoreDataSwift.NSFetchRequest<CoreDataSwift.NSManagedObject>(entityName: "CDSortEntity")
        request.sortDescriptors = [MIOSortDescriptor(key: "counter", ascending: true)]

        XCTAssertEqual(names(try moc.fetch(request)), ["n1", "n2", "n3"])
    }

    // MARK: Key extraction cost

    func testSortExtractsEachKeyExactlyOncePerElement() {
        let total = 64
        var objs: [CoreDataSwift.NSManagedObject] = []
        for i in 0..<total {
            objs.append(insertEntity(name: "n\(i)", counter: Int32((i * 31) % total)))
        }

        CDSortEntity.kvcReads = 0
        _ = objs.sortedArray(using: [MIOSortDescriptor(key: "counter", ascending: true)])

        // Decorate-sort: one value(forKey:) per element. The old comparator
        // performed two KVC reads per comparison — O(n log n), several
        // hundred for 64 elements.
        XCTAssertEqual(CDSortEntity.kvcReads, total)
    }
}

#endif
