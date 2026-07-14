//
//  FetchOrderingTests.swift
//  MIOCoreDataTests
//
//  The store executes the fetch in SQL — predicate, ORDER BY, limit, offset —
//  so its row order is authoritative. These tests pin that contract: fetch
//  must return incremental-store results in store order (no in-memory
//  re-sort), append pending unsaved objects after them, and honor fetchLimit.
//

#if !APPLE_CORE_DATA

import XCTest
import Foundation
import MIOCore
@testable import CoreDataSwift

// MARK: - Runtime class

class CDFetchOrderEntity: CoreDataSwift.NSManagedObject {}

// MARK: - Test model

private let fetchOrderModelXML = """
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<model type="com.apple.IDECoreDataModeler.DataModel" documentVersion="1.0">
    <entity name="CDFetchOrderEntity" representedClassName="CDFetchOrderEntity" syncable="YES">
        <attribute name="name" attributeType="String" optional="YES"/>
    </entity>
</model>
"""

private let registerFetchOrderRuntimeClasses: Void = {
    _MIOCoreRegisterClass(type: CDFetchOrderEntity.self, forKey: "CDFetchOrderEntity")
}()

private func fetchOrderModel() -> CoreDataSwift.NSManagedObjectModel {
    _ = registerFetchOrderRuntimeClasses
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("CDFetchOrderModel-\(ProcessInfo.processInfo.processIdentifier).xml")
    if FileManager.default.fileExists(atPath: url.path) == false {
        try! fetchOrderModelXML.data(using: .utf8)!.write(to: url)
    }
    return CoreDataSwift.NSManagedObjectModel(contentsOf: url)!
}

// MARK: - Stub incremental store

/// Returns canned rows in a fixed order — the way a SQL backend returns rows
/// already ordered by the query's ORDER BY.
struct StubRow {
    let id: UUID
    let name: String
}

class OrderedStubStore: CoreDataSwift.NSIncrementalStore
{
    static let storeType = "OrderedStubStore"

    /// Rows in "DB order". Deliberately NOT sorted by name.
    static var rows: [StubRow] = []

    override func loadMetadata() throws {
        self.metadata = [CoreDataSwift.NSStoreUUIDKey: UUID().uuidString, CoreDataSwift.NSStoreTypeKey: OrderedStubStore.storeType]
    }

    override func execute(_ request: CoreDataSwift.NSPersistentStoreRequest, with context: CoreDataSwift.NSManagedObjectContext?) throws -> Any {
        guard request is CoreDataSwift.NSFetchRequest<CoreDataSwift.NSManagedObject> else { return [] }
        return try OrderedStubStore.rows.map { row in
            let objID = newObjectID(for: (request as! CoreDataSwift.NSFetchRequest<CoreDataSwift.NSManagedObject>).entity!, referenceObject: row.id)
            return try context!.existingObject(with: objID)
        }
    }

    override func newValuesForObject(with objectID: CoreDataSwift.NSManagedObjectID, with context: CoreDataSwift.NSManagedObjectContext) throws -> CoreDataSwift.NSIncrementalStoreNode {
        let id = referenceObject(for: objectID) as! UUID
        let name = OrderedStubStore.rows.first { $0.id == id }?.name ?? ""
        return CoreDataSwift.NSIncrementalStoreNode(objectID: objectID, withValues: ["name": name], version: 1)
    }
}

// MARK: - Tests

final class FetchOrderingTests: XCTestCase
{
    var container: CoreDataSwift.NSPersistentContainer!
    var moc: CoreDataSwift.NSManagedObjectContext!

    override func setUp() {
        super.setUp()

        CoreDataSwift.NSPersistentStoreCoordinator.registerStoreClass(OrderedStubStore.self, forStoreType: OrderedStubStore.storeType)

        // "DB order": zebra, apple, mango — not alphabetical on purpose.
        OrderedStubStore.rows = [ StubRow(id: UUID(), name: "zebra"),
                                  StubRow(id: UUID(), name: "apple"),
                                  StubRow(id: UUID(), name: "mango") ]

        container = CoreDataSwift.NSPersistentContainer(name: "CDFetchOrderTest", managedObjectModel: fetchOrderModel())
        let description = CoreDataSwift.NSPersistentStoreDescription(url: URL(string: "stub-test://\(UUID().uuidString)")!)
        description.type = OrderedStubStore.storeType
        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores { _, error in
            if let error = error { fatalError("Store failed to load: \(error)") }
        }
        moc = container.viewContext
    }

    private func names(_ objs: [CoreDataSwift.NSManagedObject]) -> [String] {
        return objs.map { $0.value(forKey: "name") as! String }
    }

    func testFetchPreservesStoreOrderWithoutResorting() throws {
        let request = CoreDataSwift.NSFetchRequest<CoreDataSwift.NSManagedObject>(entityName: "CDFetchOrderEntity")
        // Sort descriptors are pushed to the store (ORDER BY). The stub returns
        // its fixed order — the context must NOT re-sort in memory.
        request.sortDescriptors = [ MIOSortDescriptor(key: "name", ascending: true) ]

        let results = try moc.fetch(request)

        XCTAssertEqual(names(results), ["zebra", "apple", "mango"], "fetch must keep the store's row order")
    }

    // MARK: includesPendingChanges == false (committed only)

