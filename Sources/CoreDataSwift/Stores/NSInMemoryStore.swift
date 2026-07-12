//
//  NSInMemoryStore.swift
//
//
//  Created by Javier Segura Perez on 15/3/21.
//

#if !APPLE_CORE_DATA

import Foundation

class NSInMemoryStore : NSPersistentStore
{
    override func loadMetadata() throws {
        self.metadata = [NSStoreUUIDKey: UUID().uuidString.uppercased(), NSStoreTypeKey: NSInMemoryStoreType]
    }
                        
    override func save (insertedObjects: Set<NSManagedObject>, updatedObjects: Set<NSManagedObject>, deletedObjects: Set <NSManagedObject>, context:NSManagedObjectContext) throws {
        
        for o in insertedObjects {
            // The URI is the registry key in the context, so re-register around
            // the ID mutation — otherwise the object stays keyed by its old
            // temporary URI and existingObject(with:) duplicates it.
            context._unregisterObject(o, notifyStore: false)
            o.objectID._isTemporaryID = false
            o.objectID._persistentStore = self
            context._registerObject(o, notifyStore: false)

            var objects = objectsByEntityName[ o.entity.name! ] ?? [:]
            let id = o.objectID.uriString
            objects[id] = o.changedValues()
            objectsByEntityName[ o.entity.name! ] = objects
        }
        
        for o in updatedObjects {
            var objects = objectsByEntityName[ o.entity.name! ]!
            let id = o.objectID.uriString
            let values = objects[ id ]!
            objects[ id ] = values.merging( o.changedValues() ) { (_, new) in new }
            objectsByEntityName[ o.entity.name! ] = objects
        }
        
        for o in deletedObjects {
            var objects = objectsByEntityName[ o.entity.name! ]!
            let id = o.objectID.uriString
            objects.removeValue(forKey: id)
            objectsByEntityName[ o.entity.name! ] = objects
        }
    }
}
#endif
