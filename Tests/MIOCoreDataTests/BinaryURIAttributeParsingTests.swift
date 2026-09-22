//
//  BinaryURIAttributeParsingTests.swift
//  MIOCoreDataTests
//
//  The model parser must read the two attribute types Xcode writes as
//  attributeType="Binary" and attributeType="URI", and a URI default must
//  come back as a URL, the way Apple Core Data exposes it.
//

#if !APPLE_CORE_DATA

import XCTest
import Foundation
import MIOCore
@testable import CoreDataSwift

// MARK: - Runtime classes

class CDBinURIEntity: CoreDataSwift.NSManagedObject {}

// MARK: - Test model

private let binURIModelXML = """
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<model type="com.apple.IDECoreDataModeler.DataModel" documentVersion="1.0">
    <entity name="CDBinURIEntity" representedClassName="CDBinURIEntity" syncable="YES">
        <attribute name="payload" attributeType="Binary" optional="YES"/>
        <attribute name="link" attributeType="URI" optional="YES"/>
        <attribute name="home" attributeType="URI" defaultValueString="https://dual-link.com/" optional="YES"/>
    </entity>
</model>
"""

private let registerBinURIRuntimeClasses: Void = {
    _MIOCoreRegisterClass(type: CDBinURIEntity.self, forKey: "CDBinURIEntity")
}()

private func binURIModel() -> CoreDataSwift.NSManagedObjectModel {
    _ = registerBinURIRuntimeClasses
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("CDBinURIModel-\(ProcessInfo.processInfo.processIdentifier).xml")
    if FileManager.default.fileExists(atPath: url.path) == false {
        try! binURIModelXML.data(using: .utf8)!.write(to: url)
    }
    return CoreDataSwift.NSManagedObjectModel(contentsOf: url)!
}

// MARK: - Tests

final class BinaryURIAttributeParsingTests: XCTestCase
{
    private func attribute(_ name: String) throws -> CoreDataSwift.NSAttributeDescription {
        let entity = try XCTUnwrap(binURIModel().entitiesByName["CDBinURIEntity"])
        return try XCTUnwrap(entity.attributesByName[name], "attribute \(name) missing from the parsed model")
    }

    func testBinaryTokenParsesToBinaryDataType() throws {
        let attr = try attribute("payload")
        XCTAssertEqual(attr.attributeType, .binaryDataAttributeType)
        XCTAssertNil(attr.defaultValue)
    }

    func testURITokenParsesToURIType() throws {
        let attr = try attribute("link")
        XCTAssertEqual(attr.attributeType, .URIAttributeType)
        XCTAssertNil(attr.defaultValue)
    }

    func testURIDefaultIsAURL() throws {
        let attr = try attribute("home")
        XCTAssertEqual(attr.attributeType, .URIAttributeType)
        XCTAssertEqual(attr.defaultValue as? URL, URL(string: "https://dual-link.com/"))
    }

    func testURIDefaultRoundTripsThroughConversion() throws {
        // The store hands back nothing for an unset column: the model default applies, as a URL.
        let attr = try attribute("home")
        XCTAssertEqual(try attr.coreDataValue(from: nil) as? URL, URL(string: "https://dual-link.com/"))
        XCTAssertEqual(try attr.coreDataValue(from: "https://dual-link.com/docs") as? URL, URL(string: "https://dual-link.com/docs"))
    }
}

#endif
