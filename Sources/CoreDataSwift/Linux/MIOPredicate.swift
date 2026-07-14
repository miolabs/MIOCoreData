//
//  MIOPredicate.swift
//  
//
//  Created by Javier Segura Perez on 01/06/2020.
//

#if !APPLE_CORE_DATA

import Foundation
import MIOCore
import MIOCoreLogger


#if canImport(CoreFoundation) && !os(WASI)
import CoreFoundation
#endif

public typealias NSExpression = MIOExpression
public typealias NSComparisonPredicate = MIOComparisonPredicate
public typealias NSPredicate = MIOPredicate
public typealias NSCompoundPredicate = MIOCompoundPredicate

enum MIOPredicateError : Error
{
    case invalidFunction(_ value:String)
    case unexpectedToken(_ value:String)
    case unexpectedEndOfFormat
    case missingArgument(_ index:Int)
    case invalidFormat(_ format:String)
}

extension MIOPredicateError: LocalizedError
{
    var errorDescription: String? {
        switch self {
        case .invalidFunction(let token): return "invalid function token found: \(token)"
        case .unexpectedToken(let token): return "unexpected token found: \(token)"
        case .unexpectedEndOfFormat: return "unexpected end of predicate format"
        case .missingArgument(let index): return "missing argument for placeholder at index \(index)"
        case .invalidFormat(let format): return "could not parse predicate format: \(format)"
        }
    }
}

open class MIOPredicate: NSObject, NSCopying
{
    public func copy(with zone: NSZone? = nil) -> Any {
        let obj = MIOPredicate()
        return obj
    }
}

public func MIOPredicateWithFormat(format: String, _ args: CVarArg...) -> MIOPredicate
{
    do {
        return try MIOPredicateParse(format: format, args: args)
    }
    catch {
        // Keep the non-throwing contract: log loudly and return a predicate that matches nothing
        Log.critical("MIOPredicateWithFormat parse error in \"\(format)\": \(error.localizedDescription). Returning a match-nothing predicate")
        return MIOPredicate()
    }
}

public func MIOPredicateWithFormat(format: String, arguments: [Any]) -> MIOPredicate
{
    do {
        return try MIOPredicateParse(format: format, args: arguments)
    }
    catch {
        Log.critical("MIOPredicateWithFormat parse error in \"\(format)\": \(error.localizedDescription). Returning a match-nothing predicate")
        return MIOPredicate()
    }
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

// NOTE: tokenization and parsing live in MIOPredicateParser.swift — a
// hand-written scanner and recursive-descent parser with a per-format token
// cache. The regex lexer that lived here was O(n^2) per parse.

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

        // ANY/ALL: evaluate the comparison per member of the to-many
        // relationship named by the first keypath component
        if cmp.comparisonPredicateModifier != .direct {
            return MIOPredicateEvaluateToMany(object: object, using: cmp)
        }

        func resolve(_ expression: MIOExpression) -> Any? {
            switch expression.expressionType {
            case .keyPath: return object.value(forKeyPath: expression.keyPath)
            case .constantValue: return expression.constantValue
            default: return nil
            }
        }

        let obj_value:Any? = resolve(cmp.leftExpression)
        let value:Any? = resolve(cmp.rightExpression)

        return MIOPredicateApplyOperator(obj_value, value, cmp.predicateOperatorType, cmp.options)
    }
    else if predicate is NSCompoundPredicate {
        let compound = predicate as! NSCompoundPredicate
        
        switch ( compound.compoundPredicateType ) {
        // TODO: Thow something when not has more than 1 predicate
        case .not: return !MIOPredicateEvaluate( object: object, using: compound.subpredicates[ 0 ] )
        case .and: return compound.subpredicates.reduce(true) { result, predicate in
                result && MIOPredicateEvaluate(object: object, using: predicate)
            }
        case .or : return compound.subpredicates.reduce(false) { result, predicate in
                result || MIOPredicateEvaluate(object: object, using: predicate)
            }
        }
    }
    
    return false
}


