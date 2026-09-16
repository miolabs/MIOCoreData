//
//  MIOPredicateParser.swift
//
//  Hand-written scanner and recursive-descent parser for predicate format
//  strings. Replaces the previous lexer, which matched up to 28
//  NSRegularExpressions per token against a string rebuilt after every match
//  (O(n^2), and very slow on corelibs-foundation).
//
//  - Single pass over UTF-8 bytes, no regular expressions, no allocations
//    beyond the token values themselves.
//  - Token streams are cached per format string: servers parse the same
//    handful of formats millions of times.
//  - Standard operator precedence by construction: NOT > AND > OR, with
//    AND/OR chains flattened into a single compound predicate (the shape the
//    existing parse-tree tests expect).
//

#if !APPLE_CORE_DATA

import Foundation
import MIOCoreLogger

// MARK: - Tokens

enum MIOPredicateKeyword {
    case and, or, not
    case inOp, contains, like, matches, beginsWith, endsWith, between
    case any, all
    case trueLiteral, falseLiteral, nullLiteral, selfLiteral
}

private let g_keywords: [String: MIOPredicateKeyword] = [
    "and": .and, "or": .or, "not": .not,
    "in": .inOp, "contains": .contains, "like": .like, "matches": .matches,
    "beginswith": .beginsWith, "endswith": .endsWith, "between": .between,
    "any": .any, "all": .all,
    "true": .trueLiteral, "yes": .trueLiteral,
    "false": .falseLiteral, "no": .falseLiteral,
    "null": .nullLiteral, "nil": .nullLiteral,
    "self": .selfLiteral,
]

enum MIOPredicateToken {
    case identifier(String)      // keypath or bare word
    case uuid(String)            // bare 8-4-4-4-12 hex literal
    case number(String)
    case string(String)          // quotes already stripped
    case array(String)           // inner content of [...] or {...}
    case placeholderObject       // %@
    case placeholderKeyPath      // %K
    case equal, notEqual, less, lessOrEqual, greater, greaterOrEqual
    case bitAnd, bitOr, bitXor
    case openParen, closeParen
    case keyword(MIOPredicateKeyword)
}

// MARK: - Scanner

private func isIdentStart(_ b: UInt8) -> Bool { let l = b | 0x20; return (l >= 97 && l <= 122) || b == 95 }   // a-z _
private func isDigit(_ b: UInt8) -> Bool { return b >= 48 && b <= 57 }
private func isIdentCont(_ b: UInt8) -> Bool { return isIdentStart(b) || isDigit(b) || b == 46 || b == 45 }  // . -
private func isHex(_ b: UInt8) -> Bool { let l = b | 0x20; return isDigit(b) || (l >= 97 && l <= 102) }

/// Bare UUID literal check: 8-4-4-4-12 hex groups starting at `i`
private func matchesUUID(_ bytes: [UInt8], _ i: Int) -> Bool {
    guard i + 36 <= bytes.count else { return false }
    for offset in 0..<36 {
        let b = bytes[i + offset]
        switch offset {
        case 8, 13, 18, 23: if b != 45 { return false }         // '-'
        default: if isHex(b) == false { return false }
        }
    }
    // must end at a token boundary, not inside a longer identifier
    if i + 36 < bytes.count && isIdentCont(bytes[i + 36]) { return false }
    return true
}

