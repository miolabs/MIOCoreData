//
//  AnnihilationTrackingTests.swift
//  MIOCoreDataTests
//
//  Insert+delete annihilation must leave the object COMPLETELY untracked and
//  unresurrectable. Two regressions from the 2026-08 DLHookServer incident:
//
//  1. Ghost updates: _delete removed the pending insert from every tracking
//     set, but delete propagation ran afterwards and deleteByCascade's
//     trailing _markUpdated(self) put the annihilated object into
//     updatedObjects — an unregistered object with its full pending values,
//     serialized as an UPDATE of a row that never existed. Any entity with a
//     Cascade to-many (even an empty one) triggered it on every annihilation.
//
//  2. Ghost resurrection: existingObject(with:) re-created an object for a
//     temporary ID whose insert had annihilated. A temporary ID has no store
//     row to fault from, so the resurrected object read nil for every
//     attribute — and a surviving holder's relationship then pointed at a
//     hollow ghost with no identifier (the changelog serialization crash).
//     Temporary + unregistered now throws, relationship reads skip/NSNull.
//
//  Self-contained: inline model, runtime classes, in-memory store.
//

#if !APPLE_CORE_DATA

import XCTest
import Foundation
import MIOCore
@testable import CoreDataSwift

// MARK: - Runtime classes

class CDAnnParent: CoreDataSwift.NSManagedObject {}
class CDAnnChild: CoreDataSwift.NSManagedObject {}
class CDAnnTarget: CoreDataSwift.NSManagedObject {}

// MARK: - Test model
//
// CDAnnParent mirrors the production shape that exposed both bugs
// (StockConsumptionAnnotation): a Cascade to-many, an inversed to-one, and a
// to-one WITHOUT an inverse (salesAnnotation).

private let annihilationModelXML = """
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<model type="com.apple.IDECoreDataModeler.DataModel" documentVersion="1.0">
    <entity name="CDAnnParent" representedClassName="CDAnnParent" syncable="YES">
        <attribute name="identifier" attributeType="UUID"/>
        <attribute name="name" attributeType="String" optional="YES"/>
        <relationship name="children" optional="YES" toMany="YES" deletionRule="Cascade" destinationEntity="CDAnnChild" inverseName="parent" inverseEntity="CDAnnChild"/>
        <relationship name="target" optional="YES" deletionRule="Nullify" destinationEntity="CDAnnTarget" inverseName="holders" inverseEntity="CDAnnTarget"/>
        <relationship name="freeTarget" optional="YES" deletionRule="Nullify" destinationEntity="CDAnnTarget"/>
    </entity>
    <entity name="CDAnnChild" representedClassName="CDAnnChild" syncable="YES">
        <attribute name="identifier" attributeType="UUID"/>
        <relationship name="parent" optional="YES" deletionRule="Nullify" destinationEntity="CDAnnParent" inverseName="children" inverseEntity="CDAnnParent"/>
    </entity>
    <entity name="CDAnnTarget" representedClassName="CDAnnTarget" syncable="YES">
        <attribute name="identifier" attributeType="UUID"/>
        <relationship name="holders" optional="YES" toMany="YES" deletionRule="Nullify" destinationEntity="CDAnnParent" inverseName="target" inverseEntity="CDAnnParent"/>
    </entity>
</model>
"""

private let registerAnnihilationRuntimeClasses: Void = {
    _MIOCoreRegisterClass(type: CDAnnParent.self, forKey: "CDAnnParent")
    _MIOCoreRegisterClass(type: CDAnnChild.self, forKey: "CDAnnChild")
    _MIOCoreRegisterClass(type: CDAnnTarget.self, forKey: "CDAnnTarget")
}()

private func annihilationModel() -> CoreDataSwift.NSManagedObjectModel {
    _ = registerAnnihilationRuntimeClasses
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("CDAnnihilationModel-\(ProcessInfo.processInfo.processIdentifier).xml")
    if FileManager.default.fileExists(atPath: url.path) == false {
        try! annihilationModelXML.data(using: .utf8)!.write(to: url)
    }
    return CoreDataSwift.NSManagedObjectModel(contentsOf: url)!
}

// MARK: - Tests

final class AnnihilationTrackingTests: XCTestCase
{
    var container: CoreDataSwift.NSPersistentContainer!
    var moc: CoreDataSwift.NSManagedObjectContext!

