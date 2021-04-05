//
//  MIOEntityDescription.swift
//  
//
//  Created by Javier Segura Perez on 21/05/2019.
//

import Foundation

import MIOCore

open class NSEntityDescription : NSObject
{
    public override init() {
    }
    
    open class func entity(forEntityName entityName: String, in context: NSManagedObjectContext) -> NSEntityDescription? {
        return context.persistentStoreCoordinator?.managedObjectModel.entitiesByName[entityName]
    }

    open class func insertNewObject(forEntityName entityName: String, into context: NSManagedObjectContext) -> NSManagedObject {
        let model = context.persistentStoreCoordinator!.managedObjectModel
        //FIX: let objectClass = NSClassFromString(entityName) as! NSManagedObject.Type -> Doesn't work on Linux
        let objectClass = _MIOCoreClassFromString(entityName) as! NSManagedObject.Type
        return objectClass.init(entity: model.entitiesByName[entityName]!, insertInto: context)
    }
    
    weak var _model:NSManagedObjectModel!
    unowned(unsafe) open var managedObjectModel: NSManagedObjectModel { get { return _model } }
    
    open var managedObjectClassName: String!
    
    open var name: String?
    
    var _isAbstract = false
    open var isAbstract: Bool { get { return _isAbstract } }
    
    var _subentitiesByName:[String : NSEntityDescription] = [:]
    open var subentitiesByName: [String : NSEntityDescription] { get { return _subentitiesByName } }

    open var subentities: [NSEntityDescription] = []

    open weak var _superentity:NSEntityDescription?
    unowned(unsafe) open var superentity: NSEntityDescription? { get { return _superentity } }

    var _propertiesByName:[String : NSPropertyDescription] = [:]
    open var propertiesByName: [String : NSPropertyDescription] { get { return _propertiesByName } }

    open var properties: [NSPropertyDescription] = []
     
    var _userInfo: [AnyHashable : Any]?
    open var userInfo: [AnyHashable : Any]? {
        get { return _userInfo }
        set {
            if _userInfo == nil {
                _userInfo = newValue
            }
            else if newValue != nil {
                for (key, value) in newValue! {
                    _userInfo![key] = value
                }
            }
        }
    }

    // convenience methods to get the most common (and most relevant) types of properties for an entity
    var _attributesByName:[String : NSAttributeDescription] = [:]
    open var attributesByName: [String : NSAttributeDescription] { get { return _attributesByName } }

    var _relationshipsByName:[String : NSRelationshipDescription] = [:]
    open var relationshipsByName: [String : NSRelationshipDescription] { get { return _relationshipsByName } }

    open var indexes: [NSFetchIndexDescription] = []
    
    open func relationships(forDestination entity: NSEntityDescription) -> [NSRelationshipDescription] {
        
        var relations = [NSRelationshipDescription]()
        for (_, rel) in relationshipsByName {
            if rel.destinationEntityName == entity.name {
                relations.append(rel)
            }
        }
            
        return relations
    }

    var _toManyRelationshipKeys: [String] = []
    var _toOneRelationshipKeys: [String] = []
    
    #if os(Linux)
    open var toManyRelationshipKeys: [ String ] { get { return _toManyRelationshipKeys } }
    open var toOneRelationshipKeys: [ String ] { get { return _toOneRelationshipKeys } }
    #else
    open override var toManyRelationshipKeys: [ String ] { get { return _toManyRelationshipKeys } }
    open override var toOneRelationshipKeys: [ String ] { get { return _toOneRelationshipKeys } }
    #endif
        
    init(entityName:String, parentEntity:NSEntityDescription?, isAbstract:String, managedObjectModel model:NSManagedObjectModel) {
        name = entityName
        managedObjectClassName = entityName
        _isAbstract = (isAbstract == "yes")
        _model = model
        super.init()
    }
    
    open var parentEntityName:String?
        
    @discardableResult func addAttribute(name:String, type:NSAttributeType, defaultValue:Any?, optional:Bool, transient:Bool) -> NSAttributeDescription {
        let attr = NSAttributeDescription(name: name, type: type, defaultValue: defaultValue, optional: optional, transient: transient)
        attr._entity = self
        properties.append(attr)
        _propertiesByName[name] = attr
        _attributesByName[name] = attr
        
        return attr
    }

    @discardableResult func addRelationship(name:String, destinationEntityName:String, toMany:Bool, optional:Bool, inverseName:String?, inverseEntityName:String?, deleteRule:NSDeleteRule) -> NSRelationshipDescription {
        let rel = NSRelationshipDescription(name: name, destinationEntityName: destinationEntityName, toMany: toMany, optional: optional, inverseName:inverseName, inverseEntityName: inverseEntityName)        
        rel._entity = self
        properties.append(rel)
        _propertiesByName[name] = rel
        _relationshipsByName[name] = rel
        if rel.isToMany {
            _toManyRelationshipKeys.append( name )
        } else {
            _toOneRelationshipKeys.append( name )
        }
        rel.deleteRule = deleteRule
        
        return rel
    }
    
    var isBuilt = false
    open func build() { 

        if isBuilt { return }
        isBuilt = true
        
        if let parentEntityName = parentEntityName {
            let parentEntity = managedObjectModel.entitiesByName[parentEntityName]
            _superentity = parentEntity
            parentEntity!.subentities.append(self)
            parentEntity!.build()
            
//            if userInfo != nil {
//               userInfo!.merge( parentEntity!.userInfo ?? [:] ){ (old,_new) in old }
//            }
            
            for (_, prop) in parentEntity!.propertiesByName {

                if prop is NSAttributeDescription {
                    let attr = prop as! NSAttributeDescription
                    let new_attr = addAttribute(name: attr.name, type: attr.attributeType, defaultValue: attr.defaultValue, optional: attr.isOptional, transient: attr.isTransient)
                    new_attr.userInfo = attr.userInfo
                }
                else if prop is NSRelationshipDescription {
                    let rel = prop as! NSRelationshipDescription
                    let new_rel = addRelationship(name: rel.name, destinationEntityName: rel.destinationEntityName, toMany: rel.isToMany, optional: rel.isOptional, inverseName: rel.inverseName, inverseEntityName: rel.inverseEntityName, deleteRule: rel.deleteRule)
                    new_rel.userInfo = rel.userInfo
                }
            }
        }
        
        for (_, rel) in relationshipsByName {
            if rel.destinationEntity == nil {
                rel.destinationEntity = managedObjectModel.entitiesByName[rel.destinationEntityName]
            }
            
            if rel.inverseName != nil && rel.inverseEntityName != nil {
                let inverseEntity = managedObjectModel.entitiesByName[rel.inverseEntityName!]
                let inverseRelation = inverseEntity?.relationshipsByName[rel.inverseName!]
                rel.inverseRelationship = inverseRelation
            }
        }
    }
}
