#if !APPLE_CORE_DATA
// Generated class SimpleEntity by MIOTool
import Foundation
import MIOCoreData


extension SimpleEntity
{
    public var identifier:UUID { get { value(forKey: "identifier") as! UUID } set { setValue(newValue, forKey: "identifier") } }
    public var name:String { get { value(forKey: "name") as! String } set { setValue(newValue, forKey: "name") } }
    public var type:Int16 { get { value(forKey: "type") as! Int16 } set { setValue(newValue, forKey: "type") } }
}

// MARK: Generated accessors for primitivve values
extension SimpleEntity
{
    public var primitiveIdentifier:UUID { get { primitiveValue(forKey: "primitiveIdentifier") as! UUID } set { setPrimitiveValue(newValue, forKey: "primitiveIdentifier") } }
    public var primitiveName:String { get { primitiveValue(forKey: "primitiveName") as! String } set { setPrimitiveValue(newValue, forKey: "primitiveName") } }
    public var primitiveType:Int16 { get { primitiveValue(forKey: "primitiveType") as! Int16 } set { setPrimitiveValue(newValue, forKey: "primitiveType") } }
}
#endif
