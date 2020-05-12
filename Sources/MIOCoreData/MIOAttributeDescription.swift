//
//  MIOAttributeDescription.swift
//  DLAPIServer
//
//  Created by Javier Segura Perez on 21/05/2019.
//

import Foundation

class NSAttributeDescription:NSPropertyDescription {
    
    var type: MIOAttributeType!
    var defaultValue:Any?
    var syncable = true
    
    init(name:String, type:MIOAttributeType, defaultValue:Any?, optional:Bool, syncable:Bool) {
        super.init()
        self.name = name
        self.type = type
        self.defaultValue = defaultValue
        self.optional = optional
        self.syncable = syncable
    }
}
