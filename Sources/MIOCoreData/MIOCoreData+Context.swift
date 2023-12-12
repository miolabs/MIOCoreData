//
//  MIOCoreData+Context.swift
//
//
//  Created by Javier Segura Perez on 14/9/21.
//

import Foundation

#if APPLE_CORE_DATA
@_exported import CoreData
#else
@_exported import CoreDataSwift
#endif

enum MIOCoreDataContextError : Error
{
    case entityDescriptionNotFound
}

public protocol MIOCoreDataContextProtocol
{
    var mom: NSManagedObjectModel { get }
    var moc: NSManagedObjectContext { get }
    
//    func save() throws
    
    func createEntity<T:NSManagedObject> ( _ entityName: String, id:UUID? ) throws -> T
    
    func entity ( _ entityName: String ) throws -> NSEntityDescription
//    func entity ( _ entityType: NSManagedObject.Type ) throws -> NSEntityDescription
}


extension MIOCoreDataContextProtocol
{
    
    public func createEntity<T:NSManagedObject> ( _ entityType: T.Type ) throws -> T {
        return NSEntityDescription.insertNewObject( forEntityName: entityType.description(), into: moc ) as! T
    }

    public func entity ( _ entityName: String ) throws -> NSEntityDescription {
        let e = mom.entitiesByName[ entityName ]
        if e != nil { return e! }
        
        throw MIOCoreDataContextError.entityDescriptionNotFound
    }
    
//    public func entity ( _ entityType: NSManagedObject.Type ) throws -> NSEntityDescription {
//        return try entity( entityType.description() )
//    }
    
}

