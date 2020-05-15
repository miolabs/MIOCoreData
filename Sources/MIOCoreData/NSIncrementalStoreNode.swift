//
//  File.swift
//  
//
//  Created by Javier Segura Perez on 15/05/2020.
//

import Foundation


open class NSIncrementalStoreNode : NSObject
{
    // Returns an object initialized with the following values
    // objectID -> The NSManagedObjectID corresponding to the object whose values are cached
    //
    // values -> A dictionary containing the values persisted in an external store with keys corresponding to the names of the NSPropertyDescriptions
    //      in the NSEntityDescription described by the NSManagedObjectID.  Unknown or unmodeled keys will be stripped out.
    //
    //        For attributes: an immutable value (NSNumber, NSString, NSData etc).  Missing attribute keys will assume a nil value.
    //
    //        For to-one relationships: the NSManagedObjectID of the related object or NSNull for nil relationship values. A missing key will be resolved lazily through calling
    //          -newValueForRelationship:forObjectWithID:withContext:error: on the NSPersistentStore.  Lazy resolution for to-ones is discouraged.
    //
    //      For to-many relationships: an NSArray or NSSet containing the NSManagedObjectIDs of the related objects.  Empty to-many relationships must
    //          be represented by an empty non-nil collection.  A missing key will be resolved lazily through calling.  Lazy resolution for to-manys is encouraged.
    //          -newValueForRelationship:forObjectWithID:withContext:error: on the NSPersistentStore
    //
    // version -> The revision number of this state; used for conflict detection and merging
    public init(objectID: NSManagedObjectID, withValues values: [String : Any], version: UInt64) {
        _objectID = objectID
        _version = version
    }

    
    // Update the values and version to reflect new data being saved to or loaded from the external store.
    // The values dictionary is in the same format as the initializer
    open func update(withValues values: [String : Any], version: UInt64) {
        
    }

    var _objectID:NSManagedObjectID
    // Return the object ID that identifies the data stored by this node
    open var objectID: NSManagedObjectID { get { return _objectID } }

    
    var _version:UInt64 = 0
    // Return the version of data in this node.
    open var version: UInt64 { get { return _version } }

    
    // May return NSNull for to-one relationships.  If a relationship is nil, clients should  invoke -newValueForRelationship:forObjectWithID:withContext:error: on the NSPersistentStore
    open func value(for prop: NSPropertyDescription) -> Any? {
        return nil
    }
}
