//
//  MIOPredicateFormatArgumentsTests.swift
//  MIOCoreDataTests
//
//  Pins the placeholder-binding contract of MIOPredicateWithFormat on BOTH
//  implementations: under APPLE_CORE_DATA it wraps Foundation's NSPredicate,
//  otherwise CoreDataSwift's parser. Each element of `arguments` (or each
//  vararg) binds exactly one placeholder: `%K` a key path, `%@` a value, an
//  array value feeding IN. The Apple wrapper used to forward the whole array
//  as a single vararg, so `%K` received an NSArray and Foundation raised
//  NSInvalidArgumentException (-[NSArray rangeOfString:]) while parsing —
//  MIOPersistentStore's by-identifier relationship fetch hit it on every
//  to-one fault of a not-yet-cached object.
//
//  Only public API, only behaviour both implementations share.
//

import Foundation
import XCTest
import MIOCoreData

#if APPLE_CORE_DATA
private typealias FormatPredicate = NSPredicate
#else
private typealias FormatPredicate = MIOPredicate
#endif

final class MIOPredicateFormatArgumentsTests: XCTestCase {

    private func evaluate(_ predicate: FormatPredicate, _ values: [String: Any]) -> Bool {
        #if APPLE_CORE_DATA
        return predicate.evaluate(with: values)
        #else
        return MIOPredicateEvaluate(values: values, using: predicate)
        #endif
    }

    // The exact shape MIOPersistentStore.fetchObjects(identifiers:entityName:context:) builds.
    func testArgumentsArrayBindsKeyPathThenArrayForIn() {
        let a = "62E218D2-8F0C-4512-8D40-FFB0DDF4B06C"
        let b = "F6784CD8-5D16-457F-90A8-18A700D590A2"
        let predicate = MIOPredicateWithFormat(format: "%K in %@", arguments: ["identifier", [a, b]])

        XCTAssertTrue(evaluate(predicate, ["identifier": a]))
        XCTAssertTrue(evaluate(predicate, ["identifier": b]))
        XCTAssertFalse(evaluate(predicate, ["identifier": "0A0A0A0A-0000-0000-0000-000000000000"]))
        XCTAssertFalse(evaluate(predicate, ["name": a]))
    }

    func testArgumentsArrayInPredicateStructure() {
        let predicate = MIOPredicateWithFormat(format: "%K in %@", arguments: ["identifier", ["A", "B"]])

        #if APPLE_CORE_DATA
        guard let comparison = predicate as? NSComparisonPredicate else {
            return XCTFail("Expected a comparison predicate, got \(type(of: predicate))")
        }
        XCTAssertEqual(comparison.predicateOperatorType, .in)
        #else
        guard let comparison = predicate as? MIOComparisonPredicate else {
            return XCTFail("Expected a comparison predicate, got \(type(of: predicate))")
        }
        XCTAssertEqual(comparison.predicateOperatorType, .in)
        #endif
        XCTAssertEqual(comparison.leftExpression.keyPath, "identifier")
        XCTAssertEqual((comparison.rightExpression.constantValue as? [Any])?.count, 2)
    }

    func testArgumentsArrayBindsSeveralValuePlaceholdersInOrder() {
        let predicate = MIOPredicateWithFormat(format: "name == %@ AND quantity > %@", arguments: ["Cola", 2])

        XCTAssertTrue(evaluate(predicate, ["name": "Cola", "quantity": 3]))
        XCTAssertFalse(evaluate(predicate, ["name": "Cola", "quantity": 1]))
        XCTAssertFalse(evaluate(predicate, ["name": "Beer", "quantity": 3]))
    }

    func testVariadicBindsOnePlaceholderPerArgument() {
        let predicate = MIOPredicateWithFormat(format: "%K == %@", "name", "Cola")

        XCTAssertTrue(evaluate(predicate, ["name": "Cola"]))
        XCTAssertFalse(evaluate(predicate, ["name": "Beer"]))
    }

    func testVariadicBindsSeveralPlaceholdersInOrder() {
        let predicate = MIOPredicateWithFormat(format: "%K == %@ AND %K > %@", "name", "Cola", "quantity", 2)

        XCTAssertTrue(evaluate(predicate, ["name": "Cola", "quantity": 3]))
        XCTAssertFalse(evaluate(predicate, ["name": "Cola", "quantity": 2]))
    }

    func testFormatWithoutPlaceholders() {
        let predicate = MIOPredicateWithFormat(format: "name == 'Cola'")

        XCTAssertTrue(evaluate(predicate, ["name": "Cola"]))
        XCTAssertFalse(evaluate(predicate, ["name": "Beer"]))
    }
}
