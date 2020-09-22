//
//  File.swift
//  
//
//  Created by Javier Segura Perez on 22/09/2020.
//

import XCTest
import Foundation
import CoreData

final class NSPredicateTests: XCTestCase
{
    
    func testComparisonPredicate ( ) {
        
        let predicate = NSPredicate(format: "available = true")
        XCTAssertTrue( (predicate as? NSComparisonPredicate) != nil, "NSPredicate is not NSComparisionPredicate subtype" )
        
        let cmpPredicate = predicate as! NSComparisonPredicate
        XCTAssertTrue( cmpPredicate.predicateOperatorType == NSComparisonPredicate.Operator.equalTo, "NSComparisionPredicate operator type is not EqualTo" )
        
        XCTAssertTrue( cmpPredicate.leftExpression.expressionType == NSExpression.ExpressionType.keyPath, "NSComparisionPredicate left expression is not KeyPath type" )
        XCTAssertTrue( cmpPredicate.leftExpression.keyPath == "available", "NSComparisionPredicate left expression keypath value is wrong" )

        XCTAssertTrue( cmpPredicate.rightExpression.expressionType == NSExpression.ExpressionType.constantValue, "NSComparisionPredicate right expression is not ConstantValue type" )
        guard let value = cmpPredicate.rightExpression.constantValue as? Int else {
            XCTAssertTrue(false, "NSComparisionPredicate rigth expression constant value cast type is wrong")
            return
        }
        
        XCTAssertTrue( value == 1, "NSComparisionPredicate rigth expression constant value is wrong" )
    }
    
    func testComparisionPredicateOperators() {
        
        var predicate = NSPredicate(format: "value == 0") as! NSComparisonPredicate
        XCTAssertTrue( predicate.predicateOperatorType == NSComparisonPredicate.Operator.equalTo, "NSComparisionPredicate operator type is not equalTo" )
        
        predicate = NSPredicate(format: "value = 0") as! NSComparisonPredicate
        XCTAssertTrue( predicate.predicateOperatorType == NSComparisonPredicate.Operator.equalTo, "NSComparisionPredicate operator type is not equalTo" )
        
        predicate = NSPredicate(format: "value > 1") as! NSComparisonPredicate
        XCTAssertTrue( predicate.predicateOperatorType == NSComparisonPredicate.Operator.greaterThan, "NSComparisionPredicate operator type is not greaterThan" )
        
        predicate = NSPredicate(format: "value < 1") as! NSComparisonPredicate
        XCTAssertTrue( predicate.predicateOperatorType == NSComparisonPredicate.Operator.lessThan, "NSComparisionPredicate operator type is not lessThan" )

        predicate = NSPredicate(format: "value >= 1") as! NSComparisonPredicate
        XCTAssertTrue( predicate.predicateOperatorType == NSComparisonPredicate.Operator.greaterThanOrEqualTo, "NSComparisionPredicate operator type is not greaterThanOrEqualTo" )

        predicate = NSPredicate(format: "value <= 1") as! NSComparisonPredicate
        XCTAssertTrue( predicate.predicateOperatorType == NSComparisonPredicate.Operator.lessThanOrEqualTo, "NSComparisionPredicate operator type is not lessThanOrEqualTo" )
        
        predicate = NSPredicate(format: "value != 1") as! NSComparisonPredicate
        XCTAssertTrue( predicate.predicateOperatorType == NSComparisonPredicate.Operator.notEqualTo, "NSComparisionPredicate operator type is not notEqualTo" )

        predicate = NSPredicate(format: "value contains 'v'") as! NSComparisonPredicate
        XCTAssertTrue( predicate.predicateOperatorType == NSComparisonPredicate.Operator.contains, "NSComparisionPredicate operator type is not contains" )
    }
    
