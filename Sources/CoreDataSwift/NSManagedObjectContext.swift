//
//  NSManagedObjectContext.swift
//  
//
//  Created by Javier Segura Perez on 12/05/2020.
//

#if !APPLE_CORE_DATA

import Foundation
import MIOCore
import MIOCoreLogger


enum NSManagedObjectContextError: Error
{
    case fetchRequestEntityInvalid(_ entityName: String, functionName: String = #function)
    case parentContextsUnsupported
}

extension NSManagedObjectContextError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .fetchRequestEntityInvalid(entityName, functionName):
            return "NSManagedObjectContextError.fetchRequestEntityInvalid:\(entityName) \(functionName)."
        case .parentContextsUnsupported:
            return "NSManagedObjectContextError.parentContextsUnsupported: saving a child context is not implemented — the changes would be silently lost."
        }
    }
}

public enum NSManagedObjectValidationError: Error, LocalizedError
{
    case missingMandatoryProperty(entity: String, property: String, objectID: String)
    case tooFewObjects(entity: String, property: String, minimum: Int, count: Int)
    case tooManyObjects(entity: String, property: String, maximum: Int, count: Int)
    case deleteDenied(entity: String, relationship: String)
    case multiple([Error])

    public var errorDescription: String? {
        switch self {
        case let .missingMandatoryProperty(entity, property, objectID):
            return "\(entity).\(property) is mandatory and has no value (object: \(objectID))."
        case let .tooFewObjects(entity, property, minimum, count):
            return "\(entity).\(property) requires at least \(minimum) objects, has \(count)."
        case let .tooManyObjects(entity, property, maximum, count):
            return "\(entity).\(property) allows at most \(maximum) objects, has \(count)."
        case let .deleteDenied(entity, relationship):
            return "\(entity) cannot be deleted while \(relationship) still contains objects (deny delete rule)."
        case let .multiple(errors):
            return "Multiple validation errors:\n" + errors.map { "  - \($0.localizedDescription)" }.joined(separator: "\n")
        }
    }
}

extension Notification.Name
{
    public static let NSManagedObjectContextWillSave = Notification.Name("NSManagedObjectContextWillSaveNotification")
    public static let NSManagedObjectContextDidSave = Notification.Name("NSManagedObjectContextDidSaveNotification")
}

// userInfo keys of the DidSave notification; the values are Set<NSManagedObject>
public let NSInsertedObjectsKey = "inserted"
public let NSUpdatedObjectsKey = "updated"
public let NSDeletedObjectsKey = "deleted"


public enum NSManagedObjectContextConcurrencyType : UInt
{   
    case confinementConcurrencyType = 0
    case privateQueueConcurrencyType = 1
    case mainQueueConcurrencyType = 2
}

public enum NSMergePolicy
{
    case none
}

open class NSManagedObjectContext : NSObject
{
    var mergePolicy = NSMergePolicy.none
    
#if DEBUG && !os(WASI)
    private static var instanceCount = 0
    private static let countQueue = DispatchQueue(label: "context.count")
#endif

    public init(concurrencyType ct: NSManagedObjectContextConcurrencyType) {
#if DEBUG && !os(WASI)
        Self.countQueue.sync { Self.instanceCount += 1 }
#endif
        super.init()
        _concurrencyType = ct
    }

    deinit {
#if DEBUG && !os(WASI)
        Self.countQueue.sync { Self.instanceCount -= 1 }
        Log.debug("NSManagedObjectContext deinit - objects: \(objectsByID.count) - alive: \(Self.instanceCount)")
#endif
        objectsByID.removeAll()
        objectsByEntityName.removeAll()
    }
    
    /* asynchronously performs the block on the context's queue.  Encapsulates an autorelease pool and a call to processPendingChanges */
    open func perform(_ block: @escaping () -> Void) {
        // TODO: queue confinement. Executed inline so the block is not silently dropped.
        block()
    }

    /* synchronously performs the block on the context's queue.  May safely be called reentrantly.  */
    open func performAndWait(_ block: () -> Void) {
        // TODO: queue confinement. Executed inline so the block is not silently dropped.
        block()
    }
    
