//
//  MIOIncrementalStoreTests.swift
//  MIOCoreData
//
//  Created by Javier Segura Perez on 17/2/25.
//

import XCTest
import MIOCoreData
import TestModel

final class MIOIncrementalStoreTests: MIOManagedTests
{
    override func moc() throws -> MIOCoreData.NSManagedObjectContext {
        return IncrementalStoreMOCTest()
    }
}
