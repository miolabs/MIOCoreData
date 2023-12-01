//
//  MIOPredicate.swift
//
//
//  Created by Javier Segura Perez on 22/11/23.
//

import Foundation

#if APPLE_CORE_DATA

public func MIOPredicateWithFormat(format: String, _ args: CVarArg...) -> NSPredicate
{
    return NSPredicate(format: format, args )
}

#endif
