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

// Each element of `args` binds ONE placeholder, exactly like CoreDataSwift's parser.
// `NSPredicate(format:_:)` must not receive the array as a single vararg: `%K` would
// then get an NSArray and Foundation throws `-[NSArray rangeOfString:]` while parsing.
public func MIOPredicateWithFormat(format: String, _ args: CVarArg...) -> NSPredicate {
    return NSPredicate(format: format, argumentArray: args )
}

public func MIOPredicateWithFormat(format: String, arguments: [Any]) -> NSPredicate {
    return NSPredicate(format: format, argumentArray: arguments )
}

#endif

