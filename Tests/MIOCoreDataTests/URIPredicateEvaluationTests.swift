//
//  URIPredicateEvaluationTests.swift
//  MIOCoreDataTests
//
//  A URI attribute holds a URL in memory, so the in-memory predicate
//  evaluator (in-memory store fetches, cached-object filtering) must compare
//  it against both a URL argument and its string form.
//

#if !APPLE_CORE_DATA

import XCTest
import Foundation
import MIOCore
@testable import CoreDataSwift

// MARK: - Runtime classes

class CDURIPredicateEntity: CoreDataSwift.NSManagedObject {}

// MARK: - Test model

private let uriPredicateModelXML = """
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<model type="com.apple.IDECoreDataModeler.DataModel" documentVersion="1.0">
    <entity name="CDURIPredicateEntity" representedClassName="CDURIPredicateEntity" syncable="YES">
        <attribute name="name" attributeType="String" optional="YES"/>
        <attribute name="link" attributeType="URI" optional="YES"/>
    </entity>
</model>
"""

private let registerURIPredicateRuntimeClasses: Void = {
    _MIOCoreRegisterClass(type: CDURIPredicateEntity.self, forKey: "CDURIPredicateEntity")
}()

private func uriPredicateModel() -> CoreDataSwift.NSManagedObjectModel {
    _ = registerURIPredicateRuntimeClasses
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("CDURIPredicateModel-\(ProcessInfo.processInfo.processIdentifier).xml")
    if FileManager.default.fileExists(atPath: url.path) == false {
        try! uriPredicateModelXML.data(using: .utf8)!.write(to: url)
    }
    return CoreDataSwift.NSManagedObjectModel(contentsOf: url)!
}

// MARK: - Tests

final class URIPredicateEvaluationTests: XCTestCase
{
    var container: CoreDataSwift.NSPersistentContainer!
    var moc: CoreDataSwift.NSManagedObjectContext!

    let docs = URL(string: "https://dual-link.com/docs")!
    let home = URL(string: "https://dual-link.com/")!

    override func setUp() {
        super.setUp()
        container = CoreDataSwift.NSPersistentContainer(name: "CDURIPredicateTest", managedObjectModel: uriPredicateModel())
        let description = CoreDataSwift.NSPersistentStoreDescription()
        description.type = CoreDataSwift.NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores { _, error in
            if let error = error { fatalError("Store failed to load: \(error)") }
        }
        moc = container.viewContext
        for (name, link) in [("docs", docs), ("home", home)] {
            let obj = CoreDataSwift.NSEntityDescription.insertNewObject(forEntityName: "CDURIPredicateEntity", into: moc)
            obj.setValue(name, forKey: "name")
            obj.setValue(link, forKey: "link")
        }
    }

    private func fetch(_ format: String, _ arguments: [Any] = []) throws -> [String] {
        let request = CoreDataSwift.NSFetchRequest<CoreDataSwift.NSManagedObject>(entityName: "CDURIPredicateEntity")
        request.predicate = MIOPredicateWithFormat(format: format, arguments: arguments)
        return try moc.fetch(request).compactMap { $0.value(forKey: "name") as? String }.sorted()
    }

    func testEqualsURLArgument() throws {
        XCTAssertEqual(try fetch("link == %@", [docs]), ["docs"])
    }

    func testEqualsStringArgumentMatchesTheAbsoluteString() throws {
        XCTAssertEqual(try fetch("link == %@", ["https://dual-link.com/docs"]), ["docs"])
        XCTAssertEqual(try fetch("link != %@", ["https://dual-link.com/docs"]), ["home"])
    }

    func testEqualsStringLiteralInFormat() throws {
        XCTAssertEqual(try fetch("link == 'https://dual-link.com/'"), ["home"])
    }

    func testInStringList() throws {
        XCTAssertEqual(try fetch("link IN %@", [["https://dual-link.com/", "https://dual-link.com/docs"]]), ["docs", "home"])
        XCTAssertEqual(try fetch("link IN %@", [["https://dual-link.com/"]]), ["home"])
    }

    func testInURLList() throws {
        XCTAssertEqual(try fetch("link IN %@", [[docs]]), ["docs"])
    }
}

#endif
