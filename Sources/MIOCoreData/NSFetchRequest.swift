//
//  MIOFetchRequest.swift
//  DLAPIServer
//
//  Created by Javier Segura Perez on 22/05/2019.
//

import Foundation

public struct NSFetchRequestResultType : OptionSet
{
    public let rawValue:UInt
    public init(rawValue:UInt){
        self.rawValue = rawValue
    }
    
    public static var managedObjectResultType:NSFetchRequestResultType { get { return NSFetchRequestResultType(rawValue: 1 << 0) } }
    public static var managedObjectIDResultType:NSFetchRequestResultType { get { return NSFetchRequestResultType(rawValue: 1 << 1) } }
    public static var dictionaryResultType:NSFetchRequestResultType { get { return NSFetchRequestResultType(rawValue: 1 << 2) } }
    public static var countResultType:NSFetchRequestResultType{ get { return NSFetchRequestResultType(rawValue: 1 << 3) } }
}

public protocol NSFetchRequestResult : NSObjectProtocol
{
    
}

open class NSFetchRequest<ResultType> : NSPersistentStoreRequest where ResultType : NSFetchRequestResult
{
    var includesSubentities = true
    
    var predicate:NSPredicate?
    var fetchLimit = 0
    var fetchOffset = 0
    var fetchBatchSize = 0
    
    var sortDescriptors:[NSSortDescriptor]?
    var relationshipKeyPathsForPrefetching:[String]?
    
    var resultType = NSFetchRequestResultType.managedObjectResultType

    static func fetchRequest(withEntityName entityName:String) -> NSFetchRequest {
        let fetch = NSFetchRequest(entityName: entityName)
        return fetch;
    }
     
    public override init() {
        super.init()
    }
    
    public convenience init(entityName:String) {
        self.init()
        _entityName = entityName;
    }
    
    open var entity:NSEntityDescription?
    
    var _entityName:String?
    open var entityName:String? { get { return _entityName } }


}