func MIOPredicateScan(_ format: String) throws -> [MIOPredicateToken] {
    var tokens: [MIOPredicateToken] = []
    let bytes = Array(format.utf8)
    let n = bytes.count
    var i = 0

    func slice(_ from: Int, _ to: Int) -> String {
        return String(decoding: bytes[from..<to], as: UTF8.self)
    }

    while i < n {
        let b = bytes[i]
        switch b {
        case 32, 9, 10, 13:                                     // whitespace
            i += 1

        case UInt8(ascii: "("): tokens.append(.openParen);  i += 1
        case UInt8(ascii: ")"): tokens.append(.closeParen); i += 1

        case UInt8(ascii: "="):
            i += 1
            if i < n && bytes[i] == UInt8(ascii: "=") { i += 1 }
            tokens.append(.equal)

        case UInt8(ascii: "!"):
            guard i + 1 < n, bytes[i + 1] == UInt8(ascii: "=") else {
                throw MIOPredicateError.unexpectedToken("'!' at offset \(i)")
            }
            tokens.append(.notEqual); i += 2

        case UInt8(ascii: "<"):
            if i + 1 < n && bytes[i + 1] == UInt8(ascii: "=") { tokens.append(.lessOrEqual); i += 2 }
            else if i + 1 < n && bytes[i + 1] == UInt8(ascii: ">") { tokens.append(.notEqual); i += 2 }
            else { tokens.append(.less); i += 1 }

        case UInt8(ascii: ">"):
            if i + 1 < n && bytes[i + 1] == UInt8(ascii: "=") { tokens.append(.greaterOrEqual); i += 2 }
            else { tokens.append(.greater); i += 1 }

        case UInt8(ascii: "&"):
            if i + 1 < n && bytes[i + 1] == UInt8(ascii: "&") { tokens.append(.keyword(.and)); i += 2 }
            else { tokens.append(.bitAnd); i += 1 }

        case UInt8(ascii: "|"):
            if i + 1 < n && bytes[i + 1] == UInt8(ascii: "|") { tokens.append(.keyword(.or)); i += 2 }
            else { tokens.append(.bitOr); i += 1 }

        case UInt8(ascii: "^"):
            tokens.append(.bitXor); i += 1

        case UInt8(ascii: "%"):
            guard i + 1 < n else { throw MIOPredicateError.unexpectedEndOfFormat }
            switch bytes[i + 1] {
            case UInt8(ascii: "@"): tokens.append(.placeholderObject);  i += 2
            case UInt8(ascii: "K"): tokens.append(.placeholderKeyPath); i += 2
            default: throw MIOPredicateError.unexpectedToken("'%\(Character(UnicodeScalar(bytes[i + 1])))' at offset \(i)")
            }

        case UInt8(ascii: "'"), UInt8(ascii: "\""):
            let quote = b
            var j = i + 1
            while j < n && bytes[j] != quote { j += 1 }
            guard j < n else { throw MIOPredicateError.unexpectedToken("unterminated string starting at offset \(i)") }
            tokens.append(.string(slice(i + 1, j)))
            i = j + 1

        case UInt8(ascii: "["), UInt8(ascii: "{"):
            let close: UInt8 = (b == UInt8(ascii: "[")) ? UInt8(ascii: "]") : UInt8(ascii: "}")
            var j = i + 1
            while j < n && bytes[j] != close { j += 1 }
            guard j < n else { throw MIOPredicateError.unexpectedToken("unterminated collection starting at offset \(i)") }
            tokens.append(.array(slice(i + 1, j)))
            i = j + 1

        case UInt8(ascii: "-"):
            guard i + 1 < n, isDigit(bytes[i + 1]) else {
                throw MIOPredicateError.unexpectedToken("'-' at offset \(i)")
            }
            fallthrough

        default:
            if b == UInt8(ascii: "-") || isDigit(b) {
                // Bare UUIDs can start with a digit — check the shape before
                // committing to a number
                if matchesUUID(bytes, i) {
                    tokens.append(.uuid(slice(i, i + 36)))
                    i += 36
                    continue
                }
                let start = i
                if b == UInt8(ascii: "-") { i += 1 }
                while i < n && isDigit(bytes[i]) { i += 1 }
                if i < n && bytes[i] == UInt8(ascii: ".") && i + 1 < n && isDigit(bytes[i + 1]) {
                    i += 1
                    while i < n && isDigit(bytes[i]) { i += 1 }
                }
                if i < n && (bytes[i] | 0x20) == UInt8(ascii: "e") {
                    var j = i + 1
                    if j < n && (bytes[j] == UInt8(ascii: "+") || bytes[j] == UInt8(ascii: "-")) { j += 1 }
                    if j < n && isDigit(bytes[j]) {
                        i = j
                        while i < n && isDigit(bytes[i]) { i += 1 }
                    }
                }
                tokens.append(.number(slice(start, i)))
            }
            else if isIdentStart(b) {
                if matchesUUID(bytes, i) {
                    tokens.append(.uuid(slice(i, i + 36)))
                    i += 36
                    continue
                }
                let start = i
                i += 1
                while i < n && isIdentCont(bytes[i]) { i += 1 }
                let word = slice(start, i)
                if let keyword = g_keywords[word.lowercased()] {
                    tokens.append(.keyword(keyword))
                }
                else {
                    tokens.append(.identifier(word))
                }
            }
            else {
                throw MIOPredicateError.unexpectedToken("'\(Character(UnicodeScalar(b)))' at offset \(i)")
            }
        }
    }

    return tokens
}

// MARK: - Token cache

final class MIOPredicateTokenCache: @unchecked Sendable   // all mutable state is lock-protected
{
    static let shared = MIOPredicateTokenCache()

    private let lock = NSLock()
    private var cache: [String: [MIOPredicateToken]] = [:]
    private let capacity = 512

