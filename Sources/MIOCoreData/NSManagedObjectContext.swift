//
//  File.swift
//  
//
//  Created by Javier Segura Perez on 12/05/2020.
//

import Foundation

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
            let objectClass = NSClassFromString(objectID.entity.name!) as! NSManagedObject.Type
            obj = objectClass.init(entity: objectID.entity, insertInto: self)
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
        
    }
        
    // if flag is YES, merges an object with the state of the object available in the persistent store coordinator; if flag is NO, simply refaults an object without merging (which also causes other related managed objects to be released, so you can use this method to trim the portion of your object graph you want to hold in memory)
    open func refresh(_ object: NSManagedObject, mergeChanges flag: Bool) {
        
    }
    
    
    open func save() throws {
        
    }
    
    //    private managedObjectChanges = {};
    //
    //    private objectsByEntity = {};
    //    private objectsByID = {};
    //
    //    private insertedObjects: MIOSet = MIOSet.set();
    //    private updatedObjects: MIOSet = MIOSet.set();
    //    private deletedObjects: MIOSet = MIOSet.set();
    //
    //    private blockChanges = null;
    
    
    //    var _parent: MIOManagedObjectContext = null;
    //    set parent(value: MIOManagedObjectContext) {
    //        this._parent = value;
    //        if (value != null) {
    //            this.persistentStoreCoordinator = value.persistentStoreCoordinator;
    //        }
    //    }
    //    get parent() { return this._parent; }
    
    
}
