//
//  NSAttributeDescription+ValueConversion.swift
//  MIOCoreData
//
//  Canonical "untyped value -> Core Data value" conversion, shared by every
//  layer that ingests values from a transport (sync change-blocks, request
//  payload dictionaries, store cache rows fed by web/sync sources).
//
//  It replaces two drifted implementations — DualLinkDB's
//  NSAttributeDescription.deserialize (nil on failed conversion, silently
//  nulling mandatory attributes) and MIOPersistentStore's MPSCacheNode.convert
//  (throwing, but with its own type table) — with one set of semantics:
//
//  - nil / NSNull       -> the model defaultValue (nil when there is none;
//                          whether nil is legal is the save validator's
//                          business, not the converter's)
//  - convertible value  -> the Core Data value class for the attribute type
//  - failed conversion  -> throws, naming entity.attribute and the value.
//                          Never a silent nil.
//
//  This file intentionally lives in the MIOCoreData wrapper target with no
//  APPLE_CORE_DATA gate: it compiles against whichever NSAttributeDescription
//  the build re-exports (CoreDataSwift or Apple CoreData), so consumers like
//  DualLinkDB can rely on it in both flavors.
//

import Foundation
import MIOCore

public enum NSAttributeValueConversionError: Error, LocalizedError
{
    // The offending value travels as a pre-formatted String: Error implies
    // Sendable in Swift 6 and an Any payload cannot satisfy it
    case cannotConvert(entity: String, attribute: String, type: NSAttributeType, value: String)

    public var errorDescription: String? {
        switch self {
        case let .cannotConvert(entity, attribute, type, value):
            return "Cannot convert value \(value) to attribute type \(type) for \(entity).\(attribute)."
        }
    }
}

extension NSAttributeDescription
{
    /// Converts an untyped transport value into the Core Data value class for
    /// this attribute's type. See the header comment for the exact semantics.
    public func coreDataValue(from value: Any?) throws -> Any? {

        if value == nil || value is NSNull {
            return defaultValue
        }
        let v = value!

        func fail() -> NSAttributeValueConversionError {
            return .cannotConvert(entity: entity.name ?? "?", attribute: name, type: attributeType, value: "\(v) (\(Swift.type(of: v)))")
        }

        switch attributeType {

        case .dateAttributeType:
            if let date = v as? Date { return date }
            if let string = v as? String {
                if let date = MIOCoreDate(fromString: string) { return date }
            }
            throw fail()

        case .UUIDAttributeType:
            if let uuid = v as? UUID { return uuid }
            if let string = v as? String, let uuid = UUID(uuidString: string) { return uuid }
            throw fail()

        case .stringAttributeType:
            if let string = v as? String { return string }
            if v is NSString { return v }
            if let uuid = v as? UUID { return uuid.uuidString.uppercased() }
            if MIOCoreIsIntValue(v), let int = MIOCoreInt64Value(v) { return String(int) }
            throw fail()

        case .booleanAttributeType:
            if let bool = MIOCoreBoolValue(v) { return bool }
            throw fail()

        case .integer16AttributeType:
            if let int = MIOCoreInt16Value(v) { return int }
            throw fail()

        case .integer32AttributeType:
            if let int = MIOCoreInt32Value(v) { return int }
            throw fail()

        case .integer64AttributeType:
            if let int = MIOCoreInt64Value(v) { return int }
            throw fail()

        case .decimalAttributeType:
            if let decimal = MCDecimalValue(v) { return decimal }
            throw fail()

        case .doubleAttributeType:
            // NOTE: one of the old converters routed doubles through
            // MIOCoreFloatValue, silently losing precision
            if let double = MIOCoreDoubleValue(v) { return double }
            throw fail()

        case .floatAttributeType:
            if let float = MIOCoreFloatValue(v) { return float }
            throw fail()

        case .transformableAttributeType:
            // Web/sync sources deliver transformables as JSON text; the DB
            // driver hands over the parsed graph (dictionary, array or
            // fragment), which passes through as-is. An unparseable string
            // stays a string — transformable is Any by definition — and an
            // empty string means "no value".
            if let string = v as? String {
                if string.isEmpty { return defaultValue }
                if let object = try? JSONSerialization.jsonObject(with: string.data(using: .utf8)!, options: [.allowFragments]) {
                    return object
                }
                return string
            }
            return v

        case .binaryDataAttributeType:
            if let data = v as? Data { return data }
            if let string = v as? String, let data = Data(base64Encoded: string) { return data }
            throw fail()

        default:
            // undefined, objectID, URI, composite (Apple builds): no
            // conversion defined — pass through untouched
            return v
        }
    }
}
