//
//  EntityCoreBridgeTests.swift
//  MIOCoreDataTests
//
//  Created by MIO Research Labs on 2026.
//
//  Phase 3 of MIOENTITYCORE-ENTITY-OWNERSHIP-PLAN.md: the bridge.
//
//  The JSON row expectations are the same ones pinned in MIOEntityCore's
//  MECCodecJSONTests and, before that, against the code the codec replaced.
//  Reaching them from an NSManagedObject is what makes the three-way
//  translation real rather than a table of unit tests.
//

import Foundation
import XCTest
import MIOCore
import MIOEntityCore
@testable import MIOCoreData

// `import XCTest` drags Apple's real CoreData into scope on Apple platforms.
#if !APPLE_CORE_DATA
typealias NSManagedObjectModel         = CoreDataSwift.NSManagedObjectModel
typealias NSManagedObjectContext       = CoreDataSwift.NSManagedObjectContext
typealias NSManagedObject              = CoreDataSwift.NSManagedObject
typealias NSEntityDescription          = CoreDataSwift.NSEntityDescription
typealias NSPersistentContainer        = CoreDataSwift.NSPersistentContainer
typealias NSPersistentStoreDescription = CoreDataSwift.NSPersistentStoreDescription
#endif

final class EntityCoreBridgeTests : XCTestCase
{
    static let instant = Date( timeIntervalSince1970: 1_700_000_000 )
    static let uuid    = UUID( uuidString: "6BA7B810-9DAD-11D1-80B4-00C04FD430C8" )!

