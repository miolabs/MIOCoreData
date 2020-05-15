//
//  File.swift
//  
//
//  Created by Javier Segura Perez on 12/05/2020.
//

import Foundation

open class NSManagedObjectModel : NSObject
{
    static func entity(entityName:String, context:NSManagedObjectContext) -> NSEntityDescription {
           
        let mom = context.persistentStoreCoordinator!.managedObjectModel;
        let entity = mom.entitiesByName[entityName];
           
//        if (entity == nil) {
//            throw new Error("MIOManagedObjectModel: Unkown entity \(entityName)");
//        }
           
        return entity!;
    }
    
    
    public convenience init?(contentsOf url: URL) {
        self.init()
        
        let parser = ManagedObjectModelParser(url: url, model: self)
        parser.parse()
    }
        
    var entitiesByName: [String : NSEntityDescription] = [:]
    
}
