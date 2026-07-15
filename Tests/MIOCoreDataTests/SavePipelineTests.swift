//
//  SavePipelineTests.swift
//  MIOCoreDataTests
//
//  Covers the save pipeline:
//  - mandatory (non-optional) properties are validated before the store save
//  - validation failures collect into a single thrown error, nothing persists
//  - min/max count limits on to-many relationships
//  - the deny delete rule blocks deletion while related objects remain
//  - willSave/didSave hooks and the validateFor* subclass hooks run
//  - the DidSave notification carries the inserted/updated/deleted sets
//  - rollback discards pending changes and restores deleted objects
//  - validatesOnSave = false bypasses validation (migration escape hatch)
//
//  Self-contained: builds its model from inline XML and registers its own
//  runtime classes.
//

#if !APPLE_CORE_DATA

import XCTest
import Foundation
import MIOCore
@testable import CoreDataSwift

// MARK: - Runtime classes

class CDSaveValEntity: CoreDataSwift.NSManagedObject {}
class CDSaveValParent: CoreDataSwift.NSManagedObject {}
class CDSaveValChild: CoreDataSwift.NSManagedObject {}
class CDSaveValGroup: CoreDataSwift.NSManagedObject {}
class CDSaveValMember: CoreDataSwift.NSManagedObject {}
class CDSaveValDBDefault: CoreDataSwift.NSManagedObject {}

class CDSaveValHooked: CoreDataSwift.NSManagedObject {
    static var didSaveCount = 0

    override func willSave() {
        if value(forKey: "note") == nil { setValue("stamped", forKey: "note") }
    }

    override func didSave() { CDSaveValHooked.didSaveCount += 1 }
}

enum CDSaveValRejectError: Error { case rejected }

class CDSaveValReject: CoreDataSwift.NSManagedObject {
    override func validateForInsert() throws { throw CDSaveValRejectError.rejected }
}

// MARK: - Test model

private let savePipelineModelXML = """
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<model type="com.apple.IDECoreDataModeler.DataModel" documentVersion="1.0">
    <entity name="CDSaveValEntity" representedClassName="CDSaveValEntity" syncable="YES">
        <attribute name="name" attributeType="String"/>
        <attribute name="note" attributeType="String" optional="YES"/>
    </entity>
    <entity name="CDSaveValHooked" representedClassName="CDSaveValHooked" syncable="YES">
        <attribute name="name" attributeType="String" optional="YES"/>
        <attribute name="note" attributeType="String" optional="YES"/>
    </entity>
    <entity name="CDSaveValReject" representedClassName="CDSaveValReject" syncable="YES">
        <attribute name="name" attributeType="String" optional="YES"/>
    </entity>
    <entity name="CDSaveValParent" representedClassName="CDSaveValParent" syncable="YES">
        <attribute name="name" attributeType="String" optional="YES"/>
        <relationship name="children" destinationEntity="CDSaveValChild" toMany="YES" optional="YES" inverseName="parent" inverseEntity="CDSaveValChild" deletionRule="Deny"/>
    </entity>
    <entity name="CDSaveValChild" representedClassName="CDSaveValChild" syncable="YES">
        <attribute name="name" attributeType="String" optional="YES"/>
        <relationship name="parent" destinationEntity="CDSaveValParent" optional="YES" inverseName="children" inverseEntity="CDSaveValParent" deletionRule="Nullify"/>
    </entity>
    <entity name="CDSaveValGroup" representedClassName="CDSaveValGroup" syncable="YES">
        <attribute name="name" attributeType="String" optional="YES"/>
        <relationship name="members" destinationEntity="CDSaveValMember" toMany="YES" optional="YES" minCount="2" maxCount="3" deletionRule="Nullify"/>
    </entity>
    <entity name="CDSaveValMember" representedClassName="CDSaveValMember" syncable="YES">
        <attribute name="name" attributeType="String" optional="YES"/>
    </entity>
    <entity name="CDSaveValDBDefault" representedClassName="CDSaveValDBDefault" syncable="YES">
        <attribute name="name" attributeType="String" optional="YES"/>
        <attribute name="stamp" attributeType="Date">
            <userInfo>
                <entry key="DBDefaultFunction" value="appIdFromRequest"/>
            </userInfo>
        </attribute>
        <attribute name="seq" attributeType="Integer 64">
            <userInfo>
                <entry key="DBDefaultValue" value="true"/>
            </userInfo>
        </attribute>
    </entity>
</model>
"""

