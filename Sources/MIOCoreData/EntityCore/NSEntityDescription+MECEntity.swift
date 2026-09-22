//
//  NSEntityDescription+MECEntity.swift
//  MIOCoreData
//
//  Created by MIO Research Labs on 2026.
//
//  Core Data's description of a model, translated into MIOEntityCore's.
//
//  The direction is deliberate: MIOCoreData knows about MIOEntityCore, and
//  MIOEntityCore has never heard of Core Data. It cannot — NSEntityDescription
//  is not in Foundation, and reaching for it from there is a package cycle.
//
//  Compiles in both variants. Under -D APPLE_CORE_DATA these names are Apple's
//  Core Data; without it they are CoreDataSwift's.
//

import Foundation
import MIOEntityCore

extension MECAttributeType
{
    /// The MIO type for one of Core Data's.
    ///
    /// - Returns: The matching case, or `nil` for a type this package has never
    ///   heard of, which is what a future SDK adding one looks like.
    public init?( _ attributeType: NSAttributeType ) {
        // `NSAttributeType` is `UInt`-backed in both variants; MECAttributeType
        // is `Int`, because a raw value that cannot be negative does not need a
        // type that says so and Int is what every caller already holds.
        self.init( coreDataRawValue: Int( attributeType.rawValue ) )
    }
}

extension MECAttribute
{
    /// Translates one attribute.
    ///
    /// - Parameter attribute: Core Data's description.
    /// - Returns: The attribute, or `nil` when its type is one MIOEntityCore
    ///   does not know. `nil` rather than ``MECAttributeType/undefined``: an
    ///   attribute that silently loses its type renders as null and loses data.
    public init?( _ attribute: NSAttributeDescription ) {
        guard let type = MECAttributeType( attribute.attributeType ) else { return nil }

        self.init( name: attribute.name,
                   type: type,
                   isOptional: attribute.isOptional,
                   // Core Data kept the value and threw the model file's text
                   // away, so the text is written back out of the value.
                   defaultValueString: type.defaultText( from: attribute.defaultValue ),
                   isTransient: attribute.isTransient )
    }
}

extension MECRelationship
{
    /// Translates one relationship, by name at both ends.
    ///
    /// Core Data's reference graph is never copied across: both ends are read as
    /// names and resolved through a ``MECModel`` when somebody asks.
    public init( _ relationship: NSRelationshipDescription ) {
        self.init( name: relationship.name,
                   destinationEntityName: relationship.destinationEntity?.name ?? "",
                   inverseName: relationship.inverseRelationship?.name,
                   isToMany: relationship.isToMany,
                   isOptional: relationship.isOptional )
    }
}

extension MECEntity
{
    /// Translates one entity, without its inheritance link.
    ///
    /// The parent is a parameter rather than read from `entity.superentity`,
    /// because ``MECEntity`` is immutable: a parent has to exist before the child
    /// that names it. Callers should use ``MECModel/init(coreDataModel:)``, which
    /// orders that walk.
    ///
    /// - Parameters:
    ///   - entity: Core Data's description.
    ///   - superEntity: The already-translated parent, if any.
    public convenience init( _ entity: NSEntityDescription, superEntity: MECEntity? = nil ) {
        self.init( name: entity.name ?? "",
                   isAbstract: entity.isAbstract,
                   superEntity: superEntity,
                   attributes: entity.attributesByName.values
                       .compactMap { MECAttribute( $0 ) }
                       .sorted { $0.name < $1.name },
                   relationships: entity.relationshipsByName.values
                       .map { MECRelationship( $0 ) }
                       .sorted { $0.name < $1.name } )
    }
}
