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

enum MIOCoreDataContextProtocolError : Error
{
    case entityDescriptionNotFound
}

public protocol MIOCoreDataContextProtocol
{
    var mom: NSManagedObjectModel { get }
    var moc: NSManagedObjectContext { get }
    
    func save() throws

#if APPLE_CORE_DATA
    func createEntity<T:NSManagedObject> ( _ entityName: String ) throws -> T
    func entity ( _ entityType: NSManagedObject.Type ) throws -> NSEntityDescription
#endif
    
}

#if APPLE_CORE_DATA
extension MIOCoreDataContextProtocol
{
    func createEntity<T:NSManagedObject> ( _ entityType: T.Type ) throws -> T {
        return NSEntityDescription.insertNewObject( forEntityName: entityType.description(), into: moc ) as! T
    }
    
    func entity ( _ entityType: NSManagedObject.Type ) throws -> NSEntityDescription {
        guard let e = mom.entitiesByName[ entityType.description() ] else {
            throw MIOCoreDataContextProtocolError.entityDescriptionNotFound
        }
        return e
    }
}
#endif
