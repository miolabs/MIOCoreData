//
//  NSPropertyDescription+DBNames.swift
//  
//
//  Created by Javier Segura Perez on 11/6/22.
//

#if !APPLE_CORE_DATA
import Foundation
import CoreDataSwift

extension NSPropertyDescription
{
    public func to_db_table_column ( ) -> String {
        return userInfo?[ "DBName" ] as? String ?? name.camelCaseToSnakeCase( )
    }
}
#endif

