//
//  File.swift
//  
//
//  Created by Javier Segura Perez on 01/06/2020.
//

import Foundation
import MIOCore

public typealias NSExpression = MIOExpression
public typealias NSComparisonPredicate = MIOComparisonPredicate
public typealias NSPredicate = MIOPredicate
public typealias NSCompoundPredicate = MIOCompoundPredicate

open class MIOPredicate: NSObject, NSCopying
{
    public func copy(with zone: NSZone? = nil) -> Any {
        let obj = MIOPredicate()
        return obj
    }
    
    //override init() {}
    
    //    public init(format predicateFormat: String, argumentArray arguments: [Any]?) {
    //        super.init()
    //        parse(predicateFormat, arguments: arguments)
    //    }
    //
    //    public init(format predicateFormat: String, arguments argList: CVaListPointer) {
    //        super.init()
    //        parse(predicateFormat, arguments: nil)
    //    }
    
        
    /*
     private booleanFromString(value:string){
     
     let v = value.toLocaleLowerCase();
     let bv = false;
     
     switch (v) {
     
     case "yes":
     case "true":
     bv = true;
     break;
     
     case "no":
     case "false":
     bv = false;
     break;
     
     default:
     throw new Error(`MIOPredicate: Error. Can't convert '${value}' to boolean`);
     }
     
     return bv;
     }
     
     private nullFromString(value:string){
     
     let v = value.toLocaleLowerCase();
     let nv = null;
     
     switch (v) {
     
     case "nil":
     case "null":
     nv = null;
     break;
     
     default:
     throw new Error(`MIOPredicate: Error. Can't convert '${value}' to null`);
     }
     
     return nv;
     }*/
    
    
}

/*
 extension NSPredicate {
 
 public convenience init(format predicateFormat: String, _ args: CVarArg...) {
 //let array = getVaList(args)
 self.init(format:predicateFormat, argumentArray:nil)
 //object_setClass(self, MIOComparisonPredicate.self)
 
 }
 
 }
 */

public func MIOPredicateWithFormat(format: String, _ args: CVarArg...) -> MIOPredicate
{
    let lexer = MIOPredicateTokenize(format)
    let predicate = MIOPredicateParseTokens(lexer: lexer)
    
    return predicate
}

public enum MIOPredicateTokenType: Int
{
    case identifier
    
    case uuidValue
    case stringValue
    case numberValue
    case booleanValue
    case nullValue
    case propertyValue
    
    case minorOrEqualComparator
    case minorComparator
    case majorOrEqualComparator
    case majorComparator
    case equalComparator
    case distinctComparator
    case containsComparator
    case inComparator
    case notIntComparator
    
    case bitwiseAND
    case bitwiseOR
    
    case plusOperation
    case minusOperation
    case multiplyOperation
    case divisionOperation
    
    case arraySymbol
    case openParenthesisSymbol
    case closeParenthesisSymbol
    case whitespace
    
    case and
    case or
    case not
    
    case any
    case all
    
    case classValue
}

