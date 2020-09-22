//
//  MIOPredicateTests.swift
//  
//
//  Created by Javier Segura Perez on 22/09/2020.
//

import Foundation
import XCTest
import MIOCoreData


final class MIOPredicateTests: XCTestCase {
    
    func testComparisonPredicate ( ) {
        
        let predicate = MIOPredicateWithFormat(format: "available = true")
        
        XCTAssertTrue( (predicate as? MIOComparisonPredicate) != nil, "??" )
        let cmpPredicate = predicate as! MIOComparisonPredicate
        XCTAssertTrue( cmpPredicate.predicateOperatorType == MIOComparisonPredicate.Operator.equalTo, "MIOComparisonPredicate operator type is not EqualTo" )
        
        XCTAssertTrue( cmpPredicate.leftExpression.expressionType == MIOExpression.ExpressionType.keyPath, "MIOComparisonPredicate left expression is not KeyPath type" )
        XCTAssertTrue( cmpPredicate.leftExpression.keyPath == "available", "MIOComparisonPredicate left expression keypath value is wrong" )

        XCTAssertTrue( cmpPredicate.rightExpression.expressionType == MIOExpression.ExpressionType.constantValue, "MIOComparisonPredicate right expression is not ConstantValue type" )
        guard let value = cmpPredicate.rightExpression.constantValue as? Int else {
            XCTAssertTrue(false, "MIOComparisonPredicate rigth expression constant value cast type is wrong")
            return
        }
        
        XCTAssertTrue( value == 1, "MIOComparisonPredicate rigth expression constant value is wrong" )
    }
    
    func testComparisionPredicateOperators() {
        
        var predicate = MIOPredicateWithFormat(format: "value == 0") as! MIOComparisonPredicate
        XCTAssertTrue( predicate.predicateOperatorType == MIOComparisonPredicate.Operator.equalTo, "MIOComparisonPredicate operator type is not equalTo" )
        
        predicate = MIOPredicateWithFormat(format: "value = 0") as! MIOComparisonPredicate
        XCTAssertTrue( predicate.predicateOperatorType == MIOComparisonPredicate.Operator.equalTo, "MIOComparisonPredicate operator type is not equalTo" )
        
        predicate = MIOPredicateWithFormat(format: "value > 1") as! MIOComparisonPredicate
        XCTAssertTrue( predicate.predicateOperatorType == MIOComparisonPredicate.Operator.greaterThan, "MIOComparisonPredicate operator type is not greaterThan" )
        
        predicate = MIOPredicateWithFormat(format: "value < 1") as! MIOComparisonPredicate
        XCTAssertTrue( predicate.predicateOperatorType == MIOComparisonPredicate.Operator.lessThan, "MIOComparisonPredicate operator type is not lessThan" )

        predicate = MIOPredicateWithFormat(format: "value >= 1") as! MIOComparisonPredicate
        XCTAssertTrue( predicate.predicateOperatorType == MIOComparisonPredicate.Operator.greaterThanOrEqualTo, "MIOComparisonPredicate operator type is not greaterThanOrEqualTo" )

        predicate = MIOPredicateWithFormat(format: "value <= 1") as! MIOComparisonPredicate
        XCTAssertTrue( predicate.predicateOperatorType == MIOComparisonPredicate.Operator.lessThanOrEqualTo, "MIOComparisonPredicate operator type is not lessThanOrEqualTo" )
        
        predicate = MIOPredicateWithFormat(format: "value != 1") as! MIOComparisonPredicate
        XCTAssertTrue( predicate.predicateOperatorType == MIOComparisonPredicate.Operator.notEqualTo, "MIOComparisonPredicate operator type is not notEqualTo" )

        predicate = MIOPredicateWithFormat(format: "value contains 'v'") as! MIOComparisonPredicate
        XCTAssertTrue( predicate.predicateOperatorType == MIOComparisonPredicate.Operator.contains, "MIOComparisonPredicate operator type is not contains" )
    }
    
