//
//  NSManagedObject.swift
//  
//
//  Created by Javier Segura Perez on 12/05/2020.
//

#if !APPLE_CORE_DATA

import Foundation

open class NSManagedObject : NSObject
{
#if os(Linux)
    open var className: String {
        return entity.name ?? "NSManagedObject"
    }
#endif
    
    /*  Distinguish between changes that should and should not dirty the object for any key unknown to Core Data.  10.5 & earlier default to NO.  10.6 and later default to YES. */
    /*    Similarly, transient attributes may be individually flagged as not dirtying the object by adding +(BOOL)contextShouldIgnoreChangesFor<key> where <key> is the property name. */
    //open class var contextShouldIgnoreUnmodeledPropertyChanges: Bool { get }
    
    
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
        _managedObjectContext = context
        _objectID = NSManagedObjectID(WithEntity: entity, referenceObject: nil)
        super.init()
        
        context?.insert(self)
        _setDefaultValues()
                
        awakeFromFetch()
    }
    
    func _setDefaultValues() {
        //let attributes = this.entity.attributesByName;
        for prop in entity.properties {
            if prop is NSRelationshipDescription { continue }
            
            let attr = prop as! NSAttributeDescription
            let value = attr.defaultValue

            if value == nil { continue }
            setValue(value, forKey: prop.name)
        }
    }
    
    public required override init() {
        super.init()
    }
    
    /* Returns a new object, inserted into managedObjectContext. This method is only legal to call on subclasses of NSManagedObject that represent a single entity in the model.
     */
    //    public convenience init(context moc: NSManagedObjectContext) {
    //
    //    }
    
    weak var _managedObjectContext:NSManagedObjectContext?
    // identity
    unowned(unsafe) open var managedObjectContext: NSManagedObjectContext? { get { return _managedObjectContext } }
    
    open var entity: NSEntityDescription { get {return objectID.entity } }
    
    var _objectID:NSManagedObjectID!
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
    var relationShipsNamedNotFault:Set<String> = Set()
    open func hasFault(forRelationshipNamed key: String) -> Bool { return !relationShipsNamedNotFault.contains(key) }
    
    
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
    #if os(Linux)
    open func willChangeValue(forKey key: String) {}
    open func didChangeValue(forKey key: String) {}
    #endif
    
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
    #if os(Linux)
    open func value(forKey key: String) -> Any? { return _value(forKey:key)}
    #else
    open override func value(forKey key: String) -> Any? { return _value(forKey:key) }
    #endif
    
    open func _value(forKey key: String) -> Any? {
        
        guard let property = entity.propertiesByName[key] else {
            #if os(Linux)
            return nil
            #else
            return super.value(forKey:key)
            #endif
        }
        
        willAccessValue(forKey:key)
        
        var value:Any?
        if property is NSAttributeDescription {
            
            if _changedValues.keys.contains(key) {
                value = _changedValues[key]
            }
            else {
                value = storedValues[key]
            }
        }
        else if property is NSRelationshipDescription {
            let relationship = property as! NSRelationshipDescription
            if relationship.isToMany == false {
                if _changedValues.keys.contains(key) {
                    if let objID = _changedValues[key] as? NSManagedObjectID {
                        value = try! managedObjectContext!.existingObject(with: objID)
                    }
                }
                else {
                    if let objID = primitiveValue(forKey:key) as? NSManagedObjectID {
                        value = try! managedObjectContext!.existingObject(with: objID)
                    }
                }
            }
            else {
                let values:Set<NSManagedObjectID>?
                if _changedValues.keys.contains(key) {
                    values = _changedValues[key] as? Set<NSManagedObjectID>
                } 
                else {
                    values = primitiveValue(forKey:key) as? Set<NSManagedObjectID>
                }
                
                value = Set( (values ?? Set()).map{ try! managedObjectContext!.existingObject(with: $0 ) } )
            }
        }
        
        didAccessValue(forKey:key)
        
        return value is NSNull ? nil : value
    }
    
    
    // KVC - overridden to access generic dictionary storage unless subclasses explicitly provide accessors
    #if os(Linux)
    open func setValue(_ value: Any?, forKey key: String) {
        var cache = Set<NSManagedObject>()
        _setValue(value, forKey: key, cache: &cache)
    }
    #else
    open override func setValue(_ value: Any?, forKey key: String) {
        var cache = Set<NSManagedObject>()
        _setValue(value, forKey: key, cache: &cache )
    }
    #endif
    
    open func _setValue(_ value: Any?, forKey key: String, cache:inout Set<NSManagedObject>) {
        cache.insert( self )
        
        guard let property = entity.propertiesByName[key] else {
            #if os(OSX)
            super.setValue(value, forKey: key)
            #endif
            return
        }

        willChangeValue(forKey: key)

        if property is NSRelationshipDescription {
            let relationship = property as! NSRelationshipDescription
            if relationship.isToMany == false {
                // Undo the inverse of the CURRENT value (pending change first,
                // committed otherwise) — and only when an inverse exists, so a
                // plain to-one set does not force a store round-trip.
                if relationship.inverseRelationship != nil, let last_obj = _currentToOneObject(forKey: key) {
                    removeInverseRelationship(relationship, last_obj, cache: &cache)
                }

                if let obj = value as? NSManagedObject {
                    _changedValues[key] = obj.objectID
                    addInverseRelationship( relationship, obj, cache: &cache )
                }
                else {
                    _changedValues[key] = NSNull()
                }
            }
            else {
                if relationship.inverseRelationship != nil {
                    for obj in _currentToManyObjects(forKey: key) { removeInverseRelationship( relationship, obj, cache: &cache ) }
                }

                if let objects = value as? Set<NSManagedObject> {
                    var objIDs:Set<NSManagedObjectID> = Set( )
                    for obj in objects {
                        addInverseRelationship( relationship, obj, cache: &cache )
                        objIDs.insert(obj.objectID)
                    }
                    _changedValues[key] = objIDs
                }
                else {
                    _changedValues[key] = NSNull()
                }
            }
        }
        else {
            _changedValues[key] = value ?? NSNull()
        }

        didChangeValue(forKey: key)

        // Mark dirty without refaulting: the old refresh() here wiped the
        // snapshot, so writing one attribute forced the next read of any other
        // attribute to reload the whole object from the store.
        managedObjectContext?._markUpdated(self)

        cache.remove( self )
    }

    // Current (pending-first) relationship values, used for inverse maintenance.
    // Falls back to committedValues — which may fire the relationship fault —
    // only when there is no pending change for the key.
    func _currentToOneObject(forKey key: String) -> NSManagedObject? {
        if _changedValues.keys.contains(key) {
            guard let moc = managedObjectContext, let objID = _changedValues[key] as? NSManagedObjectID else { return nil }
            return try? moc.existingObject(with: objID)
        }
        return committedValues(forKeys: [key])[key] as? NSManagedObject
    }

    func _currentToManyObjects(forKey key: String) -> Set<NSManagedObject> {
        if _changedValues.keys.contains(key) {
            guard let moc = managedObjectContext, let objIDs = _changedValues[key] as? Set<NSManagedObjectID> else { return [] }
            return Set( objIDs.compactMap { try? moc.existingObject(with: $0) } )
        }
        return committedValues(forKeys: [key])[key] as? Set<NSManagedObject> ?? []
    }
    
    // primitive methods give access to the generic dictionary storage from subclasses that implement explicit accessors like -setName/-name to add custom document logic
    open func primitiveValue(forKey key: String) -> Any? {
        // Pending changes ARE the current primitive state: after setValue or
        // setPrimitiveValue the primitive must return the new value, and unsaved
        // objects (temporary ID, empty snapshot) must read their values back.
        if _changedValues.keys.contains(key) {
            let value = _changedValues[key]
            return value is NSNull ? nil : value
        }
        if hasFault(forRelationshipNamed: key) && objectID.persistentStore != nil {
            unfaultRelationshipNamed( key, fromStore: objectID.persistentStore! )
        }
        let value = storedValues[key]
        return value is NSNull ? nil : value
    }

    // NOTE: this deviates from Apple on purpose — the change IS tracked (shows
    // up in changedValues() and gets saved) so that values written from
    // awakeFromInsert/awakeFromFetch survive; what it skips versus setValue is
    // the will/didChange observers and the inverse-relationship maintenance.
    // Writing the old _storedValues dictionary lost the value whenever the
    // object refaulted, and never persisted it for unsaved objects.
    open func setPrimitiveValue(_ value: Any?, forKey key: String) {
        _changedValues[key] = value ?? NSNull()
        managedObjectContext?._markUpdated(self)
    }
    
    // returns a dictionary of the last fetched or saved keys and values of this object.  Pass nil to get all persistent modeled properties.
    open func committedValues(forKeys keys: [String]?) -> [String : Any] {
        if keys == nil { return storedValues }
            
        var values:[String: Any] = [:]
        for key in keys! {
            if entity.propertiesByName[key] is NSRelationshipDescription {
                if hasFault(forRelationshipNamed: key) && objectID.persistentStore != nil {
                    unfaultRelationshipNamed(key, fromStore: objectID.persistentStore!)
                }
                
                if let v = storedValues[key] as? [NSManagedObjectID] {
                    values[key] = Set(v.map{ try? managedObjectContext!.existingObject(with: $0 ) } )
                }
                else if let v = storedValues[key] as? [NSManagedObject] {
                    values[key] = Set(v)
                }
                else if let v = storedValues[key] as? Set<NSManagedObjectID> {
                    values[key] = Set(v.map{ try? managedObjectContext!.existingObject(with: $0 ) } )
                }
                else if let v = storedValues[key] as? Set<NSManagedObject> {
                    values[key] = v
                }
                else if let v = storedValues[key] as? NSManagedObjectID {
                    values[key] = try? managedObjectContext!.existingObject(with: v )
                }
                else if let v = storedValues[key] as? NSManagedObject {
                    values[key] = v
                }
                // TODO: Check if the relationship is to many or not
                else {
                    values[key] = Set<NSManagedObject>()
                }
            }
            else if entity.propertiesByName[key] is NSAttributeDescription {
                values[ key ] = storedValues[ key ]
            }
        }
        return values
    }
    
    
    // returns a dictionary with the keys and (new) values that have been changed since last fetching or saving the object (this is implemented efficiently without firing relationship faults)
    var _changedValues:[String: Any] = [:]
    open func changedValues() -> [String : Any] {
        return Dictionary( uniqueKeysWithValues: _changedValues.map{ (k,v) in
            if let relation = entity.relationshipsByName[ k ] {
                if relation.isToMany {
                    if v is NSNull { return ( k, Set<NSManagedObjectID>() ) }
                    return (k, Set( (v as! Set<NSManagedObjectID>).map{ try? managedObjectContext!.existingObject(with: $0 ) } ) )
                } else {
                    if v is NSNull { return ( k, v ) }
                    return (k, try! managedObjectContext!.existingObject(with: v as! NSManagedObjectID) )
                }
            } else {
                return (k,v)
            }
        } )
    }
    
    
    //open func changedValuesForCurrentEvent() -> [String : Any]
    
    
    // validation - in addition to KVC validation managed objects have hooks to validate their lifecycle state; validation is a critical piece of functionality and the following methods are likely the most commonly overridden methods in custom subclasses
    //    open override func validateValue(_ value: AutoreleasingUnsafeMutablePointer<AnyObject?>, forKey key: String) throws { // KVC
    //    }
    
    open func validateForDelete() throws {
        
    }
    
    open func validateForInsert() throws {
        
    }
    
    open func validateForUpdate() throws {
        
    }
    
    //
    // Custom methods
    //
    
    func setIsFault(_ value:Bool)
    {
//        if value == _isFault { return }
        
        willChangeValue(forKey: "hasChanges")
        willChangeValue(forKey:"isFault")
        _isFault = value
        if value == true {
            _storedValues = [:]
            relationShipsNamedNotFault = Set()
        }
        didChangeValue(forKey: "isFault")
        didChangeValue(forKey: "hasChanges")
    }
    
    var _storedValues: [String:Any] = [:]
    var storedValues: [String : Any] {
        get {
            if objectID.isTemporaryID == true { return [:] }
            if objectID.persistentStore == nil { return [:] }
            
            if _isFault == false { return _storedValues }
            
            unfaultAttributes(fromStore: objectID.persistentStore!)
            setIsFault(false)
            
            return _storedValues
        }
    }
    
    func unfaultAttributes(fromStore store:NSPersistentStore?) {
        //if _isDeleted == true { return }
        _storedValues = [:]
        
        if let memory_store = store as? NSInMemoryStore {
            let objects = memory_store.objectsByEntityName[ objectID.entity.name! ]
            let values = objects?[objectID.uriString] as? [String:Any] ?? [:]

            for (key, attr) in entity.attributesByName {
                var v = values[ key ]
                if attr.isOptional == false && ( v == nil || v is NSNull ) { v = attr.defaultValue }
                _storedValues[key] = v
            }
        }
        else if let incremental_store = store as? NSIncrementalStore {
            
            let node = try? incremental_store.newValuesForObject(with: objectID, with: managedObjectContext!)
            if node == nil { return }
            
            for (key, attr) in entity.attributesByName {
                let value = node!.value(for: attr)
                _storedValues[key] = value
            }
        }
        
        _isFault = false
        // Force to unfault all relationships
        // relationShipsNamedNotFault = Set()
    }
    
    func unfaultRelationshipNamed(_ key:String, fromStore store:NSPersistentStore?) {
        //if _isDeleted == true { return }
        
        if store == nil { return }
        if isFault { unfaultAttributes(fromStore: store! ) }
        
        relationShipsNamedNotFault.insert(key)
        
        guard let relation = entity.relationshipsByName[key] else { return }
        guard let incrementalStore = store as? NSIncrementalStore else { return }
        
        let value = try? incrementalStore.newValue(forRelationship: relation, forObjectWith: objectID, with: managedObjectContext)
        if value == nil { return }

        _storedValues[relation.name] = relation.isToMany ? Set( value! as! [NSManagedObjectID] ) : value!
    }
    
    func _didCommit( inserted: Bool = false ) {
        // Merge the committed changes into the snapshot and stay realized:
        // refaulting here forced a store round-trip on the next attribute read
        // after every save. Inserted objects carry every meaningful value in
        // _changedValues, so their merged snapshot is complete even though they
        // were never unfaulted from a store. An updated object that is still a
        // fault keeps refaulting (its snapshot is incomplete).
        if inserted || _isFault == false {
            _storedValues.merge(_changedValues) { (_, new) in new }
            for key in _changedValues.keys where entity.relationshipsByName[key] != nil {
                relationShipsNamedNotFault.insert(key)
            }
            _isFault = false
        }
        _changedValues = [:]
    }
    
    func _setIsInserted(_ value:Bool) {
        willChangeValue(forKey: "hasChanges")
        willChangeValue(forKey: "isInserted")
        _isInserted = value
        didChangeValue(forKey: "isInserted")
        didChangeValue(forKey: "hasChanges")
    }
            
    func _setIsUpdated(_ value:Bool) {        
        willChangeValue(forKey: "hasChanges")
        willChangeValue(forKey: "isUpdated")
        _isUpdated = value
        didChangeValue(forKey: "isUpdated")
        didChangeValue(forKey: "hasChanges")
    }

    func _setIsDeleted(_ value:Bool, cache:inout Set<NSManagedObject>) {
        willChangeValue(forKey: "hasChanges")
        willChangeValue(forKey: "isDeleted")
        _isDeleted = value
        deleteInverseRelationships(cache: &cache)
        _isDeleted = value
        didChangeValue(forKey: "isDeleted")
        didChangeValue(forKey: "hasChanges")
    }

    open func _addObject(_ object:NSManagedObject, forKey key:String ) {
        var cache:Set<NSManagedObject> = Set()
        _addObject(object, forKey: key, cache: &cache)
    }
    
    open func _addObject(_ object:NSManagedObject, forKey key:String, cache: inout Set<NSManagedObject> ) {
        cache.insert( self )
        
        if hasFault(forRelationshipNamed: key) == true { unfaultRelationshipNamed(key, fromStore: objectID.persistentStore) }
        
        var objIDs:Set<NSManagedObjectID> = _changedValues[key] as? Set<NSManagedObjectID> ??
                                            storedValues[key] as? Set<NSManagedObjectID> ??
                                            Set( )
        
        addInverseRelationship( entity.relationshipsByName[ key ]!, object, cache: &cache )
        
        objIDs.insert(object.objectID)
        _changedValues[key] = objIDs
        managedObjectContext?._markUpdated(self)

        cache.remove( self )
    }

    open func _removeObject(_ object:NSManagedObject, forKey key:String, refresh: Bool = true) {
        var cache:Set<NSManagedObject> = Set()
        _removeObject(object, forKey: key, cache: &cache, refresh: refresh)
    }
    
    open func _removeObject(_ object:NSManagedObject, forKey key:String, cache: inout Set<NSManagedObject>, refresh: Bool = true) {
        cache.insert( self )
        
        if hasFault(forRelationshipNamed: key) == true { unfaultRelationshipNamed(key, fromStore: objectID.persistentStore) }
        
        var objIDs:Set<NSManagedObjectID> = _changedValues[key] as? Set<NSManagedObjectID> ??
                                            storedValues[key] as? Set<NSManagedObjectID> ??
                                            Set( )

        removeInverseRelationship( entity.relationshipsByName[ key ]!, object, cache: &cache )
        
        objIDs.remove( object.objectID )

        _changedValues[key] = objIDs
        if refresh { managedObjectContext?._markUpdated(self) }

        cache.remove( self )
    }

    
    func addInverseRelationship ( _ relationship: NSRelationshipDescription, _ obj: NSManagedObject, cache: inout Set<NSManagedObject> ) {
        if relationship.inverseRelationship == nil || cache.contains( obj ) { return }
                
        if relationship.inverseRelationship!.isToMany == false {
            obj._setValue( self, forKey: relationship.inverseName!, cache: &cache )
        } else {
            obj._addObject( self, forKey: relationship.inverseName!, cache: &cache )
        }
    }
    
    func removeInverseRelationship ( _ relationship: NSRelationshipDescription, _ obj: NSManagedObject, cache: inout Set<NSManagedObject> ) {
        if relationship.inverseRelationship == nil || cache.contains( obj ) { return }
        
        if relationship.inverseRelationship!.isToMany == false {
            if let v = obj.value(forKey: relationship.inverseName!) as? NSManagedObject {
                if v.objectID == self.objectID {
                    obj._setValue( nil, forKey: relationship.inverseName!, cache: &cache )
                }
            }
        } else {
            if let v = obj.value(forKey: relationship.inverseName!) as? Set<NSManagedObject> {
                if v.contains( self) {
                    obj._removeObject( self, forKey: relationship.inverseName!, cache: &cache )
                }
            }
        }
    }
    
    func deleteInverseRelationships( cache: inout Set<NSManagedObject>) {

        for (_, rel) in entity.relationshipsByName {
            
            switch rel.deleteRule {
            case .cascadeDeleteRule: deleteByCascade(fromRelationship: rel, cache: &cache)
            case .nullifyDeleteRule: deleteByNullify(fromRelationship: rel, cache: &cache)
            default: break
            }
        }
    }
    
    func deleteByNullify(fromRelationship relationship: NSRelationshipDescription, cache:inout Set<NSManagedObject>){
        
        if relationship.isToMany == false {
            guard let obj = value(forKey: relationship.name ) as? NSManagedObject else { return }
            if obj.isDeleted == false { obj._nullify_inverse_relation( relationship.inverseRelationship, self, cache: &cache) }
        }
        else {
            let objects = value(forKey: relationship.name ) as! Set<NSManagedObject>
            for obj in objects {
                if obj.isDeleted == false { obj._nullify_inverse_relation( relationship.inverseRelationship, self, cache: &cache ) }
            }
        }
    }
    
    func _nullify_inverse_relation (_ relationship: NSRelationshipDescription?, _ obj: NSManagedObject, cache:inout Set<NSManagedObject>) {
        guard let relationship = relationship else { return }
        
        if relationship.isToMany == false {
            _setValue(nil, forKey:relationship.name, cache: &cache)
        }
        else {
            _removeObject(obj, forKey: relationship.name, cache: &cache)
        }
    }

    
    func deleteByCascade(fromRelationship relationship: NSRelationshipDescription, cache:inout Set<NSManagedObject>) {

        if relationship.isToMany == false {
            guard let obj = value(forKey: relationship.name ) as? NSManagedObject else { return }
            if obj.isDeleted == false { managedObjectContext?._delete(obj, cache: &cache) }
        }
        else {
            let objects = value(forKey: relationship.name  ) as! Set<NSManagedObject>
            for obj in objects {
                if obj.isDeleted == false { managedObjectContext?._delete(obj, cache: &cache) }
                _removeObject(obj, forKey: relationship.name, cache: &cache, refresh: false)
            }
            managedObjectContext?._markUpdated(self)
        }
    }
    
    open override var description: String {
        get {
            var str = ""
            str += "<\(entity.name!): \(Unmanaged.passUnretained(self).toOpaque())>\n"
            let keys = entity.attributesByName.keys.sorted()
            for k in keys {
                let v = value(forKey: k)
                if v == nil { str += "  \(k): <null>\n" }
                else if v is NSNull { str += "  \(k): <null>\n" }
                else if v is String { str += "  \(k): '\(v!)'\n" }
                else { str += "  \(k): \(v!)\n" }
            }
            
            return str
        }
    }
    
    public func printAsJSON() throws -> String? {
        // JSONSerialization cannot serialize a managed object (or Date/UUID/Decimal
        // values) directly, so build a JSON-safe dictionary from the attributes.
        var json:[String:Any] = [:]
        for key in entity.attributesByName.keys {
            switch value(forKey: key) {
            case nil:                json[key] = NSNull()
            case is NSNull:          json[key] = NSNull()
            case let v as String:    json[key] = v
            case let v as Bool:      json[key] = v
            case let v as Date:      json[key] = ISO8601DateFormatter().string(from: v)
            case let v as UUID:      json[key] = v.uuidString
            case let v as Decimal:   json[key] = "\(v)"
            case let v as Data:      json[key] = v.base64EncodedString()
            case let v as NSNumber:  json[key] = v
            case let v?:             json[key] = "\(v)"
            }
        }
        let data = try JSONSerialization.data(withJSONObject: json)
        return String(data: data, encoding: .utf8)
    }
}

#endif