private let registerSavePipelineRuntimeClasses: Void = {
    _MIOCoreRegisterClass(type: CDSaveValEntity.self, forKey: "CDSaveValEntity")
    _MIOCoreRegisterClass(type: CDSaveValHooked.self, forKey: "CDSaveValHooked")
    _MIOCoreRegisterClass(type: CDSaveValReject.self, forKey: "CDSaveValReject")
    _MIOCoreRegisterClass(type: CDSaveValParent.self, forKey: "CDSaveValParent")
    _MIOCoreRegisterClass(type: CDSaveValChild.self, forKey: "CDSaveValChild")
    _MIOCoreRegisterClass(type: CDSaveValGroup.self, forKey: "CDSaveValGroup")
    _MIOCoreRegisterClass(type: CDSaveValMember.self, forKey: "CDSaveValMember")
    _MIOCoreRegisterClass(type: CDSaveValDBDefault.self, forKey: "CDSaveValDBDefault")
}()

private func savePipelineModel() -> CoreDataSwift.NSManagedObjectModel {
    _ = registerSavePipelineRuntimeClasses
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("CDSaveValModel-\(ProcessInfo.processInfo.processIdentifier).xml")
    if FileManager.default.fileExists(atPath: url.path) == false {
        try! savePipelineModelXML.data(using: .utf8)!.write(to: url)
    }
    return CoreDataSwift.NSManagedObjectModel(contentsOf: url)!
}

// MARK: - Tests

final class SavePipelineTests: XCTestCase
{
    var container: CoreDataSwift.NSPersistentContainer!
    var moc: CoreDataSwift.NSManagedObjectContext!

    override func setUp() {
        super.setUp()

        container = CoreDataSwift.NSPersistentContainer(name: "CDSaveValTest", managedObjectModel: savePipelineModel())
        let description = CoreDataSwift.NSPersistentStoreDescription()
        description.type = CoreDataSwift.NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores { _, error in
            if let error = error { fatalError("Store failed to load: \(error)") }
        }
        moc = container.viewContext
    }

    @discardableResult
    private func insert(_ entityName: String, name: String? = nil) -> CoreDataSwift.NSManagedObject {
        let obj = CoreDataSwift.NSEntityDescription.insertNewObject(forEntityName: entityName, into: moc)
        if let name = name { obj.setValue(name, forKey: "name") }
        return obj
    }

    // MARK: Mandatory property validation

    func testMandatoryViolationWarningPolicySavesAnyway() {
        // Opt-in escape hatch: downgrade missing-mandatory failures to logged
        // warnings for data sets that predate validation
        moc.mandatoryValidationPolicy = .warning
        insert("CDSaveValEntity")   // name is mandatory and not set

        XCTAssertNoThrow(try moc.save())
    }

    func testSaveThrowsWhenMandatoryAttributeMissing() {
        // Default policy: save() checks and fails
        let obj = insert("CDSaveValEntity")   // name is mandatory and not set

        XCTAssertThrowsError(try moc.save()) { error in
            guard case let NSManagedObjectValidationError.missingMandatoryProperty(entity, property, objectID) = error else {
                XCTFail("Expected missingMandatoryProperty, got \(error)")
                return
            }
            XCTAssertEqual(entity, "CDSaveValEntity")
            XCTAssertEqual(property, "name")
            XCTAssertFalse(objectID.isEmpty, "the error must identify the failing object")
        }

        // Nothing was persisted and the change is still pending: fixing the
        // object makes the same save succeed
        XCTAssertTrue(moc.hasChanges)
        obj.setValue("valid", forKey: "name")
        XCTAssertNoThrow(try moc.save())
    }