    func testComparisionPredicateValueTypes() {
        var predicate = MIOPredicateWithFormat(format: "value = true") as! MIOComparisonPredicate
        if let v = predicate.rightExpression.constantValue as? Int {
            XCTAssertTrue( v == 1, "Boolean value conversion fails. Value is wrong: \(v)")
        }
        else {
            XCTAssertTrue(false, "Boolean value conversion fails. Value is null")
        }
                
        predicate = MIOPredicateWithFormat(format: "value = 1") as! MIOComparisonPredicate
        if let v = predicate.rightExpression.constantValue as? Int {
            XCTAssertTrue( v == 1, "Int value conversion fails. Value is wrong: \(v)")
        }
        else {
            XCTAssertTrue(false, "Int value conversion fails. Value is null")
        }
        
        predicate = MIOPredicateWithFormat(format: "value = 1.0") as! MIOComparisonPredicate
        if let v = predicate.rightExpression.constantValue as? Double {
            XCTAssertTrue( v == 1.0, "Double value conversion fails. Value is wrong: \(v)")
        }
        else {
            XCTAssertTrue(false, "Double value conversion fails. Value is null")
        }

        predicate = MIOPredicateWithFormat(format: "value = 'string'") as! MIOComparisonPredicate
        if let v = predicate.rightExpression.constantValue as? String {
            XCTAssertTrue( v == "string", "String value conversion fails. Value is wrong: \(v)")
        }
        else {
            XCTAssertTrue(false, "String value conversion fails. Value is null")
        }

        predicate = MIOPredicateWithFormat(format: "value = \"string\"") as! MIOComparisonPredicate
        if let v = predicate.rightExpression.constantValue as? String {
            XCTAssertTrue( v == "string", "String value conversion fails. Value is wrong: \(v)")
        }
        else {
            XCTAssertTrue(false, "String value conversion fails. Value is null")
        }
        
        predicate = MIOPredicateWithFormat(format: "value = nil") as! MIOComparisonPredicate
        XCTAssertTrue( predicate.rightExpression.constantValue == nil, "Null value conversion fails. Value is wrong: \(String(describing: predicate.rightExpression.constantValue))")

        predicate = MIOPredicateWithFormat(format: "value = null") as! MIOComparisonPredicate
        XCTAssertTrue( predicate.rightExpression.constantValue == nil, "Null value conversion fails. Value is wrong: \(String(describing: predicate.rightExpression.constantValue))")

    }
    
    func testCompoundPredicate() {
        var predicate = MIOPredicateWithFormat(format: "available = true and value > 1")
        XCTAssertTrue( (predicate as? MIOCompoundPredicate) != nil, "MIOPredicate is not MIOCompoundPredicate subtype" )

        predicate = MIOPredicateWithFormat(format: "available = true or value > 1")
        XCTAssertTrue( (predicate as? MIOCompoundPredicate) != nil, "MIOPredicate is not MIOCompoundPredicate subtype" )
        
        predicate = MIOPredicateWithFormat(format: "not available = true")
        XCTAssertTrue( (predicate as? MIOCompoundPredicate) != nil, "MIOPredicate is not MIOCompoundPredicate subtype" )
    }
    