// One operator dispatcher shared by direct evaluation and the ANY/ALL walker
func MIOPredicateApplyOperator(_ leftValue: Any?, _ rightValue: Any?, _ op: MIOComparisonPredicate.Operator, _ options: MIOComparisonPredicate.Options) -> Bool
{
    var left = leftValue
    var right = rightValue
    if left is UUID { right = (try? MIOCoreUUIDValue( right )) ?? right }

    // Case/diacritic options apply to string-vs-string comparisons
    if options.isEmpty == false, let l = left as? String, let r = right as? String {
        left = MIOPredicateFold(l, options)
        right = MIOPredicateFold(r, options)
    }

    switch op {
        case .equalTo             : return  MIOPredicateEvaluateEqual     ( left, right )
        case .notEqualTo          : return !MIOPredicateEvaluateEqual     ( left, right )
        case .lessThan            : return  MIOPredicateEvaluateLess      ( left, right )
        case .lessThanOrEqualTo   : return  MIOPredicateEvaluateLessEqual ( left, right )
        case .greaterThan         : return !MIOPredicateEvaluateLessEqual ( left, right )
        case .greaterThanOrEqualTo: return !MIOPredicateEvaluateLess      ( left, right )
        case .in                  : return  MIOPredicateEvaluateIn        ( left, right )
        case .contains            : return  MIOPredicateEvaluateContains  ( left, right )
        case .beginsWith          : return  MIOPredicateEvaluateBeginsWith( left, right )
        case .endsWith            : return  MIOPredicateEvaluateEndsWith  ( left, right )
        case .like                : return  MIOPredicateEvaluateLike      ( left, right )
        case .matches             : return  MIOPredicateEvaluateMatches   ( left, right )
        case .between             : return  MIOPredicateEvaluateBetween   ( left, right )
    }
}

// Three-way comparison used by sort descriptors. nil ordering follows the
// production database (Postgres): ascending sorts put NULLs last, so nil
// compares as GREATER than any value — descending then puts them first,
// matching DESC NULLS FIRST. Incomparable values compare as equal.
func MIOPredicateCompareValues(_ left: Any?, _ right: Any?) -> ComparisonResult
{
    let leftIsNull = left == nil || left is NSNull
    let rightIsNull = right == nil || right is NSNull
    if leftIsNull || rightIsNull {
        if leftIsNull && rightIsNull { return .orderedSame }
        return leftIsNull ? .orderedDescending : .orderedAscending
    }

    if MIOPredicateEvaluateLess(left, right) { return .orderedAscending }
    if MIOPredicateEvaluateLess(right, left) { return .orderedDescending }
    return .orderedSame
}

func MIOPredicateFold(_ value: String, _ options: MIOComparisonPredicate.Options) -> String
{
    var result = value
    if options.contains(.caseInsensitive) { result = result.lowercased() }
    if options.contains(.diacriticInsensitive) { result = result.folding(options: .diacriticInsensitive, locale: nil) }
    return result
}

// ANY items.name == 'x' / ALL items.done == true — evaluates over the members
// of the to-many relationship named by the first keypath component. ALL over
// an empty collection is vacuously true, like Apple.
func MIOPredicateEvaluateToMany(object: NSManagedObject, using cmp: NSComparisonPredicate) -> Bool
{
    guard cmp.leftExpression.expressionType == .keyPath else { return false }

    let keyPath = cmp.leftExpression.keyPath
    let parts = keyPath.split(separator: ".", maxSplits: 1)
    let relationshipName = String(parts[0])
    let remainder = parts.count > 1 ? String(parts[1]) : nil

    guard let relationship = object.entity.relationshipsByName[relationshipName], relationship.isToMany,
          let members = object.value(forKey: relationshipName) as? Set<NSManagedObject> else {
        return false
    }

    let rightValue = cmp.rightExpression.expressionType == .constantValue ? cmp.rightExpression.constantValue : nil

    if cmp.comparisonPredicateModifier == .any {
        return members.contains { member in
            let leftValue = remainder != nil ? member.value(forKeyPath: remainder!) : member
            return MIOPredicateApplyOperator(leftValue, rightValue, cmp.predicateOperatorType, cmp.options)
        }
    }

    // .all
    return members.allSatisfy { member in
        let leftValue = remainder != nil ? member.value(forKeyPath: remainder!) : member
        return MIOPredicateApplyOperator(leftValue, rightValue, cmp.predicateOperatorType, cmp.options)
    }
}

