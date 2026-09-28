//
//  FaultMutationGuardTests.swift
//  MIOCoreDataTests
//
//  A relationship change built on a read the store could not answer must not
//  reach the store. _addObject/_removeObject start from the stored set; when
//  the store could not load it they started from an empty one, and the store
//  side diffs the pending set against the stored row: an add of x saved as
//  "add x, remove every existing member". A delete walked its delete rules
//  over the same empty read: cascade children survived, nullified inverses
//  kept pointing at the deleted object, and a Deny rule let the delete through.
//
//  Contract pinned here:
//  - add/remove on an unloaded relationship makes save() throw
//    relationshipNotLoaded, and nothing reaches the store
//  - so does a delete whose nullify/cascade walk could not read a relationship
//  - a Deny rule on an unreadable relationship refuses the delete
//  - the guard runs even with validatesOnSave == false
//  - rollback clears it; a healthy add saves normally
//

#if !APPLE_CORE_DATA

import XCTest
import Foundation
import MIOCore
@testable import CoreDataSwift

// MARK: - Runtime classes

class CDGuardOwner: CoreDataSwift.NSManagedObject {}
class CDGuardMember: CoreDataSwift.NSManagedObject {}
class CDGuardPart: CoreDataSwift.NSManagedObject {}
class CDGuardBlocker: CoreDataSwift.NSManagedObject {}

// MARK: - Store with failable reads, per object

enum FlakyMutationStoreError: Error { case storeUnavailable }

class FlakyMutationStore: CoreDataSwift.NSIncrementalStore
{
    static let storeType = "FlakyMutationStore"

    nonisolated(unsafe) var rows: [String:[String:Any]] = [:]            // object URI -> attribute values
    nonisolated(unsafe) var relationships: [String:[String:Any]] = [:]   // object URI -> key -> objectID | [objectID] | NSNull
    var failingObjectLoads: Set<String> = []                             // object URIs whose row load throws
    var failingRelationshipReads: Set<String> = []                       // object URIs whose relationship reads throw
    var saveRequests = 0                                                 // save requests that reached the store

    override func loadMetadata() throws {
        self.metadata = [CoreDataSwift.NSStoreUUIDKey: UUID().uuidString, CoreDataSwift.NSStoreTypeKey: FlakyMutationStore.storeType]
    }

    override func execute(_ request: CoreDataSwift.NSPersistentStoreRequest, with context: CoreDataSwift.NSManagedObjectContext?) throws -> Any {
        if request is CoreDataSwift.NSSaveChangesRequest { saveRequests += 1 }
        return []
    }

    override func newValuesForObject(with objectID: CoreDataSwift.NSManagedObjectID, with context: CoreDataSwift.NSManagedObjectContext) throws -> CoreDataSwift.NSIncrementalStoreNode {
        if failingObjectLoads.contains(objectID.uriString) { throw FlakyMutationStoreError.storeUnavailable }
        return CoreDataSwift.NSIncrementalStoreNode(objectID: objectID, withValues: rows[objectID.uriString] ?? [:], version: 1)
    }

    override func newValue(forRelationship relationship: CoreDataSwift.NSRelationshipDescription, forObjectWith objectID: CoreDataSwift.NSManagedObjectID, with context: CoreDataSwift.NSManagedObjectContext?) throws -> Any {
        if failingRelationshipReads.contains(objectID.uriString) { throw FlakyMutationStoreError.storeUnavailable }
        let value = relationships[objectID.uriString]?[relationship.name]
        if relationship.isToMany { return value as? [CoreDataSwift.NSManagedObjectID] ?? [] }
        return value ?? NSNull()
    }
}

// MARK: - Test model

