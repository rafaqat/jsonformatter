import Foundation
import JSONFormatterFeature

// Debug version of JSONFixer to understand what's happening
public actor DebugJSONFixer {
    
    enum Token: Equatable, CustomStringConvertible {
        case leftBrace
        case rightBrace
        case leftBracket
        case rightBracket
        case comma
        case colon
        case string(String)
        case number(Double)
        case boolean(Bool)
        case null
        case unknown(String)
        case whitespace
        case eof
        
        var description: String {
            switch self {
            case .leftBrace: return "{"
            case .rightBrace: return "}"
            case .leftBracket: return "["
            case .rightBracket: return "]"
            case .comma: return ","
            case .colon: return ":"
            case .string(let s): return "\"\(s)\""
            case .number(let n): return "\(n)"
            case .boolean(let b): return "\(b)"
            case .null: return "null"
            case .unknown(let s): return "?\(s)"
            case .whitespace: return "_"
            case .eof: return "EOF"
            }
        }
    }
    
    public func testFix(_ input: String) async {
        print("\n🔍 DEBUG: Testing fix for:")
        print(input)
        print("\n" + "=" * 60)
        
        // Tokenize
        let tokens = tokenize(input)
        print("\n📝 Tokens:")
        for (i, token) in tokens.enumerated() {
            print("  [\(i)]: \(token)")
        }
        
        // Check for missing bracket pattern
        print("\n🔎 Checking for missing bracket pattern...")
        
        var index = 0
        while index < tokens.count {
            // Look for pattern: string("coordinates") : number , number ]
            if case .string(let key) = tokens[index],
               key == "coordinates" || key.contains("coord") {
                print("\n  Found key: \(key) at index \(index)")
                
                // Check next tokens
                if index + 1 < tokens.count {
                    print("  Next token: \(tokens[index + 1])")
                    
                    if case .colon = tokens[index + 1] {
                        print("  Found colon after key")
                        
                        // Skip whitespace
                        var checkIndex = index + 2
                        while checkIndex < tokens.count && tokens[checkIndex] == .whitespace {
                            checkIndex += 1
                        }
                        
                        if checkIndex < tokens.count {
                            print("  Token after colon: \(tokens[checkIndex])")
                            
                            // Check if it's a number (missing bracket case)
                            if case .number(let n1) = tokens[checkIndex] {
                                print("  ⚠️ Found number \(n1) directly after coordinates!")
                                
                                // Look for comma and another number
                                var hasComma = false
                                var hasSecondNumber = false
                                var hasClosingBracket = false
                                
                                var peekIndex = checkIndex + 1
                                while peekIndex < tokens.count {
                                    switch tokens[peekIndex] {
                                    case .comma:
                                        hasComma = true
                                        print("  Found comma at index \(peekIndex)")
                                    case .number(let n2):
                                        if hasComma {
                                            hasSecondNumber = true
                                            print("  Found second number \(n2) at index \(peekIndex)")
                                        }
                                    case .rightBracket:
                                        hasClosingBracket = true
                                        print("  Found closing bracket at index \(peekIndex)")
                                        break
                                    case .whitespace:
                                        break // skip
                                    default:
                                        break
                                    }
                                    
                                    if hasClosingBracket {
                                        break
                                    }
                                    peekIndex += 1
                                }
                                
                                if hasComma && hasClosingBracket {
                                    print("\n  ✅ DETECTED: Missing opening bracket pattern!")
                                    print("     Pattern: key:number,number] (missing [)")
                                    return
                                }
                            }
                        }
                    }
                }
            }
            index += 1
        }
        
        print("\n❌ Pattern not detected")
    }
    
    private func tokenize(_ input: String) -> [Token] {
        var tokens: [Token] = []
        var chars = Array(input)
        var i = 0
        
        while i < chars.count {
            // Skip whitespace but track it
            if chars[i].isWhitespace {
                while i < chars.count && chars[i].isWhitespace {
                    i += 1
                }
                tokens.append(.whitespace)
                continue
            }
            
            let char = chars[i]
            
            switch char {
            case "{":
                tokens.append(.leftBrace)
                i += 1
            case "}":
                tokens.append(.rightBrace)
                i += 1
            case "[":
                tokens.append(.leftBracket)
                i += 1
            case "]":
                tokens.append(.rightBracket)
                i += 1
            case ",":
                tokens.append(.comma)
                i += 1
            case ":":
                tokens.append(.colon)
                i += 1
            case "\"":
                // Parse string
                var str = ""
                i += 1
                while i < chars.count && chars[i] != "\"" {
                    if chars[i] == "\\" && i + 1 < chars.count {
                        i += 1
                    }
                    str.append(chars[i])
                    i += 1
                }
                if i < chars.count {
                    i += 1 // skip closing quote
                }
                tokens.append(.string(str))
            case "-", "0"..."9":
                // Parse number
                var numStr = ""
                while i < chars.count && (chars[i] == "-" || chars[i] == "." || chars[i].isNumber) {
                    numStr.append(chars[i])
                    i += 1
                }
                if let num = Double(numStr) {
                    tokens.append(.number(num))
                } else {
                    tokens.append(.unknown(numStr))
                }
            default:
                // Unknown token
                var unknown = ""
                while i < chars.count && !chars[i].isWhitespace && 
                      !"{[}],:\"".contains(chars[i]) {
                    unknown.append(chars[i])
                    i += 1
                }
                tokens.append(.unknown(unknown))
            }
        }
        
        tokens.append(.eof)
        return tokens
    }
}

struct DebugTestRunner {
    static func main() async {
        let debugFixer = DebugJSONFixer()
        
        // Test the simple case
        await debugFixer.testFix("""
        {"coordinates": -0.1695, 51.4865]}
        """)
        
        // Test the complex case
        await debugFixer.testFix("""
        {
          "geometry": {
            "coordinates": -0.1695, 51.4865]
          }
        }
        """)
    }
}