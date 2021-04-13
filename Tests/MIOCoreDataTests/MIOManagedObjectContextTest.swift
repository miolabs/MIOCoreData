//
//  MIOManagedObjectContextTest.swift
//
//
//  Created by Javier Segura Perez on 5/4/21.
//

import Foundation
import MIOCoreData

fileprivate var _persistentContainer: NSPersistentContainer? = nil

func MIOManagedObjectContextTest () -> NSManagedObjectContext
{
    if _persistentContainer != nil { return _persistentContainer!.viewContext }
    
    /*
     The persistent container for the application. This implementation
     creates and returns a container, having loaded the store for the
     application to it. This property is optional since there are legitimate
     error conditions that could cause the creation of the store to fail.
    */
    
    let documentPath = CommandLine.arguments.count < 2 ? "\(FileManager().currentDirectoryPath)" : CommandLine.arguments[1]
    
    let modelPath = documentPath.appending("/TestModel/TestModel.xcdatamodeld/TestModel.xcdatamodel/contents")

    let mom = NSManagedObjectModel(contentsOf: URL(string: modelPath)! )!
    
    let container = NSPersistentContainer(name: "TestModel", managedObjectModel: mom)
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
    mom.registerDataModelRuntimeObjects()
    
    return _persistentContainer!.viewContext
}
