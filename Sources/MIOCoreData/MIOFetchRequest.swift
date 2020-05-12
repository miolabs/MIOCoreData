//
//  MIOFetchRequest.swift
//  DLAPIServer
//
//  Created by Javier Segura Perez on 22/05/2019.
//

import Foundation

class NSFetchRequest:MIOPersistentStoreRequest {
    
    var entityName:String!
    var entity:MIOEntityDescription?
    var predicate:MIOPredicate?
    var sortDescriptors:MIOSortDescriptor?
    //resultType = MIOFetchRequestResultType.MIOManagedObject
    var fetchLimit = 0
    var fetchOffset = 0
    var relationshipKeyPathsForPrefetching:[String] = []

    static func fetchRequest(withEntityName entityName:String) -> NSFetchRequest {
        let fetch = MIOFetchRequest(withEntityName: entityName)
        return fetch;
    }
    
    init(withEntityName entityName:String) {
        super.init()
        self.entityName = entityName;
        self.requestType = MIORequestType.Fetch;
    }
}
