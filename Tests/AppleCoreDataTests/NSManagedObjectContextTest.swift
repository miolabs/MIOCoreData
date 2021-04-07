//
//  NSManagedObjectContextTest.swift
//  
//
//  Created by Javier Segura Perez on 5/4/21.
//

import Foundation
import CoreData

fileprivate var _persistentContainer: NSPersistentContainer? = nil

func ManagedObjectContextTest () -> NSManagedObjectContext
{
    if _persistentContainer != nil { return _persistentContainer!.viewContext }
    
    /*
     The persistent container for the application. This implementation
     creates and returns a container, having loaded the store for the
     application to it. This property is optional since there are legitimate
     error conditions that could cause the creation of the store to fail.
    */
    let container = NSPersistentContainer(name: "NSCoreDataTestStore")
    let description = NSPersistentStoreDescription()
    description.type = NSInMemoryStoreType
    container.persistentStoreDescriptions = [description]
    
    container.loadPersistentStores(completionHandler: { (storeDescription, error) in
        if let error = error {
            // Replace this implementation with code to handle the error appropriately.
            // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
             
            /*
             Typical reasons for an error here include:
             * The parent directory does not exist, cannot be created, or disallows writing.
             * The persistent store is not accessible, due to permissions or data protection when the device is locked.
             * The device is out of space.
             * The store could not be migrated to the current model version.
             Check the error message to determine what the actual problem was.
             */
            fatalError("Unresolved error \(error)")
        }
    })

    _persistentContainer = container
    
    populateMOM(container.managedObjectModel)
    
    return _persistentContainer!.viewContext
}

fileprivate func populateMOM(_ mom: NSManagedObjectModel ){
 
    let e1 = NSEntityDescription()
    let e1_attr_id = NSAttributeDescription()
    e1_attr_id.name = "identifier"
    e1_attr_id.attributeType = .UUIDAttributeType
    e1_attr_id.isOptional = false
    e1.properties.append(e1_attr_id)
    
    mom.entities.append(e1)
}
