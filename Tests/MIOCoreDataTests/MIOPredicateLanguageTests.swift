//
//  MIOPredicateLanguageTests.swift
//  MIOCoreDataTests
//
//  Covers the predicate language features added with the hand-written
//  scanner/parser:
//  - BEGINSWITH / ENDSWITH / LIKE / MATCHES / BETWEEN
//  - case/diacritic option suffixes ([c], [d], [cd])
//  - ANY / ALL modifiers over to-many relationships
//  - %K keypath placeholder
//  - operators without surrounding whitespace ("a==1 AND(b==2)")
//  - parse throughput smoke check (token cache)
//
//  Self-contained: builds its model from inline XML.
//

#if !APPLE_CORE_DATA

import XCTest
import Foundation
import MIOCore
@testable import CoreDataSwift

// MARK: - Runtime classes

class CDLangEntity: CoreDataSwift.NSManagedObject {}
class CDLangParent: CoreDataSwift.NSManagedObject {}
class CDLangChild: CoreDataSwift.NSManagedObject {}

// MARK: - Test model

private let langModelXML = """
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<model type="com.apple.IDECoreDataModeler.DataModel" documentVersion="1.0">
    <entity name="CDLangEntity" representedClassName="CDLangEntity" syncable="YES">
        <attribute name="name" attributeType="String" optional="YES"/>
        <attribute name="counter" attributeType="Integer 32" optional="YES"/>
    </entity>
    <entity name="CDLangParent" representedClassName="CDLangParent" syncable="YES">
        <attribute name="name" attributeType="String" optional="YES"/>
        <relationship name="children" destinationEntity="CDLangChild" toMany="YES" optional="YES" inverseName="parent" inverseEntity="CDLangChild" deletionRule="Nullify"/>
    </entity>
    <entity name="CDLangChild" representedClassName="CDLangChild" syncable="YES">
        <attribute name="name" attributeType="String" optional="YES"/>
        <relationship name="parent" destinationEntity="CDLangParent" optional="YES" inverseName="children" inverseEntity="CDLangParent" deletionRule="Nullify"/>
    </entity>
</model>
"""

private let registerLangRuntimeClasses: Void = {
    _MIOCoreRegisterClass(type: CDLangEntity.self, forKey: "CDLangEntity")
    _MIOCoreRegisterClass(type: CDLangParent.self, forKey: "CDLangParent")
    _MIOCoreRegisterClass(type: CDLangChild.self, forKey: "CDLangChild")
}()

private func langModel() -> CoreDataSwift.NSManagedObjectModel {
    _ = registerLangRuntimeClasses
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("CDLangModel-\(ProcessInfo.processInfo.processIdentifier).xml")
    if FileManager.default.fileExists(atPath: url.path) == false {
        try! langModelXML.data(using: .utf8)!.write(to: url)
    }
    return CoreDataSwift.NSManagedObjectModel(contentsOf: url)!
}

// MARK: - Tests

final class MIOPredicateLanguageTests: XCTestCase
{
    var container: CoreDataSwift.NSPersistentContainer!
    var moc: CoreDataSwift.NSManagedObjectContext!

    override func setUp() {
        super.setUp()
        container = CoreDataSwift.NSPersistentContainer(name: "CDLangTest", managedObjectModel: langModel())
        let description = CoreDataSwift.NSPersistentStoreDescription()
        description.type = CoreDataSwift.NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores { _, error in
            if let error = error { fatalError("\(error)") }
        }
        moc = container.viewContext
    }

    @discardableResult
    private func insertEntity(name: String? = nil, counter: Int32? = nil) -> CoreDataSwift.NSManagedObject {
        let obj = CoreDataSwift.NSEntityDescription.insertNewObject(forEntityName: "CDLangEntity", into: moc)
        if let name = name { obj.setValue(name, forKey: "name") }
        if let counter = counter { obj.setValue(counter, forKey: "counter") }
        return obj
    }

    private func fetchNames(_ format: String, arguments: [Any] = []) throws -> Set<String> {
        let request = CoreDataSwift.NSFetchRequest<CoreDataSwift.NSManagedObject>(entityName: "CDLangEntity")
        request.predicate = MIOPredicateWithFormat(format: format, arguments: arguments)
        return Set(try moc.fetch(request).compactMap { $0.value(forKey: "name") as? String })
    }

    // MARK: String operators

