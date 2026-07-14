//
//  AppleParityTests.swift
//  AppleCoreDataTests
//
//  Behavior-parity suite: runs the same scenarios MIOCoreDataTests pins for
//  CoreDataSwift against REAL Apple Core Data (in-memory store, programmatic
//  model — no compiled .momd needed). Where the two implementations are
//  meant to agree, the assertions here mirror the CoreDataSwift tests;
//  deliberate differences are marked DEVIATION and listed in DEVIATIONS.md.
//

#if canImport(CoreData) && !os(Linux)

import Foundation
import XCTest
import CoreData

// MARK: - Hook subclass

@objc(PHooked)
final class PHooked: NSManagedObject {
    static var didSaveCount = 0

    override func willSave() {
        // Guarded: Apple re-invokes willSave after changes made inside it
        if value(forKey: "note") == nil { setValue("stamped", forKey: "note") }
        super.willSave()
    }

    override func didSave() {
        PHooked.didSaveCount += 1
        super.didSave()
    }
}

// MARK: - Programmatic model

private func makeParityModel() -> NSManagedObjectModel {

    func attribute(_ name: String, _ type: NSAttributeType, optional: Bool = true, defaultValue: Any? = nil) -> NSAttributeDescription {
        let attr = NSAttributeDescription()
        attr.name = name
        attr.attributeType = type
        attr.isOptional = optional
        attr.defaultValue = defaultValue
        return attr
    }

    let entity = NSEntityDescription()
    entity.name = "PEntity"
    entity.managedObjectClassName = "NSManagedObject"
    entity.properties = [
        attribute("name", .stringAttributeType),
        attribute("counter", .integer32AttributeType, optional: false, defaultValue: Int32(7)),
        attribute("score", .doubleAttributeType),
    ]

    let parent = NSEntityDescription()
    parent.name = "PParent"
    parent.managedObjectClassName = "NSManagedObject"

    let child = NSEntityDescription()
    child.name = "PChild"
    child.managedObjectClassName = "NSManagedObject"

    let children = NSRelationshipDescription()
    children.name = "children"
    children.destinationEntity = child
    children.minCount = 0
    children.maxCount = 0                      // to-many
    children.isOptional = true
    children.deleteRule = .denyDeleteRule

    let parentRel = NSRelationshipDescription()
    parentRel.name = "parent"
    parentRel.destinationEntity = parent
    parentRel.minCount = 0
    parentRel.maxCount = 1                     // to-one
    parentRel.isOptional = true
    parentRel.deleteRule = .nullifyDeleteRule

    children.inverseRelationship = parentRel
    parentRel.inverseRelationship = children

    parent.properties = [attribute("name", .stringAttributeType), children]
    child.properties = [attribute("name", .stringAttributeType), parentRel]

    let hooked = NSEntityDescription()
    hooked.name = "PHooked"
    hooked.managedObjectClassName = "PHooked"
    hooked.properties = [
        attribute("name", .stringAttributeType),
        attribute("note", .stringAttributeType),
    ]

    let model = NSManagedObjectModel()
    model.entities = [entity, parent, child, hooked]
    return model
}

// MARK: - Tests

final class AppleParityTests: XCTestCase
{
    var container: NSPersistentContainer!
    var moc: NSManagedObjectContext!

    override func setUp() {
        super.setUp()
        container = NSPersistentContainer(name: "Parity", managedObjectModel: makeParityModel())
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores { _, error in
            if let error = error { fatalError("\(error)") }
        }
        moc = container.viewContext
    }

    @discardableResult
    private func insertEntity(name: String? = nil, counter: Int32? = nil) -> NSManagedObject {
        let obj = NSEntityDescription.insertNewObject(forEntityName: "PEntity", into: moc)
        if let name = name { obj.setValue(name, forKey: "name") }
        if let counter = counter { obj.setValue(counter, forKey: "counter") }
        return obj
    }

    private func fetchNames(_ format: String, arguments: [Any] = []) throws -> Set<String> {
        let request = NSFetchRequest<NSManagedObject>(entityName: "PEntity")
        request.predicate = NSPredicate(format: format, argumentArray: arguments)
        return Set(try moc.fetch(request).compactMap { $0.value(forKey: "name") as? String })
    }

    // MARK: Defaults (parity with DefaultValuesTests)

    func testDefaultsPopulatedAtInsert() {
        let obj = insertEntity()
        XCTAssertEqual(obj.value(forKey: "counter") as? Int32, 7, "defaults readable right after insert — parity")
    }