private let guardModelXML = """
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<model type="com.apple.IDECoreDataModeler.DataModel" documentVersion="1.0">
    <entity name="CDGuardOwner" representedClassName="CDGuardOwner" syncable="YES">
        <attribute name="name" attributeType="String" optional="YES"/>
        <relationship name="members" optional="YES" toMany="YES" deletionRule="Nullify" destinationEntity="CDGuardMember" inverseName="owner" inverseEntity="CDGuardMember"/>
        <relationship name="parts" optional="YES" toMany="YES" deletionRule="Cascade" destinationEntity="CDGuardPart" inverseName="whole" inverseEntity="CDGuardPart"/>
        <relationship name="blockers" optional="YES" toMany="YES" deletionRule="Deny" destinationEntity="CDGuardBlocker" inverseName="holder" inverseEntity="CDGuardBlocker"/>
    </entity>
    <entity name="CDGuardMember" representedClassName="CDGuardMember" syncable="YES">
        <attribute name="name" attributeType="String" optional="YES"/>
        <relationship name="owner" optional="YES" maxCount="1" deletionRule="Nullify" destinationEntity="CDGuardOwner" inverseName="members" inverseEntity="CDGuardOwner"/>
    </entity>
    <entity name="CDGuardPart" representedClassName="CDGuardPart" syncable="YES">
        <attribute name="name" attributeType="String" optional="YES"/>
        <relationship name="whole" optional="YES" maxCount="1" deletionRule="Nullify" destinationEntity="CDGuardOwner" inverseName="parts" inverseEntity="CDGuardOwner"/>
    </entity>
    <entity name="CDGuardBlocker" representedClassName="CDGuardBlocker" syncable="YES">
        <attribute name="name" attributeType="String" optional="YES"/>
        <relationship name="holder" optional="YES" maxCount="1" deletionRule="Nullify" destinationEntity="CDGuardOwner" inverseName="blockers" inverseEntity="CDGuardOwner"/>
    </entity>
</model>
"""

private let registerGuardRuntimeClasses: Void = {
    _MIOCoreRegisterClass(type: CDGuardOwner.self, forKey: "CDGuardOwner")
    _MIOCoreRegisterClass(type: CDGuardMember.self, forKey: "CDGuardMember")
    _MIOCoreRegisterClass(type: CDGuardPart.self, forKey: "CDGuardPart")
    _MIOCoreRegisterClass(type: CDGuardBlocker.self, forKey: "CDGuardBlocker")
    CoreDataSwift.NSPersistentStoreCoordinator.registerStoreClass(FlakyMutationStore.self, forStoreType: FlakyMutationStore.storeType)
}()

private func guardModel() -> CoreDataSwift.NSManagedObjectModel {
    _ = registerGuardRuntimeClasses
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("CDFaultMutationGuardModel-\(ProcessInfo.processInfo.processIdentifier).xml")
    if FileManager.default.fileExists(atPath: url.path) == false {
        try! guardModelXML.data(using: .utf8)!.write(to: url)
    }
    return CoreDataSwift.NSManagedObjectModel(contentsOf: url)!
}

// MARK: - Tests

final class FaultMutationGuardTests: XCTestCase
{
    var container: CoreDataSwift.NSPersistentContainer!
    var moc: CoreDataSwift.NSManagedObjectContext!
    var store: FlakyMutationStore!

    override func setUp() {
        super.setUp()

        container = CoreDataSwift.NSPersistentContainer(name: "CDFaultMutationGuardTest", managedObjectModel: guardModel())
        let description = CoreDataSwift.NSPersistentStoreDescription()
        description.type = FlakyMutationStore.storeType
        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores { _, error in
            if let error = error { fatalError("Store failed to load: \(error)") }
        }
        moc = container.viewContext
        moc.validatesOnSave = true
        store = (container.persistentStoreCoordinator.persistentStores[0] as! FlakyMutationStore)
    }

    // MARK: Helpers

    /// A store-backed object (permanent ID, row in the store) materialized as
    /// a fault in the context — the shape every fetched object has.
    private func storeObject(_ entityName: String, _ reference: String) throws -> CoreDataSwift.NSManagedObject {
        let entity = container.managedObjectModel.entitiesByName[entityName]!
        let objID = store.newObjectID(for: entity, referenceObject: reference)
        store.rows[objID.uriString] = ["name": reference]
        return try moc.existingObject(with: objID)
    }

    /// Owner with members m1, m2 in the store.
    private func ownerWithMembers(_ tag: String) throws -> (CoreDataSwift.NSManagedObject, CoreDataSwift.NSManagedObject, CoreDataSwift.NSManagedObject) {
        let m1 = try storeObject("CDGuardMember", "\(tag)-m1")
        let m2 = try storeObject("CDGuardMember", "\(tag)-m2")
        let owner = try storeObject("CDGuardOwner", "\(tag)-owner")
        store.relationships[owner.objectID.uriString] = ["members": [m1.objectID, m2.objectID]]
        store.relationships[m1.objectID.uriString] = ["owner": owner.objectID]
        store.relationships[m2.objectID.uriString] = ["owner": owner.objectID]
        return (owner, m1, m2)
    }