    /* coordinator which provides model and handles persistency (multiple contexts can share a coordinator) */
    open var persistentStoreCoordinator: NSPersistentStoreCoordinator?
    
    open weak var parent: NSManagedObjectContext?
    
    /* custom label for a context.  NSPrivateQueueConcurrencyType contexts will set the label on their queue */
    open var name: String?
    
    //open var undoManager: UndoManager?
    
    open var hasChanges: Bool { get { return insertedObjects.count > 0 || updatedObjects.count > 0 || deletedObjects.count > 0 } }
    
    var _userInfo = NSMutableDictionary()
    open var userInfo: NSMutableDictionary { get { return _userInfo } }
    
    var _concurrencyType = NSManagedObjectContextConcurrencyType.mainQueueConcurrencyType
    open var concurrencyType: NSManagedObjectContextConcurrencyType { get { return _concurrencyType } }
    
    
    // Keyed by the full URI string, not its hashValue: hashing alone made a
    // collision silently return the wrong object.
    var objectsByID:[String:NSManagedObject] = [:]

    /* returns the object for the specified ID if it is already registered in the context, or faults the object into the context.  It might perform I/O if the data is uncached.  If the object cannot be fetched, or does not exist, or cannot be faulted, it returns nil.  Unlike -objectWithID: it never returns a fault.  */
    open func existingObject(with objectID: NSManagedObjectID) throws -> NSManagedObject {

        var obj = objectsByID[objectID.uriString]
        
        //let store = objectID.persistentStore as! NSIncrementalStore
        //let node = try store.newValuesForObject(with: objectID, with: self)

        if obj == nil {
            //FIX: let objectClass = NSClassFromString(objectID.entity.name!) as! NSManagedObject.Type -> Doesn't work on Linux
            let objectClass = _MIOCoreClassFromString(objectID.entity.name!) as! NSManagedObject.Type
            obj = objectClass.init()
            obj!._objectID = objectID
            obj!._managedObjectContext = self

            obj!.awakeFromFetch()
            _registerObject(obj!)
        }
        // NOTE: an already-registered object is returned as-is. Refaulting it
        // here (the old behavior) discarded its cached values, so reading a
        // relationship with N members caused N store round-trips.

        return obj!
    }
    
    
    // method to fetch objects from the persistent stores into the context (fetch request defines the entity and predicate as well as a sort order for the objects); context will match the results from persistent stores with current changes in the context (so inserted objects are returned even if they are not persisted yet); to fetch a single object with an ID if it is not guaranteed to exist and thus -objectWithObjectID: cannot be used, one would create a predicate like [NSComparisonPredicate predicateWithLeftExpression:[NSExpression expressionForKeyPath:@"objectID"] rightExpression:[NSExpression expressionForConstantValue:<object id>] modifier:NSPredicateModifierDirect type:NSEqualToPredicateOperatorType options:0]
    //open func fetch(_ request: NSFetchRequest<NSFetchRequestResult>) throws -> [Any]
    open func fetch<T>(_ request: NSFetchRequest<T>) throws -> [T] where T : NSFetchRequestResult {
        let offset = request.fetchOffset

        if let store = persistentStoreCoordinator!.persistentStores[0] as? NSIncrementalStore {
            // --- NSLog("Fetch entity: \(request.entityName!)")

            request.entity = self.persistentStoreCoordinator?.managedObjectModel.entitiesByName[request.entityName!]
            if request.entity == nil {
                throw NSManagedObjectContextError.fetchRequestEntityInvalid(request.entityName!)
            }

            // The store executed the entire request in SQL (predicate,
            // ORDER BY, limit, offset), so its result is the committed truth
            // in DB order — never re-filtered or re-sorted here.
            let store_objs = try store.execute(request, with: self) as! [T]

            // includesPendingChanges == false: committed rows only (Apple
            // parity for the non-default flag value).
            if request.includesPendingChanges == false { return store_objs }
            if request.resultType != .managedObjectResultType { return store_objs }
            // The SQL offset already consumed committed rows; merging pending
            // changes into an offset window is not meaningful.
            if offset > 0 { return store_objs }
            if insertedObjects.isEmpty && updatedObjects.isEmpty && deletedObjects.isEmpty {
                return store_objs
            }

            // Apple parity for the default (includesPendingChanges == true):
            // merge this context's unsaved changes into the committed result —
            // pending deletes disappear, updated objects are re-evaluated
            // against their in-memory values, unsaved inserts join in. Only
            // when the merge actually changes something are the results
            // re-sorted and the limit re-applied.
            let fetch_entity_name = request.entity!.name
            func belongs(_ obj: NSManagedObject) -> Bool {
                var e: NSEntityDescription? = obj.entity
                while let current = e {
                    if current.name == fetch_entity_name { return true }
                    e = current.superentity
                }
                return false
            }
            func matches(_ obj: NSManagedObject) -> Bool {
                guard let predicate = request.predicate else { return true }
                return MIOPredicateEvaluate(object: obj, using: predicate)
            }

            var results = store_objs.map { $0 as! NSManagedObject }
            var merged = false

            if deletedObjects.isEmpty == false {
                let count = results.count
                results.removeAll { deletedObjects.contains($0) }
                merged = merged || results.count != count
            }

            if updatedObjects.isEmpty == false && request.predicate != nil {
                let count = results.count
                results.removeAll { updatedObjects.contains($0) && matches($0) == false }
                merged = merged || results.count != count

                let present = Set(results)
                for obj in updatedObjects {
                    if belongs(obj) && present.contains(obj) == false && matches(obj) {
                        results.append(obj)
                        merged = true
                    }
                }
            }

            for obj in insertedObjects {
                if belongs(obj) && matches(obj) {
                    results.append(obj)
                    merged = true
                }
            }

            if merged == false { return store_objs }

            if request.sortDescriptors != nil { results = results.sortedArray(using: request.sortDescriptors!) }
            if request.fetchLimit > 0 && results.count > request.fetchLimit {
                results = Array(results.prefix(request.fetchLimit))
            }
            return results as! [T]
        }

        // Non-incremental stores (in-memory) have no ordered source: filter
        // and sort the registered objects here. Flags this path does not
        // implement are reported once instead of silently ignored.
        if request.fetchBatchSize > 0 { Self._warnUnsupportedFetchFlagOnce("fetchBatchSize") }
        if request.propertiesToFetch != nil { Self._warnUnsupportedFetchFlagOnce("propertiesToFetch") }
        if request.propertiesToGroupBy != nil { Self._warnUnsupportedFetchFlagOnce("propertiesToGroupBy") }
        if request.havingPredicate != nil { Self._warnUnsupportedFetchFlagOnce("havingPredicate") }
        if request.returnsDistinctResults { Self._warnUnsupportedFetchFlagOnce("returnsDistinctResults") }

        let objs = objectsByEntityName[request.entityName!]
        if objs == nil { return [] }

        var results = objs!.filter(using: request.predicate) as! [T]
        if request.sortDescriptors != nil { results = results.sortedArray(using: request.sortDescriptors!) }

        // An offset past the end returns an empty result, like Core Data (slicing there would trap)
        if offset >= results.count { return offset == 0 ? results : [] }
        if request.fetchLimit == 0 { return Array( results[ offset... ] ) }

        let limit = min( offset + request.fetchLimit, results.count )
        return Array( results[ offset..<limit ] )
    }
    
//    open func execute(_ request: NSPersistentStoreRequest) throws -> NSPersistentStoreResult {
//
        //let entityName = request.entityName
//        let entity = NSEntityDescription.entity(forEntityName: entityName, in: self)
//        request.entity = entity;
//
//        //TODO: Get the store from configuration name
//        guard let store = persistentStoreCoordinator!.persistentStores[0] as? NSIncrementalStore else {
//            return [NSManagedObject]()
//        }
//
//        let objs = try store.execute(request, with: self) as! NSPersistentStoreResult
//
//        for (let index = 0; index < objs.length; index++) {
//            let o = objs[index];
//            this._registerObject(o);
//        }
//
//        if (request instanceof MIOFetchRequest) {
//            let fetchRequest = request as MIOFetchRequest;
//            let objects = _MIOPredicateFilterObjects(this.objectsByEntity[entityName], fetchRequest.predicate);
//            objects = _MIOSortDescriptorSortObjects(objects, fetchRequest.sortDescriptors);
//            return objects;
//        }
//
//        return [];
        
//        return objs
//    }
    