func MIOPredicateEvaluateBeginsWith( _ leftValue: Any?, _ rightValue: Any? ) -> Bool
{
    guard let l = leftValue as? String, let r = rightValue as? String else { return false }
    return l.hasPrefix(r)
}

func MIOPredicateEvaluateEndsWith( _ leftValue: Any?, _ rightValue: Any? ) -> Bool
{
    guard let l = leftValue as? String, let r = rightValue as? String else { return false }
    return l.hasSuffix(r)
}

// LIKE: ? matches one character, * matches any run — classic iterative
// wildcard matcher, no regex involved
func MIOPredicateEvaluateLike( _ leftValue: Any?, _ rightValue: Any? ) -> Bool
{
    guard let l = leftValue as? String, let r = rightValue as? String else { return false }

    let text = Array(l)
    let pattern = Array(r)
    var t = 0, p = 0
    var starIndex = -1, starMark = 0

    while t < text.count {
        if p < pattern.count && (pattern[p] == "?" || pattern[p] == text[t]) {
            t += 1; p += 1
        }
        else if p < pattern.count && pattern[p] == "*" {
            starIndex = p; starMark = t
            p += 1
        }
        else if starIndex >= 0 {
            p = starIndex + 1
            starMark += 1
            t = starMark
        }
        else {
            return false
        }
    }
    while p < pattern.count && pattern[p] == "*" { p += 1 }
    return p == pattern.count
}

func MIOPredicateEvaluateMatches( _ leftValue: Any?, _ rightValue: Any? ) -> Bool
{
    guard let l = leftValue as? String, let r = rightValue as? String else { return false }
    #if os(WASI)
    Log.warning("MATCHES is not supported on WASI (no NSRegularExpression)")
    return false
    #else
    guard let regex = try? NSRegularExpression(pattern: r) else {
        Log.warning("MATCHES pattern is not a valid regular expression: \(r)")
        return false
    }
    let range = NSRange(l.startIndex..., in: l)
    // MATCHES is a full-string match, like Apple
    return regex.firstMatch(in: l, options: [], range: range).map { $0.range == range } ?? false
    #endif
}

func MIOPredicateEvaluateBetween( _ leftValue: Any?, _ rightValue: Any? ) -> Bool
{
    guard let bounds = rightValue as? [Any], bounds.count >= 2 else { return false }
    return MIOPredicateEvaluateLessEqual(bounds[0], leftValue) && MIOPredicateEvaluateLessEqual(leftValue, bounds[1])
}

