//
//  TestIncrementalStore.swift
//  MIOCoreData
//
//  Created by Javier Segura Perez on 16/2/25.
//

import Foundation
import MIOCoreData

enum TestIncrementalStoreError: Error
{
    case unknown
    case uninplemented
}

class TestIncrementalStore: NSIncrementalStore
{
    public static let storeType:String = "TestIncrementalStore"
    
    public override func loadMetadata() throws {
        self.metadata = [NSStoreUUIDKey: UUID().uuidString, NSStoreTypeKey: TestIncrementalStore.storeType]
    }
    
    public override func execute(_ request: NSPersistentStoreRequest, with context: NSManagedObjectContext?) throws -> Any {
        
        switch request {
            
        case let fetchRequest as NSFetchRequest<NSManagedObject>:
            return try fetch_objects( request: fetchRequest, with: context! )
            
        case let saveRequest as NSSaveChangesRequest:
            try save_objects( request: saveRequest, with: context! )
            return []
            
        default: return try super.execute(request, with: context)
        }
    }
    
    var _objects_by_entity_name:[String:[String:NSIncrementalStoreNode]] = [:]
    
    func fetch_objects( request:NSFetchRequest<NSManagedObject>, with context:NSManagedObjectContext ) throws -> [Any] {
        throw TestIncrementalStoreError.uninplemented
    }
    
    func save_objects( request:NSSaveChangesRequest, with context:NSManagedObjectContext ) throws {
        
        for obj in request.insertedObjects! {
            var objects = _objects_by_entity_name[ obj.entity.name! ] ?? [:]
            let node = NSIncrementalStoreNode(objectID: obj.objectID, withValues: obj.changedValues(), version: 1)
            objects[ obj.objectID.uriRepresentation().absoluteString ] = node
            _objects_by_entity_name[ obj.entity.name! ] = objects
        }
        
        for obj in request.updatedObjects! {
            let objects = _objects_by_entity_name[ obj.entity.name! ] ?? [:]
            let node = objects[ obj.objectID.uriRepresentation().absoluteString ]!
            node.update(withValues: obj.changedValues(), version: node.version + 1)
        }
        
        for obj in request.deletedObjects! {
            var objects = _objects_by_entity_name[ obj.entity.name! ] ?? [:]
            objects.removeValue(forKey: obj.objectID.uriRepresentation().absoluteString)
            _objects_by_entity_name[ obj.entity.name! ] = objects
        }
    }
    
    public override func newValuesForObject(with objectID: NSManagedObjectID, with context: NSManagedObjectContext) throws -> NSIncrementalStoreNode
    {
        let objects = _objects_by_entity_name[ objectID.entity.name! ]!
        return objects[ objectID.uriRepresentation().absoluteString ]!
    }
    
