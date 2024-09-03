//
//  ModelParser.swift
//  MIOCoreData
//
//  Created by Javier Segura Perez on 31/8/24.
//

import Foundation

#if canImport(FoundationXML)
import FoundationXML
#endif

enum ModelSubClassType
{
    case swift
    case objc
}

protocol ModelOutputDelegate
{
    func setNamespace      (parser:ModelParser, namespace:String?)
    func openModelEntity   (parser:ModelParser, filename:String, classname:String, parentName:String?)
    func closeModelEntity  (parser:ModelParser)
    func appendAttribute   (parser:ModelParser, name:String, type:String, optional:Bool, defaultValue:String?, usesScalarValueType:Bool)
    func appendRelationship(parser:ModelParser, name:String, destinationEntity:String, toMany:String, optional:Bool)
    func writeModelFile    (parser:ModelParser)
}

enum ModelParserError:Error
{
    case currentVersionNotFound
    case currenctVersionKeyNotFound
    case currentVersionKeyIsNotString
}

class ModelParser :NSObject, XMLParserDelegate
{
    public var modelPath:String
    var modelFilePath:String
    var modelFileContentPath:String
    var modelCustomClassesPath:String
    var modelType:ModelSubClassType
    var namespace:String?
    
    var outputDelegate:ModelOutputDelegate? = nil
    
    var customEntity:String?
    var customEntityFound = false
    
//    var code_generation = false
                
    init(withFilename filename:String, outputPath:String, type:ModelSubClassType, entity:String? = nil, namespace:String? = nil) throws
    {
        self.customEntity = entity
        
        guard let default_model_data = FileManager.default.contents(atPath: filename + "/.xccurrentversion") else {
            throw ModelParserError.currentVersionNotFound
        }
        
        guard let info = try PropertyListSerialization.propertyList(from: default_model_data, options: .mutableContainersAndLeaves, format: nil) as? [String:Any] else {
            throw ModelParserError.currenctVersionKeyNotFound
        }
        
        guard let contents_file_path = info[ "_XCCurrentVersionName" ] as? String else {
            throw ModelParserError.currentVersionKeyIsNotString
        }
                        
        self.modelFilePath = filename
        self.modelFileContentPath = filename + "/" + contents_file_path + "/contents"
        self.modelCustomClassesPath = ( modelFilePath as NSString ).deletingLastPathComponent + "/Classes"
        
        self.modelPath = outputPath
        
        self.modelType = type
        self.namespace = namespace
                
        switch type {
        case .swift: outputDelegate = SwiftModelOutputDelegate( objcSupport: false ); print( "ModelParser OBJC Support: false" )
        case .objc:  outputDelegate = SwiftModelOutputDelegate( objcSupport: true ); print( "ModelParser OBJC Support: true" )
        }
    }
    
    func parserDidStartDocument(_ parser: XMLParser) {
        outputDelegate?.setNamespace(parser: self, namespace: namespace)
    }
            
    func execute() {
                
        print("Parsing file: \(modelFileContentPath)")
        print("Custom Class folder: " + self.modelCustomClassesPath )
        
        let parser = XMLParser(contentsOf:URL(fileURLWithPath: modelFileContentPath))
        if (parser != nil) {
            parser!.delegate = self;
            parser!.parse();
        }
        else {
            print("Error creating parser\n")
        }
    }
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        
        if (elementName == "entity") {
            
            let filename = attributeDict["name"]
            let classname = attributeDict["representedClassName"]
            let parentName = attributeDict["parentEntity"]
//            code_generation = attributeDict["codeGenerationType"] == "category"
            
//            if code_generation == false { return }
            
            if customEntity != nil {
                if customEntity! != classname { return }
                customEntityFound = true
                outputDelegate?.openModelEntity(parser:self, filename:filename!, classname:classname!, parentName:parentName)
            }
            else {
                customEntityFound = true
                outputDelegate?.openModelEntity(parser:self, filename:filename!, classname:classname!, parentName:parentName)
            }
        }
        else if (elementName == "attribute") {
            
//            if code_generation == false { return }
            if customEntityFound == false { return }
            
            let name = attributeDict["name"]
            let type = attributeDict["attributeType"]
            let optional = attributeDict["optional"] ?? "NO"
            let defaultValue = attributeDict["defaultValueString"]
            let usesScalarValueType = attributeDict["usesScalarValueType"] ?? "YES"
            
            outputDelegate?.appendAttribute(parser:self, name:name!, type:type!, optional:(optional == "YES"), defaultValue: defaultValue, usesScalarValueType: (usesScalarValueType == "YES"))
        }
        else if (elementName == "relationship") {
            
//            if code_generation == false { return }
            if customEntityFound == false { return }
            
            let name = attributeDict["name"];
            let optional = attributeDict["optional"] ?? "NO";
            let destinationEntity = attributeDict["destinationEntity"];
            let toMany = attributeDict["toMany"] ?? "NO"
            
            if destinationEntity != nil {
                outputDelegate?.appendRelationship(parser:self, name:name!, destinationEntity:destinationEntity!, toMany:toMany, optional:(optional == "YES"))
            }
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
    
        if (elementName == "entity") {
//            if code_generation == false { return }
            if customEntityFound == false { return }
            customEntityFound = false
            outputDelegate?.closeModelEntity(parser:self)
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
    
    }
    
    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
    
    }
    
    func parserDidEndDocument(_ parser: XMLParser) {
        if customEntity == nil { outputDelegate?.writeModelFile(parser:self) }
    }
}
