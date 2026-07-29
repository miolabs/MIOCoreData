//
//  StoreRegistrationNotificationTests.swift
//  MIOCoreData
//
//  Verifies the NSIncrementalStore registration contract against the behavior
//  observed in Apple Core Data (macOS probe, 2026-07):
//
//    insert            -> no store notification (temporary IDs never reach it)
//    save (inserts)    -> obtainPermanentIDs -> execute(SAVE) ->
//                         didRegisterObjects with the PERMANENT IDs
//    reset             -> didUnregisterObjects with the permanent IDs
//

#if !APPLE_CORE_DATA

import XCTest
import Foundation
@testable import CoreDataSwift

/// Minimal incremental store that records every store callback in call order.
/// Self-contained (not the TestModel TestIncrementalStore, which is internal
/// to that target).
class RecordingIncrementalStore: CoreDataSwift.NSIncrementalStore
{
    public static let recStoreType: String = "RecordingIncrementalStore"

    // The coordinator instantiates the store, so the log lives at type level;
    // tests reset it in setUp and read it after acting.
    nonisolated(unsafe) static var events: [String] = []

    var nodesByURI: [String: CoreDataSwift.NSIncrementalStoreNode] = [:]

    public override func loadMetadata() throws {
        self.metadata = [CoreDataSwift.NSStoreUUIDKey: UUID().uuidString, CoreDataSwift.NSStoreTypeKey: RecordingIncrementalStore.recStoreType]
    }

    public override func execute(_ request: CoreDataSwift.NSPersistentStoreRequest, with context: CoreDataSwift.NSManagedObjectContext?) throws -> Any {
        guard let saveRequest = request as? CoreDataSwift.NSSaveChangesRequest else {
            RecordingIncrementalStore.events.append("execute(FETCH)")
            return [CoreDataSwift.NSManagedObject]()
        }

        let ins = saveRequest.insertedObjects ?? Set()
        let upd = saveRequest.updatedObjects ?? Set()
        let del = saveRequest.deletedObjects ?? Set()
        RecordingIncrementalStore.events.append("execute(SAVE i=\(ins.count) u=\(upd.count) d=\(del.count))")

        for obj in ins {
            nodesByURI[obj.objectID.uriRepresentation().absoluteString] =
                CoreDataSwift.NSIncrementalStoreNode(objectID: obj.objectID, withValues: obj.changedValues(), version: 1)
        }
        for obj in upd {
            let node = nodesByURI[obj.objectID.uriRepresentation().absoluteString]!
            node.update(withValues: obj.changedValues(), version: node.version + 1)
        }
        for obj in del {
            nodesByURI.removeValue(forKey: obj.objectID.uriRepresentation().absoluteString)
        }
        return []
    }

    public override func obtainPermanentIDs(for array: [CoreDataSwift.NSManagedObject]) throws -> [CoreDataSwift.NSManagedObjectID] {
        RecordingIncrementalStore.events.append("obtainPermanentIDs(\(array.count))")
        return array.map { newObjectID(for: $0.entity, referenceObject: UUID()) }
    }

    public override func newValuesForObject(with objectID: CoreDataSwift.NSManagedObjectID, with context: CoreDataSwift.NSManagedObjectContext) throws -> CoreDataSwift.NSIncrementalStoreNode {
        RecordingIncrementalStore.events.append("newValuesForObject(temp:\(objectID.isTemporaryID))")
        return nodesByURI[objectID.uriRepresentation().absoluteString]!
    }

    public override func managedObjectContextDidRegisterObjects(with objectIDs: [CoreDataSwift.NSManagedObjectID]) {
        for objID in objectIDs {
            RecordingIncrementalStore.events.append("didRegister(temp:\(objID.isTemporaryID))")
        }
    }

    public override func managedObjectContextDidUnregisterObjects(with objectIDs: [CoreDataSwift.NSManagedObjectID]) {
        for objID in objectIDs {
            RecordingIncrementalStore.events.append("didUnregister(temp:\(objID.isTemporaryID))")
        }
    }
}

