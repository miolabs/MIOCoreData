//
//  SwiftModelOutputDelegate.swift
//  MIOCoreData
//
//  Created by Javier Segura Perez on 31/8/24.
//

import Foundation

class SwiftModelOutputDelegate : ModelOutputDelegate
{
    var namespace:String? = nil
    
    var fileContent:String = ""
    var filename:String = ""

    var currentParentClassName:String?
    var currentClassName:String = ""
    var currentClassEntityName:String = ""
    
    var primitiveProperties:[String] = []
    var relationships:[String] = []
    var relationships2:[String] = []
    
    var _model_register_content:String = ""
    
    let _objc_support:Bool
    init( objcSupport:Bool ) {
        _objc_support = objcSupport
        if !_objc_support {
            _model_register_content += "import Foundation\n"
            _model_register_content += "import MIOCore\n"
            _model_register_content += "func _CORE_DATA_SWIFT_RegisterRuntimeObjects(){\n"
        }
    }
    
    func setNamespace(parser: ModelParser, namespace: String?) {
        self.namespace = namespace
    }
    
    func openModelEntity(parser:ModelParser, filename:String, classname:String, parentName:String?)
    {
        self.filename = "/\(filename)+CoreDataProperties.swift"
        let cn = classname
        currentClassEntityName = cn;
        currentClassName = classname;
        
        relationships = []
        primitiveProperties = []
        
        currentParentClassName = parentName
        
        fileContent = "\n"
        fileContent += "// Generated class \(cn) by MIO CORE DATA Model Builder\n"
        fileContent += "import Foundation\n"
        fileContent += "import MIOCoreData\n"
        fileContent += "\n\n"
        fileContent += "extension \(cn)\n{\n\n"
        if _objc_support { fileContent += "@nonobjc\n"}
        fileContent += "public class func fetchRequest() -> NSFetchRequest<\(cn)> {\n"
        fileContent += "  return NSFetchRequest<\(cn)>(entityName: \"\(cn)\") }\n\n"
    }
    
    func appendAttribute(parser:ModelParser, name:String, type:String, optional:Bool, defaultValue:String?, usesScalarValueType:Bool)
    {
        let t:String
        let cast_t:String
        
        switch type {
        
        case "Boolean":
            t = usesScalarValueType == false ? "NSNumber?" : "Bool"
            cast_t = usesScalarValueType == false ? "as? NSNumber" : "as! Bool"
        
        case "Integer":
            t = usesScalarValueType == false ? "NSNumber?" : "Int"
            cast_t = usesScalarValueType == false ? "as? NSNumber" : "as! Int"
                                
        case "Integer 16":
            t = usesScalarValueType == false ? "NSNumber?" : "Int16"
            cast_t = usesScalarValueType == false ? "as? NSNumber" : "as! Int16"
            
        case "Integer 8":
            t = usesScalarValueType == false ? "NSNumber?" : "Int8"
            cast_t = usesScalarValueType == false ? "as? NSNumber" : "as! Int8"
        
        case "Integer 32":
            t = usesScalarValueType == false ? "NSNumber?" : "Int32"
            cast_t = usesScalarValueType == false ? "as? NSNumber" : "as! Int32"
            
        case "Integer 64":
            t = usesScalarValueType == false ? "NSNumber?" : "Int64"
            cast_t = usesScalarValueType == false ? "as? NSNumber" : "as! Int64"

        case "Float":
            t = usesScalarValueType == false ? "NSNumber?" : "Float"
            cast_t = usesScalarValueType == false ? "as? NSNumber" : "as! Float"

        case "Double":
            t = usesScalarValueType == false ? "NSNumber?" : "Double"
            cast_t = usesScalarValueType == false ? "as? NSNumber" : "as! Double"
            
        case "Decimal":
            t = "NSDecimalNumber?"
            cast_t = "as? NSDecimalNumber"
            
            
        case "Transformable":
            t = optional ? "Any?" : "Any"
            cast_t = optional ? "" : "as! Any"
            
        default:
            t = optional ? "\(type)?" : type
            cast_t = optional ? "as? \(type)" : "as! \(type)"
        }
        
        // Setter and Getter of property value
        if _objc_support {
            fileContent += "    @NSManaged public var \(name):\(t)\n"
        } else {
            fileContent += "    public var \(name):\(t) { get { value(forKey: \"\(name)\") \(cast_t) } set { setValue(newValue, forKey: \"\(name)\") } }\n"
            // Setter and Getter of property primitive value (raw)
            let first = String(name.prefix(1))
            let cname = first.uppercased() + String(name.dropFirst())
            primitiveProperties.append("    public var primitive\(cname):\(t) { get { primitiveValue(forKey: \"primitive\(cname)\") \(cast_t) } set { setPrimitiveValue(newValue, forKey: \"primitive\(cname)\") } }\n")
        }
    }
    