    open func insert(_ object: NSManagedObject) {
//        guard let store = persistentStoreCoordinator?.persistentStores[0] as? NSIncrementalStore else {
//            //TODO: Throws error. No Store
//            return
//          }

        //let objectID = object.objectID

//        objectID._setStoreIdentifier(store.identifier)
//        objectID._setPersistentStore(store)

        if updatedObjects.contains(object) { updatedObjects.remove(object) }

        insertedObjects.insert(object)
        _registerObject(object)
        object._setIsInserted(true)

        if object._managedObjectContext == nil { object._managedObjectContext = self }

        // Defaults belong to creation, not save: any read after insert must
        // already return them. This covers objects built with the plain init,
        // which never ran the designated init's _setDefaultValues (the call is
        // non-clobbering, so values set by the caller before insert survive).
        object._setDefaultValues()
    }
        
    // if flag is YES, merges an object with the state of the object available in the persistent store coordinator; if flag is NO, simply refaults an object without merging (which also causes other related managed objects to be released, so you can use this method to trim the portion of your object graph you want to hold in memory)
    open func refresh(_ object: NSManagedObject, mergeChanges flag: Bool) {
        if flag == false {
            // Apple semantics: discard the unsaved changes, then refault. The
            // old implementation kept the pending changes and marked the object
            // updated — refresh is not a way to dirty an object (use setValue),
            // it is a way to reload it.
            //
            // Inserted objects are exempt: they have no committed state to
            // reload, so discarding their pending values (which include the
            // model default values applied at init) would leave a hollow
            // object. They keep their values.
            if insertedObjects.contains(object) == false {
                object._changedValues = [:]
                if updatedObjects.contains(object) {
                    updatedObjects.remove(object)
                    object._setIsUpdated(false)
                }
            }
        }

        // Drop the snapshot so the next access reloads from the store; with
        // mergeChanges == true the pending changes stay applied on top.
        object.setIsFault(true)
    }

