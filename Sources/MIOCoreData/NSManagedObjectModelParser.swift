//
//  File.swift
//  
//
//  Created by Javier Segura Perez on 14/05/2020.
//

import Foundation

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
        let parser = XMLParser(contentsOf: url)
        parser?.delegate = self
        
        parser?.parse()
    }
    
    // #region XML Parser delegate
    var currentEntity:NSEntityDescription?
    var currentConfigName:String?
        
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        
        //console.log("XMLParser: Start element (" + element + ")");
        
        if elementName == "entity" {
            
            let name = attributeDict["name"]
            let parentName = attributeDict["parentEntity"]
            let parentEntity = parentName != nil ? model.entitiesByName[parentName!] : nil
            
            currentEntity = NSEntityDescription(entityName: name!, parentEntity: parentEntity, managedObjectModel: model)
            
            NSLog("\n\n--- " + name!)
        }
        else if elementName == "attribute" {
            
            let name = attributeDict["name"]
            let type = attributeDict["attributeType"]
            let optional = attributeDict["optional"] != nil ? attributeDict["optional"]?.lowercased() : "yes"
            let syncable = attributeDict["syncable"]
            let defaultValueString = attributeDict["defaultValueString"]
            
            addAttribute(name: name!, type: type!, optional: optional, syncable: syncable, defaultValueString: defaultValueString)
        }
        else if elementName == "relationship" {
            
            let name = attributeDict["name"]
            let destinationEntityName = attributeDict["destinationEntity"]
            let toMany = attributeDict["toMany"]
            let optional = attributeDict["optional"] != nil ? attributeDict["optional"]?.lowercased() : "yes"
            let inverseName = attributeDict["inverseName"]
            let inverseEntityName = attributeDict["inverseEntity"]
            
            addRelationship(name:name!, destinationEntityName:destinationEntityName!, toMany:toMany, inverseName:inverseName, inverseEntityName:inverseEntityName, optional:optional);
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
        
        if (elementName == "entity") {
            model.entitiesByName[currentEntity!.managedObjectClassName] = currentEntity
            currentEntity = nil;
        }
    }
    
    func parserDidEndDocument(_ parser: XMLParser) {
        
        // Check every relation ship and assign the right destination entity
//        for let entityName in model.entitiesByName) {
//            
//            let e:MIOEntityDescription = this._entitiesByName[entityName];
//            for (var index = 0; index < e.relationships.length; index++) {
//                let r:MIORelationshipDescription = e.relationships[index];
//            
//                if (r.destinationEntity == null){
//                    let de = this._entitiesByName[r.destinationEntityName];
//                    r.destinationEntity = de;
//                }
//            }
//        }
        
        //console.log("datamodel.xml parser finished");
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "MIOManagedObjectModelDidParseDataModel") , object: nil)
    }
    
    func addAttribute(name:String, type:String, optional:String?, syncable:String?, defaultValueString:String?){
        
        //NSLog((serverName != null ? serverName : name) + " (" + type + ", optional=" + optional + (defaultValue != null? ", defaultValue: " + defaultValue : "") + "): ");
        
        var attrType = NSAttributeType.undefinedAttributeType
        var defaultValue:Any?
        
        switch(type){
        case "Boolean":
            attrType = NSAttributeType.booleanAttributeType
            defaultValue = (defaultValueString != nil && defaultValueString!.lowercased() == "true") ? true : false
            
        case "Integer":
            attrType = NSAttributeType.integer32AttributeType
            defaultValue = defaultValueString != nil ? defaultValue = Int(defaultValueString!) : nil
            
        case "Integer 8":
            attrType = NSAttributeType.integer16AttributeType
            defaultValue = defaultValueString != nil ? defaultValue = Int8(defaultValueString!) : nil
            
        case "Integer 16":
            attrType = NSAttributeType.integer16AttributeType
            defaultValue = defaultValueString != nil ? defaultValue = Int16(defaultValueString!) : nil
            
        case "Integer 32":
            attrType = NSAttributeType.integer32AttributeType
            defaultValue = defaultValueString != nil ? defaultValue = Int32(defaultValueString!) : nil
            
        case "Integer 64":
            attrType = NSAttributeType.integer64AttributeType
            defaultValue = defaultValueString != nil ? defaultValue = Int64(defaultValueString!) : nil
            
        case "Float":
            attrType = NSAttributeType.floatAttributeType
            defaultValue = defaultValueString != nil ? defaultValue = Float(defaultValueString!) : nil
            
        case "Decimal":
            attrType = NSAttributeType.decimalAttributeType
            defaultValue = defaultValueString != nil ? defaultValue = Double(defaultValueString!) : nil
            
        case "String":
            attrType = NSAttributeType.stringAttributeType
            defaultValue = defaultValueString
            
        case "Date":
            attrType = NSAttributeType.dateAttributeType;
            //if (defaultValueString != null) defaultValue = MIODateFromString(defaultValueString);
            
        default:
            NSLog("MIOManagedObjectModel: Unknown class type: " + type);
        }
        
        let optional = (optional != nil && optional!.lowercased() == "no") ? false : true
        let transient = (syncable != nil && syncable!.lowercased() == "no") ? false : true
        
        currentEntity?.addAttribute(name: name, type: attrType, defaultValue: defaultValue, optional: optional, transient: transient)
    }
    
    func addRelationship(name:String, destinationEntityName:String, toMany:String?, inverseName:String?, inverseEntityName:String?, optional:String?){
        
        //let optional = (optional != nil && optional!.lowercased() == "no") ? false : true
        let isToMany = (toMany != nil && toMany?.lowercased() == "yes") ? true : false
                
        currentEntity?.addRelationship(name: name, destinationEntityName: destinationEntityName, toMany: isToMany, inverseName: inverseName, inverseEntityName: inverseEntityName)
    }
    
    /*
     // XML Parser delegate
     parserDidStartElement(parser:MIOXMLParser, element:string, attributes){
     
     //console.log("XMLParser: Start element (" + element + ")");
     
     if (element == "entity"){
     
     let name = attributes["name"];
     let parentName = attributes["parentEntity"];
     let parentEntity = parentName != null ? this._entitiesByName[parentName] : null;
     
     this.currentEntity = new MIOEntityDescription();
     this.currentEntity.initWithEntityName(name, parentEntity);
     
     MIOLog("\n\n--- " + name);
     }
     else if (element == "attribute") {
     
     let name = attributes["name"];
     let type = attributes["attributeType"];
     let serverName = attributes["serverName"];
     let optional = attributes["optional"] != null ? attributes["optional"].toLowerCase() : "yes";
     let optionalValue = optional == "no" ? false : true;
     let syncable = attributes["syncable"];
     let defaultValueString = attributes["defaultValueString"];
     this._addAttribute(name, type, optionalValue, serverName, syncable, defaultValueString);
     }
     else if (element == "relationship") {
     
     let name = attributes["name"];
     let destinationEntityName = attributes["destinationEntity"];
     let toMany = attributes["toMany"];
     let serverName = attributes["serverName"];
     let optional = attributes["optional"] != null ? attributes["optional"].toLowerCase() : "yes";
     let inverseName = attributes["inverseName"];
     let inverseEntity = attributes["inverseEntity"];
     this._addRelationship(name, destinationEntityName, toMany, serverName, inverseName, inverseEntity, optional);
     }
     else if (element == "configuration") {
     this.currentConfigName = attributes["name"];
     }
     else if (element == "memberEntity") {
     let entityName = attributes["name"];
     let entity = this._entitiesByName[entityName];
     this._setEntityForConfiguration(entity, this.currentConfigName);
     }
     
     }
     
     parserDidEndElement(parser:MIOXMLParser, element:string){
     
     //console.log("XMLParser: End element (" + element + ")");
     
     if (element == "entity") {
     let entity = this.currentEntity;
     this._entitiesByName[entity.managedObjectClassName] = entity;
     this.currentEntity = null;
     }
     }
     
     parserDidEndDocument(parser:MIOXMLParser){
     
     // Check every relation ship and assign the right destination entity
     for (var entityName in this._entitiesByName) {
     
     let e:MIOEntityDescription = this._entitiesByName[entityName];
     for (var index = 0; index < e.relationships.length; index++) {
     let r:MIORelationshipDescription = e.relationships[index];
     
     if (r.destinationEntity == null){
     let de = this._entitiesByName[r.destinationEntityName];
     r.destinationEntity = de;
     }
     }
     }
     
     //console.log("datamodel.xml parser finished");
     MIONotificationCenter.defaultCenter().postNotification("MIOManagedObjectModelDidParseDataModel", null);
     }
     */
    
}