    func testComparisionPredicateValueTypes() {
        var predicate = NSPredicate(format: "value = true") as! NSComparisonPredicate
        if let v = predicate.rightExpression.constantValue as? Int {
            XCTAssertTrue( v == 1, "Boolean value conversion fails. Value is wrong: \(v)")
        }
        else {
            XCTAssertTrue(false, "Boolean value conversion fails. Value is null")
        }
                
        predicate = NSPredicate(format: "value = 1") as! NSComparisonPredicate
        if let v = predicate.rightExpression.constantValue as? Int {
            XCTAssertTrue( v == 1, "Int value conversion fails. Value is wrong: \(v)")
        }
        else {
            XCTAssertTrue(false, "Int value conversion fails. Value is null")
        }
        
        predicate = NSPredicate(format: "value = 1.0") as! NSComparisonPredicate
        if let v = predicate.rightExpression.constantValue as? Double {
            XCTAssertTrue( v == 1.0, "Double value conversion fails. Value is wrong: \(v)")
        }
        else {
            XCTAssertTrue(false, "Double value conversion fails. Value is null")
        }

        predicate = NSPredicate(format: "value = 'string'") as! NSComparisonPredicate
        if let v = predicate.rightExpression.constantValue as? String {
            XCTAssertTrue( v == "string", "String value conversion fails. Value is wrong: \(v)")
        }
        else {
            XCTAssertTrue(false, "String value conversion fails. Value is null")
        }

        predicate = NSPredicate(format: "value = \"string\"") as! NSComparisonPredicate
        if let v = predicate.rightExpression.constantValue as? String {
            XCTAssertTrue( v == "string", "String value conversion fails. Value is wrong: \(v)")
        }
        else {
            XCTAssertTrue(false, "String value conversion fails. Value is null")
        }

        predicate = NSPredicate(format: "value = nil") as! NSComparisonPredicate
        XCTAssertTrue( predicate.rightExpression.constantValue == nil, "Null value conversion fails. Value is wrong: \(String(describing: predicate.rightExpression.constantValue))")

        predicate = NSPredicate(format: "value = null") as! NSComparisonPredicate
        XCTAssertTrue( predicate.rightExpression.constantValue == nil, "Null value conversion fails. Value is wrong: \(String(describing: predicate.rightExpression.constantValue))")
        
    }
    
    func testCompoundPredicate() {
        var predicate = NSPredicate(format: "available = true and value > 1")
        XCTAssertTrue( (predicate as? NSCompoundPredicate) != nil, "NSPredicate is not NSCompoundPredicate subtype" )

        predicate = NSPredicate(format: "available = true or value > 1")
        XCTAssertTrue( (predicate as? NSCompoundPredicate) != nil, "NSPredicate is not NSCompoundPredicate subtype" )
        
        predicate = NSPredicate(format: "not available = true")
        XCTAssertTrue( (predicate as? NSCompoundPredicate) != nil, "NSPredicate is not NSCompoundPredicate subtype" )
    }
    
    func testCompoundPredicateAND() {
        let predicate = NSPredicate(format: "available = true and value > 1") as! NSCompoundPredicate        
        XCTAssertTrue(predicate.compoundPredicateType == .and, "NSCompoundPredicate is not the right type: \(predicate.compoundPredicateType)")
        
        // Checking first subpredicate
        guard let subpredicate1 = predicate.subpredicates[0] as? NSComparisonPredicate else {
            XCTAssertTrue(false, "First subpredicate is not NSComparisonPredicate subtype")
            return
        }
        
        XCTAssertTrue(subpredicate1.leftExpression.expressionType == .keyPath)
        XCTAssertTrue(subpredicate1.leftExpression.keyPath == "available")
        
        XCTAssertTrue(subpredicate1.predicateOperatorType == .equalTo)
        
        XCTAssertTrue(subpredicate1.rightExpression.expressionType == .constantValue)
        var v = subpredicate1.rightExpression.constantValue as? Int
        XCTAssertTrue(v != nil && v! == 1)
        
        // Checking second subpredicate
        guard let subpredicate2 = predicate.subpredicates[1] as? NSComparisonPredicate else {
            XCTAssertTrue(false, "Second subpredicate is not NSComparisonPredicate subtype")
            return
        }

        XCTAssertTrue(subpredicate2.leftExpression.expressionType == .keyPath)
        XCTAssertTrue(subpredicate2.leftExpression.keyPath == "value")
        
        XCTAssertTrue(subpredicate2.predicateOperatorType == .greaterThan)
        
        XCTAssertTrue(subpredicate2.rightExpression.expressionType == .constantValue)
        v = subpredicate2.rightExpression.constantValue as? Int
        XCTAssertTrue(v != nil && v == 1)

    }
    