    func appendRelationship(parser:ModelParser, name:String, destinationEntity:String, toMany:String, optional:Bool)
    {
        fileContent += "    // Relationship: \(name)\n"
        
        if toMany == "NO" {
            if _objc_support {
                fileContent += "    @NSManaged public var \(name):\(destinationEntity)\(optional ? "?" : "")\n"
            } else {
                fileContent += "    public var \(name):\(destinationEntity)\(optional ? "?" : "") { get { value(forKey: \"\(name)\") as\(optional ? "?" : "!")  \(destinationEntity) } set { setValue(newValue, forKey: \"\(name)\") }}\n"
            }
        }
        else {
            let first = String(name.prefix(1))
            let cname = first.uppercased() + String(name.dropFirst())
            
            if _objc_support {
                fileContent += "    @NSManaged public var \(name):Set<\(destinationEntity)>?\n"
                
                           
                var content = "// MARK: Generated accessors for \(name)\n"
                content += "extension \(self.currentClassName)\n"
                content += "{\n"
                content += "    @objc(add\(cname)Object:)\n"
                //content += "    @NSManaged public func addTo\(cname)(_ value: \(destinationEntity))\n"
                content += "    @NSManaged public func add\(cname)Object(_ value: \(destinationEntity))\n"
                content += "\n"
                content += "    @objc(remove\(cname)Object:)\n"
                //content += "    @NSManaged public func removeFrom\(cname)(_ value: \(destinationEntity))\n"
                content += "    @NSManaged public func remove\(cname)Object(_ value: \(destinationEntity))\n"
                content += "\n"
                content += "    @objc(add\(cname):)\n"
                //content += "    @NSManaged public func addTo\(cname)(_ values: NSSet)\n"
                content += "    @NSManaged public func add\(cname)(_ values: Set<\(destinationEntity)>)\n"
                content += "\n"
                content += "    @objc(remove\(cname):)\n"
                //content += "    @NSManaged public func removeFrom\(cname)(_ values: NSSet)\n"
                content += "    @NSManaged public func remove\(cname)(_ values: Set<\(destinationEntity)>)\n"
                content += "}\n"
                
                relationships.append(content)

            } else {
                fileContent += "    public var \(name):Set<\(destinationEntity)>? { get { value(forKey: \"\(name)\") as? Set<\(destinationEntity)> } set { setValue(newValue, forKey: \"\(name)\") }}\n"
                
                var content = "// MARK: Generated accessors for \(name)\n"
                content += "extension \(self.currentClassName)\n"
                content += "{\n"
                content += "    @objc(add\(cname)Object:)\n"
                content += "    public func add\(cname)Object(_ value: \(destinationEntity)) { _addObject(value, forKey: \"\(name)\") }\n"
                content += "\n"
                content += "    @objc(remove\(cname)Object:)\n"
                content += "    public func remove\(cname)Object(_ value: \(destinationEntity)) { _removeObject(value, forKey: \"\(name)\") }\n"
                content += "\n"
                content += "    @objc(add\(cname):)\n"
                content += "    public func add\(cname)(_ values: Set<\(destinationEntity)>) { for obj in values { _addObject(obj, forKey: \"\(name)\") } }\n"
                content += "\n"
                content += "    @objc(remove\(cname):)\n"
                content += "    public func remove\(cname)(_ values: Set<\(destinationEntity)>) { for obj in values { _removeObject(obj, forKey: \"\(name)\") } }\n"
                content += "}\n"
                
                relationships.append(content)
            }
            
        }
    }
    
    func closeModelEntity(parser:ModelParser)
    {
        fileContent += "}\n"
        
        for rel in relationships {
            fileContent += "\n" + rel
        }
                
        if !_objc_support
        {
            fileContent += "\n"
            fileContent += "// MARK: Generated accessors for primitive values\n"
            fileContent += "extension \(self.currentClassName)\n"
            fileContent += "{\n"
            for primitiveProperty in primitiveProperties {
                fileContent += primitiveProperty
            }
            fileContent += "}\n"
        }
            
        let modelPath = parser.modelPath
        let path = modelPath + filename
        //Write to disc
        WriteTextFile(content:fileContent, path:path)
                
        let check_path = parser.modelCustomClassesPath + "/" + self.currentClassName + "+CoreDataClass.swift"
        // Create Subclass in case that is not already create
        if ( FileManager.default.fileExists( atPath:check_path ) == false ) {
            var content = ""
            content += "//\n"
            content += "// Generated class \(self.currentClassName)\n"
            content += "//\n"
            content += "import Foundation\n"
            content += "import MIOCoreData\n"
            content += "\n"
            if _objc_support { content += "@objc(\(self.currentClassName))\n" }
            content += "public class \(self.currentClassName) : \(currentParentClassName ?? "NSManagedObject")\n"
            content += "{\n"
            content += "\n}\n"
            
            let fp = modelPath + "/" + self.currentClassName + "+CoreDataClass.swift"
            WriteTextFile(content: content, path: fp)
        }
        
        if !_objc_support {
            _model_register_content += "\n\t_MIOCoreRegisterClass(type: " + self.currentClassName + ".self, forKey: \"" + self.currentClassName + "\")"
        }
    }
    
    func writeModelFile(parser:ModelParser)
    {
        if !_objc_support {
            let modelPath = parser.modelPath
            
            _model_register_content += "\n}\n"
            
            let path = modelPath + "/_CoreDataClasses.swift"
            WriteTextFile(content:_model_register_content, path:path)
        }
    }
}