    private static var _warnedFetchFlags = Set<String>()
    private static let _warnedFetchFlagsLock = NSLock()
    static func _warnUnsupportedFetchFlagOnce(_ flag: String) {
        _warnedFetchFlagsLock.lock(); defer { _warnedFetchFlagsLock.unlock() }
        if _warnedFetchFlags.contains(flag) { return }
        _warnedFetchFlags.insert(flag)
        Log.warning("NSFetchRequest.\(flag) is not supported by the in-memory fetch path and is ignored")
    }

    // Track an object as dirty for the next save, without touching its
    // in-memory state. This is what setValue and friends call.
    func _markUpdated(_ object: NSManagedObject) {
        if insertedObjects.contains(object) { return }
        if deletedObjects.contains(object) { return }

        if updatedObjects.insert(object).inserted {
            object._setIsUpdated(true)
        }
    }
    
//    open func delete(_ object: NSManagedObject) {
//        var visited: Set<NSManagedObjectID> = Set()
//        _delete(object, visited: &visited)
//    }
    
//    func _delete(_ object: NSManagedObject, visited: inout Set<NSManagedObjectID>) {
    
    open func delete(_ object: NSManagedObject) {
        var cache:Set<NSManagedObject> = Set()
        cache.insert( object )
        _delete(object, cache: &cache)
    }
    
    func _delete(_ object: NSManagedObject, cache: inout Set<NSManagedObject>) {
        if deletedObjects.contains(object) { return }

        // Callback while the object graph is still intact, before delete
        // propagation tears the relationships down
        object.prepareForDeletion()

        insertedObjects.remove(object)
        object._setIsInserted(false)
        updatedObjects.remove(object)
        object._setIsUpdated(false)
        deletedObjects.insert(object)

        object._setIsDeleted(true, cache: &cache)
    }

            
    public var insertedObjects: Set<NSManagedObject> = Set()
    public var updatedObjects: Set<NSManagedObject> = Set()
    public var deletedObjects: Set<NSManagedObject> = Set()
    
