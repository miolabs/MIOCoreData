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
        XCTAssertTrue( predicate.predicateOperatorType == MIOComparisonPredicate.Operator.equalTo, "MIOComparisonPredicate operator type is not 'equalTo'" )
        
        predicate = MIOPredicateWithFormat(format: "value = 0") as! MIOComparisonPredicate
        XCTAssertTrue( predicate.predicateOperatorType == MIOComparisonPredicate.Operator.equalTo, "MIOComparisonPredicate operator type is not 'equalTo'" )
        
        predicate = MIOPredicateWithFormat(format: "value > 1") as! MIOComparisonPredicate
        XCTAssertTrue( predicate.predicateOperatorType == MIOComparisonPredicate.Operator.greaterThan, "MIOComparisonPredicate operator type is not 'greaterThan'" )
        
        predicate = MIOPredicateWithFormat(format: "value < 1") as! MIOComparisonPredicate
        XCTAssertTrue( predicate.predicateOperatorType == MIOComparisonPredicate.Operator.lessThan, "MIOComparisonPredicate operator type is not 'lessThan'" )

        predicate = MIOPredicateWithFormat(format: "value >= 1") as! MIOComparisonPredicate
        XCTAssertTrue( predicate.predicateOperatorType == MIOComparisonPredicate.Operator.greaterThanOrEqualTo, "MIOComparisonPredicate operator type is not 'greaterThanOrEqualTo'" )

        predicate = MIOPredicateWithFormat(format: "value <= 1") as! MIOComparisonPredicate
        XCTAssertTrue( predicate.predicateOperatorType == MIOComparisonPredicate.Operator.lessThanOrEqualTo, "MIOComparisonPredicate operator type is not 'lessThanOrEqualTo'" )
        
        predicate = MIOPredicateWithFormat(format: "value != 1") as! MIOComparisonPredicate
        XCTAssertTrue( predicate.predicateOperatorType == MIOComparisonPredicate.Operator.notEqualTo, "MIOComparisonPredicate operator type is not 'notEqualTo'" )

        predicate = MIOPredicateWithFormat(format: "value contains 'v'") as! MIOComparisonPredicate
        XCTAssertTrue( predicate.predicateOperatorType == MIOComparisonPredicate.Operator.contains, "MIOComparisonPredicate operator type is not 'contains'" )
        
        let array = ["1", "2"]
        predicate = MIOPredicateWithFormat(format: "value in %@", array) as! MIOComparisonPredicate
        XCTAssertTrue( predicate.predicateOperatorType == MIOComparisonPredicate.Operator.in, "NSComparisionPredicate operator type is not 'in'" )
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
        
        let array = ["1", "2"]
        predicate = MIOPredicateWithFormat(format: "value in %@", array) as! MIOComparisonPredicate
        if let v = predicate.rightExpression.constantValue as? [String] {
            XCTAssertTrue( true, "String value conversion fails. Value is wrong: \(v)")
        }
        else {
            XCTAssertTrue(false, "String value conversion fails. Value is null")
        }

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
        XCTAssertTrue((subpredicate1_1.rightExpression.constantValue as? Int ) == 1)


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
        XCTAssertTrue((subpredicate2_1.rightExpression.constantValue as? Int ) == 1)
        

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
    
    func testSimpleGroupPredicate() {
        let predicate = MIOPredicateWithFormat(format: "(available = 1)")
        XCTAssertTrue( predicate is MIOComparisonPredicate, "Predicate is not MIOComparisionPredicate type")
        
        let cmpPredicate = predicate as! MIOComparisonPredicate
        XCTAssertTrue( cmpPredicate.predicateOperatorType == MIOComparisonPredicate.Operator.equalTo, "MIOComparisionPredicate operator type is not EqualThan" )

        XCTAssertTrue( cmpPredicate.leftExpression.expressionType == MIOExpression.ExpressionType.keyPath, "MIOComparisionPredicate right expression is not KeyPath type" )
        XCTAssertTrue( cmpPredicate.leftExpression.keyPath == "available", "MIOComparisionPredicate left expression keypath value is wrong" )
        
        XCTAssertTrue( cmpPredicate.rightExpression.expressionType == MIOExpression.ExpressionType.constantValue, "NSComparisionPredicate right expression is not ConstantValue type" )
        guard let value = cmpPredicate.rightExpression.constantValue as? Int else {
            XCTAssertTrue(false, "MIOComparisionPredicate rigth expression constant value cast type is wrong")
            return
        }
        
        XCTAssertTrue( value == 1, "NSComparisionPredicate rigth expression constant value is wrong" )
    }
    
    func testBitwiseANDFunction() {
        
        let predicate = MIOPredicateWithFormat(format: "(key & 1) > 0")
        XCTAssertTrue( predicate is MIOComparisonPredicate, "Predicate is not NSComparisionPredicate type")
        
        let cmpPredicate = predicate as! MIOComparisonPredicate
        XCTAssertTrue( cmpPredicate.predicateOperatorType == MIOComparisonPredicate.Operator.greaterThan, "NSComparisionPredicate operator type is not GreaterThan" )
        
        XCTAssertTrue( cmpPredicate.leftExpression.expressionType == MIOExpression.ExpressionType.function, "NSComparisionPredicate left expression is not Function type" )
        XCTAssertTrue( cmpPredicate.leftExpression.function == "bitwiseAnd:with:", "NSComparisionPredicate left expression function is not 'bitwiseAnd:with:'" )
        guard let arguments = cmpPredicate.leftExpression.arguments else {
            XCTAssertTrue( false, "NSComparisionPredicate left expression arguments are null")
            return
        }

        if arguments.count != 2 {
            XCTAssertTrue( false, "NSComparisionPredicate left expression arguments are wrong" )
            return
        }

        XCTAssertTrue( arguments[0].keyPath == "key", "NSComparisionPredicate left expression arguments[0] has not the right value: 'key'" )
        XCTAssertTrue( (arguments[1].constantValue as! Int) == 1, "NSComparisionPredicate left expression arguments[1] has not the right value: '1'" )

        XCTAssertTrue( cmpPredicate.rightExpression.expressionType == MIOExpression.ExpressionType.constantValue, "NSComparisionPredicate right expression is not ConstantValue type" )
        guard let value = cmpPredicate.rightExpression.constantValue as? Int else {
            XCTAssertTrue(false, "NSComparisionPredicate rigth expression constant value cast type is wrong")
            return
        }
        
        XCTAssertTrue( value == 0, "NSComparisionPredicate rigth expression constant value is wrong" )
    }
    
    func testBitwiseORFunction() {
        
        let predicate = MIOPredicateWithFormat(format: "(key | 1) > 0")
        XCTAssertTrue( predicate is MIOComparisonPredicate, "Predicate is not NSComparisionPredicate type")
        
        let cmpPredicate = predicate as! MIOComparisonPredicate
        XCTAssertTrue( cmpPredicate.predicateOperatorType == MIOComparisonPredicate.Operator.greaterThan, "NSComparisionPredicate operator type is not GreaterThan" )
        
        XCTAssertTrue( cmpPredicate.leftExpression.expressionType == MIOExpression.ExpressionType.function, "NSComparisionPredicate left expression is not Function type" )
        XCTAssertTrue( cmpPredicate.leftExpression.function == "bitwiseOr:with:", "NSComparisionPredicate left expression function is not 'bitwiseOr:with:'" )
        guard let arguments = cmpPredicate.leftExpression.arguments else {
            XCTAssertTrue( false, "NSComparisionPredicate left expression arguments are null")
            return
        }

        if arguments.count != 2 {
            XCTAssertTrue( false, "NSComparisionPredicate left expression arguments are wrong" )
            return
        }

        XCTAssertTrue( arguments[0].keyPath == "key", "NSComparisionPredicate left expression arguments[0] has not the right value: 'key'" )
        XCTAssertTrue( (arguments[1].constantValue as! Int) == 1, "NSComparisionPredicate left expression arguments[1] has not the right value: '1'" )

        XCTAssertTrue( cmpPredicate.rightExpression.expressionType == MIOExpression.ExpressionType.constantValue, "NSComparisionPredicate right expression is not ConstantValue type" )
        guard let value = cmpPredicate.rightExpression.constantValue as? Int else {
            XCTAssertTrue(false, "NSComparisionPredicate rigth expression constant value cast type is wrong")
            return
        }
        
        XCTAssertTrue( value == 0, "NSComparisionPredicate rigth expression constant value is wrong" )
    }
        
    func testBitwiseXORFunction() {
        
        let predicate = MIOPredicateWithFormat(format: "(key ^ 1) > 0")
        XCTAssertTrue( predicate is MIOComparisonPredicate, "Predicate is not NSComparisionPredicate type")
        
        let cmpPredicate = predicate as! MIOComparisonPredicate
        XCTAssertTrue( cmpPredicate.predicateOperatorType == MIOComparisonPredicate.Operator.greaterThan, "NSComparisionPredicate operator type is not GreaterThan" )
        
        XCTAssertTrue( cmpPredicate.leftExpression.expressionType == MIOExpression.ExpressionType.function, "NSComparisionPredicate left expression is not Function type" )
        XCTAssertTrue( cmpPredicate.leftExpression.function == "bitwiseXor:with:", "NSComparisionPredicate left expression function is not 'bitwiseXor:with:'" )
        guard let arguments = cmpPredicate.leftExpression.arguments else {
            XCTAssertTrue( false, "NSComparisionPredicate left expression arguments are null")
            return
        }

        if arguments.count != 2 {
            XCTAssertTrue( false, "NSComparisionPredicate left expression arguments are wrong" )
            return
        }

        XCTAssertTrue( arguments[0].keyPath == "key", "NSComparisionPredicate left expression arguments[0] has not the right value: 'key'" )
        XCTAssertTrue( (arguments[1].constantValue as! Int) == 1, "NSComparisionPredicate left expression arguments[1] has not the right value: '1'" )

        XCTAssertTrue( cmpPredicate.rightExpression.expressionType == MIOExpression.ExpressionType.constantValue, "NSComparisionPredicate right expression is not ConstantValue type" )
        guard let value = cmpPredicate.rightExpression.constantValue as? Int else {
            XCTAssertTrue(false, "NSComparisionPredicate rigth expression constant value cast type is wrong")
            return
        }
        
        XCTAssertTrue( value == 0, "NSComparisionPredicate rigth expression constant value is wrong" )
    }
    
    func testComplexWithKeyPathPredicate() {
        let predicate = MIOPredicateWithFormat(format: "cashDesk.identifier = \'3CEF7AEA-11C2-48AB-B289-C3C02E6A38A6\' and isOpen = true and deletedAt = null and beginDate <= \'2021-05-25 23:11:32.050000\' and (endDate = null or endDate >= \'2021-05-25 23:11:32.050000\')")
        
        guard let cp = predicate as? MIOCompoundPredicate else {
            XCTAssertTrue( false, "NSPredicate is not MIOCompoundPredicate subtype" )
            return
        }
        
        XCTAssertTrue( cp.compoundPredicateType == .and, "Expected MIOCompoundPredicate type: AND")
        XCTAssertTrue( cp.subpredicates.count == 5, "Number of subpredcated must be equal to 5")
        
        // First predicate
        guard let sp1 = cp.subpredicates[0] as? MIOComparisonPredicate else {
            XCTAssertTrue( false, "Subpredicate 0 is not MIOCompoundPredicate subtype" )
            return
        }
        
        XCTAssertTrue(sp1.leftExpression.expressionType == .keyPath, "Expected left expression of keyPath type")
        XCTAssertTrue(sp1.leftExpression.keyPath == "cashDesk.identifier", "Expected left expression keyPath value: cashDesk.identifier")
        XCTAssertTrue(sp1.predicateOperatorType == .equalTo, "Expected left expression operator: equalTo")
        XCTAssertTrue(sp1.rightExpression.expressionType == .constantValue, "Expected right expression of constantValue type")
        XCTAssertTrue((sp1.rightExpression.constantValue as? String) == "3CEF7AEA-11C2-48AB-B289-C3C02E6A38A6", "Expected right expression value: 3CEF7AEA-11C2-48AB-B289-C3C02E6A38A6")

        
        // Second predicate
        guard let sp2 = cp.subpredicates[1] as? MIOComparisonPredicate else {
            XCTAssertTrue( false, "Subpredicate 1 is not MIOCompoundPredicate subtype" )
            return
        }
        
        XCTAssertTrue(sp2.leftExpression.expressionType == .keyPath, "Expected left expression of keyPath type")
        XCTAssertTrue(sp2.leftExpression.keyPath == "isOpen", "Expected left expression keyPath value: isOpen")
        XCTAssertTrue(sp2.predicateOperatorType == .equalTo, "Expected left expression operator: equalTo")
        XCTAssertTrue(sp2.rightExpression.expressionType == .constantValue, "Expected right expression of constantValue type")
        XCTAssertTrue((sp2.rightExpression.constantValue as? Int) == 1, "Expected right expression value: 1")

        
        // Third predicate
        guard let sp3 = cp.subpredicates[2] as? MIOComparisonPredicate else {
            XCTAssertTrue( false, "Subpredicate 2 is not MIOCompoundPredicate subtype" )
            return
        }
        
        XCTAssertTrue(sp3.leftExpression.expressionType == .keyPath, "Expected left expression of keyPath type")
        XCTAssertTrue(sp3.leftExpression.keyPath == "deletedAt", "Expected left expression keyPath value: deletedAt")
        XCTAssertTrue(sp3.predicateOperatorType == .equalTo, "Expected left expression operator: equalTo")
        XCTAssertTrue(sp3.rightExpression.expressionType == .constantValue, "Expected right expression of constantValue type")
        XCTAssertTrue(sp3.rightExpression.constantValue == nil, "Expected right expression value: nil")

        
        // Forth predicate
        guard let sp4 = cp.subpredicates[3] as? MIOComparisonPredicate else {
            XCTAssertTrue( false, "Subpredicate 3 is not MIOCompoundPredicate subtype" )
            return
        }
        
        XCTAssertTrue(sp4.leftExpression.expressionType == .keyPath, "Expected left expression of keyPath type")
        XCTAssertTrue(sp4.leftExpression.keyPath == "beginDate", "Expected left expression keyPath value: beginDate")
        XCTAssertTrue(sp4.predicateOperatorType == .lessThanOrEqualTo, "Expected left expression operator: lessThanOrEqualTo")
        XCTAssertTrue(sp4.rightExpression.expressionType == .constantValue, "Expected right expression of constantValue type")
        XCTAssertTrue((sp4.rightExpression.constantValue as? String) == "2021-05-25 23:11:32.050000", "Expected right expression value: 2021-05-25 23:11:32.050000")


        // Fith predicate
        guard let sp5 = cp.subpredicates[4] as? MIOCompoundPredicate else {
            XCTAssertTrue( false, "Subpredicate 4 is MIOCompoundPredicate subtype" )
            return
        }
        
        XCTAssertTrue( sp5.compoundPredicateType == .or, "Expected MIOCompoundPredicate type: OR")
        XCTAssertTrue( sp5.subpredicates.count == 2, "Number of subpredcated must be equal to 2")
        
        guard let sp5_sp1 = sp5.subpredicates[0] as? MIOComparisonPredicate else {
            XCTAssertTrue( false, "Subpredicate 0 is not MIOCompoundPredicate subtype" )
            return
        }
        
        XCTAssertTrue(sp5_sp1.leftExpression.expressionType == .keyPath, "Expected left expression of keyPath type")
        XCTAssertTrue(sp5_sp1.leftExpression.keyPath == "endDate", "Expected left expression keyPath value: endDate")
        XCTAssertTrue(sp5_sp1.predicateOperatorType == .equalTo, "Expected left expression operator: equalTo")
        XCTAssertTrue(sp5_sp1.rightExpression.expressionType == .constantValue, "Expected right expression of constantValue type")
        XCTAssertTrue(sp5_sp1.rightExpression.constantValue == nil, "Expected right expression value: nil")

        
        guard let sp5_sp2 = sp5.subpredicates[1] as? MIOComparisonPredicate else {
            XCTAssertTrue( false, "Subpredicate 1 is not MIOCompoundPredicate subtype" )
            return
        }
        
        XCTAssertTrue(sp5_sp2.leftExpression.expressionType == .keyPath, "Expected left expression of keyPath type")
        XCTAssertTrue(sp5_sp2.leftExpression.keyPath == "endDate", "Expected left expression keyPath value: endDate")
        XCTAssertTrue(sp5_sp2.predicateOperatorType == .greaterThanOrEqualTo, "Expected left expression operator: greaterThanOrEqualTo")
        XCTAssertTrue(sp5_sp2.rightExpression.expressionType == .constantValue, "Expected right expression of constantValue type")
        XCTAssertTrue((sp5_sp2.rightExpression.constantValue as? String) == "2021-05-25 23:11:32.050000", "Expected right expression value: 2021-05-25 23:11:32.050000")

    }

}