func MIOPredicateTokenize(_ predicateFormat: String) -> MIOCoreLexer
{
    let lexer = MIOCoreLexer(withString: predicateFormat)
    
    // Values
    lexer.addTokenType(MIOPredicateTokenType.uuidValue.rawValue, regex: try! NSRegularExpression(pattern: "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}", options:.caseInsensitive))
    lexer.addTokenType(MIOPredicateTokenType.stringValue.rawValue, regex: try! NSRegularExpression(pattern: "^\"([^\"]*)\"|^'([^']*)'"))
    lexer.addTokenType(MIOPredicateTokenType.numberValue.rawValue, regex: try! NSRegularExpression(pattern:"^-?\\d+(?:\\.\\d+)?(?:e[+\\-]?\\d+)?", options:.caseInsensitive))
    lexer.addTokenType(MIOPredicateTokenType.booleanValue.rawValue, regex: try! NSRegularExpression(pattern:"^(true|false)", options:.caseInsensitive))
    lexer.addTokenType(MIOPredicateTokenType.nullValue.rawValue, regex: try! NSRegularExpression(pattern:"^(null|nil)", options:.caseInsensitive))
    
    // Symbols
    lexer.addTokenType(MIOPredicateTokenType.arraySymbol.rawValue, regex: try! NSRegularExpression(pattern: "^\\[([^\\]]*)\\]"))
    lexer.addTokenType(MIOPredicateTokenType.openParenthesisSymbol.rawValue, regex: try! NSRegularExpression(pattern:"^\\("))
    lexer.ignoreTokenType(MIOPredicateTokenType.openParenthesisSymbol.rawValue)
    lexer.addTokenType(MIOPredicateTokenType.closeParenthesisSymbol.rawValue, regex: try! NSRegularExpression(pattern:"^\\)"))
    lexer.ignoreTokenType(MIOPredicateTokenType.closeParenthesisSymbol.rawValue)
    
    // Comparators
    lexer.addTokenType(MIOPredicateTokenType.minorOrEqualComparator.rawValue, regex: try! NSRegularExpression(pattern:"^<="))
    lexer.addTokenType(MIOPredicateTokenType.minorComparator.rawValue, regex: try! NSRegularExpression(pattern:"^<"))
    lexer.addTokenType(MIOPredicateTokenType.majorOrEqualComparator.rawValue, regex: try! NSRegularExpression(pattern:"^>="))
    lexer.addTokenType(MIOPredicateTokenType.majorComparator.rawValue, regex: try! NSRegularExpression(pattern:"^>"))
    lexer.addTokenType(MIOPredicateTokenType.equalComparator.rawValue, regex: try! NSRegularExpression(pattern:"^==?"))
    lexer.addTokenType(MIOPredicateTokenType.distinctComparator.rawValue, regex: try! NSRegularExpression(pattern:"^!="))
    lexer.addTokenType(MIOPredicateTokenType.containsComparator.rawValue, regex: try! NSRegularExpression(pattern:"^contains ", options: .caseInsensitive))
    lexer.addTokenType(MIOPredicateTokenType.inComparator.rawValue, regex: try! NSRegularExpression(pattern:"^in ", options:.caseInsensitive))
    
    // Bitwise operators
    lexer.addTokenType(MIOPredicateTokenType.bitwiseAND.rawValue, regex: try! NSRegularExpression(pattern:"^& ", options: .caseInsensitive))
    lexer.addTokenType(MIOPredicateTokenType.bitwiseOR.rawValue, regex: try! NSRegularExpression(pattern:"^\\| ", options: .caseInsensitive))
    
    // Operations
    //this.lexer.addTokenType(MIOPredicateTokenType.MinusOperation, /^- /i);
    // Join operators
    lexer.addTokenType(MIOPredicateTokenType.and.rawValue, regex: try! NSRegularExpression(pattern:"^(and|&&) ", options: .caseInsensitive))
    lexer.addTokenType(MIOPredicateTokenType.or.rawValue, regex: try! NSRegularExpression(pattern:"^(or|\\|\\|) ", options: .caseInsensitive))
    lexer.addTokenType(MIOPredicateTokenType.not.rawValue, regex: try! NSRegularExpression(pattern:"^not ", options: .caseInsensitive))
//    // Relationship operators
    lexer.addTokenType(MIOPredicateTokenType.any.rawValue, regex: try! NSRegularExpression(pattern:"^any ", options: .caseInsensitive))
    lexer.addTokenType(MIOPredicateTokenType.all.rawValue, regex: try! NSRegularExpression(pattern:"^all ", options: .caseInsensitive))
    // Extra
    lexer.addTokenType(MIOPredicateTokenType.whitespace.rawValue, regex: try! NSRegularExpression(pattern:"^\\s+", options: .caseInsensitive))
    lexer.ignoreTokenType(MIOPredicateTokenType.whitespace.rawValue)
    
    // Placeholder
    lexer.addTokenType(MIOPredicateTokenType.classValue.rawValue, regex: try! NSRegularExpression(pattern:"^%@", options: .caseInsensitive))
    
    // Identifiers - Has to be the last one
    lexer.addTokenType(MIOPredicateTokenType.identifier.rawValue, regex: try! NSRegularExpression(pattern:"^[a-zA-Z_][a-zA-Z0-9-_\\.]*"))
    
    lexer.tokenize()
    
    return lexer
}

