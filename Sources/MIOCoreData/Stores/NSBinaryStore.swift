//
//  NSBinaryStore.swift
//  
//
//  Created by Javier Segura Perez on 15/3/21.
//

import Foundation

class NSBinaryStoreType : NSPersistentStore
{
    override func loadMetadata() throws {
        self.metadata = [NSStoreUUIDKey: UUID().uuidString.uppercased(), NSStoreTypeKey: NSBinaryStoreType]        
    }
}