    func testBeginsWithAndEndsWith() throws {
        insertEntity(name: "prefix-match")
        insertEntity(name: "match-suffix")
        insertEntity(name: "neither")

        XCTAssertEqual(try fetchNames("name BEGINSWITH 'prefix'"), ["prefix-match"])
        XCTAssertEqual(try fetchNames("name ENDSWITH 'suffix'"), ["match-suffix"])
    }

    func testCaseAndDiacriticInsensitiveOptions() throws {
        insertEntity(name: "Café con Leche")
        insertEntity(name: "tea")

        XCTAssertEqual(try fetchNames("name CONTAINS[c] 'café'"), ["Café con Leche"])
        XCTAssertEqual(try fetchNames("name CONTAINS[cd] 'CAFE'"), ["Café con Leche"])
        XCTAssertEqual(try fetchNames("name ==[c] 'TEA'"), ["tea"])
        XCTAssertEqual(try fetchNames("name CONTAINS 'CAFE'"), [], "without options the match stays case/diacritic sensitive")
    }

    func testLikeWildcards() throws {
        insertEntity(name: "invoice-2026-001.pdf")
        insertEntity(name: "invoice-2026-001.txt")
        insertEntity(name: "receipt-2026-001.pdf")

        XCTAssertEqual(try fetchNames("name LIKE 'invoice-*.pdf'"), ["invoice-2026-001.pdf"])
        XCTAssertEqual(try fetchNames("name LIKE '*-2026-00?.pdf'"), ["invoice-2026-001.pdf", "receipt-2026-001.pdf"])
    }

    func testMatchesRegularExpression() throws {
        insertEntity(name: "ABC-123")
        insertEntity(name: "ABC-12X")

        XCTAssertEqual(try fetchNames("name MATCHES '[A-Z]{3}-[0-9]{3}'"), ["ABC-123"])
    }

    func testBetween() throws {
        insertEntity(name: "low", counter: 1)
        insertEntity(name: "mid", counter: 3)
        insertEntity(name: "edge", counter: 5)
        insertEntity(name: "high", counter: 9)

        XCTAssertEqual(try fetchNames("counter BETWEEN {2, 5}"), ["mid", "edge"])
    }

    // MARK: ANY / ALL

    func testAnyAndAllOverToManyRelationship() throws {
        func makeParent(_ name: String, childNames: [String]) {
            let parent = CoreDataSwift.NSEntityDescription.insertNewObject(forEntityName: "CDLangParent", into: moc)
            parent.setValue(name, forKey: "name")
            for childName in childNames {
                let child = CoreDataSwift.NSEntityDescription.insertNewObject(forEntityName: "CDLangChild", into: moc)
                child.setValue(childName, forKey: "name")
                child.setValue(parent, forKey: "parent")
            }
        }
        makeParent("mixed", childNames: ["ready", "pending"])
        makeParent("all-ready", childNames: ["ready", "ready"])
        makeParent("empty", childNames: [])

        let request = CoreDataSwift.NSFetchRequest<CoreDataSwift.NSManagedObject>(entityName: "CDLangParent")

        request.predicate = MIOPredicateWithFormat(format: "ANY children.name == 'ready'")
        XCTAssertEqual(Set(try moc.fetch(request).compactMap { $0.value(forKey: "name") as? String }), ["mixed", "all-ready"])

        request.predicate = MIOPredicateWithFormat(format: "ALL children.name == 'ready'")
        // ALL over an empty collection is vacuously true, like Apple
        XCTAssertEqual(Set(try moc.fetch(request).compactMap { $0.value(forKey: "name") as? String }), ["all-ready", "empty"])
    }

    // MARK: Object arguments (the "relationship == %@" idiom)