    func tokens(for format: String) throws -> [MIOPredicateToken] {
        lock.lock()
        if let cached = cache[format] { lock.unlock(); return cached }
        lock.unlock()

        let tokens = try MIOPredicateScan(format)

        lock.lock()
        // Formats are a small finite set in practice; a full flush on overflow
        // beats LRU bookkeeping on every hit
        if cache.count >= capacity { cache.removeAll(keepingCapacity: true) }
        cache[format] = tokens
        lock.unlock()

        return tokens
    }
}

// MARK: - Parser

struct MIOPredicateParserState
{
    let tokens: [MIOPredicateToken]
    let args: [Any]
    var pos = 0
    var argIndex = 0

    init(tokens: [MIOPredicateToken], args: [Any]) {
        self.tokens = tokens
        self.args = args
    }

    // MARK: token helpers

    private func peek() -> MIOPredicateToken? {
        return pos < tokens.count ? tokens[pos] : nil
    }

    private mutating func matchKeyword(_ keyword: MIOPredicateKeyword) -> Bool {
        if case .keyword(let k)? = peek(), k == keyword { pos += 1; return true }
        return false
    }

    private mutating func expectCloseParen() throws {
        guard case .closeParen? = peek() else { throw MIOPredicateError.unexpectedToken("expected ')'") }
        pos += 1
    }

    // MARK: grammar

    mutating func parse() throws -> MIOPredicate {
        guard tokens.isEmpty == false else {
            throw MIOPredicateError.invalidFormat("no predicate could be built from the format string")
        }
        let predicate = try parseOr()
        guard pos == tokens.count else {
            throw MIOPredicateError.unexpectedToken("unconsumed input after position \(pos)")
        }
        return predicate
    }

    private mutating func parseOr() throws -> MIOPredicate {
        var subpredicates = [try parseAnd()]
        while matchKeyword(.or) { subpredicates.append(try parseAnd()) }
        return subpredicates.count == 1 ? subpredicates[0] : MIOCompoundPredicate(orPredicateWithSubpredicates: subpredicates)
    }

    private mutating func parseAnd() throws -> MIOPredicate {
        var subpredicates = [try parseUnary()]
        while matchKeyword(.and) { subpredicates.append(try parseUnary()) }
        return subpredicates.count == 1 ? subpredicates[0] : MIOCompoundPredicate(andPredicateWithSubpredicates: subpredicates)
    }

    private mutating func parseUnary() throws -> MIOPredicate {
        if matchKeyword(.not) {
            return MIOCompoundPredicate(notPredicateWithSubpredicate: try parseUnary())
        }
        if matchKeyword(.any) { return try parseComparison(modifier: .any) }
        if matchKeyword(.all) { return try parseComparison(modifier: .all) }

        if case .openParen? = peek(), isPredicateGroup() {
            pos += 1
            let predicate = try parseOr()
            try expectCloseParen()
            return predicate
        }

        return try parseComparison(modifier: .direct)
    }

    /// A '(' can open a predicate group — "(a = 1 and b = 2)" — or a
    /// parenthesized left expression — "(key & 1) > 0". Look at the token
    /// after the matching ')': an operator means expression.
    private func isPredicateGroup() -> Bool {
        var depth = 0
        var j = pos
        while j < tokens.count {
            if case .openParen = tokens[j] { depth += 1 }
            else if case .closeParen = tokens[j] {
                depth -= 1
                if depth == 0 { break }
            }
            j += 1
        }

        guard j + 1 < tokens.count else { return true }
        switch tokens[j + 1] {
        case .equal, .notEqual, .less, .lessOrEqual, .greater, .greaterOrEqual,
             .bitAnd, .bitOr, .bitXor:
            return false
        case .keyword(let k):
            switch k {
            case .inOp, .contains, .like, .matches, .beginsWith, .endsWith, .between: return false
            default: return true
            }
        default:
            return true
        }
    }

    private mutating func parseComparison(modifier: MIOComparisonPredicate.Modifier) throws -> MIOPredicate {
        let lhs = try parseExpression()
        var negate = false
        let (op, options) = try parseOperator(negate: &negate)
        let rhs = try parseExpression()

        var predicate: MIOPredicate = MIOComparisonPredicate(leftExpression: lhs, rightExpression: rhs, modifier: modifier, type: op, options: options)
        if negate {
            // "NOT IN" is represented the way Apple does it: NOT ( lhs IN rhs )
            predicate = MIOCompoundPredicate(notPredicateWithSubpredicate: predicate)
        }
        return predicate
    }

