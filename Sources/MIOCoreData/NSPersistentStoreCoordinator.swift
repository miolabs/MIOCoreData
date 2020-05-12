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
}