    /// Folder and Todo from the guide, plus an inheritance pair, so the walk has
    /// a parent to order and a subentity to place.
    static let modelXML = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <model type="com.apple.IDECoreDataModeler.DataModel" documentVersion="1.0" minimumToolsVersion="Automatic" sourceLanguage="Swift" userDefinedModelVersionIdentifier="">
        <entity name="Folder" representedClassName="Folder" syncable="YES">
            <attribute name="identifier" attributeType="UUID"/>
            <attribute name="title" attributeType="String"/>
            <attribute name="note" optional="YES" attributeType="String"/>
            <attribute name="count" attributeType="Integer 64" defaultValueString="3"/>
            <attribute name="done" attributeType="Boolean" defaultValueString="NO"/>
            <attribute name="price" optional="YES" attributeType="Decimal"/>
            <attribute name="createdAt" optional="YES" attributeType="Date"/>
            <relationship name="todos" optional="YES" toMany="YES" deletionRule="Cascade" destinationEntity="Todo" inverseName="folder" inverseEntity="Todo"/>
        </entity>
        <entity name="Todo" representedClassName="Todo" syncable="YES">
            <attribute name="identifier" attributeType="UUID"/>
            <attribute name="title" attributeType="String"/>
            <relationship name="folder" optional="YES" maxCount="1" deletionRule="Nullify" destinationEntity="Folder" inverseName="todos" inverseEntity="Folder"/>
        </entity>
        <entity name="Document" representedClassName="Document" isAbstract="YES" syncable="YES">
            <attribute name="identifier" attributeType="UUID"/>
        </entity>
        <entity name="Invoice" representedClassName="Invoice" parentEntity="Document" syncable="YES">
            <attribute name="total" attributeType="Decimal"/>
        </entity>
    </model>
    """

    nonisolated(unsafe) static let model: NSManagedObjectModel = {
        let dir = URL( fileURLWithPath: NSTemporaryDirectory() )
            .appendingPathComponent( "mec-bridge-\(UUID().uuidString)" )
        try! FileManager.default.createDirectory( at: dir, withIntermediateDirectories: true )
        let file = dir.appendingPathComponent( "contents" )
        try! modelXML.write( to: file, atomically: true, encoding: .utf8 )

        guard let model = NSManagedObjectModel( contentsOf: file ), model.entities.isEmpty == false else {
            fatalError( "fixture model failed to parse" )
        }
        for entity in model.entities {
            _MIOCoreRegisterClass( type: NSManagedObject.self, forKey: entity.name! )
        }
        return model
    }()

    var moc: NSManagedObjectContext!

    override func setUpWithError ( ) throws {
        let container   = NSPersistentContainer( name: "Fixture", managedObjectModel: Self.model )
        let description = NSPersistentStoreDescription( url: URL( fileURLWithPath: "/dev/null" ) )
        description.type = CoreDataSwift.NSInMemoryStoreType
        container.persistentStoreDescriptions = [ description ]
        container.loadPersistentStores { _, _ in }
        moc = container.viewContext
    }

    // MARK: - The schema

    func testEveryEntityCrossesOver ( ) throws {
        let model = MECModel( coreDataModel: Self.model )

        XCTAssertEqual( Set( model.entitiesByName.keys ),
                        [ "Folder", "Todo", "Document", "Invoice" ] )
    }

    func testAttributeTypesCrossOver ( ) throws {
        let folder = try XCTUnwrap( MECModel( coreDataModel: Self.model ).entity( named: "Folder" ) )

        XCTAssertEqual( folder.attributesByName[ "identifier" ]?.type, .uuid )
        XCTAssertEqual( folder.attributesByName[ "title" ]?.type,      .string )
        XCTAssertEqual( folder.attributesByName[ "count" ]?.type,      .integer64 )
        XCTAssertEqual( folder.attributesByName[ "done" ]?.type,       .boolean )
        XCTAssertEqual( folder.attributesByName[ "price" ]?.type,      .decimal )
        XCTAssertEqual( folder.attributesByName[ "createdAt" ]?.type,  .date )
    }

    func testOptionalityCrossesOver ( ) throws {
        let folder = try XCTUnwrap( MECModel( coreDataModel: Self.model ).entity( named: "Folder" ) )

        XCTAssertFalse( try XCTUnwrap( folder.attributesByName[ "title" ] ).isOptional )
        XCTAssertTrue( try XCTUnwrap( folder.attributesByName[ "note" ] ).isOptional )
    }

    /// Core Data parsed the model file long ago and kept the value, not the
    /// text, so the bridge writes the text back out. `NO` rather than `0`,
    /// because that is how a model file spells it.
    func testDefaultsComeBackAsTheModelSpellsThem ( ) throws {
        let folder = try XCTUnwrap( MECModel( coreDataModel: Self.model ).entity( named: "Folder" ) )

        XCTAssertEqual( folder.attributesByName[ "count" ]?.defaultValueString, "3" )
        XCTAssertEqual( folder.attributesByName[ "done" ]?.defaultValueString, "NO" )
        XCTAssertNil( folder.attributesByName[ "title" ]?.defaultValueString, "no default in the model" )
    }

    func testRelationshipsCrossOverAsNames ( ) throws {
        let model  = MECModel( coreDataModel: Self.model )
        let folder = try XCTUnwrap( model.entity( named: "Folder" ) )
        let todos  = try XCTUnwrap( folder.relationshipsByName[ "todos" ] )

        XCTAssertEqual( todos.destinationEntityName, "Todo" )
        XCTAssertEqual( todos.inverseName, "folder" )
        XCTAssertTrue( todos.isToMany )

        let todo   = try XCTUnwrap( model.entity( named: "Todo" ) )
        let parent = try XCTUnwrap( todo.relationshipsByName[ "folder" ] )

        XCTAssertEqual( parent.destinationEntityName, "Folder" )
        XCTAssertFalse( parent.isToMany )
    }

    /// The one interesting part of the walk. `MECEntity` takes its parent at
    /// `init`, so the bridge has to build shallowest-first whatever order Core
    /// Data hands the entities over in.
    func testInheritanceIsWiredParentsFirst ( ) throws {
        let model    = MECModel( coreDataModel: Self.model )
        let invoice  = try XCTUnwrap( model.entity( named: "Invoice" ) )
        let document = try XCTUnwrap( model.entity( named: "Document" ) )

        XCTAssertTrue( invoice.superEntity === document )
        XCTAssertTrue( document.isAbstract )
        XCTAssertEqual( model.subEntities( of: document ).map( \.name ), [ "Invoice" ] )
    }

    /// The parent is the same object, not a second translation of it, or the
    /// cache's identity-based inheritance walk would miss.
    func testTheParentIsTheModelsOwnEntity ( ) throws {
        let model   = MECModel( coreDataModel: Self.model )
        let invoice = try XCTUnwrap( model.entity( named: "Invoice" ) )

        XCTAssertTrue( invoice.superEntity === model.entity( named: "Document" ) )
    }

    // MARK: - The object

    func testManagedObjectRendersToJSON ( ) throws {
        let folder = NSEntityDescription.insertNewObject( forEntityName: "Folder", into: moc )
        folder.setValue( Self.uuid, forKey: "identifier" )
        folder.setValue( "L'Oréal", forKey: "title" )
        folder.setValue( Int64( 42 ), forKey: "count" )
        folder.setValue( true, forKey: "done" )
        folder.setValue( Decimal( string: "1.50" )!, forKey: "price" )
        folder.setValue( Self.instant, forKey: "createdAt" )

        let json = try folder.mecJSON()

        XCTAssertEqual( json[ "identifier" ] as? String, "6BA7B810-9DAD-11D1-80B4-00C04FD430C8" )
        XCTAssertEqual( json[ "title" ] as? String, "L'Oréal" )
        XCTAssertEqual( json[ "count" ] as? Int64, 42 )
        XCTAssertEqual( json[ "done" ] as? Bool, true )
        XCTAssertEqual( json[ "price" ] as? String, "1.5", "a decimal keeps its precision as text" )
        XCTAssertEqual( json[ "createdAt" ] as? String, "2023-11-14T22:13:20.000Z" )
    }

    /// The payload has to survive the thing it exists for.
    func testTheJSONSerialises ( ) throws {
        let folder = NSEntityDescription.insertNewObject( forEntityName: "Folder", into: moc )
        folder.setValue( Self.uuid, forKey: "identifier" )
        folder.setValue( "a title", forKey: "title" )
        folder.setValue( Int64( 1 ), forKey: "count" )
        folder.setValue( false, forKey: "done" )

        let data = try JSONSerialization.data( withJSONObject: try folder.mecJSON() )
        XCTAssertFalse( data.isEmpty )
    }

    /// An absent optional is dropped by default, which is what a PATCH-style API
    /// wants: a missing key and an explicit null mean different things.
    func testAbsentOptionalsAreOmitted ( ) throws {
        let folder = NSEntityDescription.insertNewObject( forEntityName: "Folder", into: moc )
        folder.setValue( Self.uuid, forKey: "identifier" )
        folder.setValue( "a title", forKey: "title" )
        folder.setValue( Int64( 1 ), forKey: "count" )
        folder.setValue( false, forKey: "done" )

        let json = try folder.mecJSON()

        XCTAssertNil( json[ "note" ] )
        XCTAssertNil( json[ "price" ] )
    }

    func testIncludeNullsKeepsTheKeys ( ) throws {
        let folder = NSEntityDescription.insertNewObject( forEntityName: "Folder", into: moc )
        folder.setValue( Self.uuid, forKey: "identifier" )
        folder.setValue( "a title", forKey: "title" )
        folder.setValue( Int64( 1 ), forKey: "count" )
        folder.setValue( false, forKey: "done" )

        let json = try folder.mecJSON( policy: MECPolicy( includeNulls: true ) )

        XCTAssertTrue( json[ "note" ] is NSNull )
    }

    /// Rendering choices belong to the policy, not to the object.
    func testThePolicyReachesTheObject ( ) throws {
        let folder = NSEntityDescription.insertNewObject( forEntityName: "Folder", into: moc )
        folder.setValue( Self.uuid, forKey: "identifier" )
        folder.setValue( "a title", forKey: "title" )
        folder.setValue( Int64( 1 ), forKey: "count" )
        folder.setValue( false, forKey: "done" )

        let json = try folder.mecJSON( policy: MECPolicy( uppercaseUUIDs: false ) )

        XCTAssertEqual( json[ "identifier" ] as? String, "6ba7b810-9dad-11d1-80b4-00c04fd430c8" )
    }

    /// Passing the translated entity is the same answer as deriving one, and is
    /// what a caller with a model in hand should do rather than building an
    /// entity per object.
    func testPassingTheEntityMatchesDerivingIt ( ) throws {
        let folder = NSEntityDescription.insertNewObject( forEntityName: "Folder", into: moc )
        folder.setValue( Self.uuid, forKey: "identifier" )
        folder.setValue( "a title", forKey: "title" )
        folder.setValue( Int64( 1 ), forKey: "count" )
        folder.setValue( false, forKey: "done" )

        let meta   = try XCTUnwrap( MECModel( coreDataModel: Self.model ).entity( named: "Folder" ) )
        let passed = try folder.mecJSON( entity: meta )
        let derived = try folder.mecJSON()

        XCTAssertEqual( passed.keys.sorted(), derived.keys.sorted() )
        XCTAssertEqual( passed[ "identifier" ] as? String, derived[ "identifier" ] as? String )
    }
}