    private mutating func parseOperator(negate: inout Bool) throws -> (MIOComparisonPredicate.Operator, MIOComparisonPredicate.Options) {
        guard let token = peek() else { throw MIOPredicateError.unexpectedEndOfFormat }
        pos += 1

        let op: MIOComparisonPredicate.Operator
        switch token {
        case .equal:          op = .equalTo
        case .notEqual:       op = .notEqualTo
        case .less:           op = .lessThan
        case .lessOrEqual:    op = .lessThanOrEqualTo
        case .greater:        op = .greaterThan
        case .greaterOrEqual: op = .greaterThanOrEqualTo
        case .keyword(.inOp):       op = .in
        case .keyword(.contains):   op = .contains
        case .keyword(.like):       op = .like
        case .keyword(.matches):    op = .matches
        case .keyword(.beginsWith): op = .beginsWith
        case .keyword(.endsWith):   op = .endsWith
        case .keyword(.between):    op = .between
        case .keyword(.not):
            guard matchKeyword(.inOp) else { throw MIOPredicateError.unexpectedToken("expected IN after NOT") }
            op = .in
            negate = true
        default:
            throw MIOPredicateError.unexpectedToken("expected a comparison operator")
        }

        // Option suffix — CONTAINS[cd] 'x' — arrives as an array token because
        // the scanner folds [..] into one token. Only recognized for operators
        // where a collection cannot follow (IN keeps its array as the operand)
        var options: MIOComparisonPredicate.Options = []
        if opSupportsOptions(op), case .array(let content)? = peek() {
            switch content.lowercased() {
            case "c":        options = [.caseInsensitive];  pos += 1
            case "d":        options = [.diacriticInsensitive]; pos += 1
            case "cd", "dc": options = [.caseInsensitive, .diacriticInsensitive]; pos += 1
            default: break
            }
        }

        return (op, options)
    }

    private func opSupportsOptions(_ op: MIOComparisonPredicate.Operator) -> Bool {
        switch op {
        case .equalTo, .notEqualTo, .contains, .like, .matches, .beginsWith, .endsWith: return true
        default: return false
        }
    }

    // MARK: expressions

    private mutating func parseExpression() throws -> MIOExpression {
        var expression = try parsePrimaryExpression()

        while true {
            let function: MIOExpression.FunctionType
            switch peek() {
            case .bitAnd: function = .bitwiseAnd
            case .bitOr:  function = .bitwiseOr
            case .bitXor: function = .bitwiseXor
            default: return expression
            }
            pos += 1
            let rhs = try parsePrimaryExpression()
            expression = MIOExpression(forFunction: function.rawValue, arguments: [expression, rhs])
        }
    }

    private mutating func parsePrimaryExpression() throws -> MIOExpression {
        guard let token = peek() else { throw MIOPredicateError.unexpectedEndOfFormat }
        pos += 1

        switch token {
        case .identifier(let value):
            return MIOExpression(forKeyPath: value)

        case .uuid(let value):
            return MIOExpression(forConstantValue: value)

        case .number(let value):
            if value.contains(".") || value.lowercased().contains("e") {
                return MIOExpression(forConstantValue: Double(value))
            }
            return MIOExpression(forConstantValue: Int(value))

        case .string(let value):
            return MIOExpression(forConstantValue: value)

        case .array(let content):
            // Same behavior as before: try JSON, fall back to the raw
            // bracketed text (EvaluateIn re-parses that shape)
            let text = "[" + content + "]"
            let value = ( try? JSONSerialization.jsonObject(with: text.data(using: .utf8)!, options: .fragmentsAllowed) ) ?? text
            return MIOExpression(forConstantValue: value)

        case .keyword(.trueLiteral):  return MIOExpression(forConstantValue: true as NSNumber)
        case .keyword(.falseLiteral): return MIOExpression(forConstantValue: false as NSNumber)
        case .keyword(.nullLiteral):  return MIOExpression(forConstantValue: nil)
        case .keyword(.selfLiteral):  return MIOExpression(expressionType: .evaluatedObject)

        case .placeholderObject:
            guard argIndex < args.count else { throw MIOPredicateError.missingArgument(argIndex) }
            let value = args[argIndex]
            argIndex += 1
            return MIOExpression(forConstantValue: value)

        case .placeholderKeyPath:
            guard argIndex < args.count else { throw MIOPredicateError.missingArgument(argIndex) }
            guard let keyPath = args[argIndex] as? String else {
                throw MIOPredicateError.unexpectedToken("%K argument at index \(argIndex) is not a String")
            }
            argIndex += 1
            return MIOExpression(forKeyPath: keyPath)

        case .openParen:
            let expression = try parseExpression()
            try expectCloseParen()
            return expression

        default:
            throw MIOPredicateError.unexpectedToken("expected an expression")
        }
    }
}

// MARK: - Entry point

func MIOPredicateParse(format: String, args: [Any]) throws -> MIOPredicate {
    let tokens = try MIOPredicateTokenCache.shared.tokens(for: format)
    var parser = MIOPredicateParserState(tokens: tokens, args: args)
    return try parser.parse()
}

#endif
