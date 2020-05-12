//
//  MIOAttributeDescription.swift
//  DLAPIServer
//
//  Created by Javier Segura Perez on 21/05/2019.
//

import Foundation

public class NSAttributeDescription:NSPropertyDescription {
    
    var type: NSAttributeType!
    var defaultValue:Any?
    var syncable = true
    
    init(name:String, type:NSAttributeType, defaultValue:Any?, optional:Bool, syncable:Bool) {
        super.init()
        self.name = name
        self.type = type
        self.defaultValue = defaultValue
        self.optional = optional
        self.syncable = syncable
    }
}