    func testCommittedOnlyFetchExcludesUnsavedObjectsUntilSave() throws {
        let pending = CoreDataSwift.NSEntityDescription.insertNewObject(forEntityName: "CDFetchOrderEntity", into: moc)
        pending.setValue("banana", forKey: "name")

        let request = CoreDataSwift.NSFetchRequest<CoreDataSwift.NSManagedObject>(entityName: "CDFetchOrderEntity")
        request.includesPendingChanges = false

        // Before save: committed rows only — the unsaved object is absent.
        XCTAssertEqual(names(try moc.fetch(request)), ["zebra", "apple", "mango"])

        try moc.save()

        // Simulate the row the save just committed: the stub's "DB" learns it,
        // keyed by the permanent reference the store assigned at save time.
        let store = container.persistentStoreCoordinator.persistentStores[0] as! OrderedStubStore
        let permanentID = store.referenceObject(for: pending.objectID) as! UUID
        OrderedStubStore.rows.append(StubRow(id: permanentID, name: "banana"))

        // After save: the object is committed and fetch returns it.
        XCTAssertEqual(names(try moc.fetch(request)), ["zebra", "apple", "mango", "banana"])
    }

    // MARK: includesPendingChanges == true (Apple default)

    func testDefaultFetchIncludesPendingInsertedObjects() throws {
        let pending = CoreDataSwift.NSEntityDescription.insertNewObject(forEntityName: "CDFetchOrderEntity", into: moc)
        pending.setValue("banana", forKey: "name")

        let request = CoreDataSwift.NSFetchRequest<CoreDataSwift.NSManagedObject>(entityName: "CDFetchOrderEntity")
        let results = try moc.fetch(request)

        // Without sort descriptors the committed rows keep DB order and the
        // pending insert joins the results.
        XCTAssertEqual(Array(names(results).prefix(3)), ["zebra", "apple", "mango"])
        XCTAssertTrue(names(results).contains("banana"))
        XCTAssertEqual(results.count, 4)
    }

    func testPendingMergeResortsWhenSortDescriptorsPresent() throws {
        let pending = CoreDataSwift.NSEntityDescription.insertNewObject(forEntityName: "CDFetchOrderEntity", into: moc)
        pending.setValue("banana", forKey: "name")

        let request = CoreDataSwift.NSFetchRequest<CoreDataSwift.NSManagedObject>(entityName: "CDFetchOrderEntity")
        request.sortDescriptors = [ MIOSortDescriptor(key: "name", ascending: true) ]

        let results = try moc.fetch(request)

        // The merge changed the result set, so sort descriptors are applied
        // in memory to keep pending objects in their sorted position.
        XCTAssertEqual(names(results), ["apple", "banana", "mango", "zebra"])
    }

    func testPendingDeletedObjectsAreExcludedFromFetch() throws {
        let request = CoreDataSwift.NSFetchRequest<CoreDataSwift.NSManagedObject>(entityName: "CDFetchOrderEntity")
        let zebra = try moc.fetch(request).first { ($0.value(forKey: "name") as? String) == "zebra" }!

        moc.delete(zebra)

        XCTAssertEqual(names(try moc.fetch(request)), ["apple", "mango"])

        // Committed-only fetches still see the row until the delete is saved.
        let committedOnly = CoreDataSwift.NSFetchRequest<CoreDataSwift.NSManagedObject>(entityName: "CDFetchOrderEntity")
        committedOnly.includesPendingChanges = false
        XCTAssertEqual(names(try moc.fetch(committedOnly)), ["zebra", "apple", "mango"])
    }

    func testUpdatedObjectNoLongerMatchingPredicateIsExcluded() throws {
        let request = CoreDataSwift.NSFetchRequest<CoreDataSwift.NSManagedObject>(entityName: "CDFetchOrderEntity")
        let zebra = try moc.fetch(request).first { ($0.value(forKey: "name") as? String) == "zebra" }!

        zebra.setValue("aaa", forKey: "name")

        // The stub "DB" still matches the old value; the pending merge must
        // re-evaluate the updated object against its in-memory value and drop it.
        let filtered = CoreDataSwift.NSFetchRequest<CoreDataSwift.NSManagedObject>(entityName: "CDFetchOrderEntity")
        filtered.predicate = MIOPredicateWithFormat(format: "name contains 'z'")
        let results = try moc.fetch(filtered)

        XCTAssertFalse(names(results).contains("aaa"))
        XCTAssertFalse(names(results).contains("zebra"))
    }

    func testFetchLimitReappliedAfterPendingMerge() throws {
        let pending = CoreDataSwift.NSEntityDescription.insertNewObject(forEntityName: "CDFetchOrderEntity", into: moc)
        pending.setValue("aardvark", forKey: "name")

        let request = CoreDataSwift.NSFetchRequest<CoreDataSwift.NSManagedObject>(entityName: "CDFetchOrderEntity")
        request.sortDescriptors = [ MIOSortDescriptor(key: "name", ascending: true) ]
        request.fetchLimit = 2

        // The stub ignores the SQL limit and returns 3 rows; after the merge
        // (+1 pending) the limit must clamp the sorted results.
        let results = try moc.fetch(request)
        XCTAssertEqual(names(results), ["aardvark", "apple"])
    }
}

#endif
