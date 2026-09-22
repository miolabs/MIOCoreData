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
    ///
    /// - Parameters:
    ///   - value: The untyped transport value.
    ///   - dateTimeZone: By default (`nil`) date strings follow the wall-clock contract —
    ///     they are read in the process time zone, as-is. A caller that needs a fixed frame
    ///     can force one, e.g. `TimeZone(secondsFromGMT: 0)` to convert in GMT+0. The zone
    ///     only affects `.dateAttributeType` values arriving as strings.
    public func coreDataValue(from value: Any?, dateTimeZone: TimeZone? = nil) throws -> Any? {

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
                // A caller-chosen zone is the deliberate opt-out from the wall-clock
                // default: the text is read in that zone, markers still ignored.
                if let tz = dateTimeZone {
                    if let date = MCDate.parseOrNil( string, in: tz ) { return date }
                    throw fail()
                }
                // Wire timestamps are the local wall clock with no offset (the DualLinkDB
                // contract, same as the DB layer): parse with the wall-clock engine, which
                // also ignores embedded zone markers. The explicit-UTC parser is only a
                // last resort for ISO shapes the wall-clock engine cannot read.
                if let date = MCDate.parseOrNil( string ) { return date }
                if let date = MCDate.parseUTC( string ) { return date }
            }
            throw fail()

        case .UUIDAttributeType:
            if let uuid = v as? UUID { return uuid }
            if let string = v as? String {
                // Legacy String columns converted to UUID hold '' where they
                // meant "no value" — treat it like nil, not a failed conversion.
                if string.isEmpty { return defaultValue }
                if let uuid = UUID(uuidString: string) { return uuid }
            }
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

        case .URIAttributeType:
            // Apple Core Data holds a URL in memory; the store carries it as its
            // absolute string when the database has no URI type of its own.
            if let url = v as? URL { return url }
            if let string = v as? String {
                // Same precedent as UUID: a legacy text column re-typed as URI holds '' for "no value".
                if string.isEmpty { return defaultValue }
                if let url = URL(string: string) { return url }
            }
            throw fail()

        default:
            // undefined, objectID, composite (Apple builds): no
            // conversion defined — pass through untouched
            return v
        }
    }
}