    public override func newValue(forRelationship relationship: NSRelationshipDescription, forObjectWith objectID: NSManagedObjectID, with context: NSManagedObjectContext?) throws -> Any
    {
    
        throw TestIncrementalStoreError.uninplemented
        
//        let identifier = referenceObject(for: objectID) as! UUID
//        
//        var node = try cacheNode( withIdentifier: identifier, entity: objectID.entity )
//        if node == nil {
//            node = try cacheNode(newNodeWithValues: [:], identifier: identifier, version: 0, entity: objectID.entity, objectID: objectID)
//        }
//        
//        if node!.version == 0 {
//            //let delegate = ( context!.persistentStoreCoordinator!.persistentStores[0] as! MIOPersistentStore ).delegate!
//            //print("\(delegate): newValue -> fetchObject: \(objectID.entity.name!).\(relationship.name) -> \(relationship.destinationEntity!.name!)://\(identifier)")
//            _log.debug( "MIOPersistenStore:newValue:forRelationship:forObjectWith:with: fetchObject \(objectID.entity.name!) \(identifier)" )
//            let ret = try fetchObject( withIdentifier:identifier, entityName: objectID.entity.name!, context:context! )
//            _log.debug( "MIOPersistenStore:newValue:forRelationship:forObjectWith:with: fetchObject \(objectID.entity.name!) \(identifier) : \(String(describing: ret))" )
//        }
//        
//        let value = try node!.value( forRelationship: relationship )
//        
//        if relationship.isToMany == false {
//            guard let relIdentifier = value as? UUID else { return NSNull() }
//            
//            var relNode = try cacheNode( withIdentifier: relIdentifier, entity: relationship.destinationEntity! )
//            if relNode == nil {
//                //let delegate = ( context!.persistentStoreCoordinator!.persistentStores[0] as! MIOPersistentStore ).delegate!
//                //print("\(delegate): newValue -> fetchObject: \(objectID.entity.name!).\(relationship.name) -> \(relationship.destinationEntity!.name!)://\(identifier)")
//                _log.debug( "MIOPersistenStore:newValue:forRelationship:forObjectWith:with: fetchObject \(relationship.destinationEntity!.name!) \(relIdentifier)" )
//                let ret = try fetchObject( withIdentifier:relIdentifier, entityName: relationship.destinationEntity!.name!, context:context! )
//                _log.debug( "MIOPersistenStore:newValue:forRelationship:forObjectWith:with: fetchObject \(objectID.entity.name!) \(identifier) : \(String(describing: ret))" )
//                relNode = try cacheNode(withIdentifier: relIdentifier, entity: relationship.destinationEntity!)
//            }
//            
//            if relNode == nil {
//                let delegate = ( context!.persistentStoreCoordinator!.persistentStores[0] as! MIOPersistentStore ).delegate!
//                _log.critical("CD CACHE NODE NULL: \(delegate): \(objectID.entity.name!).\(relationship.name) -> \(relationship.destinationEntity!.name!)://\(relIdentifier)")
//                throw MIOPersistentStoreError.identifierIsNull()
//            }
//            
//            if relNode!.version == 0 {
//                _log.debug( "MIOPersistenStore:newValue:forRelationship:forObjectWith:with: fetchObject \(relationship.destinationEntity!.name!) \(relIdentifier)" )
//                let ret = try fetchObject( withIdentifier:relIdentifier, entityName: relationship.destinationEntity!.name!, context:context! )
//                _log.debug( "MIOPersistenStore:newValue:forRelationship:forObjectWith:with: fetchObject \(relationship.destinationEntity!.name!) \(relIdentifier) : \(String(describing: ret))" )
//
//            }
//            
//            return relNode!.objectID
//        }
//        else {
//            if value is Set<NSManagedObject> {
//                return (value as! Set<NSManagedObject>).map{ $0.objectID }
//            }
//            
//            guard let relIdentifiers = value as? [UUID] else {
//                return [UUID]()
//            }
//            
//            var objectIDs:Set<NSManagedObjectID> = Set()
//            var faultNodeIDs:[UUID] = []
//            for relID in relIdentifiers {
//                let relNode = try cacheNode( withIdentifier: relID, entity: relationship.destinationEntity! )
//                if relNode == nil || relNode?.version == 0 { faultNodeIDs.append( relID ) }
//                else { objectIDs.insert( relNode!.objectID ) }
//            }
//            
//            if faultNodeIDs.isEmpty == false {
//                _log.debug( "MIOPersistenStore:newValue:forRelationship:forObjectWith:with: fetchObject \(relationship.destinationEntity!.name!) \(faultNodeIDs)" )
//                let ret = try fetchObjects(identifiers: faultNodeIDs, entityName: relationship.destinationEntity!.name!, context: context!)
//                _log.debug( "MIOPersistenStore:newValue:forRelationship:forObjectWith:with: fetchObject \(relationship.destinationEntity!.name!) \(faultNodeIDs) : \(String(describing: ret))" )
//
//                for relID in faultNodeIDs {
//                    let relNode = try cacheNode(withIdentifier: relID, entity: relationship.destinationEntity!)
//                    if relNode == nil {
//                        let delegate = (context!.persistentStoreCoordinator!.persistentStores[0] as! MIOPersistentStore ).delegate!
//                        _log.critical( "CD CACHE NODE NULL: \(delegate): \(objectID.entity.name!).\(relationship.name) -> \(relationship.destinationEntity!.name!)://\(relID)")
//                        throw MIOPersistentStoreError.identifierIsNull()
//                    }
//                    
//                    objectIDs.insert(relNode!.objectID)
//                }
//            }
//            
//            return Array( objectIDs )
//        }
    }
}
