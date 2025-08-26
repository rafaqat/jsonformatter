import Foundation

/// Tree-walking JSON fixer that builds a partial parse tree and walks back up to detect missing braces/brackets
public actor TreeWalkingJSONFixer {
    
    public init() {}
    
    // Token types for lexical analysis
    private enum Token: Equatable {
        case leftBrace      // {
        case rightBrace     // }
        case leftBracket    // [
        case rightBracket   // ]
        case colon          // :
        case comma          // ,
        case string(String)
        case number(Double)
        case boolean(Bool)
        case null
        case whitespace
        case unknown(String)
        case eof
    }
    
    // Parse tree node with position tracking
    private class ParseNode {
        enum NodeType {
            case object([ObjectMember])
            case array([ParseNode])
            case string(String)
            case number(Double)
            case boolean(Bool)
            case null
            case error(String)  // Represents parse error
        }
        
        struct ObjectMember {
            let key: String
            let value: ParseNode
            let hasComma: Bool
        }
        
        let type: NodeType
        let startToken: Int  // Token index where this node starts
        let endToken: Int    // Token index where this node ends
        var parent: ParseNode?  // Parent node reference for tree walking
        var depth: Int = 0  // Depth in tree
        
        // Brace/bracket tracking
        var openBraces: Int = 0
        var closeBraces: Int = 0
        var openBrackets: Int = 0
        var closeBrackets: Int = 0
        
        init(type: NodeType, startToken: Int, endToken: Int) {
            self.type = type
            self.startToken = startToken
            self.endToken = endToken
        }
    }
    
    public struct FixResult: Sendable {
        public let fixed: String
        public let wasFixed: Bool
        public let fixes: [String]
    }
    
    // Main fix function
    public func fix(_ jsonString: String) async -> FixResult {
        guard !jsonString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return FixResult(fixed: "{}", wasFixed: false, fixes: [])
        }
        
        var fixes: [String] = []
        
        // Tokenize
        let tokens = tokenize(jsonString)
        
        // Build parse tree with error recovery and parent tracking
        let (root, parseErrors) = buildParseTree(tokens)
        
        // Walk the tree to detect and fix structural issues
        let structuralFixes = walkTreeAndDetectIssues(root, tokens: tokens)
        fixes.append(contentsOf: structuralFixes)
        
        // Reconstruct JSON from the fixed tree
        let reconstructed = reconstructJSON(from: root, fixes: &fixes)
        
        // Add parse errors to fixes
        fixes.append(contentsOf: parseErrors)
        
        return FixResult(
            fixed: reconstructed,
            wasFixed: !fixes.isEmpty,
            fixes: fixes
        )
    }
    
    // Tree walking to detect structural issues
    private func walkTreeAndDetectIssues(_ root: ParseNode?, tokens: [Token]) -> [String] {
        guard let root = root else { return [] }
        
        var fixes: [String] = []
        var nodeStack: [ParseNode] = [root]
        
        while !nodeStack.isEmpty {
            let node = nodeStack.removeLast()
            
            // Count braces/brackets in this node's token range
            countDelimiters(in: tokens, from: node.startToken, to: node.endToken, node: node)
            
            // Check for mismatches
            if node.openBraces > node.closeBraces {
                let missing = node.openBraces - node.closeBraces
                fixes.append("Missing \(missing) closing brace(s) }")
                
                // Fix by adding missing closing braces to the node
                if case .object = node.type {
                    // Mark that we need closing braces
                    node.closeBraces = node.openBraces
                }
            } else if node.closeBraces > node.openBraces {
                let missing = node.closeBraces - node.openBraces
                fixes.append("Missing \(missing) opening brace(s) {")
                
                // Fix by marking we need opening braces
                node.openBraces = node.closeBraces
            }
            
            if node.openBrackets > node.closeBrackets {
                let missing = node.openBrackets - node.closeBrackets
                fixes.append("Missing \(missing) closing bracket(s) ]")
                
                // Fix by adding missing closing brackets
                if case .array = node.type {
                    node.closeBrackets = node.openBrackets
                }
            } else if node.closeBrackets > node.openBrackets {
                let missing = node.closeBrackets - node.openBrackets
                fixes.append("Missing \(missing) opening bracket(s) [")
                
                // Fix by marking we need opening brackets
                node.openBrackets = node.closeBrackets
            }
            
            // Walk back up to parent and check context
            if let parent = node.parent {
                checkParentChildRelationship(parent: parent, child: node, fixes: &fixes)
            }
            
            // Add children to stack for processing
            switch node.type {
            case .object(let members):
                for member in members {
                    nodeStack.append(member.value)
                }
            case .array(let elements):
                nodeStack.append(contentsOf: elements)
            default:
                break
            }
        }
        
        return fixes
    }
    
    // Check parent-child relationship for structural issues
    private func checkParentChildRelationship(parent: ParseNode, child: ParseNode, fixes: inout [String]) {
        // Check if child's delimiters match parent's expectations
        switch (parent.type, child.type) {
        case (.object, .object):
            // Object within object - child should have balanced braces
            if child.openBraces != child.closeBraces {
                fixes.append("Nested object has unbalanced braces")
            }
        case (.array, .object):
            // Object within array - should have balanced braces
            if child.openBraces != child.closeBraces {
                fixes.append("Object in array has unbalanced braces")
            }
        case (.object, .array):
            // Array within object - should have balanced brackets
            if child.openBrackets != child.closeBrackets {
                fixes.append("Array in object has unbalanced brackets")
            }
        case (.array, .array):
            // Nested array - should have balanced brackets
            if child.openBrackets != child.closeBrackets {
                fixes.append("Nested array has unbalanced brackets")
            }
        default:
            break
        }
    }
    
    // Count delimiters in token range
    private func countDelimiters(in tokens: [Token], from start: Int, to end: Int, node: ParseNode) {
        let endIndex = min(end, tokens.count - 1)
        for i in start...endIndex {
            switch tokens[i] {
            case .leftBrace:
                node.openBraces += 1
            case .rightBrace:
                node.closeBraces += 1
            case .leftBracket:
                node.openBrackets += 1
            case .rightBracket:
                node.closeBrackets += 1
            default:
                break
            }
        }
    }
    
    // Tokenizer
    private func tokenize(_ input: String) -> [Token] {
        var tokens: [Token] = []
        let chars = Array(input)
        var i = 0
        
        while i < chars.count {
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
            case ":":
                tokens.append(.colon)
                i += 1
            case ",":
                tokens.append(.comma)
                i += 1
            case "\"":
                if let (str, newIndex) = parseString(chars, from: i) {
                    tokens.append(.string(str))
                    i = newIndex
                } else {
                    i += 1
                }
            case "'":
                // Handle single quotes as strings
                if let (str, newIndex) = parseSingleQuoteString(chars, from: i) {
                    tokens.append(.string(str))
                    i = newIndex
                } else {
                    i += 1
                }
            case "-", "0"..."9":
                if let (num, newIndex) = parseNumber(chars, from: i) {
                    tokens.append(.number(num))
                    i = newIndex
                } else {
                    i += 1
                }
            case "t", "f":
                if let newIndex = parseBoolean(chars, from: i, isTrue: char == "t") {
                    tokens.append(.boolean(char == "t"))
                    i = newIndex
                } else if let (str, newIndex) = parseUnquotedString(chars, from: i) {
                    tokens.append(.unknown(str))
                    i = newIndex
                } else {
                    i += 1
                }
            case "n":
                if let newIndex = parseNull(chars, from: i) {
                    tokens.append(.null)
                    i = newIndex
                } else if let (str, newIndex) = parseUnquotedString(chars, from: i) {
                    tokens.append(.unknown(str))
                    i = newIndex
                } else {
                    i += 1
                }
            case " ", "\t", "\n", "\r":
                tokens.append(.whitespace)
                i += 1
            default:
                if char.isLetter || char == "_" {
                    if let (str, newIndex) = parseUnquotedString(chars, from: i) {
                        tokens.append(.unknown(str))
                        i = newIndex
                    } else {
                        i += 1
                    }
                } else {
                    i += 1
                }
            }
        }
        
        tokens.append(.eof)
        return tokens
    }
    
    // Parse tree builder with parent tracking
    private func buildParseTree(_ tokens: [Token]) -> (ParseNode?, [String]) {
        var index = 0
        var errors: [String] = []
        
        func skipWhitespace() {
            while index < tokens.count && tokens[index] == .whitespace {
                index += 1
            }
        }
        
        func parseValue(parent: ParseNode? = nil) -> ParseNode? {
            skipWhitespace()
            guard index < tokens.count else { return nil }
            
            let startToken = index
            var node: ParseNode?
            
            switch tokens[index] {
            case .leftBrace:
                node = parseObject(parent: parent)
            case .leftBracket:
                node = parseArray(parent: parent)
            case .string(let str):
                index += 1
                node = ParseNode(type: .string(str), startToken: startToken, endToken: index - 1)
            case .number(let num):
                index += 1
                node = ParseNode(type: .number(num), startToken: startToken, endToken: index - 1)
            case .boolean(let bool):
                index += 1
                node = ParseNode(type: .boolean(bool), startToken: startToken, endToken: index - 1)
            case .null:
                index += 1
                node = ParseNode(type: .null, startToken: startToken, endToken: index - 1)
            case .unknown(let str):
                index += 1
                errors.append("Unquoted value: \(str)")
                node = ParseNode(type: .string(str), startToken: startToken, endToken: index - 1)
            default:
                // Check if we're missing an opening delimiter
                if case .string = tokens[index], index + 1 < tokens.count {
                    // Peek ahead for colon (indicates missing opening brace)
                    var peekIndex = index + 1
                    while peekIndex < tokens.count && tokens[peekIndex] == .whitespace {
                        peekIndex += 1
                    }
                    if peekIndex < tokens.count && tokens[peekIndex] == .colon {
                        errors.append("Missing opening brace { detected")
                        // Parse as object without opening brace
                        node = parseObjectWithoutBrace(parent: parent)
                    }
                } else if case .number = tokens[index] {
                    // Check if this might be array elements without opening bracket
                    errors.append("Missing opening bracket [ detected")
                    node = parseArrayWithoutBracket(parent: parent)
                }
                
                if node == nil {
                    errors.append("Unexpected token at position \(index)")
                    index += 1
                }
            }
            
            if let node = node {
                node.parent = parent
                node.depth = (parent?.depth ?? -1) + 1
            }
            
            return node
        }
        
        func parseObject(parent: ParseNode? = nil) -> ParseNode {
            let startToken = index
            var members: [ParseNode.ObjectMember] = []
            index += 1 // skip {
            skipWhitespace()
            
            while index < tokens.count && tokens[index] != .rightBrace && tokens[index] != .eof {
                // Parse key
                skipWhitespace()
                guard index < tokens.count else { break }
                
                let key: String
                switch tokens[index] {
                case .string(let str):
                    key = str
                    index += 1
                case .unknown(let str):
                    key = str
                    index += 1
                    errors.append("Unquoted key: \(str)")
                case .comma:
                    // Extra comma, skip
                    index += 1
                    continue
                default:
                    errors.append("Expected key at position \(index)")
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
                
                // Parse value
                let node = ParseNode(type: .object(members), startToken: startToken, endToken: index)
                node.parent = parent
                node.depth = (parent?.depth ?? -1) + 1
                
                guard let value = parseValue(parent: node) else {
                    errors.append("Missing value for key: \(key)")
                    continue
                }
                
                skipWhitespace()
                
                // Check for comma
                let hasComma = index < tokens.count && tokens[index] == .comma
                if hasComma {
                    index += 1
                }
                
                members.append(ParseNode.ObjectMember(key: key, value: value, hasComma: hasComma))
                skipWhitespace()
            }
            
            // Check for closing brace
            let endToken = index
            if index < tokens.count && tokens[index] == .rightBrace {
                index += 1
            } else {
                errors.append("Missing closing brace }")
            }
            
            let node = ParseNode(type: .object(members), startToken: startToken, endToken: endToken)
            node.parent = parent
            node.depth = (parent?.depth ?? -1) + 1
            return node
        }
        
        func parseObjectWithoutBrace(parent: ParseNode? = nil) -> ParseNode {
            let startToken = index
            var members: [ParseNode.ObjectMember] = []
            
            // Parse object members without opening brace
            while index < tokens.count && tokens[index] != .rightBrace && tokens[index] != .comma && tokens[index] != .eof {
                skipWhitespace()
                guard index < tokens.count else { break }
                
                guard case .string(let key) = tokens[index] else {
                    break
                }
                index += 1
                skipWhitespace()
                
                if index < tokens.count && tokens[index] == .colon {
                    index += 1
                }
                
                skipWhitespace()
                
                let node = ParseNode(type: .object(members), startToken: startToken, endToken: index)
                node.parent = parent
                node.depth = (parent?.depth ?? -1) + 1
                
                guard let value = parseValue(parent: node) else {
                    break
                }
                
                skipWhitespace()
                
                let hasComma = index < tokens.count && tokens[index] == .comma
                if hasComma {
                    index += 1
                }
                
                members.append(ParseNode.ObjectMember(key: key, value: value, hasComma: hasComma))
                skipWhitespace()
                
                if index < tokens.count && tokens[index] == .rightBrace {
                    index += 1
                    break
                }
            }
            
            let node = ParseNode(type: .object(members), startToken: startToken, endToken: index - 1)
            node.parent = parent
            node.depth = (parent?.depth ?? -1) + 1
            return node
        }
        
        func parseArray(parent: ParseNode? = nil) -> ParseNode {
            let startToken = index
            var elements: [ParseNode] = []
            index += 1 // skip [
            skipWhitespace()
            
            let node = ParseNode(type: .array(elements), startToken: startToken, endToken: index)
            node.parent = parent
            node.depth = (parent?.depth ?? -1) + 1
            
            while index < tokens.count && tokens[index] != .rightBracket && tokens[index] != .eof {
                if tokens[index] == .comma {
                    // Extra comma, skip
                    index += 1
                    skipWhitespace()
                    continue
                }
                
                guard let value = parseValue(parent: node) else {
                    errors.append("Invalid array element")
                    index += 1
                    continue
                }
                
                elements.append(value)
                skipWhitespace()
                
                if index < tokens.count && tokens[index] == .comma {
                    index += 1
                    skipWhitespace()
                }
            }
            
            // Check for closing bracket
            let endToken = index
            if index < tokens.count && tokens[index] == .rightBracket {
                index += 1
            } else {
                errors.append("Missing closing bracket ]")
            }
            
            // Update the node with final elements
            let finalNode = ParseNode(type: .array(elements), startToken: startToken, endToken: endToken)
            finalNode.parent = parent
            finalNode.depth = (parent?.depth ?? -1) + 1
            return finalNode
        }
        
        func parseArrayWithoutBracket(parent: ParseNode? = nil) -> ParseNode {
            let startToken = index
            var elements: [ParseNode] = []
            
            let node = ParseNode(type: .array(elements), startToken: startToken, endToken: index)
            node.parent = parent
            node.depth = (parent?.depth ?? -1) + 1
            
            // Collect numbers/values until we hit a closing bracket or other structure
            while index < tokens.count {
                switch tokens[index] {
                case .number, .string, .boolean, .null:
                    if let value = parseValue(parent: node) {
                        elements.append(value)
                    }
                    skipWhitespace()
                case .comma:
                    index += 1
                    skipWhitespace()
                case .rightBracket:
                    index += 1
                    errors.append("Found closing bracket ] without opening [")
                    let finalNode = ParseNode(type: .array(elements), startToken: startToken, endToken: index - 1)
                    finalNode.parent = parent
                    finalNode.depth = (parent?.depth ?? -1) + 1
                    return finalNode
                default:
                    let finalNode = ParseNode(type: .array(elements), startToken: startToken, endToken: index - 1)
                    finalNode.parent = parent
                    finalNode.depth = (parent?.depth ?? -1) + 1
                    return finalNode
                }
            }
            
            let finalNode = ParseNode(type: .array(elements), startToken: startToken, endToken: index - 1)
            finalNode.parent = parent
            finalNode.depth = (parent?.depth ?? -1) + 1
            return finalNode
        }
        
        let tree = parseValue()
        return (tree, errors)
    }
    
    // Helper parsing functions
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
            } else if char == "\\" {
                escapeNext = true
                result.append(char)
                i += 1
            } else if char == "\"" {
                i += 1
                return (result, i)
            } else {
                result.append(char)
                i += 1
            }
        }
        
        // Unclosed string
        return (result, i)
    }
    
    private func parseSingleQuoteString(_ chars: [Character], from start: Int) -> (String, Int)? {
        guard start < chars.count && chars[start] == "'" else { return nil }
        
        var result = ""
        var i = start + 1
        
        while i < chars.count {
            let char = chars[i]
            if char == "'" {
                i += 1
                return (result, i)
            } else {
                result.append(char)
                i += 1
            }
        }
        
        return (result, i)
    }
    
    private func parseNumber(_ chars: [Character], from start: Int) -> (Double, Int)? {
        var numStr = ""
        var i = start
        
        while i < chars.count {
            let char = chars[i]
            if char == "-" || char == "+" || char == "." || char == "e" || char == "E" || char.isNumber {
                numStr.append(char)
                i += 1
            } else {
                break
            }
        }
        
        guard let num = Double(numStr) else { return nil }
        return (num, i)
    }
    
    private func parseBoolean(_ chars: [Character], from start: Int, isTrue: Bool) -> Int? {
        let expected = isTrue ? "true" : "false"
        let remaining = String(chars[start...])
        
        if remaining.hasPrefix(expected) {
            return start + expected.count
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
        
        guard !result.isEmpty else { return nil }
        return (result, i)
    }
    
    // Reconstruct JSON from parse tree
    private func reconstructJSON(from tree: ParseNode?, fixes: inout [String]) -> String {
        guard let tree = tree else { return "{}" }
        
        func nodeToJSON(_ node: ParseNode, indent: Int = 0) -> String {
            let indentStr = String(repeating: "  ", count: indent)
            let nextIndentStr = String(repeating: "  ", count: indent + 1)
            
            switch node.type {
            case .object(let members):
                if members.isEmpty {
                    return "{}"
                }
                
                var result = "{\n"
                for (index, member) in members.enumerated() {
                    result += nextIndentStr + "\"\(member.key)\": "
                    
                    let valueStr = nodeToJSON(member.value, indent: indent + 1)
                    
                    // Check if value is multiline
                    if valueStr.contains("\n") && !isSimpleValue(member.value) {
                        result += valueStr
                    } else {
                        result += valueStr
                    }
                    
                    // Add comma if not last item (ignoring hasComma from parsing)
                    if index < members.count - 1 {
                        result += ","
                    }
                    result += "\n"
                }
                result += indentStr + "}"
                return result
                
            case .array(let elements):
                if elements.isEmpty {
                    return "[]"
                }
                
                // Check if all elements are simple values
                let allSimple = elements.allSatisfy { isSimpleValue($0) }
                
                if allSimple && elements.count <= 3 {
                    // Inline for simple arrays
                    let elemStrs = elements.map { nodeToJSON($0, indent: 0) }
                    return "[" + elemStrs.joined(separator: ", ") + "]"
                } else {
                    // Multi-line for complex arrays
                    var result = "[\n"
                    for (index, element) in elements.enumerated() {
                        result += nextIndentStr + nodeToJSON(element, indent: indent + 1)
                        if index < elements.count - 1 {
                            result += ","
                        }
                        result += "\n"
                    }
                    result += indentStr + "]"
                    return result
                }
                
            case .string(let str):
                return "\"\(str)\""
                
            case .number(let num):
                if num.truncatingRemainder(dividingBy: 1) == 0 {
                    return String(Int(num))
                } else {
                    return String(num)
                }
                
            case .boolean(let bool):
                return bool ? "true" : "false"
                
            case .null:
                return "null"
                
            case .error(let msg):
                fixes.append("Parse error: \(msg)")
                return "null"
            }
        }
        
        func isSimpleValue(_ node: ParseNode) -> Bool {
            switch node.type {
            case .string, .number, .boolean, .null:
                return true
            case .array(let elements):
                return elements.isEmpty || (elements.count <= 3 && elements.allSatisfy { isSimpleValue($0) })
            case .object(let members):
                return members.isEmpty
            case .error:
                return true
            }
        }
        
        return nodeToJSON(tree)
    }
}