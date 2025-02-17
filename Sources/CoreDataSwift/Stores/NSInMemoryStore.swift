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
            o.objectID._isTemporaryID = false
            o.objectID._persistentStore = self

            var objects = objectsByEntityName[ o.entity.name! ] ?? [:]
            let id = o.objectID.uriRepresentation().absoluteString
            objects[id] = o.changedValues()
            objectsByEntityName[ o.entity.name! ] = objects
        }
        
        for o in updatedObjects {
            var objects = objectsByEntityName[ o.entity.name! ]!
            let id = o.objectID.uriRepresentation().absoluteString
            let values = objects[ id ]!
            objects[ id ] = values.merging( o.changedValues() ) { (_, new) in new }
            objectsByEntityName[ o.entity.name! ] = objects
        }
        
        for o in deletedObjects {
            var objects = objectsByEntityName[ o.entity.name! ]!
            let id = o.objectID.uriRepresentation().absoluteString
            objects.removeValue(forKey: id)
            objectsByEntityName[ o.entity.name! ] = objects
        }
    }
}
#endif
