//
//  NSAttributeDescription+MCSerialization.swift
//
//  Created by MIO Research Labs on 2026.
//
//  One attribute, model value to JSON value.
//
//  The other direction already exists: `coreDataValue( from: )` in
//  MIOCoreData's NSAttributeDescription+ValueConversion.swift. This module does
//  not duplicate it, it only adds the outbound half and the object-level
//  assembly on top.
//

import Foundation
import MIOCoreData

extension NSAttributeDescription
{
    /// The attribute's value as something `JSONSerialization` will accept.
    ///
    /// Returns `NSNull` for an absent optional, so a caller that wants the key
    /// omitted can filter; `NSManagedObject.mcs_json` does that via the policy.
    public func mcs_jsonValue ( from value: Any?,
                                policy: MCSerializationPolicy = .default ) throws -> Any? {

        let entityName = entity.name ?? "?"

        if value == nil || value is NSNull {
            if let fallback = defaultValue, fallback is NSNull == false {
                return try mcs_jsonValue( from: fallback, policy: policy )
            }
            if isOptional { return NSNull() }
            throw MCSerializationError.missingRequiredValue( entity: entityName, property: name )
        }

        switch attributeType {

            case .UUIDAttributeType:
                if let uuid = value as? UUID {
                    return policy.uppercaseUUIDs ? uuid.uuidString.uppercased() : uuid.uuidString.lowercased()
                }
                // Some drivers hand identity back as text. Normalise rather
                // than pass through, so one row does not serialize two ways
                // depending on which backend produced it.
                if let text = value as? String, let uuid = UUID( uuidString: text ) {
                    return policy.uppercaseUUIDs ? uuid.uuidString.uppercased() : uuid.uuidString.lowercased()
                }
                throw MCSerializationError.valueTypeMismatch( entity: entityName, property: name, value: value )

            case .dateAttributeType:
                if let date = value as? Date { return policy.dateFormatter( date ) }
                // Already formatted by a driver that returned text; trust it
                // rather than reformat something we cannot parse unambiguously.
                if let text = value as? String { return text }
                throw MCSerializationError.valueTypeMismatch( entity: entityName, property: name, value: value )

            case .decimalAttributeType:
                guard let decimal = mcs_decimal( from: value ) else {
                    throw MCSerializationError.valueTypeMismatch( entity: entityName, property: name, value: value )
                }
                switch policy.decimalFormat {
                    case .number: return NSDecimalNumber( decimal: decimal )
                    case .string: return NSDecimalNumber( decimal: decimal ).stringValue
                }

            case .binaryDataAttributeType:
                guard let data = value as? Data else {
                    throw MCSerializationError.valueTypeMismatch( entity: entityName, property: name, value: value )
                }
                return data.base64EncodedString()

            case .URIAttributeType:
                if let url = value as? URL { return url.absoluteString }
                if let text = value as? String { return text }
                throw MCSerializationError.valueTypeMismatch( entity: entityName, property: name, value: value )

            case .transformableAttributeType:
                // A transformable is whatever its value transformer says it is,
                // and this module has no way to know. Guessing works only for
                // values that happen to be JSON already.
                throw MCSerializationError.unsupportedAttribute(
                    entity: entityName, property: name,
                    reason: "transformable attributes need their own value transformer" )

            case .integer16AttributeType, .integer32AttributeType, .integer64AttributeType,
                 .doubleAttributeType, .floatAttributeType,
                 .booleanAttributeType, .stringAttributeType:
                return value

            case .objectIDAttributeType, .undefinedAttributeType:
                return NSNull()

            @unknown default:
                throw MCSerializationError.unsupportedAttribute(
                    entity: entityName, property: name, reason: "unknown attribute type \(attributeType)" )
        }
    }

    /// The inverse, delegating to MIOCoreData's existing converter so there is
    /// exactly one implementation of JSON-to-model-value in the ecosystem.
    public func mcs_modelValue ( from json: Any? ) throws -> Any? {
        if json == nil || json is NSNull {
            if isOptional { return nil }
            if let fallback = defaultValue { return fallback }
            throw MCSerializationError.missingRequiredValue( entity: entity.name ?? "?", property: name )
        }
        return try coreDataValue( from: json )
    }

    private func mcs_decimal ( from value: Any? ) -> Decimal? {
        if let d = value as? Decimal { return d }
        if let n = value as? NSDecimalNumber { return n.decimalValue }
        if let d = value as? Double { return Decimal( d ) }
        if let i = value as? Int { return Decimal( i ) }
        if let s = value as? String { return Decimal( string: s ) }
        return nil
    }
}
