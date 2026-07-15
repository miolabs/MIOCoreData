//
//  AttributeValueConversionTests.swift
//  MIOCoreDataTests
//
//  Full matrix for NSAttributeDescription.coreDataValue(from:) — the
//  canonical transport-value converter:
//  - every attribute type x accepted input shapes
//  - nil/NSNull resolves to the model default (nil when there is none)
//  - failed conversions throw naming entity.attribute (never silent nil)
//

#if !APPLE_CORE_DATA

import XCTest
import Foundation
import MIOCore
import MIOCoreData
@testable import CoreDataSwift

final class AttributeValueConversionTests: XCTestCase
{
    private var entity: CoreDataSwift.NSEntityDescription!

    override func setUp() {
        super.setUp()
        entity = CoreDataSwift.NSEntityDescription()
        entity._name = "ConvEntity"
    }

    private func attribute(_ type: CoreDataSwift.NSAttributeType, default defaultValue: Any? = nil) -> CoreDataSwift.NSAttributeDescription {
        return entity.addAttribute(name: "attr", type: type, defaultValue: defaultValue, optional: true, transient: false)
    }

    private func assertThrows(_ attr: CoreDataSwift.NSAttributeDescription, _ value: Any, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertThrowsError(try attr.coreDataValue(from: value), file: file, line: line) { error in
            guard case NSAttributeValueConversionError.cannotConvert = error else {
                XCTFail("Expected cannotConvert, got \(error)", file: file, line: line)
                return
            }
        }
    }

    // MARK: nil handling

    func testNilResolvesToModelDefault() throws {
        let attr = attribute(.integer32AttributeType, default: Int32(7))
        XCTAssertEqual(try attr.coreDataValue(from: nil) as? Int32, 7)
        XCTAssertEqual(try attr.coreDataValue(from: NSNull()) as? Int32, 7)
    }

    func testNilWithoutDefaultStaysNil() throws {
        let attr = attribute(.stringAttributeType)
        XCTAssertNil(try attr.coreDataValue(from: nil))
        XCTAssertNil(try attr.coreDataValue(from: NSNull()))
    }

    // MARK: Date

    func testDateConversions() throws {
        let attr = attribute(.dateAttributeType)
        let date = Date(timeIntervalSince1970: 1_000_000)
        XCTAssertEqual(try attr.coreDataValue(from: date) as? Date, date)
        XCTAssertNotNil(try attr.coreDataValue(from: "2021-05-25 23:11:32") as? Date)
        assertThrows(attr, "not a date")
    }

    // MARK: UUID

    func testUUIDConversions() throws {
        let attr = attribute(.UUIDAttributeType)
        let uuid = UUID()
        XCTAssertEqual(try attr.coreDataValue(from: uuid) as? UUID, uuid)
        XCTAssertEqual(try attr.coreDataValue(from: uuid.uuidString) as? UUID, uuid)
        assertThrows(attr, "not-a-uuid")
    }

    // MARK: String

    func testStringConversions() throws {
        let attr = attribute(.stringAttributeType)
        XCTAssertEqual(try attr.coreDataValue(from: "plain") as? String, "plain")
        XCTAssertEqual(try attr.coreDataValue(from: 42) as? String, "42")

        let uuid = UUID()
        XCTAssertEqual(try attr.coreDataValue(from: uuid) as? String, uuid.uuidString.uppercased())
    }

    // MARK: Bool

    func testBooleanConversions() throws {
        let attr = attribute(.booleanAttributeType)
        XCTAssertEqual(try attr.coreDataValue(from: true) as? Bool, true)
        XCTAssertEqual(try attr.coreDataValue(from: 1) as? Bool, true)
        XCTAssertEqual(try attr.coreDataValue(from: 0) as? Bool, false)
    }

    // MARK: Integers

    func testIntegerConversions() throws {
        XCTAssertEqual(try attribute(.integer16AttributeType).coreDataValue(from: 42) as? Int16, 42)
        XCTAssertEqual(try attribute(.integer32AttributeType).coreDataValue(from: "42") as? Int32, 42)
        XCTAssertEqual(try attribute(.integer64AttributeType).coreDataValue(from: 42) as? Int64, 42)
        assertThrows(attribute(.integer64AttributeType), "not-a-number")
    }

    // MARK: Decimal / floating point

    func testDecimalConversionThrowsInsteadOfSilentNil() throws {
        // The old DualLinkDB deserialize returned nil on a failed Decimal
        // conversion — callers wrote that nil into mandatory attributes
        // (the BankMovement.fee bug class)
        let attr = attribute(.decimalAttributeType)
        XCTAssertEqual(try attr.coreDataValue(from: Decimal(5)) as? Decimal, 5)
        XCTAssertEqual(try attr.coreDataValue(from: 1.5) as? Decimal, Decimal(1.5))
        XCTAssertEqual(try attr.coreDataValue(from: "2.5") as? Decimal, Decimal(string: "2.5"))
        assertThrows(attr, "not-a-decimal")
    }

    func testDoubleKeepsPrecision() throws {
        // The old MPSCacheNode.convert routed doubles through
        // MIOCoreFloatValue, truncating to Float precision
        let attr = attribute(.doubleAttributeType)
        let precise = 1.123456789012345
        XCTAssertEqual(try attr.coreDataValue(from: precise) as? Double, precise)
    }

    func testFloatConversions() throws {
        let attr = attribute(.floatAttributeType)
        XCTAssertEqual(try attr.coreDataValue(from: 1.5) as? Float, 1.5)
        assertThrows(attr, "nope")
    }

    // MARK: Transformable

    func testTransformableConversions() throws {
        let attr = attribute(.transformableAttributeType)

        // JSON text from web/sync sources parses into the object graph
        let parsed = try attr.coreDataValue(from: "{\"a\": 1}")
        XCTAssertEqual((parsed as? [String: Any])?["a"] as? Int, 1)
        XCTAssertEqual(try attr.coreDataValue(from: "[1, 2]") as? [Int], [1, 2])

        // Already-parsed graphs pass through
        let dict: [String: Any] = ["k": "v"]
        XCTAssertEqual((try attr.coreDataValue(from: dict) as? [String: Any])?["k"] as? String, "v")

        // Unparseable text stays text; empty string means no value
        XCTAssertEqual(try attr.coreDataValue(from: "plain text") as? String, "plain text")
        XCTAssertNil(try attr.coreDataValue(from: ""))
    }

    // MARK: Binary

    func testBinaryConversions() throws {
        let attr = attribute(.binaryDataAttributeType)
        let data = Data([1, 2, 3])
        XCTAssertEqual(try attr.coreDataValue(from: data) as? Data, data)
        XCTAssertEqual(try attr.coreDataValue(from: data.base64EncodedString()) as? Data, data)
        assertThrows(attr, "###not-base64###")
    }

    // MARK: Error content

    func testErrorNamesEntityAndAttribute() {
        let attr = attribute(.UUIDAttributeType)
        XCTAssertThrowsError(try attr.coreDataValue(from: "bad")) { error in
            let description = error.localizedDescription
            XCTAssertTrue(description.contains("ConvEntity"), "error must name the entity: \(description)")
            XCTAssertTrue(description.contains("attr"), "error must name the attribute: \(description)")
        }
    }
}

#endif