    /* When false, save() skips the mandatory-property / delete-rule validation.
       Escape hatch for existing data sets that predate validation — prefer
       fixing the data over disabling the checks. */
    open var validatesOnSave = true

    /* How save() reacts to a non-optional property that has no value and no
       DBDefaultFunction to fill it: fail the save (default), or downgrade to
       a logged warning — an escape hatch for data sets that predate this
       validation. Count limits, deny delete rules and the validateFor* hooks
       always fail regardless of this policy. */
    public enum MIOMandatoryValidationPolicy { case error, warning }
    open var mandatoryValidationPolicy = MIOMandatoryValidationPolicy.error

    open func save() throws {

        // Check if nothing changed... to avoid unnecessay methods calls
        if insertedObjects.count == 0 && updatedObjects.count == 0 && deletedObjects.count == 0 { return }

        // The old implementation silently skipped the store save for child
        // contexts, losing the changes. Fail loudly until parent propagation
        // is implemented.
        guard parent == nil else { throw NSManagedObjectContextError.parentContextsUnsupported }

        // 1. willSave hooks. A willSave implementation may dirty other objects
        //    (or itself) through setValue — loop so newly dirtied objects get
        //    their willSave too. Each object is notified once; the iteration
        //    cap breaks pathological chains.
        var notified = Set<NSManagedObject>()
        var iterations = 0
        while iterations < 100 {
            let pending = insertedObjects.union(updatedObjects).union(deletedObjects).subtracting(notified)
            if pending.isEmpty { break }
            for obj in pending { obj.willSave() }
            notified.formUnion(pending)
            iterations += 1
        }

        #if !os(WASI) // wasm Foundation lacks the legacy Notification.Name post API
        NotificationCenter.default.post(name: .NSManagedObjectContextWillSave, object: self)
        #endif

        // 2. Validation — collect every failure instead of stopping at the
        //    first one, then fail before anything reaches the store.
        if validatesOnSave {
            var errors: [Error] = []

            for obj in insertedObjects {
                obj._validateMandatoryProperties(changedKeysOnly: false, errors: &errors)
                do { try obj.validateForInsert() } catch { errors.append(error) }
            }
            for obj in updatedObjects {
                obj._validateMandatoryProperties(changedKeysOnly: true, errors: &errors)
                do { try obj.validateForUpdate() } catch { errors.append(error) }
            }
            for obj in deletedObjects {
                obj._validateDeleteRules(errors: &errors)
                do { try obj.validateForDelete() } catch { errors.append(error) }
            }

            // A non-optional property that nobody fills (no code value, no
            // DBDefaultFunction) is a modeling/data problem — but existing
            // data sets predate this validation, so by default it warns
            // instead of failing the save
            if mandatoryValidationPolicy == .warning {
                errors = errors.filter { error in
                    if case NSManagedObjectValidationError.missingMandatoryProperty = error {
                        Log.warning("Save validation: \(error.localizedDescription)")
                        return false
                    }
                    return true
                }
            }

            if errors.count == 1 { throw errors[0] }
            if errors.count > 1 { throw NSManagedObjectValidationError.multiple(errors) }
        }

        // Keep the sets for the didSave hooks and the notification: the
        // tracking properties are cleared before those run
        let inserted = insertedObjects
        let updated = updatedObjects
        let deleted = deletedObjects

        // 3. Save to persistent store
        let store = persistentStoreCoordinator!.persistentStores[0]
        try store.save(insertedObjects: insertedObjects, updatedObjects: updatedObjects, deletedObjects: deletedObjects, context: self)

        // 4. Commit in-memory state
        for obj in inserted {
            obj._didCommit(inserted: true)
            obj._setIsInserted(false)
        }

        for obj in updated {
            obj._didCommit()
            obj._setIsUpdated(false)
        }

        for obj in deleted {
            obj._didCommit()
            _unregisterObject(obj)
        }

        insertedObjects = Set()
        updatedObjects = Set()
        deletedObjects = Set()

        // 5. didSave hooks and notification
        for obj in inserted { obj.didSave() }
        for obj in updated  { obj.didSave() }
        for obj in deleted  { obj.didSave() }

        #if os(WASI)
        // wasm Foundation only ships the typed-message NotificationCenter API.
        // TODO(wasm): replace with a WASI-compatible did-save event mechanism
        #else
        NotificationCenter.default.post(name: .NSManagedObjectContextDidSave, object: self, userInfo: [
            NSInsertedObjectsKey: inserted,
            NSUpdatedObjectsKey: updated,
            NSDeletedObjectsKey: deleted,
        ])
        #endif
    }
    
