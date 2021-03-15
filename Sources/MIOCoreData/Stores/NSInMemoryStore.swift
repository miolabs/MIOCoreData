//
//  File.swift
//  
//
//  Created by Javier Segura Perez on 15/3/21.
//

import Foundation

class NSInMemoryStore : NSPersistentStore
{
    override func loadMetadata() throws {
        self.metadata = [NSStoreUUIDKey: UUID().uuidString.uppercased(), NSStoreTypeKey: NSInMemoryStoreType]
    }
}
