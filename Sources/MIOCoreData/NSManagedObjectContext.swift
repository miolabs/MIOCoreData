//
//  File.swift
//  
//
//  Created by Javier Segura Perez on 12/05/2020.
//

import Foundation

import MIOCore

enum NSManagedObjectContextError: Error
{
    case fetchRequestEntityInvalid
}

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
    
    public init(concurrencyType ct: NSManagedObjectContextConcurrencyType) {
        super.init()
        _concurrencyType = ct
    }
    
    /* asynchronously performs the block on the context's queue.  Encapsulates an autorelease pool and a call to processPendingChanges */
    open func perform(_ block: @escaping () -> Void) {
        
    }
    
    /* synchronously performs the block on the context's queue.  May safely be called reentrantly.  */
    open func performAndWait(_ block: () -> Void) {
        
    }
    
    /* coordinator which provides model and handles persistency (multiple contexts can share a coordinator) */
    open var persistentStoreCoordinator: NSPersistentStoreCoordinator?
    
    open var parent: NSManagedObjectContext?
    
    /* custom label for a context.  NSPrivateQueueConcurrencyType contexts will set the label on their queue */
    open var name: String?
    
    //open var undoManager: UndoManager?
    
    var managedObjectChanges:[String:Any] = [:]
    open var hasChanges: Bool { get { return managedObjectChanges.count > 0 } }
    
    var _userInfo = NSMutableDictionary()
    open var userInfo: NSMutableDictionary { get { return _userInfo } }
    
    var _concurrencyType = NSManagedObjectContextConcurrencyType.mainQueueConcurrencyType
    open var concurrencyType: NSManagedObjectContextConcurrencyType { get { return _concurrencyType } }
    
    
    var objectsByID:[String:NSManagedObject] = [:]
    
    /* returns the object for the specified ID if it is already registered in the context, or faults the object into the context.  It might perform I/O if the data is uncached.  If the object cannot be fetched, or does not exist, or cannot be faulted, it returns nil.  Unlike -objectWithID: it never returns a fault.  */
    open func existingObject(with objectID: NSManagedObjectID) throws -> NSManagedObject {
        
        var obj = objectsByID[objectID.uriRepresentation().absoluteString]

        //let store = objectID.persistentStore as! NSIncrementalStore
        //let node = try store.newValuesForObject(with: objectID, with: self)

        if obj != nil {
            obj!.setIsFault(true)
        }
        else {
            
            //FIX: let objectClass = NSClassFromString(objectID.entity.name!) as! NSManagedObject.Type -> Doesn't work on Linux
            let objectClass = _MIOCoreClassFromString(objectID.entity.name!) as! NSManagedObject.Type
            obj = objectClass.init()
            obj!._objectID = objectID
            obj!._managedObjectContext = self
            obj!._isFault = true;
            obj!._storedValues = nil

            obj!.awakeFromFetch()
            //this._registerObject(obj);
        }

        return obj!
    }
    
    
    // method to fetch objects from the persistent stores into the context (fetch request defines the entity and predicate as well as a sort order for the objects); context will match the results from persistent stores with current changes in the context (so inserted objects are returned even if they are not persisted yet); to fetch a single object with an ID if it is not guaranteed to exist and thus -objectWithObjectID: cannot be used, one would create a predicate like [NSComparisonPredicate predicateWithLeftExpression:[NSExpression expressionForKeyPath:@"objectID"] rightExpression:[NSExpression expressionForConstantValue:<object id>] modifier:NSPredicateModifierDirect type:NSEqualToPredicateOperatorType options:0]
    //open func fetch(_ request: NSFetchRequest<NSFetchRequestResult>) throws -> [Any]
    open func fetch<T>(_ request: NSFetchRequest<T>) throws -> [T] where T : NSFetchRequestResult {
    
        guard let store = persistentStoreCoordinator!.persistentStores[0] as? NSIncrementalStore else {
            return []
        }

        request.entity = self.persistentStoreCoordinator?.managedObjectModel.entitiesByName[request.entityName!]
        if request.entity == nil {
            throw NSManagedObjectContextError.fetchRequestEntityInvalid
        }
        
        let objs = try store.execute(request, with: self) as! [T]
        
        return objs
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
        guard let store = persistentStoreCoordinator?.persistentStores[0] as? NSIncrementalStore else {
            //TODO: Throws error. No Store
            return
        }

        let objectID = object.objectID

//        objectID._setStoreIdentifier(store.identifier)
//        objectID._setPersistentStore(store)

        insertedObjects.insert(object)
        //this._registerObject(object);
        object._setIsInserted(true)
    }
        
    // if flag is YES, merges an object with the state of the object available in the persistent store coordinator; if flag is NO, simply refaults an object without merging (which also causes other related managed objects to be released, so you can use this method to trim the portion of your object graph you want to hold in memory)
    open func refresh(_ object: NSManagedObject, mergeChanges flag: Bool) {
        object.setIsFault(true)
    }
        
    var insertedObjects: Set<NSManagedObject> = Set()
    var updatedObjects: Set<NSManagedObject> = Set()
    var deletedObjects: Set<NSManagedObject> = Set()
    
    open func save() throws {
    
        // Check if nothing changed... to avoid unnecessay methods calls
        if insertedObjects.count == 0 && updatedObjects.count == 0 && deletedObjects.count == 0 { return }

        // There's changes, so keep going...
        //MIONotificationCenter.defaultCenter().postNotification(MIOManagedObjectContextWillSaveNotification, this);

        // Deleted objects
        var deletedObjectsByEntityName:[String:[NSManagedObject]] = [:]
        for delObj in deletedObjects {
            // Track object for save notification
            let entityName = delObj.entity.name!
            var array = deletedObjectsByEntityName[entityName]
            if array == nil {
                array = []
                deletedObjectsByEntityName[entityName] = array
            }
            array!.append(delObj)
        }

        // Inserted objects
        var insertedObjectsByEntityName:[String:[NSManagedObject]] = [:]
        for insObj in insertedObjects {
            _obtainPermanentIDForObject(insObj)

            // Track object for save notification
            let entityName = insObj.entity.name!
            var array = insertedObjectsByEntityName[entityName]
            if array == nil {
                array = []
                insertedObjectsByEntityName[entityName] = array
            }
            array!.append(insObj)
        }

        // Updated objects
        var updatedObjectsByEntityName:[String:[NSManagedObject]] = [:]
        for updObj in updatedObjects {

            // Track object for save notification
            let entityName = updObj.entity.name!
            var array = updatedObjectsByEntityName[entityName]
            if array == nil {
                array = []
                updatedObjectsByEntityName[entityName] = array
            }
            array!.append(updObj)
        }

        if parent == nil {
            // Save to persistent store
            let saveRequest = NSSaveChangesRequest(inserted: insertedObjects, updated: updatedObjects, deleted: deletedObjects, locked: nil)
            
            //TODO: Execute save per store configuration
            guard let store = persistentStoreCoordinator?.persistentStores[0] as? NSIncrementalStore else {
                //TODO: Throws error. No Store
                return
            }
            
            _ = try store.execute(saveRequest, with: self)

            //Clear values
            for obj in insertedObjects {
                obj._didCommit()
            }

            for obj in updatedObjects {
                obj._didCommit()
            }

            for obj in deletedObjects {
                obj._didCommit()
            }

            // Clear
            insertedObjects = Set()
            updatedObjects = Set()
            deletedObjects = Set()
        }

//        let objsChanges = {};
//        objsChanges[MIOInsertedObjectsKey] = insertedObjectsByEntityName;
//        objsChanges[MIOUpdatedObjectsKey] = updatedObjectsByEntityName;
//        objsChanges[MIODeletedObjectsKey] = deletedObjectsByEntityName;
//
//        let noty = new MIONotification(MIOManagedObjectContextDidSaveNotification, this, objsChanges);
//        if (this.parent != null) {
//            this.parent.mergeChangesFromContextDidSaveNotification(noty);
//        }
//
//        MIONotificationCenter.defaultCenter().postNotification(MIOManagedObjectContextDidSaveNotification, this, objsChanges);
        
    }
    
    func _obtainPermanentIDForObject(_ object: NSManagedObject) {
//        let store: NSPersistentStore = object.objectID.persistentStore
//        let objID = store._obtainPermanentIDForObject(object)
//
//        delete this.objectsByID[object.objectID.URIRepresentation.absoluteString];
//
//        object.objectID._setReferenceObject(objID._getReferenceObject());
//
//        this.objectsByID[object.objectID.URIRepresentation.absoluteString] = object;
    }

        
    
}
