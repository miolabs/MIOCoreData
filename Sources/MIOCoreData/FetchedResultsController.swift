//
//  MIOCoreData+RPC.swift
//  MIOCoreData
//
//  Created by Javier Segura Perez on 9/9/24.
//

import Foundation

class FetchedResultsController<T:NSFetchRequestResult>
{
    var _type: FetchedResultsControllerType
    
    init( type: FetchedResultsControllerType = .local, request: NSFetchRequest<T>, sectionNameKeyPath:String? = nil, cacheName:String? = nil ) {
        _type = type
        
        if _type != .local { MIOCoreDataRPCManager.shared.register( ) }
    }
    
    deinit {
        if _type != .local { MIOCoreDataRPCManager.shared.unregister( ) }
    }
    
    func performFetch() throws {
        
    }
}

extension FetchedResultsController
{
    enum FetchedResultsControllerType {
        case local
        case remote
        case both
    }
}
