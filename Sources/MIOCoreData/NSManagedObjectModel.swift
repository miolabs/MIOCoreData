//
//  File.swift
//  
//
//  Created by Javier Segura Perez on 12/05/2020.
//

import Foundation

//#if os(Linux)
//import FoundationNetwork
//#endif

public class NSManagedObjectModel
{
    static func entity(entityName:String, context:NSManagedObjectContext) -> NSEntityDescription {
           
        let mom = context.persistentStoreCoordinator!.managedObjectModel;
        let entity = mom.entitiesByName[entityName];
           
//        if (entity == nil) {
//            throw new Error("MIOManagedObjectModel: Unkown entity \(entityName)");
//        }
           
        return entity!;
    }
        
    private var url:URL?
    public convenience init?(contentsOf url: URL) {
        self.init()
        self.url = url
        
//        URLSession.shared.dataTask(with: url) {
//            data, response, error in
//
//            print(data)
//            print(response)
//            print(error)
//        }
    }
    
    var entitiesByName: [String : NSEntityDescription] = [:]
    
    // MARK - URL Connection Delegate
    
}
