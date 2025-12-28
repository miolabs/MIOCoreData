//
//  NSPersistentContainer.swift
//  
//
//  Created by Javier Segura Perez on 12/05/2020.
//

#if !APPLE_CORE_DATA

import Foundation
import MIOCoreLogger

open class NSPersistentContainer : NSObject
{
    //open class func defaultDirectoryURL() -> URL
    
    let _name: String
    open var name:String { get { return _name } }

    let _managedObjectContext:NSManagedObjectContext?
    open var viewContext: NSManagedObjectContext { get { return _managedObjectContext! } }
    
    let _managedObjectModel: NSManagedObjectModel
    open var managedObjectModel:NSManagedObjectModel { get { return _managedObjectModel } }
    
    let _coordinator:NSPersistentStoreCoordinator
    open var persistentStoreCoordinator: NSPersistentStoreCoordinator { get { return _coordinator } }

    open var persistentStoreDescriptions: [NSPersistentStoreDescription] = []
    
    private static var instanceCount = 0
    private static let countQueue = DispatchQueue(label: "context.count")

    public convenience init(name: String){
//        let url = URL(fileURLWithPath: name)
//        let model = NSManagedObjectModel(contentsOf: url)
        self.init(name:name, managedObjectModel:NSManagedObjectModel())
    }
    
    public init(name: String, managedObjectModel model: NSManagedObjectModel) {
        Self.countQueue.sync { Self.instanceCount += 1 }
        _name = name
        _managedObjectModel = model
        _coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        _managedObjectContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        _managedObjectContext?.persistentStoreCoordinator = _coordinator
        super.init()
    }
    
    deinit {
        Self.countQueue.sync { Self.instanceCount -= 1 }
        Log.debug("NSPersistentContainer deinit. Alive: \(Self.instanceCount)")
    }
    
    public func loadPersistentStores(completionHandler block: @escaping (NSPersistentStoreDescription, Error?) -> Void) {
                        
        for desc in persistentStoreDescriptions {
            do {
                try _ = _coordinator.addPersistentStore(ofType: desc.type, configurationName: nil, at: desc.url)
            }
            catch _ {
            }
            
            block(desc, nil)
        }
    }
    
}

#endif