    // MARK: Change tracking (parity with FaultingAndPrimitiveValueTests)

    func testChangedAndCommittedValues() throws {
        let obj = insertEntity(name: "committed")
        try moc.save()

        obj.setValue("pending", forKey: "name")
        XCTAssertEqual(obj.changedValues()["name"] as? String, "pending")
        XCTAssertEqual(obj.committedValues(forKeys: ["name"])["name"] as? String, "committed")

        try moc.save()
        XCTAssertEqual(obj.changedValues().count, 0)
        XCTAssertEqual(obj.committedValues(forKeys: ["name"])["name"] as? String, "pending")
    }

    func testSetPrimitiveValueIsNotTracked_DEVIATION() throws {
        // DEVIATION: Apple does not track setPrimitiveValue in changedValues;
        // CoreDataSwift deliberately does (so awakeFromInsert-set values
        // persist) — see DEVIATIONS.md
        let obj = insertEntity(name: "primitive")
        try moc.save()

        obj.setPrimitiveValue("sneaky", forKey: "name")
        XCTAssertEqual(obj.changedValues().count, 0, "Apple: primitive writes bypass change tracking")
    }

    func testTrackingFlagsClearAfterSave() throws {
        let obj = insertEntity(name: "flags")
        XCTAssertTrue(obj.isInserted)
        try moc.save()
        XCTAssertFalse(obj.isInserted)

        obj.setValue("flags-2", forKey: "name")
        XCTAssertTrue(obj.isUpdated)
        try moc.save()
        XCTAssertFalse(obj.isUpdated)
    }

    // MARK: refresh / rollback (parity with SavePipelineTests)

    func testRefreshWithoutMergeDiscardsPendingChanges() throws {
        let obj = insertEntity(name: "committed")
        try moc.save()

        obj.setValue("pending", forKey: "name")
        moc.refresh(obj, mergeChanges: false)

        XCTAssertEqual(obj.changedValues().count, 0)
        XCTAssertEqual(obj.value(forKey: "name") as? String, "committed")
    }

    func testRollbackRestoresDeletedObject() throws {
        let obj = insertEntity(name: "restored")
        try moc.save()

        moc.delete(obj)
        XCTAssertTrue(obj.isDeleted)
        moc.rollback()
        XCTAssertFalse(obj.isDeleted)

        let request = NSFetchRequest<NSManagedObject>(entityName: "PEntity")
        XCTAssertEqual(try moc.fetch(request).count, 1)
    }

    // MARK: Save validation (parity with SavePipelineTests)

