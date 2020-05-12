//
//  File.swift
//  
//
//  Created by Javier Segura Perez on 12/05/2020.
//

import Foundation

public class NSPersistentContainer : NSObject
{
    let _name: String
    var name:String { get { return _name } }
    
    let _managedObjectModel: NSManagedObjectModel
    var managedObjectModel:NSManagedObjectModel { get { return _managedObjectModel } }
    
    let _managedObjectContext:NSManagedObjectContext?
    public var viewContext: NSManagedObjectContext { get { return _managedObjectContext! } }
    
    public convenience init(name: String){
//        let url = URL(fileURLWithPath: name)
//        let model = NSManagedObjectModel(contentsOf: url)
        self.init(name:name, managedObjectModel:NSManagedObjectModel())
    }
    
    public init(name: String, managedObjectModel model: NSManagedObjectModel) {
        self._name = name
        self._managedObjectModel = model
        self._managedObjectContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        super.init()
    }
    
    public func loadPersistentStores(completionHandler block: @escaping (NSPersistentStoreDescription, Error?) -> Void) {
        
    }
    
}