final class StoreRegistrationNotificationTests: XCTestCase
{
    var container: CoreDataSwift.NSPersistentContainer!
    var moc: CoreDataSwift.NSManagedObjectContext!

    private static func modelPath() -> String {
        return URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // MIOCoreDataTests
            .deletingLastPathComponent()   // Tests
            .appendingPathComponent("TestModel/TestModel.xcdatamodeld/TestModel.xcdatamodel/contents")
            .path
    }

    override func setUp() {
        super.setUp()

        CoreDataSwift.NSPersistentStoreCoordinator.registerStoreClass(RecordingIncrementalStore.self, forStoreType: RecordingIncrementalStore.recStoreType)

        let mom = CoreDataSwift.NSManagedObjectModel(contentsOf: URL(fileURLWithPath: Self.modelPath()))!
        container = CoreDataSwift.NSPersistentContainer(name: "TestModel", managedObjectModel: mom)
        let description = CoreDataSwift.NSPersistentStoreDescription()
        description.type = RecordingIncrementalStore.recStoreType
        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores { _, error in
            if let error = error { fatalError("Store failed to load: \(error)") }
        }

        moc = container.viewContext
        RecordingIncrementalStore.events = []
    }

    private func insertSimpleEntity(name: String) -> CoreDataSwift.NSManagedObject {
        let entity = container.managedObjectModel.entitiesByName["SimpleEntity"]!
        let obj = CoreDataSwift.NSManagedObject(entity: entity, insertInto: moc)
        obj.setValue(UUID(), forKey: "identifier")
        obj.setValue(name, forKey: "name")
        return obj
    }

    func testInsertDoesNotNotifyTheStore() {
        _ = insertSimpleEntity(name: "unsaved")

        XCTAssertFalse(RecordingIncrementalStore.events.contains { $0.hasPrefix("didRegister") },
                       "the store must never hear about temporary registrations, got: \(RecordingIncrementalStore.events)")
    }

    func testSaveNotifiesRegistrationWithPermanentIDAfterExecute() throws {
        _ = insertSimpleEntity(name: "saved")
        try moc.save()

        let events = RecordingIncrementalStore.events
        XCTAssertEqual(events.filter { $0.hasPrefix("didRegister") }, ["didRegister(temp:false)"],
                       "exactly one registration, with the permanent ID, got: \(events)")

        let permanentIndex = events.firstIndex { $0.hasPrefix("obtainPermanentIDs") }
        let executeIndex   = events.firstIndex { $0.hasPrefix("execute(SAVE") }
        let registerIndex  = events.firstIndex { $0.hasPrefix("didRegister") }
        XCTAssertNotNil(permanentIndex); XCTAssertNotNil(executeIndex); XCTAssertNotNil(registerIndex)
        XCTAssertLessThan(permanentIndex!, executeIndex!, "permanent IDs are assigned before the save request")
        XCTAssertLessThan(executeIndex!, registerIndex!,
                          "registration is notified after the save request has populated the store, got: \(events)")
    }

    func testUpdateSaveDoesNotReRegister() throws {
        let obj = insertSimpleEntity(name: "original")
        try moc.save()
        RecordingIncrementalStore.events = []

        obj.setValue("renamed", forKey: "name")
        try moc.save()

        let events = RecordingIncrementalStore.events
        XCTAssertEqual(events.filter { $0.hasPrefix("execute(SAVE") }, ["execute(SAVE i=0 u=1 d=0)"])
        XCTAssertTrue(events.filter { $0.hasPrefix("didRegister") }.isEmpty,
                      "an update-save must not re-register, got: \(events)")
    }

    func testResetNotifiesUnregistrationWithPermanentID() throws {
        _ = insertSimpleEntity(name: "registered")
        try moc.save()
        RecordingIncrementalStore.events = []

        moc.reset()

        XCTAssertEqual(RecordingIncrementalStore.events.filter { $0.hasPrefix("didUnregister") },
                       ["didUnregister(temp:false)"],
                       "reset unregisters the object with its permanent ID, got: \(RecordingIncrementalStore.events)")
    }
}

#endif
