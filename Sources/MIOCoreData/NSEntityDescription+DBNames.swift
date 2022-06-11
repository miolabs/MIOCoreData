//
//  NSEntityDescription+DBNames.swift
//  
//
//  Created by Javier Segura Perez on 11/6/22.
//

import Foundation

extension NSEntityDescription
{
    public func isBaseEntity ( ) -> Bool {
        return superentity == nil || superentity!.isAbstract
    }
    
    public func isInherited ( _ propertyName: String ) -> Bool {
        return !isBaseEntity( )
            && (   superentity!.propertiesByName[ propertyName ] != nil
                || superentity!.isInherited( propertyName ))
    }
    
    public func baseEntity ( _ is_59_version: Bool = true ) throws -> NSEntityDescription {
        return superentity != nil && !superentity!.isAbstract && !has_its_own_table() ? try superentity!.baseEntity()
             : self


//        return is_59_version                              ? try superentity?.baseEntity() ?? self
//             : superentity != nil && !has_its_own_table() ? try managedObjectModel.entity( superentity!.name! ).baseEntity( false )
//             : self
        
        
//        if postAbeEra( ) { return self }
//
//        return superentity != nil && !has_its_own_table() ?
//            try managedObjectModel.entity( superentity!.name! ).baseEntity( )
//              : self
    }
    
    public func has_its_own_table ( ) -> Bool {
        let v = (userInfo?[ "DBHasItsOwnTable" ] as? String ?? "false").lowercased()

        return v == "true" || v == "yes"
    }
    
    public func to_db_table_name ( ) -> String {
        return userInfo?[ "DBName" ] as? String ?? name!.camelCaseToSnakeCase()
    }
    
}
