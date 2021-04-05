//
//  NSManagedObjectModelParser.swift
//  
//
//  Created by Javier Segura Perez on 14/05/2020.
//

import Foundation

#if canImport(FoundationXML)
import FoundationXML
#endif

class ManagedObjectModelParser : NSObject, XMLParserDelegate
{
    let url:URL!
    let model:NSManagedObjectModel
    
    init(url:URL, model:NSManagedObjectModel){
        self.url = url
        self.model = model
        
        super.init()        
    }
    
    public func parse(){
        print("ManagedObjectModelParser:parse: Parsing contents of \(url.absoluteString)")
        
        guard let parser = XMLParser(contentsOf: url) else {
            print("ManagedObjectModelParser:parse: XMLParser is nil. file couldn't be read")
            return
        }
        
        parser.delegate = self
        _ = parser.parse()
    }
    
    // #region XML Parser delegate
    var entitiesByName:[String:NSEntityDescription] = [:]
    var currentEntity:NSEntityDescription?
    var currentAttribute:NSAttributeDescription?
    var currentRelationship:NSRelationshipDescription?
    var currentUserInfo:[String:Any]?
    var currentIndex:NSFetchIndexDescription?
    var currentConfigName:String?
        
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        
        //console.log("XMLParser: Start element (" + element + ")");
        
        if elementName == "entity" {
            
            let name = attributeDict["name"]
            let parentName = attributeDict["parentEntity"]
            let sync = attributeDict["syncable"]
            let isAbstract = attributeDict["isAbstract"] != nil ? attributeDict["isAbstract"]!.lowercased() : "no"
            
            currentEntity = NSEntityDescription(entityName: name!, parentEntity: nil, isAbstract: isAbstract, managedObjectModel: model)
            currentEntity!.parentEntityName = parentName
            
            if sync != nil && sync!.lowercased() == "no" {
                currentEntity!.userInfo = ["com.apple.syncservices.Syncable": false]
            }
        }
        else if elementName == "attribute" {
            
            let name = attributeDict["name"]
            let type = attributeDict["attributeType"]
            let optional = attributeDict["optional"] != nil ? attributeDict["optional"]!.lowercased() : "no"
            let syncable = attributeDict["syncable"]
            let defaultValueString = attributeDict["defaultValueString"]
            
            addAttribute(name: name!, type: type!, optional: optional, syncable: syncable, defaultValueString: defaultValueString)
        }
        else if elementName == "relationship" {
            
            let name = attributeDict["name"]
            let destinationEntityName = attributeDict["destinationEntity"]
            let toMany = attributeDict["toMany"]
            let optional = attributeDict["optional"] != nil ? attributeDict["optional"]!.lowercased() : "no"
            let inverseName = attributeDict["inverseName"]
            let inverseEntityName = attributeDict["inverseEntity"]
            let deletionRule = attributeDict["deletionRule"]
            
            addRelationship(name:name!, destinationEntityName:destinationEntityName!, toMany:toMany, inverseName:inverseName, inverseEntityName:inverseEntityName, optional:optional, deleteRuleString: deletionRule)
        }
        else if elementName == "userInfo" {
            currentUserInfo = [:]
        }
        else if elementName == "fetchIndex" {
            currentIndex = NSFetchIndexDescription(name: attributeDict[ "name" ]!, elements: [] )
        }
        else if elementName == "fetchIndexElement" {
            let property = currentEntity!.propertiesByName[ attributeDict["property"]! ]!
            currentIndex!.elements.append( NSFetchIndexElementDescription(property: property, collationType: attributeDict[ "type" ]?.lowercased() == "rtree" ? .rTree : .binary ) )
        }
        else if elementName == "entry" {
            if currentUserInfo != nil {
                if let key = attributeDict["key"] {
                    currentUserInfo![key] = attributeDict["value"]
                }
            }
        }
            
        else if elementName == "configuration" {
            //this.currentConfigName = attributes["name"];
        }
        else if elementName == "memberEntity" {
            //            let entityName = attributes["name"];
            //            let entity = this._entitiesByName[entityName];
            //            this._setEntityForConfiguration(entity, this.currentConfigName);
        }
        
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        //console.log("XMLParser: End element (" + element + ")");
        
