//
//  MCSerializationPolicy.swift
//
//  Created by MIO Research Labs on 2026.
//

import Foundation
import MIOCoreData

public struct MCSerializationPolicy : Sendable
{
    /// How a `Decimal` reaches JSON.
    public enum DecimalFormat : Sendable
    {
        /// `NSDecimalNumber`.
        case number
        /// A quoted string.
        case string
    }

    /// Attribute holding the row identity. Defaults to `"identifier"`, which is
    /// the convention MIOPersistentStore use, but a project on a schema it did
    /// not design can say otherwise per entity.
    public var identifierKey: @Sendable ( NSEntityDescription ) -> String

    /// UUIDs are emitted uppercased by default, matching what PostgreSQL and
    /// the existing MIO stack produce.
    public var uppercaseUUIDs: Bool

    public var decimalFormat: DecimalFormat

    /// Dates are ISO 8601 with a timezone by default.
    public var dateFormatter: @Sendable ( Date ) -> String

    /// Whether a nil attribute appears as `NSNull` or is left out of the
    /// dictionary. Omitting is friendlier to PATCH-style APIs, where an absent
    /// key and an explicit null mean different things.
    public var includeNulls: Bool

    public init ( identifierKey: @escaping @Sendable ( NSEntityDescription ) -> String = { _ in "identifier" },
                  uppercaseUUIDs: Bool = true,
                  decimalFormat: DecimalFormat = .string,
                  includeNulls: Bool = false,
                  dateFormatter: @escaping @Sendable ( Date ) -> String = MCSerializationPolicy.iso8601 ) {
        self.identifierKey  = identifierKey
        self.uppercaseUUIDs = uppercaseUUIDs
        self.decimalFormat  = decimalFormat
        self.includeNulls   = includeNulls
        self.dateFormatter  = dateFormatter
    }

    public static let `default` = MCSerializationPolicy()

    /// Fractional seconds included, because dropping them silently reorders
    /// records written in the same second.
    @Sendable
    public static func iso8601 ( _ date: Date ) -> String {
        return iso8601Formatter.string( from: date )
    }

    nonisolated(unsafe) private static let iso8601Formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [ .withInternetDateTime, .withFractionalSeconds ]
        return f
    }()
}

public enum MCSerializationError : Error, CustomStringConvertible
{
    /// A value the model says is required is nil and has no default.
    case missingRequiredValue( entity: String, property: String )

    /// An attribute type this layer will not guess at.
    case unsupportedAttribute( entity: String, property: String, reason: String )

    /// A value that does not match its declared attribute type.
    case valueTypeMismatch( entity: String, property: String, value: Any? )

    /// The policy names an identity attribute the entity does not have.
    case identityAttributeMissing( entity: String, key: String )

    public var description: String {
        switch self {
            case .missingRequiredValue( let e, let p ):
                return "[MCSerialization] \(e).\(p) is required but has no value and no default"
            case .unsupportedAttribute( let e, let p, let reason ):
                return "[MCSerialization] \(e).\(p) cannot be serialized: \(reason)"
            case .valueTypeMismatch( let e, let p, let value ):
                return "[MCSerialization] \(e).\(p) got \(String( describing: value )), which does not match its declared type"
            case .identityAttributeMissing( let e, let key ):
                return "[MCSerialization] the policy names \"\(key)\" as identity, but \(e) has no such attribute"
        }
    }
}