    func testCompoundPredicateOR() {
        let predicate = NSPredicate(format: "available = true or value > 1") as! NSCompoundPredicate
        XCTAssertTrue(predicate.compoundPredicateType == .or, "NSCompoundPredicate is not the right type: \(predicate.compoundPredicateType)")
        
        // Checking first subpredicate
        guard let subpredicate1 = predicate.subpredicates[0] as? NSComparisonPredicate else {
            XCTAssertTrue(false, "First subpredicate is not NSComparisonPredicate subtype")
            return
        }
        
        XCTAssertTrue(subpredicate1.leftExpression.expressionType == .keyPath)
        XCTAssertTrue(subpredicate1.leftExpression.keyPath == "available")
        
        XCTAssertTrue(subpredicate1.predicateOperatorType == .equalTo)
        
        XCTAssertTrue(subpredicate1.rightExpression.expressionType == .constantValue)
        var v = subpredicate1.rightExpression.constantValue as? Int
        XCTAssertTrue(v != nil && v! == 1)
        
        // Checking second subpredicate
        guard let subpredicate2 = predicate.subpredicates[1] as? NSComparisonPredicate else {
            XCTAssertTrue(false, "Second subpredicate is not NSComparisonPredicate subtype")
            return
        }

        XCTAssertTrue(subpredicate2.leftExpression.expressionType == .keyPath)
        XCTAssertTrue(subpredicate2.leftExpression.keyPath == "value")
        
        XCTAssertTrue(subpredicate2.predicateOperatorType == .greaterThan)
        
        XCTAssertTrue(subpredicate2.rightExpression.expressionType == .constantValue)
        v = subpredicate2.rightExpression.constantValue as? Int
        XCTAssertTrue(v != nil && v == 1)

    }
    
    func testCompoundPredicateNOT() {
        let predicate = NSPredicate(format: "not available = true") as! NSCompoundPredicate
        XCTAssertTrue(predicate.compoundPredicateType == .not, "NSCompoundPredicate is not the right type: \(predicate.compoundPredicateType)")
        
        // Checking subpredicate
        guard let subpredicate = predicate.subpredicates[0] as? NSComparisonPredicate else {
            XCTAssertTrue(false, "Subpredicate is not NSComparisonPredicate subtype")
            return
        }
        
        XCTAssertTrue(subpredicate.leftExpression.expressionType == .keyPath)
        XCTAssertTrue(subpredicate.leftExpression.keyPath == "available")
        
        XCTAssertTrue(subpredicate.predicateOperatorType == .equalTo)
        
        XCTAssertTrue(subpredicate.rightExpression.expressionType == .constantValue)
        let v = subpredicate.rightExpression.constantValue as? Int
        XCTAssertTrue(v != nil && v! == 1)
    }

