//
//  MIOEntityDescription.swift
//  DLAPIServer
//
//  Created by Javier Segura Perez on 21/05/2019.
//

import Foundation

import MIOCore

open class NSEntityDescription : NSObject
{
    open class func entity(forEntityName entityName: String, in context: NSManagedObjectContext) -> NSEntityDescription? {
        return context.persistentStoreCoordinator?.managedObjectModel.entitiesByName[entityName]
    }

    open class func insertNewObject(forEntityName entityName: String, into context: NSManagedObjectContext) -> NSManagedObject {
        let model = context.persistentStoreCoordinator!.managedObjectModel
        //FIX: let objectClass = NSClassFromString(entityName) as! NSManagedObject.Type -> Doesn't work on Linux
        let objectClass = _MIOCoreClassFromString(entityName) as! NSManagedObject.Type
        let object = objectClass.init(entity: model.entitiesByName[entityName]!, insertInto: context)
        context.insert(object)
        return object
    }
    
    weak var _model:NSManagedObjectModel!
    unowned(unsafe) open var managedObjectModel: NSManagedObjectModel { get { return _model } }
    
    open var managedObjectClassName: String!
    
    open var name: String?
    
    open var isAbstract: Bool = false
    
    var _subentitiesByName:[String : NSEntityDescription] = [:]
    open var subentitiesByName: [String : NSEntityDescription] { get { return _subentitiesByName } }

    open var subentities: [NSEntityDescription] = []

    weak var _superentity:NSEntityDescription?
    unowned(unsafe) open var superentity: NSEntityDescription? { get { return _superentity } }

    var _propertiesByName:[String : NSPropertyDescription] = [:]
    open var propertiesByName: [String : NSPropertyDescription] { get { return _propertiesByName } }

    open var properties: [NSPropertyDescription] = []
     
    open var userInfo: [AnyHashable : Any]?

    // convenience methods to get the most common (and most relevant) types of properties for an entity
    var _attributesByName:[String : NSAttributeDescription] = [:]
    open var attributesByName: [String : NSAttributeDescription] { get { return _attributesByName } }

    var _relationshipsByName:[String : NSRelationshipDescription] = [:]
    open var relationshipsByName: [String : NSRelationshipDescription] { get { return _relationshipsByName } }

    open func relationships(forDestination entity: NSEntityDescription) -> [NSRelationshipDescription]{
        
        var relations = [NSRelationshipDescription]()
        for (_, rel) in relationshipsByName {
            if rel.destinationEntityName == entity.name {
                relations.append(rel)
            }
        }
            
        return relations
    }
    
    init(entityName:String, parentEntity:NSEntityDescription?, managedObjectModel model:NSManagedObjectModel) {
        name = entityName
        managedObjectClassName = entityName;
        _model = model
        super.init()
    }
        
    @discardableResult func addAttribute(name:String, type:NSAttributeType, defaultValue:Any?, optional:Bool, transient:Bool) -> NSAttributeDescription {
        let attr = NSAttributeDescription(name: name, type: type, defaultValue: defaultValue, optional: optional, transient: transient)
        attr._entity = self
        properties.append(attr)
        _propertiesByName[name] = attr
        _attributesByName[name] = attr
        
        return attr
    }

    @discardableResult func addRelationship(name:String, destinationEntityName:String, toMany:Bool, inverseName:String?, inverseEntityName:String?) -> NSRelationshipDescription {
        let rel = NSRelationshipDescription(name: name, destinationEntityName: destinationEntityName, toMany: toMany, inverseName:inverseName, inverseEntityName: inverseEntityName)
        rel._entity = self
        properties.append(rel)
        _propertiesByName[name] = rel
        _relationshipsByName[name] = rel
        
        return rel
    }
}