    override func setUp() {
        super.setUp()

        container = CoreDataSwift.NSPersistentContainer(name: "CDAnnihilationTest", managedObjectModel: annihilationModel())
        let description = CoreDataSwift.NSPersistentStoreDescription()
        description.type = CoreDataSwift.NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores { _, error in
            if let error = error { fatalError("Store failed to load: \(error)") }
        }
        moc = container.viewContext
    }

    private func insert(_ entityName: String) -> CoreDataSwift.NSManagedObject {
        let obj = CoreDataSwift.NSEntityDescription.insertNewObject(forEntityName: entityName, into: moc)
        obj.setValue(UUID(), forKey: "identifier")
        return obj
    }

    private func assertUntracked(_ obj: CoreDataSwift.NSManagedObject, _ label: String) {
        XCTAssertFalse(moc.insertedObjects.contains(obj), "\(label) must not be inserted")
        XCTAssertFalse(moc.updatedObjects.contains(obj), "\(label) must not be updated (ghost-update revival)")
        XCTAssertFalse(moc.deletedObjects.contains(obj), "\(label) must not be a store delete")
        XCTAssertFalse(moc.registeredObjects.contains(obj), "\(label) must be unregistered")
    }

    // MARK: Ghost updates (bug 1)

    func testAnnihilatedInsertWithCascadeToManyLeavesEveryTrackingSet() {
        // The minimal trigger: a Cascade to-many — even empty — used to revive
        // the annihilated object into updatedObjects via deleteByCascade's
        // trailing _markUpdated(self).
        let parent = insert("CDAnnParent")
        moc.delete(parent)

        assertUntracked(parent, "annihilated parent")
        XCTAssertFalse(moc.hasChanges, "nothing left to save after annihilation")
    }

    func testCascadeAnnihilationOfChildLeavesEveryTrackingSet() {
        let parent = insert("CDAnnParent")
        let child = insert("CDAnnChild")
        child.setValue(parent, forKey: "parent")

        moc.delete(parent)

        assertUntracked(parent, "annihilated parent")
        assertUntracked(child, "cascade-annihilated child")
    }

    // MARK: Ghost resurrection (bug 2)

    func testSiblingDeleteDoesNotResurrectAnnihilatedHolder() throws {
        // Production order: the holder annihilates first, then the target's own
        // delete propagation walks its inverse to-many — whose membership still
        // names the annihilated holder's temporary ID. Resolving that member
        // must skip it, not resurrect a ghost and mark it updated.
        let parent = insert("CDAnnParent")
        let target = insert("CDAnnTarget")
        parent.setValue(target, forKey: "target")

        moc.delete(parent)
        moc.delete(target)

        assertUntracked(parent, "annihilated holder")
        assertUntracked(target, "annihilated target")
        XCTAssertTrue(moc.updatedObjects.isEmpty, "no ghost may survive either deletion")
        XCTAssertTrue(moc.registeredObjects.isEmpty, "no resurrected object may be registered")
    }

    func testExistingObjectThrowsForAnnihilatedTemporaryID() {
        let target = insert("CDAnnTarget")
        let objectID = target.objectID
        XCTAssertTrue(objectID.isTemporaryID)

        moc.delete(target)

        XCTAssertThrowsError(try moc.existingObject(with: objectID),
                             "a temporary ID with no registered object has nothing to fault from")
    }

    // MARK: Surviving holder of an annihilated no-inverse target

    func testValueForKeyReadsNilForAnnihilatedNoInverseTarget() {
        // freeTarget has NO inverse (the StockConsumptionAnnotation.salesAnnotation
        // shape): annihilating the target cannot nullify the holder's pointer,
        // so the dangling read must degrade to nil — not to a hollow ghost
        // whose every attribute is nil.
        let parent = insert("CDAnnParent")
        let target = insert("CDAnnTarget")
        parent.setValue(target, forKey: "freeTarget")

        moc.delete(target)

        XCTAssertTrue(moc.insertedObjects.contains(parent), "the holder survives")
        XCTAssertNil(parent.value(forKey: "freeTarget"),
                     "an annihilated target reads as nil, not a resurrected ghost")
    }

    func testChangedValuesClearsAnnihilatedNoInverseTarget() {
        let parent = insert("CDAnnParent")
        let target = insert("CDAnnTarget")
        parent.setValue(target, forKey: "freeTarget")

        moc.delete(target)

        let changes = parent.changedValues()
        XCTAssertTrue(changes["freeTarget"] is NSNull,
                      "serialization must see a clear — the target never reached the store and never will, got: \(String(describing: changes["freeTarget"]))")
    }
}

#endif
