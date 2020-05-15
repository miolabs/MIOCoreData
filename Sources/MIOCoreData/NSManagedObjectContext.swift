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
    
    open func execute(_ request: NSPersistentStoreRequest) throws -> NSPersistentStoreResult {
        
        let entityName = request.entityName
        let entity = NSEntityDescription.entity(forEntityName: entityName, in: self)
        request.entity = entity;
        
        //TODO: Get the store from configuration name
        let store: NSPersistentStore = persistentStoreCoordinator!.persistentStores[0];
        let objs = store._executeRequest(request, this);
        
        for (let index = 0; index < objs.length; index++) {
            let o = objs[index];
            this._registerObject(o);
        }
        
        if (request instanceof MIOFetchRequest) {
            let fetchRequest = request as MIOFetchRequest;
            let objects = _MIOPredicateFilterObjects(this.objectsByEntity[entityName], fetchRequest.predicate);
            objects = _MIOSortDescriptorSortObjects(objects, fetchRequest.sortDescriptors);
            return objects;
        }
        
        return [];
    }
    
    open func insert(_ object: NSManagedObject) {
        
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
