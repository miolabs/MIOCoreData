//
//  MIOEntityDescription.swift
//  DLAPIServer
//
//  Created by Javier Segura Perez on 21/05/2019.
//

import Foundation

open class NSEntityDescription : NSObject
{
    
//    static func entity(entityName:String, context:NSManagedObjectContext?) -> NSEntityDescription? {
//        let entity = NSManagedObjectModel.entity(entityName: entityName, inManagedObjectContext: context)
//        return entity;
//    }

    open class func entity(forEntityName entityName: String, in context: NSManagedObjectContext) -> NSEntityDescription? {
        return nil
    }

    open class func insertNewObject(forEntityName entityName: String, into context: NSManagedObjectContext) -> NSManagedObject {
        let objectClass = NSClassFromString(entityName) as! NSManagedObject.Type
        let object = objectClass.init(context:context)
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

    var _relationships:[NSRelationshipDescription] = []
    open func relationships(forDestination entity: NSEntityDescription) -> [NSRelationshipDescription]{ return _relationships }
    
    init(entityName:String, parentEntity:NSEntityDescription?, managedObjectModel model:NSManagedObjectModel) {
        name = entityName
        managedObjectClassName = entityName;
        _model = model
        super.init()
    }
        
    func addAttribute(name:String, type:NSAttributeType, defaultValue:Any?, optional:Bool, transient:Bool) {
        let attr = NSAttributeDescription(name: name, type: type, defaultValue: defaultValue, optional: optional, transient: transient)
        properties.append(attr)
        _propertiesByName[name] = attr;
        _attributesByName[name] = attr;
    }

    func addRelationship(name:String, destinationEntityName:String, toMany:Bool, inverseName:String?, inverseEntityName:String?) {
        let rel = NSRelationshipDescription(name: name, destinationEntityName: destinationEntityName, toMany: toMany, inverseName:inverseName, inverseEntityName: inverseEntityName)
        properties.append(rel)
        _propertiesByName[name] = rel
        _relationships.append(rel)
        _relationshipsByName[name] = rel
    }
}