    func testCompoundPredicateAND() {
        let predicate = MIOPredicateWithFormat(format: "available = true and value > 1") as! MIOCompoundPredicate
        XCTAssertTrue(predicate.compoundPredicateType == .and, "MIOCompoundPredicate is not the right type: \(predicate.compoundPredicateType)")
        
        // Checking first subpredicate
        guard let subpredicate1 = predicate.subpredicates[0] as? MIOComparisonPredicate else {
            XCTAssertTrue(false, "First subpredicate is not MIOComparisonPredicate subtype")
            return
        }
                
        XCTAssertTrue(subpredicate1.leftExpression.expressionType == .keyPath)
        XCTAssertTrue(subpredicate1.leftExpression.keyPath == "available")
        
        XCTAssertTrue(subpredicate1.predicateOperatorType == .equalTo)
        
        XCTAssertTrue(subpredicate1.rightExpression.expressionType == .constantValue)
        var v = subpredicate1.rightExpression.constantValue as? Int
        XCTAssertTrue(v != nil && v! == 1)

        // Checking second subpredicate
        guard let subpredicate2 = predicate.subpredicates[1] as? MIOComparisonPredicate else {
            XCTAssertTrue(false, "Second subpredicate is not MIOComparisonPredicate subtype")
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
        let predicate = MIOPredicateWithFormat(format: "available = true or value > 1") as! MIOCompoundPredicate
        XCTAssertTrue(predicate.compoundPredicateType == .or, "MIOCompoundPredicate is not the right type: \(predicate.compoundPredicateType)")
        
        // Checking first subpredicate
        guard let subpredicate1 = predicate.subpredicates[0] as? MIOComparisonPredicate else {
            XCTAssertTrue(false, "First subpredicate is not MIOComparisonPredicate subtype")
            return
        }
                
        XCTAssertTrue(subpredicate1.leftExpression.expressionType == .keyPath)
        XCTAssertTrue(subpredicate1.leftExpression.keyPath == "available")
        
        XCTAssertTrue(subpredicate1.predicateOperatorType == .equalTo)
        
        XCTAssertTrue(subpredicate1.rightExpression.expressionType == .constantValue)
        var v = subpredicate1.rightExpression.constantValue as? Int
        XCTAssertTrue(v != nil && v! == 1)

        // Checking second subpredicate
        guard let subpredicate2 = predicate.subpredicates[1] as? MIOComparisonPredicate else {
            XCTAssertTrue(false, "Second subpredicate is not MIOComparisonPredicate subtype")
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
        let predicate = MIOPredicateWithFormat(format: "not available = true") as! MIOCompoundPredicate
        XCTAssertTrue(predicate.compoundPredicateType == .not, "MIOCompoundPredicate is not the right type: \(predicate.compoundPredicateType)")
        
        // Checking subpredicate
        guard let subpredicate = predicate.subpredicates[0] as? MIOComparisonPredicate else {
            XCTAssertTrue(false, "Subpredicate is not MIOComparisonPredicate subtype")
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
        let predicate = MIOPredicateWithFormat(format: "available = true or value >= 1 and value <= 10.5") as! MIOCompoundPredicate
        XCTAssertTrue(predicate.compoundPredicateType == .or, "MIOCompoundPredicate is not the right type: \(predicate.compoundPredicateType)")
        
        // Checking subpredicate 1
        guard let subpredicate1 = predicate.subpredicates[0] as? MIOComparisonPredicate else {
            XCTAssertTrue(false, "Subpredicate is not MIOComparisonPredicate subtype")
            return
        }
        
        XCTAssertTrue(subpredicate1.leftExpression.expressionType == .keyPath)
        XCTAssertTrue(subpredicate1.leftExpression.keyPath == "available")
        
        XCTAssertTrue(subpredicate1.predicateOperatorType == .equalTo)
        
        XCTAssertTrue(subpredicate1.rightExpression.expressionType == .constantValue)
        var iv = subpredicate1.rightExpression.constantValue as? Int
        XCTAssertTrue(iv != nil && iv! == 1)
                
        // Checking subpredicate 2
        guard let subpredicate2 = predicate.subpredicates[1] as? MIOCompoundPredicate else {
            XCTAssertTrue(false, "Subpredicate is not MIOCompoundPredicate subtype")
            return
        }
        XCTAssertTrue(subpredicate2.compoundPredicateType == .and, "MIOCompoundPredicate is not the right type: \(predicate.compoundPredicateType)")
        
        // Checking subpredicate 2.1
        guard let subpredicate2_1 = subpredicate2.subpredicates[0] as? MIOComparisonPredicate else {
            XCTAssertTrue(false, "Subpredicate is not MIOComparisonPredicate subtype")
            return
        }
        
        XCTAssertTrue(subpredicate2_1.leftExpression.expressionType == .keyPath)
        XCTAssertTrue(subpredicate2_1.leftExpression.keyPath == "value")

        XCTAssertTrue(subpredicate2_1.predicateOperatorType == .greaterThanOrEqualTo)

        XCTAssertTrue(subpredicate2_1.rightExpression.expressionType == .constantValue)
        iv = subpredicate2_1.rightExpression.constantValue as? Int
        XCTAssertTrue(iv != nil && iv == 1)

        // Checking subpredicate 2.2
        guard let subpredicate2_2 = subpredicate2.subpredicates[1] as? MIOComparisonPredicate else {
            XCTAssertTrue(false, "Subpredicate is not MIOComparisonPredicate subtype")
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
        let predicate = MIOPredicateWithFormat(format: "not available = true or value >= 1 and value <= 10.5") as! MIOCompoundPredicate
        XCTAssertTrue(predicate.compoundPredicateType == .or, "MIOCompoundPredicate is not the right type: \(predicate.compoundPredicateType)")
        
        // Checking subpredicate 1
        guard let subpredicate1 = predicate.subpredicates[0] as? MIOCompoundPredicate else {
            XCTAssertTrue(false, "Subpredicate 1 is not MIOCompoundPredicate subtype")
            return
        }
        
        XCTAssertTrue(subpredicate1.compoundPredicateType == .not, "MIOCompoundPredicate is not the right type: \(subpredicate1.compoundPredicateType)")
        guard let subpredicate1_1 = subpredicate1.subpredicates[0] as? MIOComparisonPredicate else {
            XCTAssertTrue(false, "Subpredicate 1.1 is not MIOComparisonPredicate subtype")
            return
        }
        XCTAssertTrue(subpredicate1_1.leftExpression.expressionType == .keyPath)
        XCTAssertTrue(subpredicate1_1.leftExpression.keyPath == "available")
        XCTAssertTrue(subpredicate1_1.predicateOperatorType == .equalTo)
        XCTAssertTrue(subpredicate1_1.rightExpression.expressionType == .constantValue)
        var iv = subpredicate1_1.rightExpression.constantValue as? Int
        XCTAssertTrue(iv != nil && iv! == 1)


        // Checking subpredicate 2
        guard let subpredicate2 = predicate.subpredicates[1] as? MIOCompoundPredicate else {
            XCTAssertTrue(false, "Subpredicate 2 is not MIOCompoundPredicate subtype")
            return
        }
        
        XCTAssertTrue(subpredicate2.compoundPredicateType == .and, "MIOCompoundPredicate is not the right type: \(subpredicate2.compoundPredicateType)")
        guard let subpredicate2_1 = subpredicate2.subpredicates[0] as? MIOComparisonPredicate else {
            XCTAssertTrue(false, "Subpredicate 2.2 is not MIOComparisonPredicate subtype")
            return
        }
        
        XCTAssertTrue(subpredicate2_1.leftExpression.expressionType == .keyPath)
        XCTAssertTrue(subpredicate2_1.leftExpression.keyPath == "value")

        XCTAssertTrue(subpredicate2_1.predicateOperatorType == .greaterThanOrEqualTo)

        XCTAssertTrue(subpredicate2_1.rightExpression.expressionType == .constantValue)
        iv = subpredicate2_1.rightExpression.constantValue as? Int
        XCTAssertTrue(iv != nil && iv == 1)

        // Checking subpredicate 2.2
        guard let subpredicate2_2 = subpredicate2.subpredicates[1] as? MIOComparisonPredicate else {
            XCTAssertTrue(false, "Subpredicate 2.2 is not MIOComparisonPredicate subtype")
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
        let predicate = MIOPredicateWithFormat(format: "available = true or (value >= 1 and value <= 10.5)") as! MIOCompoundPredicate
        XCTAssertTrue(predicate.compoundPredicateType == .or, "MIOCompoundPredicate is not the right type: \(predicate.compoundPredicateType)")
        
        // Checking subpredicate 1
        guard let subpredicate1 = predicate.subpredicates[0] as? MIOComparisonPredicate else {
            XCTAssertTrue(false, "Subpredicate is not MIOComparisonPredicate subtype")
            return
        }
        
        XCTAssertTrue(subpredicate1.leftExpression.expressionType == .keyPath)
        XCTAssertTrue(subpredicate1.leftExpression.keyPath == "available")
        
        XCTAssertTrue(subpredicate1.predicateOperatorType == .equalTo)
        
        XCTAssertTrue(subpredicate1.rightExpression.expressionType == .constantValue)
        var iv = subpredicate1.rightExpression.constantValue as? Int
        XCTAssertTrue(iv != nil && iv! == 1)

        // Checking subpredicate 2
        guard let subpredicate2 = predicate.subpredicates[1] as? MIOCompoundPredicate else {
            XCTAssertTrue(false, "Subpredicate is not MIOCompoundPredicate subtype")
            return
        }
        XCTAssertTrue(subpredicate2.compoundPredicateType == .and, "MIOCompoundPredicate is not the right type: \(predicate.compoundPredicateType)")
        
        // Checking subpredicate 2.1
        guard let subpredicate2_1 = subpredicate2.subpredicates[0] as? MIOComparisonPredicate else {
            XCTAssertTrue(false, "Subpredicate is not MIOComparisonPredicate subtype")
            return
        }
        
        XCTAssertTrue(subpredicate2_1.leftExpression.expressionType == .keyPath)
        XCTAssertTrue(subpredicate2_1.leftExpression.keyPath == "value")

        XCTAssertTrue(subpredicate2_1.predicateOperatorType == .greaterThanOrEqualTo)

        XCTAssertTrue(subpredicate2_1.rightExpression.expressionType == .constantValue)
        iv = subpredicate2_1.rightExpression.constantValue as? Int
        XCTAssertTrue(iv != nil && iv == 1)

        // Checking subpredicate 2.2
        guard let subpredicate2_2 = subpredicate2.subpredicates[1] as? MIOComparisonPredicate else {
            XCTAssertTrue(false, "Subpredicate is not MIOComparisonPredicate subtype")
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
