//
//  File.swift
//  
//
//  Created by Javier Segura Perez on 14/9/21.
//

import Foundation

#if APPLE_CORE_DATA
import CoreData
#endif

public protocol MIOCoreDataContextProtocol
{
    var mom: NSManagedObjectModel { get }
    var moc: NSManagedObjectContext { get }
    
    func save() throws
}
