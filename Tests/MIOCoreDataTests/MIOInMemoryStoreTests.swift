//
//  MIOInMemoryStoreTests.swift
//  MIOCoreData
//
//  Created by Javier Segura Perez on 16/2/25.
//
import XCTest
import MIOCoreData
import TestModel

final class MIOInMemoryStoreTests: MIOManagedTests
{
    override func moc() throws -> MIOCoreData.NSManagedObjectContext {
        return InMemoryStoreMOCTest()
    }
}