    private func assertRefused(_ key: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertThrowsError(try moc.save(), file: file, line: line) { error in
            let errors: [Error]
            if case NSManagedObjectValidationError.multiple(let all) = error { errors = all } else { errors = [error] }
            let refused = errors.contains {
                if case NSManagedObjectValidationError.relationshipNotLoaded(_, let relationship, _) = $0 { return relationship == key }
                return false
            }
            XCTAssertTrue(refused, "expected relationshipNotLoaded for \(key), got \(error)", file: file, line: line)
        }
        XCTAssertEqual(store.saveRequests, 0, "nothing may reach the store", file: file, line: line)
    }

    private func memberURIs(_ owner: CoreDataSwift.NSManagedObject) -> Set<String> {
        let members = owner.changedValues()["members"] as? Set<CoreDataSwift.NSManagedObject?> ?? []
        return Set( members.compactMap { $0?.objectID.uriString } )
    }

    // MARK: Add / remove

    func testAddAfterFailedLoadRefusesTheSave() throws {
        let (owner, _, _) = try ownerWithMembers("add")
        let m3 = try storeObject("CDGuardMember", "add-m3")

        store.failingObjectLoads = [owner.objectID.uriString]
        owner._addObject(m3, forKey: "members")

        store.failingObjectLoads = []          // the store is healthy again by save time
        assertRefused("members")
    }

    func testRemoveAfterFailedRelationshipReadRefusesTheSave() throws {
        let (owner, m1, _) = try ownerWithMembers("remove")

        store.failingRelationshipReads = [owner.objectID.uriString]
        owner._removeObject(m1, forKey: "members")

        store.failingRelationshipReads = []
        assertRefused("members")
    }

    func testGuardIgnoresTheValidatesOnSaveSwitch() throws {
        let (owner, _, _) = try ownerWithMembers("switch")
        let m3 = try storeObject("CDGuardMember", "switch-m3")

        moc.validatesOnSave = false
        store.failingObjectLoads = [owner.objectID.uriString]
        owner._addObject(m3, forKey: "members")

        store.failingObjectLoads = []
        assertRefused("members")
    }

    // MARK: Delete rules

    func testDeleteWithUnreadableNullifyRelationshipRefusesTheSave() throws {
        let (owner, _, _) = try ownerWithMembers("nullify")

        store.failingObjectLoads = [owner.objectID.uriString]
        moc.delete(owner)

        store.failingObjectLoads = []
        assertRefused("members")
    }

    func testDeleteWithUnreadableCascadeRelationshipRefusesTheSave() throws {
        let part = try storeObject("CDGuardPart", "cascade-part")
        let owner = try storeObject("CDGuardOwner", "cascade-owner")
        store.relationships[owner.objectID.uriString] = ["parts": [part.objectID]]

        store.failingRelationshipReads = [owner.objectID.uriString]
        moc.delete(owner)

        store.failingRelationshipReads = []
        assertRefused("parts")
        XCTAssertFalse(part.isDeleted, "the unreadable cascade never reached the part")
    }

    func testDenyRuleOnUnreadableRelationshipRefusesTheDelete() throws {
        let blocker = try storeObject("CDGuardBlocker", "deny-blocker")
        let owner = try storeObject("CDGuardOwner", "deny-owner")
        store.relationships[owner.objectID.uriString] = ["blockers": [blocker.objectID]]

        // Still failing at save: the Deny check itself cannot read the set
        store.failingRelationshipReads = [owner.objectID.uriString]
        moc.delete(owner)

        assertRefused("blockers")
    }

    // MARK: Recovery and the healthy path

    func testRollbackClearsTheGuard() throws {
        let (owner, _, _) = try ownerWithMembers("rollback")
        let m3 = try storeObject("CDGuardMember", "rollback-m3")

        store.failingObjectLoads = [owner.objectID.uriString]
        owner._addObject(m3, forKey: "members")
        moc.rollback()

        store.failingObjectLoads = []
        owner._addObject(m3, forKey: "members")
        XCTAssertNoThrow(try moc.save())
        XCTAssertEqual(store.saveRequests, 1)
    }

    func testHealthyAddKeepsTheStoredMembers() throws {
        let (owner, m1, m2) = try ownerWithMembers("healthy")
        let m3 = try storeObject("CDGuardMember", "healthy-m3")

        owner._addObject(m3, forKey: "members")
        XCTAssertEqual(memberURIs(owner), Set([m1, m2, m3].map { $0.objectID.uriString }), "the add starts from the stored members")

        XCTAssertNoThrow(try moc.save())
        XCTAssertEqual(store.saveRequests, 1)
    }
}

#endif