    func testCompoundPredicateComplex() {
        let predicate = NSPredicate(format: "available = true or value >= 1 and value <= 10.5") as! NSCompoundPredicate
        XCTAssertTrue(predicate.compoundPredicateType == .or, "NSCompoundPredicate is not the right type: \(predicate.compoundPredicateType)")
        
        // Checking subpredicate 1
        guard let subpredicate1 = predicate.subpredicates[0] as? NSComparisonPredicate else {
            XCTAssertTrue(false, "Subpredicate is not NSComparisonPredicate subtype")
            return
        }
        
        XCTAssertTrue(subpredicate1.leftExpression.expressionType == .keyPath)
        XCTAssertTrue(subpredicate1.leftExpression.keyPath == "available")
        
        XCTAssertTrue(subpredicate1.predicateOperatorType == .equalTo)
        
        XCTAssertTrue(subpredicate1.rightExpression.expressionType == .constantValue)
        var iv = subpredicate1.rightExpression.constantValue as? Int
        XCTAssertTrue(iv != nil && iv! == 1)
                
        // Checking subpredicate 2
        guard let subpredicate2 = predicate.subpredicates[1] as? NSCompoundPredicate else {
            XCTAssertTrue(false, "Subpredicate is not NSCompoundPredicate subtype")
            return
        }
        XCTAssertTrue(subpredicate2.compoundPredicateType == .and, "NSCompoundPredicate is not the right type: \(predicate.compoundPredicateType)")
        
        // Checking subpredicate 2.1
        guard let subpredicate2_1 = subpredicate2.subpredicates[0] as? NSComparisonPredicate else {
            XCTAssertTrue(false, "Subpredicate is not NSComparisonPredicate subtype")
            return
        }
        
        XCTAssertTrue(subpredicate2_1.leftExpression.expressionType == .keyPath)
        XCTAssertTrue(subpredicate2_1.leftExpression.keyPath == "value")

        XCTAssertTrue(subpredicate2_1.predicateOperatorType == .greaterThanOrEqualTo)

        XCTAssertTrue(subpredicate2_1.rightExpression.expressionType == .constantValue)
        iv = subpredicate2_1.rightExpression.constantValue as? Int
        XCTAssertTrue(iv != nil && iv == 1)

        // Checking subpredicate 2.2
        guard let subpredicate2_2 = subpredicate2.subpredicates[1] as? NSComparisonPredicate else {
            XCTAssertTrue(false, "Subpredicate is not NSComparisonPredicate subtype")
            return
        }
        
        XCTAssertTrue(subpredicate2_2.leftExpression.expressionType == .keyPath)
        XCTAssertTrue(subpredicate2_2.leftExpression.keyPath == "value")

        XCTAssertTrue(subpredicate2_2.predicateOperatorType == .lessThanOrEqualTo)

        XCTAssertTrue(subpredicate2_2.rightExpression.expressionType == .constantValue)
        let dv = subpredicate2_2.rightExpression.constantValue as? Double
        XCTAssertTrue(dv != nil && dv == 10.5)
    }
    
    func testCompoundPredicateComplex2() {
        let predicate = NSPredicate(format: "not available = true or value >= 1 and value <= 10.5") as! NSCompoundPredicate
        XCTAssertTrue(predicate.compoundPredicateType == .or, "NSCompoundPredicate is not the right type: \(predicate.compoundPredicateType)")
        
        // Checking subpredicate 1
        guard let subpredicate1 = predicate.subpredicates[0] as? NSCompoundPredicate else {
            XCTAssertTrue(false, "Subpredicate 1 is not NSCompoundPredicate subtype")
            return
        }
        
        XCTAssertTrue(subpredicate1.compoundPredicateType == .not, "NSCompoundPredicate is not the right type: \(subpredicate1.compoundPredicateType)")
        guard let subpredicate1_1 = subpredicate1.subpredicates[0] as? NSComparisonPredicate else {
            XCTAssertTrue(false, "Subpredicate 1.1 is not NSComparisonPredicate subtype")
            return
        }
        XCTAssertTrue(subpredicate1_1.leftExpression.expressionType == .keyPath)
        XCTAssertTrue(subpredicate1_1.leftExpression.keyPath == "available")
        XCTAssertTrue(subpredicate1_1.predicateOperatorType == .equalTo)
        XCTAssertTrue(subpredicate1_1.rightExpression.expressionType == .constantValue)
        var iv = subpredicate1_1.rightExpression.constantValue as? Int
        XCTAssertTrue(iv != nil && iv! == 1)


        // Checking subpredicate 2
        guard let subpredicate2 = predicate.subpredicates[1] as? NSCompoundPredicate else {
            XCTAssertTrue(false, "Subpredicate 2 is not NSCompoundPredicate subtype")
            return
        }
        
        XCTAssertTrue(subpredicate2.compoundPredicateType == .and, "NSCompoundPredicate is not the right type: \(subpredicate2.compoundPredicateType)")
        guard let subpredicate2_1 = subpredicate2.subpredicates[0] as? NSComparisonPredicate else {
            XCTAssertTrue(false, "Subpredicate 2.2 is not NSComparisonPredicate subtype")
            return
        }
        
        XCTAssertTrue(subpredicate2_1.leftExpression.expressionType == .keyPath)
        XCTAssertTrue(subpredicate2_1.leftExpression.keyPath == "value")

        XCTAssertTrue(subpredicate2_1.predicateOperatorType == .greaterThanOrEqualTo)

        XCTAssertTrue(subpredicate2_1.rightExpression.expressionType == .constantValue)
        iv = subpredicate2_1.rightExpression.constantValue as? Int
        XCTAssertTrue(iv != nil && iv == 1)

        // Checking subpredicate 2.2
        guard let subpredicate2_2 = subpredicate2.subpredicates[1] as? NSComparisonPredicate else {
            XCTAssertTrue(false, "Subpredicate 2.2 is not NSComparisonPredicate subtype")
            return
        }

        XCTAssertTrue(subpredicate2_2.leftExpression.expressionType == .keyPath)
        XCTAssertTrue(subpredicate2_2.leftExpression.keyPath == "value")

        XCTAssertTrue(subpredicate2_2.predicateOperatorType == .lessThanOrEqualTo)

        XCTAssertTrue(subpredicate2_2.rightExpression.expressionType == .constantValue)
        let dv = subpredicate2_2.rightExpression.constantValue as? Double
        XCTAssertTrue(dv != nil && dv == 10.5)
    }
    