func MIOPredicateParseTokens(lexer: MIOCoreLexer) -> MIOPredicate
{
    var token = lexer.nextToken()
    var exit = false
    
    var lastPredicate:MIOPredicate?
    var currentPredicate:MIOPredicate?
    var rootPredicate:MIOPredicate?
    
    while (token != nil && exit == false) {
        
        switch (token!.type) {
        
        case MIOPredicateTokenType.identifier.rawValue:
            let leftExpression = MIOExpression(forKeyPath: token!.value)
            let op = MIOPredicateParseOperator(lexer)
            let rightExpression = MIOPredicateParseExpresion(lexer)
            let predicate = MIOComparisonPredicate(leftExpression: leftExpression, rightExpression: rightExpression, modifier: .direct, type: op, options: [])
            
            if lastPredicate != nil {
                (lastPredicate as! MIOCompoundPredicate).append(predicate: predicate)
            }
            else {
                lastPredicate = predicate
            }
            
            //predicates.append(predicate)
                    
        case MIOPredicateTokenType.and.rawValue:
            let predicate = MIOCompoundPredicate(type: .and)
            predicate.append(predicate: lastPredicate!)
                                    
            if currentPredicate != nil {
                (currentPredicate as! MIOCompoundPredicate).append(predicate: predicate)
                if rootPredicate == nil { rootPredicate = currentPredicate }
            }
            
            lastPredicate = nil
            currentPredicate = predicate
            
            
        case MIOPredicateTokenType.or.rawValue:
            currentPredicate = MIOCompoundPredicate(type: .or)
            (currentPredicate as! MIOCompoundPredicate).append(predicate: lastPredicate!)
            lastPredicate = nil

        case MIOPredicateTokenType.not.rawValue:
            lastPredicate = MIOCompoundPredicate(type: .not)
                    

        /*
         case MIOPredicateTokenType.ANY:
         this.lexer.nextToken();
         let anyPI = this.nextPredicateItem();
         anyPI.relationshipOperation = MIOPredicateRelationshipOperatorType.ANY;
         predicates.push(anyPI);
         break;
         
         case MIOPredicateTokenType.ALL:
         this.lexer.nextToken();
         let allPI = this.nextPredicateItem();
         anyPI.relationshipOperation = MIOPredicateRelationshipOperatorType.ALL;
         predicates.push(anyPI);
         break;
         
         case MIOPredicateTokenType.OpenParenthesisSymbol:
         let pg = new MIOPredicateGroup();
         pg.predicates = this.parsePredicates();
         predicates.push(pg);
         break;
         
         case MIOPredicateTokenType.CloseParenthesisSymbol:
         exit = true;
         break;*/
        
        default:
            //throw new Error(`MIOPredicate: Error. Unexpected token. (${token.value})`);
            break
        }
        
        if exit != true {
            token = lexer.nextToken()
        }
    }
    
    if currentPredicate == nil {
        return lastPredicate!
    }
    
    if lastPredicate != nil {
        (currentPredicate as! MIOCompoundPredicate).append(predicate: lastPredicate!)
    }
     
    if rootPredicate == nil {
        return currentPredicate!
    }
    
    return rootPredicate!
    
}

