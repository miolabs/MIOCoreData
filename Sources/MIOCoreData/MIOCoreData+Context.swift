//
//  MIOCoreData+Context.swift
//
//
//  Created by Javier Segura Perez on 14/9/21.
//

import Foundation

enum MIOCoreDataContextError : Error
{
    case entityDescriptionNotFound
}

public protocol MIOCoreDataContextProtocol
{
    var mom: NSManagedObjectModel { get }
    var moc: NSManagedObjectContext { get }
    
//    func entity ( _ entityName: String ) throws -> NSEntityDescription
}


extension MIOCoreDataContextProtocol
{
    public func entity ( _ entityName: String ) throws -> NSEntityDescription {
        let e = mom.entitiesByName[ entityName ]
        if e != nil { return e! }
        
        throw MIOCoreDataContextError.entityDescriptionNotFound
    }
}

