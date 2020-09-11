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
    case notContainsComparator
    case inComparator
    case notIntComparator

    case bitwiseAND
    case bitwiseOR

    case plusOperation
    case minusOperation
    case multiplyOperation
    case divisionOperation
    
    case openParenthesisSymbol
    case closeParenthesisSymbol
    case whitespace

    case and
    case or

    case any
    case all

    case classValue
}

open class MIOPredicate: NSObject, NSCopying
{
    public func copy(with zone: NSZone? = nil) -> Any {
        let obj = MIOPredicate()
        return obj
    }
    
    override init() {}
    
    public init(format predicateFormat: String, argumentArray arguments: [Any]?) {
        super.init()
        parse(predicateFormat, arguments: arguments)
    }
              
    public init(format predicateFormat: String, arguments argList: CVaListPointer) {
        super.init()
        parse(predicateFormat, arguments: nil)
    }
        
    var lexer:MIOCoreLexer!
    
    func parse(_ predicateFormat: String, arguments: [Any]?) {
    
        lexer = MIOCoreLexer(withString: predicateFormat)
        
        // Values
        //lexer.addTokenType(MIOPredicateTokenType.uuidValue.rawValue, regex: try! NSRegularExpression(pattern: "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}", options:.caseInsensitive))
        lexer.addTokenType(MIOPredicateTokenType.stringValue.rawValue, regex: try! NSRegularExpression(pattern: "^\"([^\"]*)\"|^'([^']*)'"))
        lexer.addTokenType(MIOPredicateTokenType.numberValue.rawValue, regex: try! NSRegularExpression(pattern:"^-?\\d+(?:\\.\\d+)?(?:e[+\\-]?\\d+)?", options:.caseInsensitive))
        lexer.addTokenType(MIOPredicateTokenType.booleanValue.rawValue, regex: try! NSRegularExpression(pattern:"^(true|false)", options:.caseInsensitive))
        lexer.addTokenType(MIOPredicateTokenType.nullValue.rawValue, regex: try! NSRegularExpression(pattern:"^(null|nil)", options:.caseInsensitive))
        
        // Symbols
        lexer.addTokenType(MIOPredicateTokenType.openParenthesisSymbol.rawValue, regex: try! NSRegularExpression(pattern:"^\\("))
        lexer.addTokenType(MIOPredicateTokenType.closeParenthesisSymbol.rawValue, regex: try! NSRegularExpression(pattern:"^\\)"))
        
        // Comparators
        lexer.addTokenType(MIOPredicateTokenType.minorOrEqualComparator.rawValue, regex: try! NSRegularExpression(pattern:"^<="))
        lexer.addTokenType(MIOPredicateTokenType.minorComparator.rawValue, regex: try! NSRegularExpression(pattern:"^<"))
        lexer.addTokenType(MIOPredicateTokenType.majorOrEqualComparator.rawValue, regex: try! NSRegularExpression(pattern:"^>="))
        lexer.addTokenType(MIOPredicateTokenType.majorComparator.rawValue, regex: try! NSRegularExpression(pattern:"^>"))
        lexer.addTokenType(MIOPredicateTokenType.equalComparator.rawValue, regex: try! NSRegularExpression(pattern:"^==?"))
        lexer.addTokenType(MIOPredicateTokenType.distinctComparator.rawValue, regex: try! NSRegularExpression(pattern:"^!="))
        lexer.addTokenType(MIOPredicateTokenType.notContainsComparator.rawValue, regex: try! NSRegularExpression(pattern:"^not contains ", options: .caseInsensitive))
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
        // Relationship operators
        lexer.addTokenType(MIOPredicateTokenType.any.rawValue, regex: try! NSRegularExpression(pattern:"^any ", options: .caseInsensitive))
        lexer.addTokenType(MIOPredicateTokenType.all.rawValue, regex: try! NSRegularExpression(pattern:"^all ", options: .caseInsensitive))
        // Extra
        lexer.addTokenType(MIOPredicateTokenType.whitespace.rawValue, regex: try! NSRegularExpression(pattern:"^\\s+", options: .caseInsensitive))
        lexer.ignoreTokenType(MIOPredicateTokenType.whitespace.rawValue)
        
        // Placeholder
        lexer.addTokenType(MIOPredicateTokenType.classValue.rawValue, regex: try! NSRegularExpression(pattern:"^%@", options: .caseInsensitive))
                
        // Identifiers - Has to be the last one
        lexer.addTokenType(MIOPredicateTokenType.identifier.rawValue, regex: try! NSRegularExpression(pattern:"^[a-zA-Z-_][a-zA-Z0-9-_\\.]"))

        lexer.tokenize()
        
        parsePredicate()
    }        
    