func MIOPredicateParseExpresion(_ lexer: MIOCoreLexer) -> NSExpression
{
    let token = lexer.nextToken()
    
    switch token!.type {
    
    case MIOPredicateTokenType.uuidValue.rawValue:
        return MIOExpression(forConstantValue: token!.value)
        
    case MIOPredicateTokenType.stringValue.rawValue:
        let v = String(token!.value.dropLast().dropFirst())
        return MIOExpression(forConstantValue: v)
    
    case MIOPredicateTokenType.numberValue.rawValue:
        if token!.value.contains(".") {
            return MIOExpression(forConstantValue: Double(token!.value))
        }
        else {
            return MIOExpression(forConstantValue: Int(token!.value))
        }
     
    case MIOPredicateTokenType.booleanValue.rawValue:
        let v = (token!.value == "true" ? true : false)
        return MIOExpression(forConstantValue: v)
        
    case MIOPredicateTokenType.arraySymbol.rawValue:
        return MIOExpression(forConstantValue: token!.value)
     
/*     case MIOPredicateTokenType.NullValue:
     item.value = this.nullFromString(token.value);
     item.valueType = MIOPredicateItemValueType.Null;
     break;
     
     case MIOPredicateTokenType.Identifier:
     item.value = token.value;
     item.valueType = MIOPredicateItemValueType.Property;
     break;
     
     case MIOPredicateTokenType.Class:
     item.value = this.nextPlaceHolderArgument();
     item.valueType = MIOPredicateItemValueType.Class;
     break;
     */
    default:
        //throw new Error(`MIOPredicate: Error. Unexpected comparator. (${token.value})`);
        break
    }
    
    //TODO: Replace by a throw error
    return NSExpression(expressionType: .anyKey)
}

func MIOPredicateParseOperator(_ lexer: MIOCoreLexer) -> NSComparisonPredicate.Operator
{
    let token = lexer.nextToken()
    
    switch token!.type {
    
    case MIOPredicateTokenType.equalComparator.rawValue:
    return NSComparisonPredicate.Operator.equalTo
    
    case MIOPredicateTokenType.majorComparator.rawValue:
    return NSComparisonPredicate.Operator.greaterThan
     
    case MIOPredicateTokenType.majorOrEqualComparator.rawValue:
    return NSComparisonPredicate.Operator.greaterThanOrEqualTo
         
    case MIOPredicateTokenType.minorComparator.rawValue:
    return NSComparisonPredicate.Operator.lessThan
     
    case MIOPredicateTokenType.minorOrEqualComparator.rawValue:
    return NSComparisonPredicate.Operator.lessThanOrEqualTo
     
    case MIOPredicateTokenType.distinctComparator.rawValue:
    return NSComparisonPredicate.Operator.notEqualTo
         
    case MIOPredicateTokenType.containsComparator.rawValue:
    return NSComparisonPredicate.Operator.contains
    
    case MIOPredicateTokenType.inComparator.rawValue:
    return NSComparisonPredicate.Operator.inOperator
    
    /*
     case MIOPredicateTokenType.BitwiseAND:
     item.bitwiseOperation = MIOPredicateBitwiseOperatorType.AND;
     item.bitwiseKey = item.key;
     item.key += " & ";
     token = this.lexer.nextToken();
     item.bitwiseValue = token.value;
     item.key += token.value;
     this.comparator(item);
     break;
     
     case MIOPredicateTokenType.BitwiseOR:
     item.bitwiseOperation = MIOPredicateBitwiseOperatorType.OR;
     item.bitwiseKey = item.key;
     item.key += " & ";
     token = this.lexer.nextToken();
     item.bitwiseValue = token.value;
     item.key += token.value;
     this.comparator(item);
     break;
     */
    default: break
        //throw new Error(`MIOPredicate: Error. Unexpected comparator. (${token.value})`);
    }
    
    return NSComparisonPredicate.Operator.equalTo
}

func MIOPredicateEvaluateObjects(_ objects: [NSManagedObject], using predicate: MIOPredicate) -> [NSManagedObject]
{
    var results:[NSManagedObject] = []
    for obj in objects {
        if MIOPredicateEvaluate(object: obj, using: predicate) {
            results.append(obj)
        }
    }

    return results
}


