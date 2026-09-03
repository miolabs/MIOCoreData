//
//  NSManagedObject+MECJSON.swift
//  MIOCoreData
//
//  Created by MIO Research Labs on 2026.
//
//  A managed object, out to JSON, through the one codec.
//

import Foundation
import MIOEntityCore

extension NSManagedObject
{
    /// The object's attributes as something `JSONSerialization` will accept.
    ///
    /// ```swift
    /// let payload = try folder.mecJSON( )
    /// let data    = try JSONSerialization.data( withJSONObject: payload )
    /// ```
    ///
    /// Every value goes through ``MECAttributeType``'s JSON leg, so a UUID is
    /// spelled one way and a decimal keeps its precision rather than becoming a
    /// `Double` on the way out. Rendering choices are ``MECPolicy``'s.
    ///
    /// Works in both variants: the same call in an app built with
    /// `-D APPLE_CORE_DATA` and on a Linux server without it produces the same
    /// payload.
    ///
    /// - Parameters:
    ///   - policy: The rendering choices.
    ///   - entity: The translated entity, when the caller already has a
    ///     ``MECModel`` and would rather not have one built per object. Omit it
    ///     and one is derived from the object's own `NSEntityDescription`.
    ///
    /// - Returns: One dictionary of property name to JSON value. Attributes
    ///   carry their value; relationships carry the identity of what they point
    ///   at. An absent optional is omitted unless ``MECPolicy/includeNulls``
    ///   says otherwise.
    public func mecJSON( policy: MECPolicy = .default,
                         entity meta: MECEntity? = nil ) throws -> [String: Any] {

        let schema = meta ?? MECEntity( entity )
        var json: [String: Any] = [:]

        for attribute in schema.attributes {
            // A transient attribute has no storage and is not part of the wire
            // shape, and asking the codec would only raise on some types.
            if attribute.isTransient { continue }

            let rendered = try attribute.jsonValue( from: value( forKey: attribute.name ),
                                                    policy: policy,
                                                    in: schema.name )

            if rendered is NSNull && policy.includeNulls == false { continue }
            json[ attribute.name ] = rendered
        }

        for relationship in schema.relationships {
            guard let reference = try _mec_reference( for: relationship, policy: policy ) else {
                if policy.includeNulls { json[ relationship.name ] = NSNull() }
                continue
            }
            json[ relationship.name ] = reference
        }

        return json
    }

    /// What one relationship contributes to a payload: the identity of what it
    /// points at, never the object itself.
    ///
    /// Nesting the destination would make the payload's size a property of the
    /// object graph, and a cycle in that graph a hang. An identity is what the
    /// other end needs in order to fetch it.
    private func _mec_reference( for relationship: MECRelationship,
                               policy: MECPolicy ) throws -> Any? {

        guard let raw = value( forKey: relationship.name ), raw is NSNull == false else { return nil }

        if relationship.isToMany == false { return try _mec_identity( of: raw, policy: policy ) }

        // A Core Data to-many is a Set, and a set has no order, so the payload
        // is sorted. An unstable payload makes diffs and caching useless.
        let objects: [Any]
        if let set = raw as? Set<NSManagedObject> { objects = Array( set ) }
        else if let array = raw as? [Any] { objects = array }
        else { return nil }

        return try objects.compactMap { try _mec_identity( of: $0, policy: policy ) }
                          .map { String( describing: $0 ) }
                          .sorted()
    }

    /// One destination object's identity, rendered through the same codec as
    /// every other value.
    private func _mec_identity( of object: Any, policy: MECPolicy ) throws -> Any? {
        guard let managed = object as? NSManagedObject else { return nil }

        let schema = MECEntity( managed.entity )
        let key    = policy.identifierKey( schema )

        guard let attribute = schema.attributesByName[ key ] else {
            throw MECError.unsupportedAttribute(
                entity: schema.name, property: key,
                reason: "the identity attribute named by the policy does not exist on this entity" )
        }

        return try attribute.jsonValue( from: managed.value( forKey: key ),
                                        policy: policy,
                                        in: schema.name )
    }
}
