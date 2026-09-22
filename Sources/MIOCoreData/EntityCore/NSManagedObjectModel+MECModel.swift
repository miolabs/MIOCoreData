//
//  NSManagedObjectModel+MECModel.swift
//  MIOCoreData
//
//  Created by MIO Research Labs on 2026.
//

import Foundation
import MIOEntityCore

extension MECModel
{
    /// Translates a whole Core Data model.
    ///
    /// ```swift
    /// let model = MECModel( coreDataModel: container.managedObjectModel )
    /// ```
    ///
    /// Entities are built parents first, because ``MECEntity`` is immutable and
    /// takes its parent at `init`. Core Data hands the entities over in no
    /// particular order, so they are sorted by inheritance depth and built
    /// shallowest first.
    ///
    /// - Parameter coreDataModel: The Core Data model.
    public convenience init( coreDataModel: NSManagedObjectModel ) {
        var translated: [String: MECEntity] = [:]

        for entity in coreDataModel.entities.sorted( by: { MECModel._depth( of: $0 ) < MECModel._depth( of: $1 ) } ) {
            guard let name = entity.name else { continue }

            let parent = entity.superentity?.name.flatMap { translated[ $0 ] }
            translated[ name ] = MECEntity( entity, superEntity: parent )
        }

        // Model order, not the order they were built in: the inheritance sort is
        // an implementation detail of this walk and should not leak into how the
        // model lists its entities.
        self.init( entities: coreDataModel.entities.compactMap { $0.name.flatMap { translated[ $0 ] } } )
    }

    /// How many superentities sit above this one. A root is 0.
    private static func _depth( of entity: NSEntityDescription ) -> Int {
        var depth  = 0
        var parent = entity.superentity
        while let current = parent {
            depth += 1
            parent = current.superentity
        }
        return depth
    }
}
