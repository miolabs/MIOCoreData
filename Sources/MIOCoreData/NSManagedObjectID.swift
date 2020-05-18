//
//  File.swift
//  
//
//  Created by Javier Segura Perez on 12/05/2020.
//

import Foundation

open class NSManagedObjectID : NSObject
{
    var _entity:NSEntityDescription
    open var entity: NSEntityDescription { get { return _entity } } // entity for the object identified by an ID
//
//    weak open var persistentStore: NSPersistentStore? { get } // persistent store that fetched the object identified by an ID
//
//    open var isTemporaryID: Bool { get } // indicates whether or not this ID will be replaced later, such as after a save operation (temporary IDs are assigned to newly inserted objects and replaced with permanent IDs when an object is written to a persistent store); most IDs return NO
//
//    open func uriRepresentation() -> URL // URI which provides an archivable reference to the object which this ID refers

    init(WithEntity entity:NSEntityDescription, referenceObject:String?){
        _entity = entity
    }
}
