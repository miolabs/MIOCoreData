//
//  File.swift
//  
//
//  Created by Javier Segura Perez on 12/05/2020.
//

import Foundation

open class NSPropertyDescription : NSObject
{
    open weak var _entity:NSEntityDescription!
    unowned(unsafe) open var entity: NSEntityDescription { get { return _entity! } }
    
    open var name: String
    
    // The optional flag specifies whether a property's value can be nil or not (before an object can be persisted).
    open var isOptional: Bool
    
    // The transient flag specifies whether a property's value is persisted or ignored when an object is persisted - transient properties are still managed for undo/redo, validation, etc.
    open var isTransient: Bool
    
    open var userInfo: [AnyHashable : Any]?
    
    init(name:String, optional:Bool, transient:Bool) {
        self.name = name
        isOptional = optional
        isTransient = transient
        super.init()
    }
}