    func parsePredicate(){

          var token = lexer.nextToken()
          var predicates = [Any]()
          var exit = false

          while (token != nil && exit == false) {

            switch (token!.type) {

            case MIOPredicateTokenType.identifier.rawValue:
                      let leftExpression = NSExpression(forKeyPath: token!.value)
                      let op = parseOperator()
                      let rightExpression = parseExpresion()

                      //predicate = NSComparisonPredicate(leftExpression: leftExpression, rightExpression: rightExpression, modifier: .direct, type: op, options: [])
                      //predicates.append(pi)

/*                  case MIOPredicateTokenType.AND:
                      predicates.push(MIOPredicateOperator.andPredicateOperatorType());
                      break;

                  case MIOPredicateTokenType.OR:
                      predicates.push(MIOPredicateOperator.orPredicateOperatorType());
                      break;

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

          //return predicates
      }


      func parseExpresion() -> NSExpression {

        let token = lexer.nextToken()

        switch token!.type {

        case MIOPredicateTokenType.uuidValue.rawValue:
            let ex = NSExpression(forConstantValue: token!.value)
            return ex

        case MIOPredicateTokenType.stringValue.rawValue:
            let v = String(token!.value.dropLast().dropFirst())
            let ex = NSExpression(forConstantValue: v)
            return ex

/*
        case MIOPredicateTokenType.numberValue.rawValue:
            let ex = NSExpression(forConstantValue: Decimal(token!.value))
            return ex

            case MIOPredicateTokenType.BooleanValue:
                item.value = this.booleanFromString(token.value);
                item.valueType = MIOPredicateItemValueType.Boolean;
                break;

            case MIOPredicateTokenType.NullValue:
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

    func parseOperator() -> NSComparisonPredicate.Operator {

        let token = lexer.nextToken()

        switch token!.type {

        case MIOPredicateTokenType.equalComparator.rawValue:
            return NSComparisonPredicate.Operator.equalTo
/*
              case MIOPredicateTokenType.MajorComparator:
                  item.comparator = MIOPredicateComparatorType.Greater;
                  break;

              case MIOPredicateTokenType.MajorOrEqualComparator:
                  item.comparator = MIOPredicateComparatorType.GreaterOrEqual;
                  break;

              case MIOPredicateTokenType.MinorComparator:
                  item.comparator = MIOPredicateComparatorType.Less;
                  break;

              case MIOPredicateTokenType.MinorOrEqualComparator:
                  item.comparator = MIOPredicateComparatorType.LessOrEqual;
                  break;

              case MIOPredicateTokenType.DistinctComparator:
                  item.comparator = MIOPredicateComparatorType.Distinct;
                  break;

              case MIOPredicateTokenType.ContainsComparator:
                  item.comparator = MIOPredicateComparatorType.Contains;
                  break;

              case MIOPredicateTokenType.NotContainsComparator:
                  item.comparator = MIOPredicateComparatorType.NotContains;
                  break;

              case MIOPredicateTokenType.InComparator:
                  item.comparator = MIOPredicateComparatorType.In;
                  break;

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
              default:
                  //throw new Error(`MIOPredicate: Error. Unexpected comparator. (${token.value})`);
            break
          }

        return NSComparisonPredicate.Operator.equalTo
      }

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

extension NSPredicate {
        
    public convenience init(format predicateFormat: String, _ args: CVarArg...) {
        //let array = getVaList(args)
        self.init(format:predicateFormat, argumentArray:nil)
        //object_setClass(self, MIOComparisonPredicate.self)
        
    }
    
}