    func testSaveThrowsWhenMandatoryAttributeSetToNil() throws {
        let obj = insert("CDSaveValEntity", name: "valid")
        try moc.save()

        obj.setValue(nil, forKey: "name")
        XCTAssertThrowsError(try moc.save()) { error in
            guard case NSManagedObjectValidationError.missingMandatoryProperty = error else {
                XCTFail("Expected missingMandatoryProperty, got \(error)")
                return
            }
        }
    }

    func testValidationCollectsAllErrors() {
        insert("CDSaveValEntity")
        insert("CDSaveValEntity")

        XCTAssertThrowsError(try moc.save()) { error in
            guard case let NSManagedObjectValidationError.multiple(errors) = error else {
                XCTFail("Expected multiple validation errors, got \(error)")
                return
            }
            XCTAssertEqual(errors.count, 2)
        }
    }

    func testExternallyDefaultedPropertiesAreExemptFromMandatoryCheck() {
        // Both mandatory attributes are filled by someone else — "stamp" by a
        // server-side function (DBDefaultFunction) and "seq" by the database
        // itself (DBDefaultValue = true) — so saving without values must pass
        insert("CDSaveValDBDefault", name: "db-defaulted")

        XCTAssertNoThrow(try moc.save())
    }

    func testDBDefaultFunctionUntouchedValueStaysOutOfSavePayload() throws {
        // Never set by code: the key must not be part of what reaches the
        // store, so the DB default / server-side substitution can fill it
        let obj = insert("CDSaveValDBDefault", name: "untouched")
        try moc.save()

        let store = container.persistentStoreCoordinator.persistentStores[0]
        let row = store.objectsByEntityName["CDSaveValDBDefault"]?[obj.objectID.uriString]
        XCTAssertNotNil(row)
        XCTAssertNil(row?["stamp"], "an untouched DBDefaultFunction column must be absent from the save payload")
        XCTAssertEqual(row?["name"] as? String, "untouched")
    }

    func testDBDefaultFunctionValueChangedByCodeIsSent() throws {
        // Set by code: the value is intentional and goes to the store as-is,
        // overriding the DB default / server substitution
        let stamp = Date(timeIntervalSince1970: 1_000_000)
        let obj = insert("CDSaveValDBDefault", name: "explicit")
        obj.setValue(stamp, forKey: "stamp")
        try moc.save()

        let store = container.persistentStoreCoordinator.persistentStores[0]
        let row = store.objectsByEntityName["CDSaveValDBDefault"]?[obj.objectID.uriString]
        XCTAssertEqual(row?["stamp"] as? Date, stamp, "a code-set DBDefaultFunction value must reach the store")
    }

    func testValidatesOnSaveFlagBypassesValidation() {
        moc.validatesOnSave = false
        insert("CDSaveValEntity")   // invalid: mandatory name missing

        XCTAssertNoThrow(try moc.save())
    }

    // MARK: min/max count

    func testToManyCountLimits() {
        let members: [CoreDataSwift.NSManagedObject] = (0..<4).map { _ in insert("CDSaveValMember") }

        let group = insert("CDSaveValGroup")
        group.setValue(Set<CoreDataSwift.NSManagedObject>([members[0]]), forKey: "members")

        XCTAssertThrowsError(try moc.save()) { error in
            guard case NSManagedObjectValidationError.tooFewObjects = error else {
                XCTFail("Expected tooFewObjects, got \(error)")
                return
            }
        }

        group.setValue(Set<CoreDataSwift.NSManagedObject>(members), forKey: "members")
        XCTAssertThrowsError(try moc.save()) { error in
            guard case NSManagedObjectValidationError.tooManyObjects = error else {
                XCTFail("Expected tooManyObjects, got \(error)")
                return
            }
        }

        group.setValue(Set<CoreDataSwift.NSManagedObject>(members[0..<2]), forKey: "members")
        XCTAssertNoThrow(try moc.save())
    }

    // MARK: Deny delete rule