func MIOPredicateEvaluateEqual( _ leftValue: Any?, _ rightValue:Any?) -> Bool {

    if leftValue == nil && rightValue == nil { return true }
    if leftValue == nil && rightValue != nil { return false }
    if leftValue != nil && rightValue == nil { return false }

    // Predicate from coredata issue. Could be number 1 or 0
    // Check first for Int & Bool Values
    if MIOCoreIsIntValue(leftValue) && MIOCoreIsIntValue(rightValue) {
        return ( MIOCoreInt64Value(leftValue)! == MIOCoreInt64Value(rightValue)! )
    }
    
    switch leftValue! {
    case is String :
        if let r = rightValue as? String { return ( leftValue as! String ) == r }
    case is Bool   : return ( leftValue as! Bool    ) == MIOCoreBoolValue ( rightValue )
    case is Int    : return ( leftValue as! Int     ) == MIOCoreIntValue  ( rightValue )
    case is Int8   : return ( leftValue as! Int8    ) == MIOCoreInt8Value ( rightValue )
    case is Int16  : return ( leftValue as! Int16   ) == MIOCoreInt16Value( rightValue )
    case is Int32  : return ( leftValue as! Int32   ) == MIOCoreInt32Value( rightValue )
    case is Int64  : return ( leftValue as! Int64   ) == MIOCoreInt64Value( rightValue )
    case is Float  : return ( leftValue as! Float   ) == MIOCoreFloatValue( rightValue )
    case is Double : return ( leftValue as! Double  ) == MIOCoreDoubleValue( rightValue )
    case is Decimal: return ( leftValue as! Decimal ) == MCDecimalValue( rightValue )
    case is UUID   :
        let l = leftValue as! UUID
        if let r = rightValue as? UUID { return l == r }
        if let s = rightValue as? String { return l == UUID(uuidString: s) }
    case is Date:
        let l = leftValue as! Date
        if let s = rightValue as? String {
            let rightDate = MIOCoreDate( fromString: s )
            return rightDate == nil ? false : l == rightDate!
        }
        if let r = rightValue as? Date { return l == r }

    default: break
    }

    Log.critical ( "MIOPredicateEvaluate equal cannot compare \(leftValue ?? "nil") with \(rightValue ?? "nil")" )
    return false
}


func MIOPredicateEvaluateLessEqual( _ leftValue: Any?, _ rightValue:Any?) -> Bool {

    if leftValue == nil && rightValue == nil { return true }
    if leftValue == nil && rightValue != nil { return false }
    if leftValue != nil && rightValue == nil { return false }

    if MIOCoreIsIntValue(leftValue) && MIOCoreIsIntValue(rightValue) {
        return ( MIOCoreInt64Value(leftValue)! <= MIOCoreInt64Value(rightValue)! )
    }

    switch leftValue! {
    case is String:
        if let r = rightValue as? String { return ( leftValue as! String ) <= r }
    case is Float:
        if let l = MIOCoreFloatValue(leftValue), let r = MIOCoreFloatValue(rightValue) { return l <= r }
    case is Double:
        if let l = MIOCoreDoubleValue(leftValue), let r = MIOCoreDoubleValue(rightValue) { return l <= r }
    case is Decimal:
        if let l = leftValue as? Decimal, let r = MCDecimalValue(rightValue) { return l <= r }
    case is UUID:
        let l = (leftValue as! UUID).uuidString
        if let r = rightValue as? UUID { return l <= r.uuidString }
        if let r = rightValue as? String { return l <= r.uppercased() }
    case is Date:
        let l = leftValue as! Date
        if let s = rightValue as? String {
            let rightDate = MIOCoreDate( fromString: s )
            return rightDate == nil ? false : l <= rightDate!
        }
        if let r = rightValue as? Date { return l <= r }

    default: break
    }

    Log.debug ( "MIOPredicateEvaluate lessEqual cannot compare \(leftValue ?? "nil") with \(rightValue ?? "nil")" )
    return false
}


