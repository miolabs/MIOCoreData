//
//  NSManagedObject+MCSerialization.swift
//
//  Created by MIO Research Labs on 2026.
//
//  A managed object to a JSON dictionary and back, driven entirely by the
//  entity description.
//

import Foundation
import MIOCoreData

extension NSManagedObject
{
    /// Attributes plus relationship identity references.
    public func mcs_json ( policy: MCSerializationPolicy = .default ) throws -> [String:Any] {

        var json: [String:Any] = [:]
        let identifierKey = policy.identifierKey( entity )

        for (name, attribute) in entity.attributesByName {
            let value = try attribute.mcs_jsonValue( from: self.value( forKey: name ), policy: policy )

            if value is NSNull && policy.includeNulls == false && name != identifierKey { continue }
            json[ name ] = value ?? NSNull()
        }

        for (name, relationship) in entity.relationshipsByName {
            guard let value = try mcs_reference( for: relationship, named: name, policy: policy ) else {
                if policy.includeNulls { json[ name ] = NSNull() }
                continue
            }
            json[ name ] = value
        }

        return json
    }

    /// Applies a JSON dictionary onto this object's attributes.
    ///
    /// Attributes only. Relationships are deliberately not resolved here.
    public func mcs_setAttributes ( fromJSON json: [String:Any],
                                    policy: MCSerializationPolicy = .default ) throws {

        for (name, attribute) in entity.attributesByName {
            guard json.keys.contains( name ) else { continue }
            let value = try attribute.mcs_modelValue( from: json[ name ] )
            setValue( value, forKey: name )
        }
    }

    /// The identity of a related object, or an array of them.
    private func mcs_reference ( for relationship: NSRelationshipDescription,
                                 named name: String,
                                 policy: MCSerializationPolicy ) throws -> Any? {

        guard let raw = self.value( forKey: name ), raw is NSNull == false else { return nil }

        func identity ( _ object: Any ) throws -> Any? {
            guard let managed = object as? NSManagedObject else { return nil }
            let key = policy.identifierKey( managed.entity )
            guard let attribute = managed.entity.attributesByName[ key ] else {
                throw MCSerializationError.unsupportedAttribute(
                    entity: managed.entity.name ?? "?", property: key,
                    reason: "the identity attribute named by the policy does not exist on this entity" )
            }
            return try attribute.mcs_jsonValue( from: managed.value( forKey: key ), policy: policy )
        }

        if relationship.isToMany == false {
            return try identity( raw )
        }

        // Sets are unordered, so the array is sorted to keep a payload stable
        // between runs. An unstable payload makes diffs and caching useless.
        let objects: [Any]
        if let set = raw as? Set<NSManagedObject> { objects = Array( set ) }
        else if let array = raw as? [Any] { objects = array }
        else { return nil }

        let ids = try objects.compactMap { try identity( $0 ) }
        return ids.map { String( describing: $0 ) }.sorted()
    }
}

extension NSEntityDescription
{
    /// Every property this module would put in a payload, in a stable order.
    /// Useful for building a projection or documenting an endpoint.
    public func mcs_serializableKeys ( ) -> [String] {
        return ( Array( attributesByName.keys ) + Array( relationshipsByName.keys ) ).sorted()
    }
}
