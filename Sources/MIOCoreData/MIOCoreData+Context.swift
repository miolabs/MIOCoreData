//
//  File.swift
//  
//
//  Created by Javier Segura Perez on 14/9/21.
//

import Foundation

public protocol MIOCoreDataContextProtocol
{
    var mom: NSManagedObjectModel { get }
    var moc: NSManagedObjectContext { get }
    
    func save() throws
}
