//
//  MIORelationshipDescription.swift
//  DLAPIServer
//
//  Created by Javier Segura Perez on 21/05/2019.
//

import Foundation

enum NSDeleteRule {
    case noActionDeleteRule
    case nullifyDeleteRule
    case cascadeDeleteRule
    case denyDeleteRule
}

class NSRelationshipDescription:NSPropertyDescription {
    
    var destinationEntityName:String?
    var inverseName:String?
    var inverseEntityName:String?
    var isToMany = false
    var deleteRule = MIODeleteRule.noActionDeleteRule

    
    init(name:String, destinationEntityName:String, toMany:Bool, inverseName:String?, inverseEntityName:String?){
        super.init()
        self.name = name;
        self.destinationEntityName = destinationEntityName
        self.isToMany = toMany
        self.inverseName = inverseName
        self.inverseEntityName = inverseEntityName
    }
    
    var destinationEntity:MIOEntityDescription?
}