        if elementName == "entity" {
            //model.entitiesByName[currentEntity!.managedObjectClassName] = currentEntity
            //model.setEntities([currentEntity!], forConfigurationName: "Default")
            entitiesByName[currentEntity!.name!] = currentEntity!
            currentEntity!.userInfo = currentUserInfo
            
            currentEntity = nil
            currentUserInfo = nil
        }
        else if elementName == "attribute" {
            currentAttribute!.userInfo = currentUserInfo
            
            currentAttribute = nil
            currentUserInfo = nil
        }
        else if elementName == "relationship" {
            currentRelationship!.userInfo = currentUserInfo
            
            currentRelationship = nil
            currentUserInfo = nil
        }
        else if elementName == "fetchIndex" {
            currentEntity!.indexes.append( currentIndex! )
            
            currentIndex = nil
        }
        else if elementName == "model" {
            //NSLog("ManagedObjectModelParser:didEndElement: End model")
            #if os(Linux)
            buildGraph()
            #endif
        }
    }
    
    func parserDidEndDocument(_ parser: XMLParser) {
                
        #if !os(Linux)
        buildGraph()
        #endif
        
        print("ManagedObjectModelParser:parserDidEndDocument: Parser finished")
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "MIOManagedObjectModelDidParseDataModel") , object: nil)
    }
    
    func buildGraph(){
        print("ManagedObjectModelParser:parserDidEndDocument: Check relationships")
        
        model.setEntities(Array(entitiesByName.values), forConfigurationName: "Default")
        
        // Check every relation ship and assign the right destination entity
        for (_, entity) in entitiesByName {
            entity.build()
        }        
    }
    
    func addAttribute(name:String, type:String, optional:String, syncable:String?, defaultValueString:String?){
        
        //NSLog("ManagedObjectModelParser:addAttribute: \(name) \(type)")
        
        var attrType = NSAttributeType.undefinedAttributeType
        var defaultValue:Any?
        
        switch(type){
        case "Boolean":
            attrType = NSAttributeType.booleanAttributeType
            if defaultValueString != nil {
                let def = defaultValueString!.lowercased()
                defaultValue = def == "true" || def == "yes"
            }
            
        case "Integer":
            attrType = NSAttributeType.integer32AttributeType
            defaultValue = defaultValueString != nil ? Int(defaultValueString!) : nil
            
        case "Integer 8":
            attrType = NSAttributeType.integer16AttributeType
            defaultValue = defaultValueString != nil ? Int8(defaultValueString!) : nil
            
        case "Integer 16":
            attrType = NSAttributeType.integer16AttributeType
            defaultValue = defaultValueString != nil ? Int16(defaultValueString!) : nil
            
        case "Integer 32":
            attrType = NSAttributeType.integer32AttributeType
            defaultValue = defaultValueString != nil ? Int32(defaultValueString!) : nil
            
        case "Integer 64":
            attrType = NSAttributeType.integer64AttributeType
            defaultValue = defaultValueString != nil ? Int64(defaultValueString!) : nil
            
        case "Float":
            attrType = NSAttributeType.floatAttributeType
            defaultValue = defaultValueString != nil ? Float(defaultValueString!) : nil
            
        case "Decimal":
            attrType = NSAttributeType.decimalAttributeType
            defaultValue = defaultValueString != nil ? Double(defaultValueString!) : nil
            
        case "String":
            attrType = NSAttributeType.stringAttributeType
            defaultValue = defaultValueString
            
        case "UUID":
            attrType = NSAttributeType.UUIDAttributeType
            defaultValue = defaultValueString == nil ? nil : UUID( uuidString: defaultValueString! )
            
        case "Date":
            attrType = NSAttributeType.dateAttributeType;
            //if (defaultValueString != null) defaultValue = MIODateFromString(defaultValueString);
            
        case "Transformable":
            attrType = NSAttributeType.transformableAttributeType
            
        default:
            print("MIOManagedObjectModel: Unknown class type: " + type);
        }
        
        let opt = optional.lowercased() == "yes" ? true : false
        let transient = (syncable != nil && syncable!.lowercased() == "no") ? false : true
        
        currentAttribute = currentEntity!.addAttribute(name: name, type: attrType, defaultValue: defaultValue, optional: opt, transient: transient)
    }
    
    func addRelationship(name:String, destinationEntityName:String, toMany:String?, inverseName:String?, inverseEntityName:String?, optional:String, deleteRuleString:String?){
                        
        let isToMany = (toMany != nil && toMany?.lowercased() == "yes") ? true : false
        let opt = optional.lowercased() == "yes" ? true : false
        
        //NSLog("ManagedObjectModelParser:addRelationship: \(name) \(destinationEntityName) toMany:\(isToMany ? "YES" : "NO")")
        var deleteRule = NSDeleteRule.noActionDeleteRule
        switch deleteRuleString {
        case "Nullify": deleteRule = .nullifyDeleteRule
        case "Cascade": deleteRule = .cascadeDeleteRule
        default:break
        }
                
        currentRelationship = currentEntity!.addRelationship(name: name, destinationEntityName: destinationEntityName, toMany: isToMany, optional: opt, inverseName: inverseName, inverseEntityName: inverseEntityName, deleteRule: deleteRule)
    }
}