    func testRelationshipEqualsManagedObjectArgument() throws {
        let parentA = CoreDataSwift.NSEntityDescription.insertNewObject(forEntityName: "CDLangParent", into: moc)
        parentA.setValue("A", forKey: "name")
        let parentB = CoreDataSwift.NSEntityDescription.insertNewObject(forEntityName: "CDLangParent", into: moc)
        parentB.setValue("B", forKey: "name")

        for (name, parent) in [("childA1", parentA), ("childA2", parentA), ("childB", parentB)] {
            let child = CoreDataSwift.NSEntityDescription.insertNewObject(forEntityName: "CDLangChild", into: moc)
            child.setValue(name, forKey: "name")
            child.setValue(parent, forKey: "parent")
        }

        let request = CoreDataSwift.NSFetchRequest<CoreDataSwift.NSManagedObject>(entityName: "CDLangChild")

        request.predicate = MIOPredicateWithFormat(format: "parent == %@", arguments: [parentA])
        XCTAssertEqual(Set(try moc.fetch(request).compactMap { $0.value(forKey: "name") as? String }), ["childA1", "childA2"])

        request.predicate = MIOPredicateWithFormat(format: "parent != %@", arguments: [parentA])
        XCTAssertEqual(Set(try moc.fetch(request).compactMap { $0.value(forKey: "name") as? String }), ["childB"])

        // objectID as the argument works the same way
        request.predicate = MIOPredicateWithFormat(format: "parent == %@", arguments: [parentB.objectID])
        XCTAssertEqual(Set(try moc.fetch(request).compactMap { $0.value(forKey: "name") as? String }), ["childB"])

        // and IN with a collection of objects
        request.predicate = MIOPredicateWithFormat(format: "parent IN %@", arguments: [[parentA, parentB]])
        XCTAssertEqual(try moc.fetch(request).count, 3)
    }

    func testSelfEqualsObjectArgument() throws {
        let target = insertEntity(name: "the-one")
        insertEntity(name: "other")

        let request = CoreDataSwift.NSFetchRequest<CoreDataSwift.NSManagedObject>(entityName: "CDLangEntity")

        // Query-by-object, Apple style: SELF == %@ with the object or its ID
        request.predicate = MIOPredicateWithFormat(format: "SELF == %@", arguments: [target])
        var results = try moc.fetch(request)
        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results.first === target)

        request.predicate = MIOPredicateWithFormat(format: "SELF == %@", arguments: [target.objectID])
        results = try moc.fetch(request)
        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results.first === target)

        request.predicate = MIOPredicateWithFormat(format: "SELF IN %@", arguments: [[target]])
        XCTAssertEqual(try moc.fetch(request).count, 1)
    }

    // MARK: Placeholders and whitespace

    func testKeyPathPlaceholder() throws {
        insertEntity(name: "target", counter: 7)
        insertEntity(name: "other", counter: 1)

        XCTAssertEqual(try fetchNames("%K == %@", arguments: ["counter", 7]), ["target"])
    }

    func testOperatorsWithoutWhitespace() throws {
        insertEntity(name: "a", counter: 1)
        insertEntity(name: "b", counter: 2)

        XCTAssertEqual(try fetchNames("counter==1 AND(name=='a')"), ["a"])
        XCTAssertEqual(try fetchNames("counter==1||counter==2"), ["a", "b"])
    }

    // MARK: Parse tree spot checks

    func testBeginsWithParseTree() {
        let predicate = MIOPredicateWithFormat(format: "name BEGINSWITH[cd] 'x'")
        guard let cmp = predicate as? MIOComparisonPredicate else {
            XCTFail("Expected comparison predicate")
            return
        }
        XCTAssertEqual(cmp.predicateOperatorType, .beginsWith)
        XCTAssertTrue(cmp.options.contains(.caseInsensitive))
        XCTAssertTrue(cmp.options.contains(.diacriticInsensitive))
    }

    func testAnyParseTree() {
        let predicate = MIOPredicateWithFormat(format: "ANY children.name == 'x'")
        guard let cmp = predicate as? MIOComparisonPredicate else {
            XCTFail("Expected comparison predicate")
            return
        }
        XCTAssertEqual(cmp.comparisonPredicateModifier, .any)
        XCTAssertEqual(cmp.leftExpression.keyPath, "children.name")
    }

    // MARK: Throughput smoke check

    func testParseThroughput() {
        let format = "cashDesk.identifier = '3CEF7AEA-11C2-48AB-B289-C3C02E6A38A6' and isOpen = true and deletedAt = null and beginDate <= '2021-05-25 23:11:32.050000' and (endDate = null or endDate >= '2021-05-25 23:11:32.050000')"

        let start = Date()
        let iterations = 10_000
        for _ in 0..<iterations {
            _ = MIOPredicateWithFormat(format: format)
        }
        let elapsed = Date().timeIntervalSince(start)
        print("== predicate parse throughput: \(iterations) parses in \(String(format: "%.3f", elapsed))s (\(String(format: "%.1f", Double(iterations) / elapsed)) parses/s)")

        // Generous ceiling — the old regex lexer needed ~1ms+ per parse of
        // this format; the scanner + token cache should be far under it
        XCTAssertLessThan(elapsed, 5.0)
    }
}

#endif