    func testCompoundPredicateGROUP() {
        let predicate = NSPredicate(format: "available = true or (value >= 1 and value <= 10.5)") as! NSCompoundPredicate
        XCTAssertTrue(predicate.compoundPredicateType == .or, "NSCompoundPredicate is not the right type: \(predicate.compoundPredicateType)")
        
        // Checking subpredicate 1
        guard let subpredicate1 = predicate.subpredicates[0] as? NSComparisonPredicate else {
            XCTAssertTrue(false, "Subpredicate is not NSComparisonPredicate subtype")
            return
        }
        
        XCTAssertTrue(subpredicate1.leftExpression.expressionType == .keyPath)
        XCTAssertTrue(subpredicate1.leftExpression.keyPath == "available")
        
        XCTAssertTrue(subpredicate1.predicateOperatorType == .equalTo)
        
        XCTAssertTrue(subpredicate1.rightExpression.expressionType == .constantValue)
        var iv = subpredicate1.rightExpression.constantValue as? Int
        XCTAssertTrue(iv != nil && iv! == 1)

        // Checking subpredicate 2
        guard let subpredicate2 = predicate.subpredicates[1] as? NSCompoundPredicate else {
            XCTAssertTrue(false, "Subpredicate is not NSCompoundPredicate subtype")
            return
        }
        XCTAssertTrue(subpredicate2.compoundPredicateType == .and, "NSCompoundPredicate is not the right type: \(predicate.compoundPredicateType)")
        
        // Checking subpredicate 2.1
        guard let subpredicate2_1 = subpredicate2.subpredicates[0] as? NSComparisonPredicate else {
            XCTAssertTrue(false, "Subpredicate is not NSComparisonPredicate subtype")
            return
        }
        
        XCTAssertTrue(subpredicate2_1.leftExpression.expressionType == .keyPath)
        XCTAssertTrue(subpredicate2_1.leftExpression.keyPath == "value")

        XCTAssertTrue(subpredicate2_1.predicateOperatorType == .greaterThanOrEqualTo)

        XCTAssertTrue(subpredicate2_1.rightExpression.expressionType == .constantValue)
        iv = subpredicate2_1.rightExpression.constantValue as? Int
        XCTAssertTrue(iv != nil && iv == 1)

        // Checking subpredicate 2.2
        guard let subpredicate2_2 = subpredicate2.subpredicates[1] as? NSComparisonPredicate else {
            XCTAssertTrue(false, "Subpredicate is not NSComparisonPredicate subtype")
            return
        }
        
        XCTAssertTrue(subpredicate2_2.leftExpression.expressionType == .keyPath)
        XCTAssertTrue(subpredicate2_2.leftExpression.keyPath == "value")

        XCTAssertTrue(subpredicate2_2.predicateOperatorType == .lessThanOrEqualTo)

        XCTAssertTrue(subpredicate2_2.rightExpression.expressionType == .constantValue)
        let dv = subpredicate2_2.rightExpression.constantValue as? Double
        XCTAssertTrue(dv != nil && dv == 10.5)

    }
}