    func testDenyDeleteRuleBlocksAndUnblocks() throws {
        let parent = insert("CDSaveValParent", name: "parent")
        let child = insert("CDSaveValChild", name: "child")
        child.setValue(parent, forKey: "parent")
        try moc.save()

        moc.delete(parent)
        XCTAssertThrowsError(try moc.save()) { error in
            guard case let NSManagedObjectValidationError.deleteDenied(entity, relationship) = error else {
                XCTFail("Expected deleteDenied, got \(error)")
                return
            }
            XCTAssertEqual(entity, "CDSaveValParent")
            XCTAssertEqual(relationship, "children")
        }

        // Deleting the child in the same save unblocks the parent: objects
        // deleted in this save do not count against the deny rule
        moc.delete(child)
        XCTAssertNoThrow(try moc.save())
    }

    // MARK: Hooks

    func testWillSaveAndDidSaveHooksRun() throws {
        CDSaveValHooked.didSaveCount = 0

        let obj = insert("CDSaveValHooked", name: "hooked")
        try moc.save()

        // willSave stamped the note before the store save persisted it
        XCTAssertEqual(obj.committedValues(forKeys: ["note"])["note"] as? String, "stamped")
        XCTAssertEqual(CDSaveValHooked.didSaveCount, 1)
    }

    func testValidateForInsertSubclassHookBlocksSave() {
        insert("CDSaveValReject")

        XCTAssertThrowsError(try moc.save()) { error in
            guard case CDSaveValRejectError.rejected = error else {
                XCTFail("Expected CDSaveValRejectError.rejected, got \(error)")
                return
            }
        }
    }

    // MARK: DidSave notification

    func testDidSaveNotificationCarriesChangeSets() throws {
        var insertedCount = -1
        var updatedCount = -1
        var deletedCount = -1

        let observer = NotificationCenter.default.addObserver(forName: Notification.Name("NSManagedObjectContextDidSaveNotification"), object: moc, queue: nil) { (note: Notification) in
            insertedCount = (note.userInfo?[CoreDataSwift.NSInsertedObjectsKey] as? Set<CoreDataSwift.NSManagedObject>)?.count ?? -1
            updatedCount = (note.userInfo?[CoreDataSwift.NSUpdatedObjectsKey] as? Set<CoreDataSwift.NSManagedObject>)?.count ?? -1
            deletedCount = (note.userInfo?[CoreDataSwift.NSDeletedObjectsKey] as? Set<CoreDataSwift.NSManagedObject>)?.count ?? -1
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        insert("CDSaveValEntity", name: "notified")
        try moc.save()

        XCTAssertEqual(insertedCount, 1)
        XCTAssertEqual(updatedCount, 0)
        XCTAssertEqual(deletedCount, 0)
    }

    // MARK: rollback

    func testRollbackDiscardsInsert() throws {
        insert("CDSaveValEntity", name: "discarded")
        moc.rollback()

        XCTAssertFalse(moc.hasChanges)
        let request = CoreDataSwift.NSFetchRequest<CoreDataSwift.NSManagedObject>(entityName: "CDSaveValEntity")
        XCTAssertEqual(try moc.fetch(request).count, 0)
    }

    func testRollbackDiscardsUpdate() throws {
        let obj = insert("CDSaveValEntity", name: "committed")
        try moc.save()

        obj.setValue("pending", forKey: "name")
        moc.rollback()

        XCTAssertFalse(moc.hasChanges)
        XCTAssertEqual(obj.changedValues().count, 0)
        XCTAssertEqual(obj.value(forKey: "name") as? String, "committed")
    }

    func testRollbackRestoresDeletedObject() throws {
        let obj = insert("CDSaveValEntity", name: "restored")
        try moc.save()

        moc.delete(obj)
        XCTAssertTrue(obj.isDeleted)

        moc.rollback()

        XCTAssertFalse(obj.isDeleted)
        XCTAssertFalse(moc.hasChanges)
        let request = CoreDataSwift.NSFetchRequest<CoreDataSwift.NSManagedObject>(entityName: "CDSaveValEntity")
        XCTAssertEqual(try moc.fetch(request).count, 1)
    }
}

#endif
