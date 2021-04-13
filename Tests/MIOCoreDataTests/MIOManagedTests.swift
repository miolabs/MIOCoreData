//
//  File.swift
//  
//
//  Created by Javier Segura Perez on 5/4/21.
//

import Foundation


import Foundation
import XCTest
import MIOCoreData

final class MIOManagedTests: XCTestCase
{
    func testEntityCreation ( ) {
        
        let moc = MIOManagedObjectContextTest()
        
        let e = NSEntityDescription.insertNewObject(forEntityName: "SimpleEntity", into: moc) as! SimpleEntity
        e.identifier = UUID()
        e.name = "Test"
        //e.type = 0 <- Default Value
        
        // type has to fill up with the default value
        XCTAssertTrue(e.changedValues().count == 3, "Changes count are wrong")
        XCTAssertTrue((e.changedValues()["name"] as! String) == "Test", "Changes name value is wrong")
        XCTAssertTrue((e.changedValues()["type"] as! Int16) == 0, "Changes type value is wrong")
        
        XCTAssertTrue(moc.insertedObjects.count == 1, "Inserted objects count is wrong")
        XCTAssertTrue(moc.updatedObjects.count == 0, "Updated objects count is wrong")
        XCTAssertTrue(moc.deletedObjects.count == 0, "Deleted objects count is wrong")
        
        do {
            try moc.save()
        }
        catch {
            XCTAssertTrue(false, error.localizedDescription)
        }
        
        XCTAssertTrue(moc.insertedObjects.count == 0, "Inserted objects count is wrong")
        XCTAssertTrue(moc.updatedObjects.count == 0, "Updated objects count is wrong")
        XCTAssertTrue(moc.deletedObjects.count == 0, "Deleted objects count is wrong")
    }
    
    func testFetchObject(){
        
        let moc = MIOManagedObjectContextTest()
        
        let request = MIOCoreData.NSFetchRequest<SimpleEntity>(entityName: "SimpleEntity")
        guard let objs = try? moc.fetch(request) else {
            XCTAssertTrue(false, "Fetching Objects throws an error" )
            return
        }
        
        XCTAssertTrue(objs.count == 1, "Fetching Objects fail" )
        
        let e = objs[0]
        XCTAssertTrue(e.name == "Test", "name value of simple entity object is wrong")
    }
    
    func testMOCChanges(){
        let moc = MIOManagedObjectContextTest()

        let request = MIOCoreData.NSFetchRequest<SimpleEntity>(entityName: "SimpleEntity")
        guard let objs = try? moc.fetch(request) else {
            XCTAssertTrue(false, "Fetching Objects throws an error" )
            return
        }
        
        XCTAssertTrue(objs.count == 1, "Fetching Objects fail" )
        
        let e = objs[0]

        e.name = "Test change"
        
        XCTAssertTrue(e.changedValues().count == 1, "Changes count are wrong")
        XCTAssertTrue((e.changedValues()["name"] as! String) == "Test change", "Changes name value is wrong")
        XCTAssertTrue((e.committedValues(forKeys: ["name"]) as! [String:String])["name"] == "Test", "Stored name value is wrong")
    
        e.setPrimitiveValue(2, forKey: "type")
        XCTAssertTrue(e.changedValues().count == 2, "Changes count are wrong")
        XCTAssertTrue((e.changedValues()["type"] as! Int16) == 2, "Changes type value is wrong")
        XCTAssertTrue((e.committedValues(forKeys: ["type"]) as! [String:Int16])["type"] == 0, "Stored type value is wrong")
    }
}
        
