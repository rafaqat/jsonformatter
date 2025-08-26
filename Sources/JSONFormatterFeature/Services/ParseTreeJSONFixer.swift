import Foundation

/// A JSON fixer that builds a partial parse tree to make intelligent fixes
public actor ParseTreeJSONFixer {
    
    // Token types for lexical analysis
    enum Token: Equatable {
        case leftBrace
        case rightBrace
        case leftBracket
        case rightBracket
        case comma
        case colon
        case string(String, wasUnterminated: Bool = false)
        case number(Double)
        case boolean(Bool)
        case null
        case unknown(String)
        case whitespace
        case eof
    }
    
    // Parse tree nodes with termination tracking
    indirect enum ParseNode {
        case object([ObjectMember], wasUnterminated: Bool = false)
        case array([ParseNode], wasUnterminated: Bool = false)
        case string(String, wasUnterminated: Bool = false)
        case number(Double)
        case boolean(Bool)
        case null
        case error(String, recovered: ParseNode?)
        
        struct ObjectMember {
            let key: String
            let value: ParseNode
            let hasComma: Bool
            let keyWasUnterminated: Bool
        }
    }
    
    public init() {}
    
    public struct FixResult: Sendable {
        public let fixed: String
        public let fixes: [String]
        public let wasFixed: Bool
    }
    
    // Main entry point
    public func fix(_ jsonString: String) async -> FixResult {
        var fixes: [String] = []
        
        // First pass: clean obvious non-structural issues
        var cleaned = cleanNonStructuralIssues(jsonString, fixes: &fixes)
        
        // Tokenize (now returns fixes for unterminated strings)
        let (tokens, tokenFixes) = tokenizeWithFixes(cleaned)
        fixes.append(contentsOf: tokenFixes)
        
        // Build parse tree (partial, with error recovery)
        let (tree, parseErrors) = buildParseTree(tokens)
        
        // Add parse errors to fixes
        fixes.append(contentsOf: parseErrors)
        
        // Fix based on parse tree
        let fixed = reconstructJSON(from: tree, fixes: &fixes)
        
        return FixResult(
            fixed: fixed,
            fixes: fixes,
            wasFixed: !fixes.isEmpty
        )
    }
    
    // Clean non-structural issues that don't affect parsing
    private func cleanNonStructuralIssues(_ input: String, fixes: inout [String]) -> String {
        var result = input
        
        // Fix smart quotes - these can be fixed safely
        let smartQuotes = [
            ("\u{201C}", "\""), // left double quote
            ("\u{201D}", "\""), // right double quote  
            ("\u{2018}", "'"),  // left single quote
            ("\u{2019}", "'")   // right single quote
        ]
        
        for (smart, regular) in smartQuotes {
            if result.contains(smart) {
                result = result.replacingOccurrences(of: smart, with: regular)
                if !fixes.contains("Fixed smart quotes") {
                    fixes.append("Fixed smart quotes")
                }
            }
        }
        
        // Remove comments safely (before parsing)
        if result.contains("//") || result.contains("/*") {
            result = removeComments(result)
            fixes.append("Removed comments")
        }
        
        return result
    }
    
    // Remove comments preserving string literals
    private func removeComments(_ input: String) -> String {
        var result = ""
        var inString = false
        var inSingleLineComment = false
        var inMultiLineComment = false
        var escapeNext = false
        var chars = Array(input)
        var i = 0
        
        while i < chars.count {
            let char = chars[i]
            
            if escapeNext {
                result.append(char)
                escapeNext = false
                i += 1
                continue
            }
            
            if inString {
                result.append(char)
                if char == "\\" {
                    escapeNext = true
                } else if char == "\"" {
                    inString = false
                }
                i += 1
                continue
            }
            
            if inSingleLineComment {
                if char == "\n" || char == "\r" {
                    inSingleLineComment = false
                    result.append(char) // Keep the newline
                }
                i += 1
                continue
            }
            
            if inMultiLineComment {
                if char == "*" && i + 1 < chars.count && chars[i + 1] == "/" {
                    inMultiLineComment = false
                    i += 2
                    continue
                }
                i += 1
                continue
            }
            
            // Check for comment starts
            if char == "/" && i + 1 < chars.count {
                if chars[i + 1] == "/" {
                    inSingleLineComment = true
                    i += 2
                    continue
                } else if chars[i + 1] == "*" {
                    inMultiLineComment = true
                    i += 2
                    continue
                }
            }
            
            if char == "\"" {
                inString = true
            }
            
            result.append(char)
            i += 1
        }
        
        return result
    }
    
    // Tokenize with fix tracking
    private func tokenizeWithFixes(_ input: String) -> ([Token], [String]) {
        var fixes: [String] = []
        let tokens = tokenizeInternal(input, fixes: &fixes)
        return (tokens, fixes)
    }
    
    // Tokenizer (legacy wrapper)
    private func tokenize(_ input: String) -> [Token] {
        var dummyFixes: [String] = []
        return tokenizeInternal(input, fixes: &dummyFixes)
    }
    
    // Tokenizer implementation
    private func tokenizeInternal(_ input: String, fixes: inout [String]) -> [Token] {
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
                if let (str, newIndex) = parseString(chars, from: i) {
                    tokens.append(.string(str, wasUnterminated: false))
                    i = newIndex
                } else {
                    // Unterminated string - try to recover
                    var str = ""
                    let startPos = i
                    i += 1
                    
                    // Scan until we find a logical end (newline, comma, colon, closing delimiter)
                    while i < chars.count {
                        let char = chars[i]
                        
                        // Stop at structural characters that likely indicate string end
                        if char == "\"" || char == "," || char == ":" || 
                           char == "}" || char == "]" || char == "\n" || char == "\r" {
                            break
                        }
                        
                        // Handle escape sequences
                        if char == "\\" && i + 1 < chars.count {
                            str.append(char)
                            i += 1
                            if i < chars.count {
                                str.append(chars[i])
                            }
                        } else {
                            str.append(char)
                        }
                        i += 1
                    }
                    
                    // Check if we found a closing quote
                    let foundClosingQuote = (i < chars.count && chars[i] == "\"")
                    if foundClosingQuote {
                        i += 1  // Consume the closing quote
                        tokens.append(.string(str, wasUnterminated: false))
                    } else {
                        // No closing quote found - this was an unterminated string
                        fixes.append("Fixed unterminated string")
                        tokens.append(.string(str, wasUnterminated: true))
                    }
                }
            case "'":
                // Handle single quotes as strings (fix them)
                if let (str, newIndex) = parseSingleQuoteString(chars, from: i) {
                    tokens.append(.string(str, wasUnterminated: false))
                    i = newIndex
                } else {
                    i += 1
                }
            case "-", "0"..."9":
                // Parse number
                if let (num, newIndex) = parseNumber(chars, from: i) {
                    tokens.append(.number(num))
                    i = newIndex
                } else {
                    i += 1
                }
            case "t", "f":
                // Try to parse boolean
                if let (bool, newIndex) = parseBoolean(chars, from: i) {
                    tokens.append(.boolean(bool))
                    i = newIndex
                } else {
                    // Not a boolean, might be unquoted string
                    if let (str, newIndex) = parseUnquotedString(chars, from: i) {
                        tokens.append(.unknown(str))
                        i = newIndex
                    } else {
                        i += 1
                    }
                }
            case "n":
                // Try to parse null
                if let newIndex = parseNull(chars, from: i) {
                    tokens.append(.null)
                    i = newIndex
                } else {
                    // Not null, might be unquoted string
                    if let (str, newIndex) = parseUnquotedString(chars, from: i) {
                        tokens.append(.unknown(str))
                        i = newIndex
                    } else {
                        i += 1
                    }
                }
            default:
                // Try to parse as unquoted string/identifier
                if let (str, newIndex) = parseUnquotedString(chars, from: i) {
                    tokens.append(.unknown(str))
                    i = newIndex
                } else {
                    i += 1
                }
            }
        }
        
        tokens.append(.eof)
        return tokens
    }
    
    private func parseString(_ chars: [Character], from start: Int) -> (String, Int)? {
        guard start < chars.count && chars[start] == "\"" else { return nil }
        
        var result = ""
        var i = start + 1
        var escapeNext = false
        
        while i < chars.count {
            let char = chars[i]
            
            if escapeNext {
                result.append(char)
                escapeNext = false
                i += 1
                continue
            }
            
            if char == "\\" {
                escapeNext = true
                result.append(char)
                i += 1
                continue
            }
            
            if char == "\"" {
                return (result, i + 1)
            }
            
            result.append(char)
            i += 1
        }
        
        return nil // Unterminated
    }
    
    private func parseSingleQuoteString(_ chars: [Character], from start: Int) -> (String, Int)? {
        guard start < chars.count && chars[start] == "'" else { return nil }
        
        var result = ""
        var i = start + 1
        
        while i < chars.count && chars[i] != "'" {
            result.append(chars[i])
            i += 1
        }
        
        if i < chars.count && chars[i] == "'" {
            return (result, i + 1)
        }
        
        return nil
    }
    
    private func parseNumber(_ chars: [Character], from start: Int) -> (Double, Int)? {
        var numStr = ""
        var i = start
        
        // Handle negative
        if i < chars.count && chars[i] == "-" {
            numStr.append("-")
            i += 1
        }
        
        // Parse digits
        while i < chars.count && chars[i].isNumber {
            numStr.append(chars[i])
            i += 1
        }
        
        // Decimal point
        if i < chars.count && chars[i] == "." {
            numStr.append(".")
            i += 1
            while i < chars.count && chars[i].isNumber {
                numStr.append(chars[i])
                i += 1
            }
        }
        
        // Exponent
        if i < chars.count && (chars[i] == "e" || chars[i] == "E") {
            numStr.append(chars[i])
            i += 1
            if i < chars.count && (chars[i] == "+" || chars[i] == "-") {
                numStr.append(chars[i])
                i += 1
            }
            while i < chars.count && chars[i].isNumber {
                numStr.append(chars[i])
                i += 1
            }
        }
        
        guard let num = Double(numStr) else { return nil }
        return (num, i)
    }
    
    private func parseBoolean(_ chars: [Character], from start: Int) -> (Bool, Int)? {
        let remaining = String(chars[start...])
        if remaining.hasPrefix("true") {
            return (true, start + 4)
        } else if remaining.hasPrefix("false") {
            return (false, start + 5)
        }
        return nil
    }
    
    private func parseNull(_ chars: [Character], from start: Int) -> Int? {
        let remaining = String(chars[start...])
        if remaining.hasPrefix("null") {
            return start + 4
        }
        return nil
    }
    
    private func parseUnquotedString(_ chars: [Character], from start: Int) -> (String, Int)? {
        var result = ""
        var i = start
        
        while i < chars.count {
            let char = chars[i]
            if char.isLetter || char.isNumber || char == "_" || char == "$" {
                result.append(char)
                i += 1
            } else {
                break
            }
        }
        
        if result.isEmpty {
            return nil
        }
        
        return (result, i)
    }
    
    // Parse tree builder with error recovery
    private func buildParseTree(_ tokens: [Token]) -> (ParseNode?, [String]) {
        var index = 0
        var errors: [String] = []
        
        func skipWhitespace() {
            while index < tokens.count && tokens[index] == .whitespace {
                index += 1
            }
        }
        
        func parseValue() -> ParseNode? {
            skipWhitespace()
            guard index < tokens.count else { return nil }
            
            switch tokens[index] {
            case .leftBrace:
                return parseObject()
            case .leftBracket:
                return parseArray()
            case .string(let str, let wasUnterminated):
                index += 1
                if wasUnterminated {
                    errors.append("Fixed unterminated string")
                }
                return .string(str, wasUnterminated: wasUnterminated)
            case .number(let num):
                index += 1
                return .number(num)
            case .boolean(let bool):
                index += 1
                return .boolean(bool)
            case .null:
                index += 1
                return .null
            case .unknown(let str):
                // Unquoted string - treat as string that needs quotes
                index += 1
                errors.append("Unquoted string: \(str)")
                return .string(str)
            default:
                errors.append("Unexpected token: \(tokens[index])")
                index += 1
                return nil
            }
        }
        
        func parseObject() -> ParseNode {
            var members: [ParseNode.ObjectMember] = []
            var wasUnterminated = false
            index += 1 // skip {
            skipWhitespace()
            
            while index < tokens.count && tokens[index] != .rightBrace && tokens[index] != .eof {
                // Parse key
                skipWhitespace()
                let key: String
                var keyWasUnterminated = false
                
                switch tokens[index] {
                case .string(let str, let wasUnterminated):
                    key = str
                    keyWasUnterminated = wasUnterminated
                    if wasUnterminated {
                        errors.append("Fixed unterminated key: \(str)")
                    }
                    index += 1
                case .unknown(let str):
                    // Unquoted key
                    key = str
                    index += 1
                    errors.append("Unquoted key: \(str)")
                default:
                    // Unexpected token for key
                    if tokens[index] == .comma {
                        // Extra comma, skip it
                        index += 1
                        skipWhitespace()
                        continue
                    }
                    errors.append("Expected key, got \(tokens[index])")
                    index += 1
                    continue
                }
                
                skipWhitespace()
                
                // Expect colon
                if index < tokens.count && tokens[index] == .colon {
                    index += 1
                } else {
                    errors.append("Missing colon after key: \(key)")
                }
                
                skipWhitespace()
                
                // Special handling for coordinates and similar array-like patterns
                if key == "coordinates" || key.contains("coordinate") || key.contains("position") || key.contains("point") || 
                   key == "location" || key == "bounds" || key == "bbox" || key == "extent" {
                    // Check if we have an array starting with [ 
                    if index < tokens.count && tokens[index] == .leftBracket {
                        // Normal array parsing but with missing bracket detection
                        let value = parseArray()
                        
                        skipWhitespace()
                        
                        // Check for comma
                        let hasComma = index < tokens.count && tokens[index] == .comma
                        if hasComma {
                            index += 1
                        }
                        
                        members.append(ParseNode.ObjectMember(key: key, value: value, hasComma: hasComma, keyWasUnterminated: keyWasUnterminated))
                        skipWhitespace()
                        continue
                    }
                    // Check if we have numbers without opening bracket
                    // This includes negative numbers that might start an array
                    else if index < tokens.count {
                        // Look ahead to see if we have number(s) followed by closing bracket
                        var peekIndex = index
                        var hasNumbers = false
                        var hasClosingBracket = false
                        
                        // Scan ahead to detect pattern: number [, number]* ]
                        while peekIndex < tokens.count {
                            switch tokens[peekIndex] {
                            case .number:
                                hasNumbers = true
                                peekIndex += 1
                            case .comma:
                                peekIndex += 1
                            case .whitespace:
                                peekIndex += 1
                            case .rightBracket:
                                hasClosingBracket = true
                                peekIndex += 1
                                break
                            default:
                                break
                            }
                            if hasClosingBracket {
                                break
                            }
                            // Check if we've hit something that's not part of an array
                            switch tokens[peekIndex] {
                            case .comma, .whitespace, .number:
                                continue  // These are expected in arrays
                            default:
                                break  // Exit the loop for any other token
                            }
                        }
                        
                        // If we have numbers followed by a closing bracket, it's a missing opening bracket
                        if hasNumbers && hasClosingBracket {
                            // We have a number but missing opening bracket
                            var elements: [ParseNode] = []
                            
                            // Collect numbers and commas until we hit a closing bracket
                            while index < tokens.count {
                                switch tokens[index] {
                                case .number(let num):
                                    elements.append(.number(num))
                                    index += 1
                                    skipWhitespace()
                                case .comma:
                                    index += 1
                                    skipWhitespace()
                                case .rightBracket:
                                    // Found closing bracket - array was missing opening bracket
                                    index += 1
                                    errors.append("Fixed missing opening bracket [ for coordinates array")
                                    break
                                default:
                                    // End of array elements
                                    break
                                }
                                
                                if index >= tokens.count || tokens[index - 1] == .rightBracket {
                                    break
                                }
                            }
                            
                            // Create array node
                            let value = ParseNode.array(elements)
                            
                            skipWhitespace()
                            
                            // Check for comma
                            let hasComma = index < tokens.count && tokens[index] == .comma
                            if hasComma {
                                index += 1
                            }
                            
                            members.append(ParseNode.ObjectMember(key: key, value: value, hasComma: hasComma, keyWasUnterminated: keyWasUnterminated))
                            skipWhitespace()
                            continue
                        }
                    }
                }
                
                // Check if next token looks like object content without opening brace
                if index < tokens.count, case .string = tokens[index] {
                    // Peek ahead to see if this looks like a key:value pair (missing opening brace)
                    var peekIndex = index + 1
                    while peekIndex < tokens.count && tokens[peekIndex] == .whitespace {
                        peekIndex += 1
                    }
                    if peekIndex < tokens.count && tokens[peekIndex] == .colon {
                        // This is a key:value pair but we're expecting a value
                        // This means we're missing an opening brace for an object
                        errors.append("Missing opening brace { for object after key: \(key)")
                        
                        // Create an object by parsing the members
                        var objectMembers: [ParseNode.ObjectMember] = []
                        
                        // Parse the object members without the opening brace
                        while index < tokens.count && tokens[index] != .rightBrace && tokens[index] != .comma && tokens[index] != .eof {
                            // Parse key
                            skipWhitespace()
                            guard case .string(let objKey, _) = tokens[index] else {
                                break
                            }
                            index += 1
                            skipWhitespace()
                            
                            // Expect colon
                            if index < tokens.count && tokens[index] == .colon {
                                index += 1
                            } else {
                                errors.append("Missing colon after key: \(objKey)")
                            }
                            
                            skipWhitespace()
                            
                            // Parse value for this object member
                            guard let objValue = parseValue() else {
                                errors.append("Missing value for key: \(objKey)")
                                break
                            }
                            
                            skipWhitespace()
                            
                            // Check for comma
                            let objHasComma = index < tokens.count && tokens[index] == .comma
                            if objHasComma {
                                index += 1
                            }
                            
                            objectMembers.append(ParseNode.ObjectMember(key: objKey, value: objValue, hasComma: objHasComma, keyWasUnterminated: false))
                            skipWhitespace()
                            
                            // Check if we hit the closing brace for this object
                            if index < tokens.count && tokens[index] == .rightBrace {
                                index += 1
                                break
                            }
                        }
                        
                        let value = ParseNode.object(objectMembers)
                        
                        skipWhitespace()
                        
                        // Check for comma
                        let hasComma = index < tokens.count && tokens[index] == .comma
                        if hasComma {
                            index += 1
                        }
                        
                        members.append(ParseNode.ObjectMember(key: key, value: value, hasComma: hasComma, keyWasUnterminated: keyWasUnterminated))
                        skipWhitespace()
                        continue
                    }
                }
                
                // Normal value parsing
                guard let value = parseValue() else {
                    errors.append("Missing value for key: \(key)")
                    continue
                }
                
                skipWhitespace()
                
                // Check for comma
                let hasComma = index < tokens.count && tokens[index] == .comma
                if hasComma {
                    index += 1
                }
                
                members.append(ParseNode.ObjectMember(key: key, value: value, hasComma: hasComma, keyWasUnterminated: keyWasUnterminated))
                skipWhitespace()
            }
            
            // Check for closing brace
            if index < tokens.count && tokens[index] == .rightBrace {
                index += 1
            } else {
                errors.append("Fixed unterminated object (missing })")
                wasUnterminated = true
            }
            
            return .object(members, wasUnterminated: wasUnterminated)
        }
        
        func parseArray() -> ParseNode {
            var elements: [ParseNode] = []
            var wasUnterminated = false
            index += 1 // skip [
            skipWhitespace()
            
            while index < tokens.count && tokens[index] != .rightBracket && tokens[index] != .eof {
                if tokens[index] == .comma {
                    // Extra comma, skip it
                    index += 1
                    skipWhitespace()
                    continue
                }
                
                // Check if we hit a closing brace (wrong bracket type) or other structural element
                if tokens[index] == .rightBrace {
                    // This might be end of parent object, stop parsing array
                    errors.append("Missing closing bracket ] for array - found }")
                    // The reconstruction will add the missing ]
                    break
                }
                
                // Check for other structural tokens that indicate we've gone too far
                if case .string = tokens[index] {
                    // Peek ahead to see if this is a key (has : after it)
                    var peekIndex = index + 1
                    while peekIndex < tokens.count && tokens[peekIndex] == .whitespace {
                        peekIndex += 1
                    }
                    if peekIndex < tokens.count && tokens[peekIndex] == .colon {
                        // This is a key:value pair, we've gone past the array
                        errors.append("Missing closing bracket ] for array")
                        break
                    }
                }
                
                guard let value = parseValue() else {
                    errors.append("Invalid array element")
                    index += 1
                    continue
                }
                
                elements.append(value)
                skipWhitespace()
                
                // Check for comma
                if index < tokens.count && tokens[index] == .comma {
                    index += 1
                    skipWhitespace()
                } else if index < tokens.count && tokens[index] != .rightBracket && tokens[index] != .rightBrace && tokens[index] != .eof {
                    // Check if next token suggests end of array
                    if case .string = tokens[index] {
                        // Might be next object key
                        var peekIndex = index + 1
                        while peekIndex < tokens.count && tokens[peekIndex] == .whitespace {
                            peekIndex += 1
                        }
                        if peekIndex < tokens.count && tokens[peekIndex] == .colon {
                            // Next object member, array is done
                            errors.append("Missing closing bracket ] for array")
                            break
                        }
                    }
                    // Otherwise it's a missing comma
                    errors.append("Missing comma between array elements")
                }
            }
            
            // Check for closing bracket
            if index < tokens.count && tokens[index] == .rightBracket {
                index += 1
            } else if index < tokens.count && tokens[index] == .rightBrace {
                // Wrong bracket type - don't consume it, might be for parent
                errors.append("Missing closing bracket ] for array (found })")
            } else {
                errors.append("Fixed unterminated array (missing ])")
                wasUnterminated = true
            }
            
            return .array(elements, wasUnterminated: wasUnterminated)
        }
        
        let tree = parseValue()
        return (tree, errors)
    }
    
    // Reconstruct valid JSON from parse tree
    private func reconstructJSON(from tree: ParseNode?, fixes: inout [String]) -> String {
        guard let tree = tree else { return "{}" }
        
        func nodeToJSON(_ node: ParseNode, indent: Int = 0) -> String {
            let indentStr = String(repeating: "  ", count: indent)
            let nextIndentStr = String(repeating: "  ", count: indent + 1)
            
            switch node {
            case .object(let members, let wasUnterminated):
                if wasUnterminated {
                    // This was already tracked in parseObject errors
                }
                if members.isEmpty {
                    return "{}"
                }
                
                var result = "{\n"
                for (index, member) in members.enumerated() {
                    result += nextIndentStr + "\"\(member.key)\": "
                    let valueStr = nodeToJSON(member.value, indent: indent + 1)
                    result += valueStr
                    
                    // Add comma if not last item
                    if index < members.count - 1 {
                        result += ","
                        if !member.hasComma {
                            fixes.append("Added missing comma after \(member.key)")
                        }
                    } else if member.hasComma {
                        fixes.append("Removed trailing comma after \(member.key)")
                    }
                    result += "\n"
                }
                result += indentStr + "}"
                return result
                
            case .array(let elements, let wasUnterminated):
                if wasUnterminated {
                    // This was already tracked in parseArray errors
                }
                if elements.isEmpty {
                    return "[]"
                }
                
                var result = "[\n"
                for (index, element) in elements.enumerated() {
                    result += nextIndentStr
                    result += nodeToJSON(element, indent: indent + 1)
                    if index < elements.count - 1 {
                        result += ","
                    }
                    result += "\n"
                }
                result += indentStr + "]"
                return result
                
            case .string(let str, let wasUnterminated):
                if wasUnterminated {
                    // This was already tracked in tokenizer
                }
                // Escape the string properly
                let escaped = str
                    .replacingOccurrences(of: "\\", with: "\\\\")
                    .replacingOccurrences(of: "\"", with: "\\\"")
                    .replacingOccurrences(of: "\n", with: "\\n")
                    .replacingOccurrences(of: "\r", with: "\\r")
                    .replacingOccurrences(of: "\t", with: "\\t")
                return "\"\(escaped)\""
                
            case .number(let num):
                if num.truncatingRemainder(dividingBy: 1) == 0 {
                    return String(Int(num))
                }
                return String(num)
                
            case .boolean(let bool):
                return bool ? "true" : "false"
                
            case .null:
                return "null"
                
            case .error(let msg, let recovered):
                fixes.append("Error recovered: \(msg)")
                if let recovered = recovered {
                    return nodeToJSON(recovered, indent: indent)
                }
                return "null"
            }
        }
        
        return nodeToJSON(tree)
    }
}