func MIOPredicateEvaluate(object: NSManagedObject, using predicate: MIOPredicate) -> Bool
{
    if predicate is NSComparisonPredicate {
        let cmp = predicate as! NSComparisonPredicate
        
        var obj_value:Any?
        var value:Any?
        
        if cmp.leftExpression.expressionType == .keyPath {
            obj_value = object.value(forKeyPath: cmp._leftExpression.keyPath)
//            obj_value = object.value(forKey: cmp.leftExpression.keyPath)
        }
        else if cmp.leftExpression.expressionType == .constantValue {
            value = cmp.leftExpression.constantValue
        }
        
        if cmp.rightExpression.expressionType == .keyPath {
            obj_value = object.value(forKeyPath: cmp._leftExpression.keyPath)
//            obj_value = object.value(forKey: cmp.rightExpression.keyPath)
        }
        else if cmp.rightExpression.expressionType == .constantValue {
            value = cmp.rightExpression.constantValue
        }

        if obj_value is UUID { obj_value = (obj_value as! UUID).uuidString.uppercased() }

        switch cmp.predicateOperatorType {
            case .equalTo             : return  MIOPredicateEvaluateEqual(     obj_value, value )
            case .notEqualTo          : return !MIOPredicateEvaluateEqual(     obj_value, value )
            case .lessThan            : return  MIOPredicateEvaluateLess(      obj_value, value )
            case .lessThanOrEqualTo   : return  MIOPredicateEvaluateLessEqual( obj_value, value )
            case .greaterThan         : return !MIOPredicateEvaluateLessEqual( obj_value, value )
            case .greaterThanOrEqualTo: return !MIOPredicateEvaluateLess(      obj_value, value )
            case .inOperator          : return  MIOPredicateEvaluateIn(        obj_value, value )
            default:break
        }

        return false
    } else if predicate is NSCompoundPredicate {
        let compound = predicate as! NSCompoundPredicate
        
        switch ( compound.compoundPredicateType ) {
            case .not: return !MIOPredicateEvaluate( object: object, using: compound.subpredicates[ 0 ] )
            case .and: return  MIOPredicateEvaluate( object: object, using: compound.subpredicates[ 0 ] ) && MIOPredicateEvaluate( object: object, using: compound.subpredicates[ 1 ] )
            case .or : return  MIOPredicateEvaluate( object: object, using: compound.subpredicates[ 0 ] ) || MIOPredicateEvaluate( object: object, using: compound.subpredicates[ 1 ] )
        }
    }
    
    return false
}


func MIOPredicateEvaluateEqual( _ leftValue: Any?, _ rightValue:Any?) -> Bool {

    if leftValue == nil && rightValue == nil { return true }
    if leftValue == nil && rightValue != nil { return false }
    if leftValue != nil && rightValue == nil { return false }

    // Predicate from coredata issue. Coulbe number 1 or 0
    // Check first for Int & Bool Values
    if MIOCoreIsIntValue(leftValue) && MIOCoreIsIntValue(rightValue) {
        return ( MIOCoreIntValue(leftValue) == MIOCoreIntValue(rightValue) )
    }
    
    switch leftValue! {
    case is String:  return ( leftValue as! String  ) == ( rightValue as! String  )
//    case is Bool:    return ( leftValue as! Bool    ) == ( rightValue as! Bool    )
//    case is Int:     return ( leftValue as! Int     ) == ( rightValue as! Int     )
//    case is Int8:    return ( leftValue as! Int8    ) == ( rightValue as! Int8    )
//    case is Int16:   return ( leftValue as! Int16   ) == ( rightValue as! Int16   )
//    case is Int32:   return ( leftValue as! Int32   ) == ( rightValue as! Int32   )
//    case is Int64:   return ( leftValue as! Int64   ) == ( rightValue as! Int64   )
    case is Float:   return ( leftValue as! Float   ) == ( rightValue as! Float   )
    case is Double:  return ( leftValue as! Double  ) == ( rightValue as! Double  )
    case is Decimal: return ( leftValue as! Decimal ) == ( rightValue as! Decimal )
        case is Date:    return rightValue is String ?
                                ( leftValue as! Date    ) == parse_date( rightValue as! String )!
                              : ( leftValue as! Date    ) == ( rightValue as! Date    )

    default: return false
    }
}