func MIOPredicateEvaluateLess( _ leftValue: Any?, _ rightValue:Any?) -> Bool {

    if leftValue == nil && rightValue == nil { return true }
    if leftValue == nil && rightValue != nil { return false }
    if leftValue != nil && rightValue == nil { return false }

    if MIOCoreIsIntValue(leftValue) && MIOCoreIsIntValue(rightValue) {
        return ( MIOCoreInt64Value(leftValue)! < MIOCoreInt64Value(rightValue)! )
    }
    
    switch leftValue! {
    case is String:
        if let r = rightValue as? String { return ( leftValue as! String ) < r }
    case is Float:
        if let l = MIOCoreFloatValue(leftValue), let r = MIOCoreFloatValue(rightValue) { return l < r }
    case is Double:
        if let l = MIOCoreDoubleValue(leftValue), let r = MIOCoreDoubleValue(rightValue) { return l < r }
    case is Decimal:
        if let l = leftValue as? Decimal, let r = MCDecimalValue(rightValue) { return l < r }
    case is UUID:
        let l = (leftValue as! UUID).uuidString
        if let r = rightValue as? UUID { return l < r.uuidString }
        if let r = rightValue as? String { return l < r.uppercased() }
    case is Date:
        let l = leftValue as! Date
        if let s = rightValue as? String {
            let rightDate = MIOCoreDate( fromString: s )
            return rightDate == nil ? false : l < rightDate!
        }
        if let r = rightValue as? Date { return l < r }

    default: break
    }

    Log.debug ( "MIOPredicateEvaluate less cannot compare \(leftValue ?? "nil") with \(rightValue ?? "nil")" )
    return false
}

func MIOPredicateEvaluateIn( _ leftValue: Any?, _ rightValue:Any?) -> Bool 
{
    if leftValue == nil && rightValue == nil { return true }
    if leftValue == nil && rightValue != nil { return false }
    if leftValue != nil && rightValue == nil { return false }

    var value:[Any] = []
    
    if let str = rightValue as? String {
        value = String( str.dropFirst().dropLast() )
                        .components(separatedBy: ",")
                        .map { inferType( String( $0.trimmingCharacters(in: .whitespaces) ), leftValue! ) }
    }
    else {
        value = rightValue as? [Any] ?? []
    }
        
    if let str_list = value as? [String] {
        if let lv = leftValue as? UUID {
            return str_list.contains( lv.uuidString )
        }
        if let lv = leftValue as? String {
            return str_list.contains( lv )
        }
        Log.critical ( "MIOPredicateEvaluate in cannot compare \(leftValue ?? "nil") with string list" )
        return false
    }
    else if let uuid_list = value as? [UUID] {
        if let lv = leftValue as? UUID {
            return uuid_list.contains( lv )
        }
        if let s = leftValue as? String, let lv = UUID(uuidString: s) {
            return uuid_list.contains( lv )
        }
        Log.critical ( "MIOPredicateEvaluate in cannot compare \(leftValue ?? "nil") with UUID list" )
        return false
    }

    guard let lv = MIOCoreIntValue( leftValue! ) else {
        Log.critical ( "MIOPredicateEvaluate in cannot compare \(leftValue ?? "nil") with \(rightValue ?? "nil")" )
        return false
    }
    let ints = value.compactMap { MIOCoreIntValue( $0 ) }
    return ints.contains( lv )
}

func MIOPredicateEvaluateContains( _ leftValue: Any?, _ rightValue:Any?) -> Bool
{
    if leftValue == nil && rightValue == nil { return false }
    if let l = leftValue as? String, let r = rightValue as? String {
        return l.contains( r )
    }
    
    return false
}


func inferType ( _ value: String, _ obj_value: Any ) -> Any {
    var v = value
    if value.starts(with: "\"" ) {
        v = value.replacingOccurrences(of: "\"", with: "")
    }
    else if value.starts(with: "'" ) {
        v = value.replacingOccurrences(of: "'", with: "")
    }
        
    if obj_value is UUID  { return UUID(uuidString: v)    ?? v }
    if obj_value is Int   { return MIOCoreIntValue( v )   ?? v }
    if obj_value is Int8  { return MIOCoreInt8Value( v )  ?? v }
    if obj_value is Int16 { return MIOCoreInt16Value( v ) ?? v }
    if obj_value is Int32 { return MIOCoreInt32Value( v ) ?? v }
    if obj_value is Int64 { return MIOCoreInt64Value( v ) ?? v }

    return value
}


#endif