    func testSaveThrowsWhenMandatoryAttributeSetToNil() throws {
        let obj = insertEntity(name: "valid")
        try moc.save()

        obj.setValue(nil, forKey: "counter")
        XCTAssertThrowsError(try moc.save()) { error in
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, NSCocoaErrorDomain)
            XCTAssertEqual(nsError.code, NSValidationMissingMandatoryPropertyError)
        }
        moc.rollback()
    }

    func testDenyDeleteRuleBlocksSave() throws {
        let parent = NSEntityDescription.insertNewObject(forEntityName: "PParent", into: moc)
        let child = NSEntityDescription.insertNewObject(forEntityName: "PChild", into: moc)
        child.setValue(parent, forKey: "parent")
        try moc.save()

        moc.delete(parent)
        XCTAssertThrowsError(try moc.save()) { error in
            let nsError = error as NSError
            XCTAssertEqual(nsError.code, NSValidationRelationshipDeniedDeleteError)
        }
        moc.rollback()
    }

    // MARK: Hooks and notifications (parity with SavePipelineTests)

    func testWillSaveAndDidSaveHooksRun() throws {
        PHooked.didSaveCount = 0

        let obj = NSEntityDescription.insertNewObject(forEntityName: "PHooked", into: moc)
        obj.setValue("hooked", forKey: "name")
        try moc.save()

        XCTAssertEqual(obj.committedValues(forKeys: ["note"])["note"] as? String, "stamped", "willSave changes persist — parity")
        XCTAssertEqual(PHooked.didSaveCount, 1)
    }

    func testDidSaveNotificationCarriesChangeSets() throws {
        var insertedCount = -1
        let observer = NotificationCenter.default.addObserver(forName: .NSManagedObjectContextDidSave, object: moc, queue: nil) { note in
            insertedCount = (note.userInfo?[NSInsertedObjectsKey] as? Set<NSManagedObject>)?.count ?? -1
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        insertEntity(name: "notified")
        try moc.save()

        XCTAssertEqual(insertedCount, 1, "userInfo carries the inserted set under the same key — parity")
    }

    // MARK: Predicate behavior (parity with MIOPredicateLanguageTests)

    func testStringOperators() throws {
        insertEntity(name: "prefix-match")
        insertEntity(name: "match-suffix")
        insertEntity(name: "Café con Leche")
        try moc.save()

        XCTAssertEqual(try fetchNames("name BEGINSWITH 'prefix'"), ["prefix-match"])
        XCTAssertEqual(try fetchNames("name ENDSWITH 'suffix'"), ["match-suffix"])
        XCTAssertEqual(try fetchNames("name CONTAINS[c] 'café'"), ["Café con Leche"])
        XCTAssertEqual(try fetchNames("name CONTAINS[cd] 'CAFE'"), ["Café con Leche"])
        XCTAssertEqual(try fetchNames("name LIKE 'prefix-*'"), ["prefix-match"])
        XCTAssertEqual(try fetchNames("name MATCHES '.*-suffix'"), ["match-suffix"])
    }

    func testBetweenAndIn() throws {
        insertEntity(name: "low", counter: 1)
        insertEntity(name: "mid", counter: 3)
        insertEntity(name: "edge", counter: 5)
        insertEntity(name: "high", counter: 9)
        try moc.save()

        XCTAssertEqual(try fetchNames("counter BETWEEN {2, 5}"), ["mid", "edge"])
        XCTAssertEqual(try fetchNames("counter IN %@", arguments: [[1, 9]]), ["low", "high"])
        XCTAssertEqual(try fetchNames("NOT (counter IN %@)", arguments: [[1, 9]]), ["mid", "edge"])
    }

    func testObjectArgumentPredicates() throws {
        let parentA = NSEntityDescription.insertNewObject(forEntityName: "PParent", into: moc)
        parentA.setValue("A", forKey: "name")
        let parentB = NSEntityDescription.insertNewObject(forEntityName: "PParent", into: moc)
        parentB.setValue("B", forKey: "name")

        for (name, parent) in [("childA1", parentA), ("childA2", parentA), ("childB", parentB)] {
            let child = NSEntityDescription.insertNewObject(forEntityName: "PChild", into: moc)
            child.setValue(name, forKey: "name")
            child.setValue(parent, forKey: "parent")
        }
        try moc.save()

        let request = NSFetchRequest<NSManagedObject>(entityName: "PChild")

        request.predicate = NSPredicate(format: "parent == %@", parentA)
        XCTAssertEqual(Set(try moc.fetch(request).compactMap { $0.value(forKey: "name") as? String }), ["childA1", "childA2"])

        request.predicate = NSPredicate(format: "parent == %@", parentB.objectID)
        XCTAssertEqual(Set(try moc.fetch(request).compactMap { $0.value(forKey: "name") as? String }), ["childB"])

        request.predicate = NSPredicate(format: "SELF IN %@", [parentA])
        let parents = NSFetchRequest<NSManagedObject>(entityName: "PParent")
        parents.predicate = request.predicate
        XCTAssertEqual(try moc.fetch(parents).count, 1)
    }

    func testAnyAllOverToMany() throws {
        func makeParent(_ name: String, childNames: [String]) {
            let parent = NSEntityDescription.insertNewObject(forEntityName: "PParent", into: moc)
            parent.setValue(name, forKey: "name")
            for childName in childNames {
                let child = NSEntityDescription.insertNewObject(forEntityName: "PChild", into: moc)
                child.setValue(childName, forKey: "name")
                child.setValue(parent, forKey: "parent")
            }
        }
        makeParent("mixed", childNames: ["ready", "pending"])
        makeParent("all-ready", childNames: ["ready", "ready"])
        makeParent("empty", childNames: [])
        try moc.save()

        let request = NSFetchRequest<NSManagedObject>(entityName: "PParent")

        request.predicate = NSPredicate(format: "ANY children.name == 'ready'")
        XCTAssertEqual(Set(try moc.fetch(request).compactMap { $0.value(forKey: "name") as? String }), ["mixed", "all-ready"])

        request.predicate = NSPredicate(format: "ALL children.name == 'ready'")
        let allNames = Set(try moc.fetch(request).compactMap { $0.value(forKey: "name") as? String })
        // Documents Apple's ALL semantics for the empty collection so the
        // CoreDataSwift behavior (vacuously true) can be compared explicitly
        print("== Apple ALL result: \(allNames)")
        XCTAssertTrue(allNames.contains("all-ready"))
    }
}

#endif
