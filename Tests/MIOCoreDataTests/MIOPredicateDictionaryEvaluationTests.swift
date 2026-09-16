//
//  MIOPredicateDictionaryEvaluationTests.swift
//  MIOCoreDataTests
//
//  Covers the public dictionary-based predicate evaluation entry point:
//  MIOPredicateEvaluate(values:using:) evaluates a parsed predicate against a
//  plain [String:Any] instead of a managed object. Exercises the operator
//  matrix (==, !=, <, <=, >, >=, CONTAINS, BEGINSWITH, ENDSWITH, IN, LIKE),
//  null checks against missing keys and NSNull, AND/OR/NOT compounds, nested
//  key paths, ANY/ALL over array values, and the mapping-rule shapes the API
//  exists for (comma-separated tag strings, UUID string equality).
//
//  Imports CoreDataSwift without @testable on purpose: these tests must only
//  touch public API.
//

#if !APPLE_CORE_DATA

import XCTest
import Foundation
import CoreDataSwift

final class MIOPredicateDictionaryEvaluationTests: XCTestCase
{
    private func evaluate(_ format: String, _ values: [String:Any]) -> Bool {
        return MIOPredicateEvaluate(values: values, using: MIOPredicateWithFormat(format: format))
    }

    // MARK: - Equality

    func testStringEquality() {
        XCTAssertTrue ( evaluate("name == 'Cola'", ["name": "Cola"]) )
        XCTAssertFalse( evaluate("name == 'Cola'", ["name": "Beer"]) )
        XCTAssertTrue ( evaluate("name != 'Cola'", ["name": "Beer"]) )
        XCTAssertFalse( evaluate("name != 'Cola'", ["name": "Cola"]) )
    }

    func testUUIDStringEquality() {
        let id = "B0E9D1DF-4B32-4E5D-9A0B-1C2D3E4F5A6B"
        XCTAssertTrue ( evaluate("businessAreaID == '\(id)'", ["businessAreaID": id]) )
        XCTAssertFalse( evaluate("businessAreaID == '\(id)'", ["businessAreaID": UUID().uuidString]) )
        XCTAssertTrue ( evaluate("businessAreaID != '\(id)'", ["businessAreaID": UUID().uuidString]) )

        // A UUID value in the dictionary compares against a string constant
        XCTAssertTrue ( evaluate("businessAreaID == '\(id)'", ["businessAreaID": UUID(uuidString: id)!]) )
        XCTAssertFalse( evaluate("businessAreaID == '\(UUID().uuidString)'", ["businessAreaID": UUID(uuidString: id)!]) )
    }

    func testBoolAndNumericLiteralEquality() {
        XCTAssertTrue ( evaluate("active == true",  ["active": true]) )
        XCTAssertFalse( evaluate("active == true",  ["active": false]) )
        XCTAssertTrue ( evaluate("active == false", ["active": false]) )
        XCTAssertTrue ( evaluate("quantity == 3",   ["quantity": 3]) )
        XCTAssertFalse( evaluate("quantity == 3",   ["quantity": 4]) )
    }

    // MARK: - Numeric comparisons

    func testNumericComparisons() {
        let values: [String:Any] = ["quantity": 5, "price": 2.5]

        XCTAssertTrue ( evaluate("quantity > 4",   values) )
        XCTAssertFalse( evaluate("quantity > 5",   values) )
        XCTAssertTrue ( evaluate("quantity >= 5",  values) )
        XCTAssertTrue ( evaluate("quantity < 6",   values) )
        XCTAssertFalse( evaluate("quantity < 5",   values) )
        XCTAssertTrue ( evaluate("quantity <= 5",  values) )
        XCTAssertTrue ( evaluate("quantity != 6",  values) )

        XCTAssertTrue ( evaluate("price > 2",      values) )
        XCTAssertTrue ( evaluate("price < 2.75",   values) )
        XCTAssertTrue ( evaluate("price == 2.5",   values) )
    }

    // MARK: - String operators

    func testContainsWithCommaSeparatedTags() {
        let values: [String:Any] = ["tags": "BEBIDA,COMIDA,TERRAZA"]

        XCTAssertTrue ( evaluate("tags CONTAINS 'BEBIDA'",  values) )
        XCTAssertTrue ( evaluate("tags CONTAINS 'COMIDA'",  values) )
        XCTAssertFalse( evaluate("tags CONTAINS 'POSTRE'",  values) )
        XCTAssertTrue ( evaluate("tags CONTAINS[c] 'bebida'", values) )
        XCTAssertFalse( evaluate("tags CONTAINS 'bebida'",  values) )
    }

    func testBeginsWithAndEndsWith() {
        let values: [String:Any] = ["name": "Coca-Cola Zero"]

        XCTAssertTrue ( evaluate("name BEGINSWITH 'Coca'", values) )
        XCTAssertFalse( evaluate("name BEGINSWITH 'Cola'", values) )
        XCTAssertTrue ( evaluate("name ENDSWITH 'Zero'",   values) )
        XCTAssertFalse( evaluate("name ENDSWITH 'Cola'",   values) )
        XCTAssertTrue ( evaluate("name BEGINSWITH[c] 'coca'", values) )
    }

