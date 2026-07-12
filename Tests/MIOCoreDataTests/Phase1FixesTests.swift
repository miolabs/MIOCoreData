//
//  Phase1FixesTests.swift
//  MIOCoreDataTests
//
//  Regression tests for the audit Phase 1 correctness fixes:
//  - multiple %@ placeholders bind to consecutive arguments
//  - keyPath expressions on the right side of a comparison are evaluated
//  - NOT IN parses (as NOT(lhs IN rhs)) instead of trapping
//  - malformed formats and type-mismatched comparisons do not crash
//  - context.hasChanges reflects the real tracking sets
//  - perform/performAndWait execute their block
//  - fetchOffset past the end returns [] instead of trapping
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

class CDP1TestEntity: CoreDataSwift.NSManagedObject {}

// MARK: - Test model

private let phase1TestModelXML = """
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<model type="com.apple.IDECoreDataModeler.DataModel" documentVersion="1.0">
    <entity name="CDP1TestEntity" representedClassName="CDP1TestEntity" syncable="YES">
        <attribute name="name" attributeType="String" optional="YES"/>
        <attribute name="alias" attributeType="String" optional="YES"/>
        <attribute name="counter" attributeType="Integer 32" optional="YES"/>
    </entity>
</model>
"""

private let registerPhase1RuntimeClasses: Void = {
    _MIOCoreRegisterClass(type: CDP1TestEntity.self, forKey: "CDP1TestEntity")
}()

private func phase1TestModel() -> CoreDataSwift.NSManagedObjectModel {
    _ = registerPhase1RuntimeClasses
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("CDP1TestModel-\(ProcessInfo.processInfo.processIdentifier).xml")
    if FileManager.default.fileExists(atPath: url.path) == false {
        try! phase1TestModelXML.data(using: .utf8)!.write(to: url)
    }
    return CoreDataSwift.NSManagedObjectModel(contentsOf: url)!
}

// MARK: - Tests

final class Phase1FixesTests: XCTestCase
{
    var container: CoreDataSwift.NSPersistentContainer!
    var moc: CoreDataSwift.NSManagedObjectContext!

    override func setUp() {
        super.setUp()

        container = CoreDataSwift.NSPersistentContainer(name: "CDP1Test", managedObjectModel: phase1TestModel())
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
        let obj = CoreDataSwift.NSEntityDescription.insertNewObject(forEntityName: "CDP1TestEntity", into: moc)
        if let name = name { obj.setValue(name, forKey: "name") }
        if let counter = counter { obj.setValue(counter, forKey: "counter") }
        return obj
    }

    private func fetch(_ predicateFormat: String? = nil, arguments: [Any] = []) throws -> [CoreDataSwift.NSManagedObject] {
        let request = CoreDataSwift.NSFetchRequest<CoreDataSwift.NSManagedObject>(entityName: "CDP1TestEntity")
        if let format = predicateFormat {
            request.predicate = MIOPredicateWithFormat(format: format, arguments: arguments)
        }
        return try moc.fetch(request)
    }

    // MARK: Multiple %@ placeholders

    func testMultiplePlaceholdersBindConsecutiveArguments() {
        let predicate = MIOPredicateWithFormat(format: "name == %@ and counter == %@", arguments: ["pepe", 42])

        guard let cp = predicate as? MIOCompoundPredicate else {
            XCTFail("Expected MIOCompoundPredicate, got \(type(of: predicate))")
            return
        }
        guard let sub1 = cp.subpredicates[0] as? MIOComparisonPredicate,
              let sub2 = cp.subpredicates[1] as? MIOComparisonPredicate else {
            XCTFail("Expected two comparison subpredicates")
            return
        }

        XCTAssertEqual(sub1.rightExpression.constantValue as? String, "pepe", "First %@ must bind args[0]")
        XCTAssertEqual(sub2.rightExpression.constantValue as? Int, 42, "Second %@ must bind args[1]")
    }

    func testMultiplePlaceholdersEvaluation() throws {
        insertEntity(name: "pepe", counter: 42)
        insertEntity(name: "pepe", counter: 7)
        insertEntity(name: "otilio", counter: 42)

        let results = try fetch("name == %@ and counter == %@", arguments: ["pepe", 42])
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.value(forKey: "counter") as? Int32, 42)
    }

    // MARK: keyPath on the right side

    func testKeyPathOnRightSideIsEvaluated() throws {
        insertEntity(name: "same")
        let distinct = insertEntity(name: "distinct")
        distinct.setValue("other", forKey: "alias")
        moc.objectsByEntityName["CDP1TestEntity"]?.forEach { obj in
            if obj.value(forKey: "name") as? String == "same" { obj.setValue("same", forKey: "alias") }
        }

        // name == alias compares two keyPaths; with the old bug the right side
        // resolved to the LEFT keyPath, so nothing (or everything) matched.
        let results = try fetch("name == alias")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.value(forKey: "name") as? String, "same")
    }

    // MARK: NOT IN

    func testNotInParsesAsNegatedIn() {
        let predicate = MIOPredicateWithFormat(format: "counter not in %@", arguments: [[1, 2]])

        guard let notPredicate = predicate as? MIOCompoundPredicate else {
            XCTFail("Expected NOT compound predicate, got \(type(of: predicate))")
            return
        }
        XCTAssertEqual(notPredicate.compoundPredicateType, .not)

        guard let inner = notPredicate.subpredicates.first as? MIOComparisonPredicate else {
            XCTFail("Expected inner comparison predicate")
            return
        }
        XCTAssertEqual(inner.predicateOperatorType, .in)
    }

    func testNotInEvaluation() throws {
        insertEntity(name: "in-list", counter: 1)
        insertEntity(name: "not-in-list", counter: 5)

        let results = try fetch("counter not in %@", arguments: [[1, 2]])
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.value(forKey: "name") as? String, "not-in-list")
    }

    // MARK: Malformed input must not crash

    func testMalformedFormatReturnsMatchNothingPredicate() throws {
        insertEntity(name: "victim")

        // Incomplete expression: previously a try!/force-unwrap trap
        let incomplete = MIOPredicateWithFormat(format: "name ==")
        XCTAssertEqual(try fetch(nil).filter { MIOPredicateEvaluate(object: $0, using: incomplete) }.count, 0)

        // Empty format
        let empty = MIOPredicateWithFormat(format: "")
        XCTAssertEqual(try fetch(nil).filter { MIOPredicateEvaluate(object: $0, using: empty) }.count, 0)
    }

    func testTypeMismatchComparisonReturnsFalseInsteadOfCrashing() throws {
        insertEntity(name: "typed", counter: 3)

        // String attribute compared against a number: must be false, not a crash
        let results = try fetch("name == 5")
        XCTAssertEqual(results.count, 0)

        // String attribute ordered against a number: must be false, not a crash
        let ordered = try fetch("name < 5")
        XCTAssertEqual(ordered.count, 0)
    }

    // MARK: Context.hasChanges

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

        let request = CoreDataSwift.NSFetchRequest<CoreDataSwift.NSManagedObject>(entityName: "CDP1TestEntity")
        request.fetchOffset = 1000
        let results = try moc.fetch(request)
        XCTAssertEqual(results.count, 0)
    }

    func testFetchOffsetAndLimitSliceCorrectly() throws {
        for i in 0..<5 { insertEntity(name: "obj-\(i)", counter: Int32(i)) }

        let request = CoreDataSwift.NSFetchRequest<CoreDataSwift.NSManagedObject>(entityName: "CDP1TestEntity")
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
