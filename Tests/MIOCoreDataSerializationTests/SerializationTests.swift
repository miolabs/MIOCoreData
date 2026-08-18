//
//  SerializationTests.swift
//
//  Created by MIO Research Labs on 2026.
//

import Foundation
import XCTest
import MIOCore
import MIOCoreData
@testable import MIOCoreDataSerialization

// `import XCTest` drags Apple's real CoreData into scope on Apple platforms.
#if !APPLE_CORE_DATA
typealias NSManagedObjectModel       = CoreDataSwift.NSManagedObjectModel
typealias NSManagedObjectContext     = CoreDataSwift.NSManagedObjectContext
typealias NSManagedObject            = CoreDataSwift.NSManagedObject
typealias NSEntityDescription        = CoreDataSwift.NSEntityDescription
typealias NSAttributeDescription     = CoreDataSwift.NSAttributeDescription
typealias NSPersistentContainer      = CoreDataSwift.NSPersistentContainer
typealias NSPersistentStoreDescription = CoreDataSwift.NSPersistentStoreDescription
#endif

final class SerializationTests : XCTestCase
{
    // MARK: - Fixture

    static let modelXML = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <model type="com.apple.IDECoreDataModeler.DataModel" documentVersion="1.0" lastSavedToolsVersion="24902" systemVersion="25F84" minimumToolsVersion="Automatic" sourceLanguage="Swift" userDefinedModelVersionIdentifier="">
        <entity name="Item" representedClassName="Item" syncable="YES">
            <attribute name="identifier" attributeType="UUID" usesScalarValueType="NO"/>
            <attribute name="title" attributeType="String"/>
            <attribute name="note" optional="YES" attributeType="String"/>
            <attribute name="done" attributeType="Boolean" defaultValueString="NO" usesScalarValueType="YES"/>
            <attribute name="count" attributeType="Integer 64" defaultValueString="3" usesScalarValueType="YES"/>
            <attribute name="price" optional="YES" attributeType="Decimal"/>
            <attribute name="createdAt" attributeType="Date" usesScalarValueType="NO"/>
            <attribute name="blob" optional="YES" attributeType="Binary"/>
            <attribute name="link" optional="YES" attributeType="URI"/>
            <attribute name="payload" optional="YES" attributeType="Transformable"/>
            <relationship name="box" optional="YES" maxCount="1" deletionRule="Nullify" destinationEntity="Box" inverseName="items" inverseEntity="Box"/>
        </entity>
        <entity name="Box" representedClassName="Box" syncable="YES">
            <attribute name="identifier" attributeType="UUID" usesScalarValueType="NO"/>
            <attribute name="name" attributeType="String"/>
            <relationship name="items" optional="YES" toMany="YES" deletionRule="Cascade" destinationEntity="Item" inverseName="box" inverseEntity="Item"/>
        </entity>
    </model>
    """

    nonisolated(unsafe) static let model: NSManagedObjectModel = {
        let dir = URL( fileURLWithPath: NSTemporaryDirectory() )
            .appendingPathComponent( "mcs-model-\(UUID().uuidString)" )
        try! FileManager.default.createDirectory( at: dir, withIntermediateDirectories: true )
        let file = dir.appendingPathComponent( "contents" )
        try! modelXML.write( to: file, atomically: true, encoding: .utf8 )

        guard let mom = NSManagedObjectModel( contentsOf: file ), mom.entities.isEmpty == false else {
            fatalError( "fixture model failed to parse" )
        }
        for entity in mom.entities {
            _MIOCoreRegisterClass( type: NSManagedObject.self, forKey: entity.name! )
        }
        return mom
    }()

    var moc: NSManagedObjectContext!

    override func setUpWithError ( ) throws {
        let container = NSPersistentContainer( name: "Fixture", managedObjectModel: Self.model )
        let description = NSPersistentStoreDescription( url: URL( fileURLWithPath: "/dev/null" ) )
        description.type = CoreDataSwift.NSInMemoryStoreType
        container.persistentStoreDescriptions = [ description ]
        container.loadPersistentStores { _, _ in }
        moc = container.viewContext
    }

    private func entity ( _ name: String ) -> NSEntityDescription {
        return Self.model.entitiesByName[ name ]!
    }

    private func attribute ( _ entityName: String, _ name: String ) -> NSAttributeDescription {
        return entity( entityName ).attributesByName[ name ]!
    }

    @discardableResult
    private func makeItem ( id: UUID = UUID(), title: String = "a title" ) -> NSManagedObject {
        let item = NSEntityDescription.insertNewObject( forEntityName: "Item", into: moc )
        item.setValue( id, forKey: "identifier" )
        item.setValue( title, forKey: "title" )
        item.setValue( false, forKey: "done" )
        item.setValue( Int64( 3 ), forKey: "count" )
        item.setValue( Date( timeIntervalSince1970: 1_700_000_000.25 ), forKey: "createdAt" )
        return item
    }

    // MARK: - Value types

    func testUUIDBecomesAnUppercasedString ( ) throws {
        let id = UUID()
        let value = try attribute( "Item", "identifier" ).mcs_jsonValue( from: id )
        XCTAssertEqual( value as? String, id.uuidString.uppercased() )
    }

    func testUUIDCasingFollowsThePolicy ( ) throws {
        let id = UUID()
        var policy = MCSerializationPolicy.default
        policy.uppercaseUUIDs = false
        let value = try attribute( "Item", "identifier" ).mcs_jsonValue( from: id, policy: policy )
        XCTAssertEqual( value as? String, id.uuidString.lowercased() )
    }

    func testUUIDArrivingAsTextIsNormalisedNotPassedThrough ( ) throws {
        // A driver may hand identity back as text. One row must not serialize
        // two different ways depending on which backend produced it.
        let id = UUID()
        let value = try attribute( "Item", "identifier" ).mcs_jsonValue( from: id.uuidString.lowercased() )
        XCTAssertEqual( value as? String, id.uuidString.uppercased() )
    }

    func testDateIsISO8601WithFractionalSeconds ( ) throws {
        let date = Date( timeIntervalSince1970: 1_700_000_000.25 )
        let value = try attribute( "Item", "createdAt" ).mcs_jsonValue( from: date )
        let text = try XCTUnwrap( value as? String )

        XCTAssertTrue( text.contains( "T" ), text )
        // Fractional seconds matter: without them, records written in the same
        // second lose their order.
        XCTAssertTrue( text.contains( ".25" ) || text.contains( ".250" ), text )
    }

    func testDecimalIsAStringByDefault ( ) throws {
        let value = try attribute( "Item", "price" ).mcs_jsonValue( from: Decimal( string: "3.50" )! )
        XCTAssertEqual( value as? String, "3.5" )
    }

    func testDecimalCanBeANumberByPolicy ( ) throws {
        var policy = MCSerializationPolicy.default
        policy.decimalFormat = .number
        let value = try attribute( "Item", "price" ).mcs_jsonValue( from: Decimal( string: "3.50" )!, policy: policy )
        XCTAssertEqual( ( value as? NSDecimalNumber )?.stringValue, "3.5" )
    }

    func testBinaryBecomesBase64 ( ) throws {
        let data = Data( [ 0x4D, 0x49, 0x4F ] )
        let value = try attribute( "Item", "blob" ).mcs_jsonValue( from: data )
        XCTAssertEqual( value as? String, data.base64EncodedString() )
    }

    func testURIBecomesItsAbsoluteString ( ) throws {
        let url = URL( string: "https://example.com/a?b=c" )!
        let value = try attribute( "Item", "link" ).mcs_jsonValue( from: url )
        XCTAssertEqual( value as? String, url.absoluteString )
    }

    func testScalarsPassThrough ( ) throws {
        XCTAssertEqual( try attribute( "Item", "title" ).mcs_jsonValue( from: "x" ) as? String, "x" )
        XCTAssertEqual( try attribute( "Item", "done" ).mcs_jsonValue( from: true ) as? Bool, true )
        XCTAssertEqual( try attribute( "Item", "count" ).mcs_jsonValue( from: Int64( 9 ) ) as? Int64, 9 )
    }

    // MARK: - Nil handling

    func testRequiredNilThrowsRatherThanDisappearing ( ) {
        // The failure mode this replaces: a required value silently serializing
        // as absent, so the other side accepts a payload and misreads it.
        XCTAssertThrowsError( try attribute( "Item", "title" ).mcs_jsonValue( from: nil ) ) { error in
            guard case MCSerializationError.missingRequiredValue = error else {
                return XCTFail( "wrong error: \(error)" )
            }
        }
    }

    func testRequiredNilFallsBackToTheModelDefault ( ) throws {
        // `count` is required but has a default of 3, so nil is recoverable.
        let value = try attribute( "Item", "count" ).mcs_jsonValue( from: nil )
        XCTAssertEqual( ( value as? NSNumber )?.intValue, 3 )
    }

    func testOptionalNilIsNull ( ) throws {
        XCTAssertTrue( try attribute( "Item", "note" ).mcs_jsonValue( from: nil ) is NSNull )
    }

    func testTransformableIsRefusedNotGuessed ( ) throws {
        // Optional, so a nil transformable still serializes as null and does
        // not poison every other test. It is only a value that cannot be
        // handled, because the transformer is the caller's business.
        let attr = attribute( "Item", "payload" )
        XCTAssertEqual( attr.attributeType, .transformableAttributeType )

        XCTAssertThrowsError( try attr.mcs_jsonValue( from: "anything" ) ) { error in
            guard case MCSerializationError.unsupportedAttribute = error else {
                return XCTFail( "wrong error: \(error)" )
            }
        }
    }

    // MARK: - Objects

    func testObjectSerializesAttributesAndOmitsNullsByDefault ( ) throws {
        let id = UUID()
        let item = makeItem( id: id, title: "write it" )

        let json = try item.mcs_json()

        XCTAssertEqual( json[ "identifier" ] as? String, id.uuidString.uppercased() )
        XCTAssertEqual( json[ "title" ] as? String, "write it" )
        XCTAssertEqual( json[ "done" ] as? Bool, false )
        XCTAssertNil( json[ "note" ], "optional nils should be omitted by default" )
    }

    func testNullsCanBeIncludedByPolicy ( ) throws {
        var policy = MCSerializationPolicy.default
        policy.includeNulls = true
        let json = try makeItem().mcs_json( policy: policy )
        XCTAssertTrue( json[ "note" ] is NSNull )
    }

    func testToOneSerializesAsAnIdentityReferenceNotANestedObject ( ) throws {
        let boxID = UUID()
        let box = NSEntityDescription.insertNewObject( forEntityName: "Box", into: moc )
        box.setValue( boxID, forKey: "identifier" )
        box.setValue( "a box", forKey: "name" )

        let item = makeItem()
        item.setValue( box, forKey: "box" )

        let json = try item.mcs_json()
        XCTAssertEqual( json[ "box" ] as? String, boxID.uuidString.uppercased() )
        XCTAssertFalse( json[ "box" ] is [String:Any], "relationships must not nest" )
    }

    func testToManySerializesAsASortedArrayOfIdentities ( ) throws {
        let box = NSEntityDescription.insertNewObject( forEntityName: "Box", into: moc )
        box.setValue( UUID(), forKey: "identifier" )
        box.setValue( "a box", forKey: "name" )

        let a = makeItem( id: UUID( uuidString: "00000000-0000-0000-0000-0000000000AA" )! )
        let b = makeItem( id: UUID( uuidString: "00000000-0000-0000-0000-0000000000BB" )! )
        a.setValue( box, forKey: "box" )
        b.setValue( box, forKey: "box" )

        let json = try box.mcs_json()
        let ids = try XCTUnwrap( json[ "items" ] as? [String] )

        XCTAssertEqual( ids.count, 2 )
        // Sorted, because a set has no order and an unstable payload makes
        // diffing and caching useless.
        XCTAssertEqual( ids, ids.sorted() )
    }

    func testIdentityAttributeNameComesFromThePolicy ( ) throws {
        var policy = MCSerializationPolicy.default
        policy.identifierKey = { _ in "title" }

        let box = NSEntityDescription.insertNewObject( forEntityName: "Box", into: moc )
        box.setValue( UUID(), forKey: "identifier" )
        box.setValue( "a box", forKey: "name" )

        let item = makeItem( title: "used as identity" )
        item.setValue( box, forKey: "box" )

        // Box has no `title`, so this must fail loudly rather than emit a
        // reference that points at nothing.
        XCTAssertThrowsError( try item.mcs_json( policy: policy ) )
    }

    // MARK: - The actual contract

    func testOutputIsAcceptedByJSONSerialization ( ) throws {
        // Everything above asserts shape.
        var policy = MCSerializationPolicy.default
        policy.includeNulls = true

        let item = makeItem()
        item.setValue( Decimal( string: "12.34" ), forKey: "price" )
        item.setValue( Data( [ 1, 2, 3 ] ), forKey: "blob" )
        item.setValue( URL( string: "https://example.com" ), forKey: "link" )

        let json = try item.mcs_json( policy: policy )

        XCTAssertTrue( JSONSerialization.isValidJSONObject( json ), "\(json)" )
        XCTAssertNoThrow( try JSONSerialization.data( withJSONObject: json ) )
    }

    // MARK: - Round trip

    func testAttributesRoundTripThroughJSONAndBack ( ) throws {
        let id = UUID()
        let item = makeItem( id: id, title: "original" )
        item.setValue( Int64( 42 ), forKey: "count" )

        let json = try item.mcs_json()

        let restored = NSEntityDescription.insertNewObject( forEntityName: "Item", into: moc )
        try restored.mcs_setAttributes( fromJSON: json )

        XCTAssertEqual( restored.value( forKey: "identifier" ) as? UUID, id )
        XCTAssertEqual( restored.value( forKey: "title" ) as? String, "original" )
        XCTAssertEqual( restored.value( forKey: "count" ) as? Int64, 42 )
    }

    func testSetAttributesLeavesAbsentKeysAlone ( ) throws {
        let item = makeItem( title: "keep me" )
        try item.mcs_setAttributes( fromJSON: [ "count": 99 ] )

        XCTAssertEqual( item.value( forKey: "title" ) as? String, "keep me" )
        XCTAssertEqual( item.value( forKey: "count" ) as? Int64, 99 )
    }

    func testSerializableKeysAreStable ( ) {
        XCTAssertEqual( entity( "Box" ).mcs_serializableKeys(), [ "identifier", "items", "name" ] )
    }
}