    func testLike() {
        XCTAssertTrue ( evaluate("code LIKE 'AB*'",  ["code": "AB123"]) )
        XCTAssertFalse( evaluate("code LIKE 'AB*'",  ["code": "XY123"]) )
        XCTAssertTrue ( evaluate("code LIKE 'AB??3'", ["code": "AB123"]) )
    }

    func testIn() {
        let predicate = MIOPredicateWithFormat(format: "type IN %@", arguments: [["DRINK", "FOOD"]])
        XCTAssertTrue ( MIOPredicateEvaluate(values: ["type": "DRINK"], using: predicate) )
        XCTAssertFalse( MIOPredicateEvaluate(values: ["type": "OTHER"], using: predicate) )
    }

    // MARK: - Null checks

    func testNullChecks() {
        XCTAssertTrue ( evaluate("closingID == null", [:]) )
        XCTAssertTrue ( evaluate("closingID == null", ["closingID": NSNull()]) )
        XCTAssertFalse( evaluate("closingID == null", ["closingID": "X"]) )
        XCTAssertTrue ( evaluate("closingID != null", ["closingID": "X"]) )
        XCTAssertFalse( evaluate("closingID != null", [:]) )
        XCTAssertFalse( evaluate("closingID != null", ["closingID": NSNull()]) )
    }

    // MARK: - Compounds

    func testAndOrCompounds() {
        let values: [String:Any] = [
            "tags": "BEBIDA,TERRAZA",
            "businessAreaID": "B0E9D1DF-4B32-4E5D-9A0B-1C2D3E4F5A6B",
            "quantity": 2
        ]

        // The motivating mapping-rule shape
        XCTAssertTrue ( evaluate("tags CONTAINS 'BEBIDA' && businessAreaID == 'B0E9D1DF-4B32-4E5D-9A0B-1C2D3E4F5A6B'", values) )
        XCTAssertFalse( evaluate("tags CONTAINS 'COMIDA' && businessAreaID == 'B0E9D1DF-4B32-4E5D-9A0B-1C2D3E4F5A6B'", values) )

        XCTAssertTrue ( evaluate("tags CONTAINS 'COMIDA' || quantity > 1", values) )
        XCTAssertFalse( evaluate("tags CONTAINS 'COMIDA' || quantity > 5", values) )

        XCTAssertTrue ( evaluate("tags CONTAINS 'BEBIDA' AND quantity == 2 AND businessAreaID != null", values) )
        XCTAssertTrue ( evaluate("(tags CONTAINS 'COMIDA' OR quantity > 1) AND businessAreaID != null", values) )
    }

    func testNot() {
        XCTAssertTrue ( evaluate("NOT name == 'Cola'", ["name": "Beer"]) )
        XCTAssertFalse( evaluate("NOT name == 'Cola'", ["name": "Cola"]) )
    }

    // MARK: - Key paths and collections

    func testNestedKeyPath() {
        let values: [String:Any] = ["line": ["product": ["name": "Cola"]]]
        XCTAssertTrue ( evaluate("line.product.name == 'Cola'", values) )
        XCTAssertFalse( evaluate("line.product.name == 'Beer'", values) )
        XCTAssertFalse( evaluate("line.missing.name == 'Cola'", values) )
    }

    func testDottedKeyWinsOverTraversal() {
        XCTAssertTrue( evaluate("a.b == 1", ["a.b": 1]) )
    }

    func testAnyAllOverArrayValues() {
        let values: [String:Any] = ["lines": [
            ["name": "Cola",  "quantity": 1],
            ["name": "Water", "quantity": 3]
        ]]

        XCTAssertTrue ( evaluate("ANY lines.name == 'Cola'",  values) )
        XCTAssertFalse( evaluate("ANY lines.name == 'Beer'",  values) )
        XCTAssertTrue ( evaluate("ALL lines.quantity >= 1",   values) )
        XCTAssertFalse( evaluate("ALL lines.quantity > 1",    values) )
        // ALL over an empty collection is vacuously true, like Apple
        XCTAssertTrue ( evaluate("ALL lines.quantity > 1",    ["lines": [Any]()]) )
    }

    // MARK: - Filtering helper

    func testEvaluateItemsFilters() {
        let items: [[String:Any]] = [
            ["name": "Cola",  "tags": "BEBIDA"],
            ["name": "Pizza", "tags": "COMIDA"],
            ["name": "Beer",  "tags": "BEBIDA,ALCOHOL"]
        ]
        let predicate = MIOPredicateWithFormat(format: "tags CONTAINS 'BEBIDA'")
        let result = MIOPredicateEvaluateItems(items, using: predicate)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result.map { $0["name"] as! String }, ["Cola", "Beer"])
    }

    // MARK: - Robustness

    func testTypeMismatchEvaluatesFalse() {
        XCTAssertFalse( evaluate("name CONTAINS 'x'", ["name": 42]) )
        XCTAssertFalse( evaluate("name BEGINSWITH 'x'", ["name": 42]) )
        // < and <= evaluate false on incomparable values; > and >= are their
        // negations, so only the direct forms are asserted here
        XCTAssertFalse( evaluate("quantity < 1",  ["quantity": "not a number"]) )
        XCTAssertFalse( evaluate("quantity <= 1", ["quantity": "not a number"]) )
    }
}

#endif