func MIOPredicateEvaluateLessEqual( _ leftValue: Any?, _ rightValue:Any?) -> Bool {

    if leftValue == nil && rightValue == nil { return true }
    if leftValue == nil && rightValue != nil { return false }
    if leftValue != nil && rightValue == nil { return false }

    if MIOCoreIsIntValue(leftValue) && MIOCoreIsIntValue(rightValue) {
        return ( MIOCoreIntValue(leftValue) <= MIOCoreIntValue(rightValue) )
    }

    switch leftValue! {
    case is String:  return ( leftValue as! String  ) <= ( rightValue as! String  )
//    case is Int:     return ( leftValue as! Int     ) <= ( rightValue as! Int     )
//    case is Int8:    return ( leftValue as! Int8    ) <= ( rightValue as! Int8    )
//    case is Int16:   return ( leftValue as! Int16   ) <= ( rightValue as! Int16   )
//    case is Int32:   return ( leftValue as! Int32   ) <= ( rightValue as! Int32   )
//    case is Int64:   return ( leftValue as! Int64   ) <= ( rightValue as! Int64   )
    case is Float:   return ( leftValue as! Float   ) <= ( rightValue as! Float   )
    case is Double:  return ( leftValue as! Double  ) <= ( rightValue as! Double  )
    case is Decimal: return ( leftValue as! Decimal ) <= ( rightValue as! Decimal )
    case is Date:    return rightValue is String ?
                            ( leftValue as! Date    ) <= parse_date( rightValue as! String )!
                          : ( leftValue as! Date    ) <= ( rightValue as! Date    )

    default: return false
    }
}


func MIOPredicateEvaluateLess( _ leftValue: Any?, _ rightValue:Any?) -> Bool {

    if leftValue == nil && rightValue == nil { return true }
    if leftValue == nil && rightValue != nil { return false }
    if leftValue != nil && rightValue == nil { return false }

    if MIOCoreIsIntValue(leftValue) && MIOCoreIsIntValue(rightValue) {
        return ( MIOCoreIntValue(leftValue) < MIOCoreIntValue(rightValue) )
    }
    
    switch leftValue! {
    case is String:  return ( leftValue as! String  ) < ( rightValue as! String  )
//    case is Int:     return ( leftValue as! Int     ) < ( rightValue as! Int     )
//    case is Int8:    return ( leftValue as! Int8    ) < ( rightValue as! Int8    )
//    case is Int16:   return ( leftValue as! Int16   ) < ( rightValue as! Int16   )
//    case is Int32:   return ( leftValue as! Int32   ) < ( rightValue as! Int32   )
//    case is Int64:   return ( leftValue as! Int64   ) < ( rightValue as! Int64   )
    case is Float:   return ( leftValue as! Float   ) < ( rightValue as! Float   )
    case is Double:  return ( leftValue as! Double  ) < ( rightValue as! Double  )
    case is Decimal: return ( leftValue as! Decimal ) < ( rightValue as! Decimal )
    case is Date:    return rightValue is String ?
                            ( leftValue as! Date    ) < parse_date( rightValue as! String )!
                          : ( leftValue as! Date    ) < ( rightValue as! Date    )

    default: return false
    }
}

func MIOPredicateEvaluateIn( _ leftValue: Any?, _ rightValue:Any?) -> Bool {
    if leftValue == nil && rightValue == nil { return true }
    if leftValue == nil && rightValue != nil { return false }
    if leftValue != nil && rightValue == nil { return false }

    let value = String((rightValue as! String).dropFirst().dropLast()).components(separatedBy: ",").map { String( $0.trimmingCharacters(in: .whitespaces).dropFirst().dropLast() ) }
    return value.contains(leftValue as! String)
}