    var objectsByEntityName: [ String: Set<NSManagedObject> ] = [:]
    func _registerObject(_ object: NSManagedObject, notifyStore:Bool = true) {

        let key = object.objectID.uriString
        if objectsByID[key] != nil {
            Log.trace("Trying to register a managed object that has already been registered")
            return
        }

        objectsByID[key] = object

        _registerObjectForEntityName(object, object.entity)

        if notifyStore == false { return }

        if object.objectID.persistentStore is NSIncrementalStore {
            let store = object.objectID.persistentStore as! NSIncrementalStore
            store.managedObjectContextDidRegisterObjects(with:[object.objectID])
        }
    }

    func _registerObjectForEntityName(_ object: NSManagedObject, _ entity:NSEntityDescription) {

        // Subscript-with-default mutates the set inside the dictionary storage.
        // Copying the set out, inserting and writing it back copied the whole
        // set on every registration — O(n^2) over a fetch.
        objectsByEntityName[entity.name!, default: []].insert(object)

        if entity.superentity != nil {
            _registerObjectForEntityName(object, entity.superentity!)
        }

    }

    func _unregisterObject(_ object: NSManagedObject, notifyStore:Bool = true) {

        let key = object.objectID.uriString
        if objectsByID.removeValue(forKey: key) == nil {
            Log.trace("Trying to unregister a managed object that has not been registered")
            return
        }

        _unregisterObjectForEntityName(object, object.entity)

        if notifyStore == false { return }

        if object.objectID.persistentStore is NSIncrementalStore {
            let store = object.objectID.persistentStore as! NSIncrementalStore
            store.managedObjectContextDidUnregisterObjects(with:[object.objectID])
        }
    }

    func _unregisterObjectForEntityName(_ object: NSManagedObject, _ entity:NSEntityDescription) {
        objectsByEntityName[entity.name!]?.remove(object)

        if entity.superentity != nil {
            _unregisterObjectForEntityName(object, entity.superentity!)
        }
    }
    
    open func reset() {
                        
        var idsByStore:[String:Set<NSManagedObjectID>] = [:]
        for ps in persistentStoreCoordinator!.persistentStores {
            idsByStore[ps.identifier] = Set<NSManagedObjectID>()
        }

        for entityName in objectsByEntityName.keys {
            if let set = objectsByEntityName[entityName] {
                for o in set {
                    idsByStore[o.objectID.persistentStore!.identifier]!.insert(o.objectID)
                    _unregisterObject(o, notifyStore: false)
                }
            }
        }

        for ps in persistentStoreCoordinator!.persistentStores {
            if ps is NSIncrementalStore {
                let obj_ids = idsByStore[ps.identifier]!
                (ps as! NSIncrementalStore).managedObjectContextDidUnregisterObjects(with:Array(obj_ids))
            }
        }
    }
    
    open func rollback() {
        // Discard every pending change. Objects deleted in this session come
        // back (their delete propagation lives in other objects' pending
        // changes, which are discarded too); inserted objects leave the
        // context entirely.
        for obj in insertedObjects {
            obj._changedValues = [:]
            obj._setIsInserted(false)
            _unregisterObject(obj)
        }

        for obj in updatedObjects {
            obj._changedValues = [:]
            obj._setIsUpdated(false)
            obj.setIsFault(true)
        }

        for obj in deletedObjects {
            obj._changedValues = [:]
            obj._isDeleted = false
            obj.setIsFault(true)
        }

        insertedObjects = Set()
        updatedObjects = Set()
        deletedObjects = Set()
    }
    
    
}


#endif
