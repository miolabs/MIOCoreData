//
//  MIOCoreData.swift
//  MIOCoreData
//
//  Created by Javier Segura Perez on 31/8/24.
//

#if !APPLE_CORE_DATA
@_exported import CoreDataSwift

public typealias NSPredicate = MIOPredicate
public typealias NSSortDescriptor = MIOSortDescriptor

#else

@_exported import CoreData

public func MIOPredicateWithFormat(format: String, _ args: CVarArg...) -> NSPredicate
{
    return NSPredicate(format: format, args )
}

#endif

