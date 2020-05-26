//
//  File.swift
//  
//
//  Created by Javier Segura Perez on 12/05/2020.
//

import Foundation

open class NSManagedObject : NSObject
{
    /*  Distinguish between changes that should and should not dirty the object for any key unknown to Core Data.  10.5 & earlier default to NO.  10.6 and later default to YES. */
    /*    Similarly, transient attributes may be individually flagged as not dirtying the object by adding +(BOOL)contextShouldIgnoreChangesFor<key> where <key> is the property name. */
    //open class var contextShouldIgnoreUnmodeledPropertyChanges: Bool { get }

    
    var _entity:NSEntityDescription
    /* The Entity represented by this subclass. This method is only legal to call on subclasses of NSManagedObject that represent a single entity in the model.
     */
//    open class func entity() -> NSEntityDescription {
//        return _entity
//    }
    
    /* A new fetch request initialized with the Entity represented by this subclass. This property's getter is only legal to call on subclasses of NSManagedObject that represent a single entity in the model.
     */
//    open class func fetchRequest() -> NSFetchRequest<NSFetchRequestResult> {
//
//    }

    
    /* The designated initializer. */
    public required init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
        _entity = entity
        _managedObjectContext = context
        _objectID = NSManagedObjectID(WithEntity: entity, referenceObject: nil)
    }

    
    /* Returns a new object, inserted into managedObjectContext. This method is only legal to call on subclasses of NSManagedObject that represent a single entity in the model.
     */
//    public convenience init(context moc: NSManagedObjectContext) {
//
//    }
    
    var _managedObjectContext:NSManagedObjectContext?
    // identity
    unowned(unsafe) open var managedObjectContext: NSManagedObjectContext? { get { return _managedObjectContext } }

    open var entity: NSEntityDescription { get {return _entity } }

    var _objectID:NSManagedObjectID
    open var objectID: NSManagedObjectID { get { return _objectID } }

    
    // state - methods
    var _isInserted = false
    open var isInserted: Bool { get { return _isInserted } }

    var _isUpdated = false
    open var isUpdated: Bool { get { return _isUpdated } }

    var _isDeleted = false
    open var isDeleted: Bool { get { return _isDeleted } }
    
    var _hasChanges = false
    open var hasChanges: Bool { get { return _hasChanges } }

    
    /* returns YES if any persistent properties do not compare isEqual to their last saved state.  Relationship faults will not be unnecessarily fired.  This differs from the existing -hasChanges method which is a simple dirty flag and also includes transient properties */
    //open var hasPersistentChangedValues: Bool { get }

    
    var _isFault = true
    // this information is useful in many situations when computations are optional - this can be used to avoid growing the object graph unnecessarily (which allows to control performance as it can avoid time consuming fetches from databases)
    open var isFault: Bool { get { return _isFault } }

    
    // returns a Boolean indicating if the relationship for the specified key is a fault.  If a value of NO is returned, the resulting relationship is a realized object;  otherwise the relationship is a fault.  If the specified relationship is a fault, calling this method does not result in the fault firing.
    //open func hasFault(forRelationshipNamed key: String) -> Bool

    
    /* returns an array of objectIDs for the contents of a relationship.  to-one relationships will return an NSArray with a single NSManagedObjectID.  Optional relationships may return an empty NSArray.  The objectIDs will be returned in an NSArray regardless of the type of the relationship.  */
    //open func objectIDs(forRelationshipNamed key: String) -> [NSManagedObjectID]

    
    /* Allow developers to determine if an object is in a transitional phase when receiving a KVO notification.  Returns 0 if the object is fully initialized as a managed object and not transitioning to or from another state */
    //open var faultingState: Int { get }

    
    // lifecycle/change management (includes key-value observing methods)
    open func willAccessValue(forKey key: String?) { // read notification
        
    }

    open func didAccessValue(forKey key: String?) { // read notification (together with willAccessValueForKey used to maintain inverse relationships, to fire faults, etc.) - each read access has to be wrapped in this method pair (in the same way as each write access has to be wrapped in the KVO method pair)

        
    }
    
    // KVO change notification
//    open func willChangeValue(forKey key: String) {
//
//    }
//
//    open func didChangeValue(forKey key: String) {
//
//    }

//    open func willChangeValue(forKey inKey: String, withSetMutation inMutationKind: NSKeyValueSetMutationKind, using inObjects: Set<AnyHashable>)
//
//    open func didChangeValue(forKey inKey: String, withSetMutation inMutationKind: NSKeyValueSetMutationKind, using inObjects: Set<AnyHashable>)

    
    // invoked after a fetch or after unfaulting (commonly used for computing derived values from the persisted properties)
    open func awakeFromFetch() {
        
    }

    
    // invoked after an insert (commonly used for initializing special default/initial settings)
    open func awakeFromInsert() {
        
    }

    
    /* Callback for undo, redo, and other multi-property state resets */
    //open func awake(fromSnapshotEvents flags: NSSnapshotEventType)

    
    /* Callback before delete propagation while the object is still alive.  Useful to perform custom propagation before the relationships are torn down or reconfigure KVO observers. */
    open func prepareForDeletion() {
        
    }
    
    // commonly used to compute persisted values from other transient/scratchpad values, to set timestamps, etc. - this method can have "side effects" on the persisted values
    open func willSave() {
        
    }

    
    // commonly used to notify other objects after a save
    open func didSave() {
        
    }

    
    // invoked automatically by the Core Data framework before receiver is converted (back) to a fault.  This method is the companion of the -didTurnIntoFault method, and may be used to (re)set state which requires access to property values (for example, observers across keypaths.)  The default implementation does nothing.
    open func willTurnIntoFault() {
        
    }

    
    // commonly used to clear out additional transient values or caches
    open func didTurnIntoFault() {
        
    }

    
    // value access (includes key-value coding methods)
    
    // KVC - overridden to access generic dictionary storage unless subclasses explicitly provide accessors
    open override func value(forKey key: String) -> Any? {
        return nil
    }

    
    // KVC - overridden to access generic dictionary storage unless subclasses explicitly provide accessors
    open override func setValue(_ value: Any?, forKey key: String) {
        
    }

    
    // primitive methods give access to the generic dictionary storage from subclasses that implement explicit accessors like -setName/-name to add custom document logic
    open func primitiveValue(forKey key: String) -> Any? {
        return nil
    }

    open func setPrimitiveValue(_ value: Any?, forKey key: String) {
        
    }

    
    // returns a dictionary of the last fetched or saved keys and values of this object.  Pass nil to get all persistent modeled properties.
    open func committedValues(forKeys keys: [String]?) -> [String : Any] {
        return [:]
    }

    
    // returns a dictionary with the keys and (new) values that have been changed since last fetching or saving the object (this is implemented efficiently without firing relationship faults)
    open func changedValues() -> [String : Any] {
        return [:]
    }

        
    //open func changedValuesForCurrentEvent() -> [String : Any]

    
    // validation - in addition to KVC validation managed objects have hooks to validate their lifecycle state; validation is a critical piece of functionality and the following methods are likely the most commonly overridden methods in custom subclasses
    open override func validateValue(_ value: AutoreleasingUnsafeMutablePointer<AnyObject?>, forKey key: String) throws { // KVC
    }

    open func validateForDelete() throws {
        
    }

    open func validateForInsert() throws {
        
    }

    open func validateForUpdate() throws {
        
    }
    
    //
    // Custom methods
    //
        
    func setIsFault(_ value:Bool) {
        
    }
}
