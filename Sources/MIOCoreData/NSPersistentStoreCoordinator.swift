//
//  File.swift
//  
//
//  Created by Javier Segura Perez on 12/05/2020.
//

import Foundation

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

//    open func addPersistentStore(ofType storeType: String, configurationName configuration: String?, at storeURL: URL?, options: [AnyHashable : Any]? = nil) throws -> NSPersistentStore {
//
//    }
    
    open func addPersistentStore(with storeDescription: NSPersistentStoreDescription, completionHandler block: @escaping (NSPersistentStoreDescription, Error?) -> Void) {
        
    }
}
