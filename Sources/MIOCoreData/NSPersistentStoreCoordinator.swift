//
//  File.swift
//  
//
//  Created by Javier Segura Perez on 12/05/2020.
//

import Foundation

// Persistent store metadata dictionary keys:

// key in the metadata dictionary to identify the store type
public let NSStoreTypeKey = "NSStoreTypeKey"

// key in the metadata dictionary to identify the store UUID - the store UUID is useful to identify stores through URI representations, but it is NOT guaranteed to be unique (while the UUID generated for new stores is unique, users can freely copy files and thus the UUID stored inside, so developers that track/reference stores explicitly do need to be aware of duplicate UUIDs and potentially override the UUID when a new store is added to the list of known stores in their application)
public let NSStoreUUIDKey = "NSStoreUUIDKey"


open class NSPersistentStoreCoordinator : NSObject
{
    open var managedObjectModel:NSManagedObjectModel
        
    init(managedObjectModel: NSManagedObjectModel) {
        self.managedObjectModel = managedObjectModel
    }
    
    var _persistentStores:[NSPersistentStore] = []
    open var persistentStores: [NSPersistentStore] { get { return _persistentStores } }

    open var name: String?

    open func persistentStore(for URL: URL) -> NSPersistentStore? {
        return nil
    }

//    open func url(for store: NSPersistentStore) -> URL {
//
//    }

    open func setURL(_ url: URL, for store: NSPersistentStore) -> Bool {
        return true
    }

    open func addPersistentStore(ofType storeType: String, configurationName configuration: String?, at storeURL: URL?, options: [AnyHashable : Any]? = nil) throws -> NSPersistentStore {
        let newClass = NSClassFromString(storeType) as! NSPersistentStore.Type
        let store = newClass.init(persistentStoreCoordinator: self, configurationName: configuration, at: storeURL!, options: nil)
        _persistentStores.append(store)
        
        return store
    }
    
    open func addPersistentStore(with storeDescription: NSPersistentStoreDescription, completionHandler block: @escaping (NSPersistentStoreDescription, Error?) -> Void) {
        
    }
}
