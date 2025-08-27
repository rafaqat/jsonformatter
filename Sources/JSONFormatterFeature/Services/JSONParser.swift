import Foundation

/// A JSON parser with precise character-level error tracking
/// Based on Douglas Crockford's recursive descent parser approach
public actor JSONParser {
    
    // Parser state
    private var text: String = ""
    private var at: Int = 0  // Current character position
    private var ch: Character = " "  // Current character
    private var line: Int = 1
    private var column: Int = 1
    private var errors: [JSONError] = []
    
    // Position tracking
    struct Position {
        let offset: Int
        let line: Int
        let column: Int
    }
    
    // Track positions for error recovery
    private var positions: [Position] = []
    
    public init() {}
    
    // MARK: - Public API
    
    public func parse(_ jsonString: String) async throws -> JSONNode {
        // Reset state
        text = jsonString
        at = 0
        line = 1
        column = 1
        errors = []
        positions = []
        
        // Initialize with first character
        if !text.isEmpty {
            ch = text[text.startIndex]
        } else {
            throw createError("Empty JSON string")
        }
        
        // Parse and validate
        do {
            let result = try value()
            try white()
            
            // Check for trailing content
            if at < text.count {
                throw createError("Unexpected trailing content after JSON value")
            }
            
            return result
        } catch {
            // Collect all errors found during parsing
            if let jsonError = error as? JSONError {
                errors.append(jsonError)
            }
            
            // Try to recover and find more errors
            tryRecoverAndFindMoreErrors()
            
            // Throw with all collected errors
            if errors.count > 1 {
                throw PreciseJSONParsingError(errors: errors)
            } else {
                throw error
            }
        }
    }
    
    public func validate(_ jsonString: String) async -> [JSONError] {
        do {
            _ = try await parse(jsonString)
            return []
        } catch let error as PreciseJSONParsingError {
            return error.errors
        } catch let error as JSONError {
            return [error]
        } catch {
            return [JSONError(
                line: line,
                column: column,
                message: error.localizedDescription,
                severity: .error
            )]
        }
    }
    
    // MARK: - Character Navigation
    
    private func next(_ expected: Character? = nil) throws {
        // Move to next character
        if let expected = expected {
            if ch != expected {
                throw createError("Expected '\(expected)' but found '\(ch)'")
            }
        }
        
        // Track position before moving
        positions.append(Position(offset: at, line: line, column: column))
        
        // Update position tracking
        if ch == "\n" {
            line += 1
            column = 1
        } else if ch == "\r" {
            line += 1
            column = 1
            // Handle \r\n as single newline
            if at + 1 < text.count {
                let nextIndex = text.index(text.startIndex, offsetBy: at + 1)
                if text[nextIndex] == "\n" {
                    at += 1
                }
            }
        } else if ch == "\t" {
            column += 4  // Tab counts as 4 spaces
        } else {
            column += 1
        }
        
        at += 1
        if at < text.count {
            let index = text.index(text.startIndex, offsetBy: at)
            ch = text[index]
        } else {
            ch = "\0"  // End of string marker
        }
    }
    
    private func peek(ahead: Int = 1) -> Character? {
        let peekPosition = at + ahead
        if peekPosition < text.count {
            let index = text.index(text.startIndex, offsetBy: peekPosition)
            return text[index]
        }
        return nil
    }
    
    // MARK: - Whitespace
    
    private func white() throws {
        while ch == " " || ch == "\t" || ch == "\n" || ch == "\r" {
            try next()
        }
    }
    
    // MARK: - Values
    
    private func value() throws -> JSONNode {
        try white()
        
        switch ch {
        case "\"":
            return try string()
        case "{":
            return try object()
        case "[":
            return try array()
        case "t", "f":
            return try boolean()
        case "n":
            return try null()
        case "-", "0"..."9":
            return try number()
        default:
            throw createError("Unexpected character '\(ch)' at start of value")
        }
    }
    
    // MARK: - String Parsing
    
    private func string() throws -> JSONNode {
        var result = ""
        let startLine = line
        let startColumn = column
        
        try next("\"")  // Opening quote
        
        while ch != "\"" && ch != "\0" {
            if ch == "\\" {
                try next()
                switch ch {
                case "\"", "\\", "/":
                    result.append(ch)
                case "b":
                    result.append("\u{0008}")
                case "f":
                    result.append("\u{000C}")
                case "n":
                    result.append("\n")
                case "r":
                    result.append("\r")
                case "t":
                    result.append("\t")
                case "u":
                    // Unicode escape - handle surrogate pairs
                    var hex = ""
                    for _ in 0..<4 {
                        try next()
                        if ch.isHexDigit {
                            hex.append(ch)
                        } else {
                            throw createError("Invalid unicode escape sequence")
                        }
                    }
                    
                    guard let codePoint = Int(hex, radix: 16) else {
                        throw createError("Invalid unicode escape sequence")
                    }
                    
                    // Check for UTF-16 surrogate pairs
                    if (0xD800...0xDBFF).contains(codePoint) {
                        // High surrogate - look for low surrogate
                        let savedAt = at
                        let savedLine = line
                        let savedColumn = column
                        let savedCh = ch
                        
                        // Try to read next \uXXXX
                        try next()  // Move past current position
                        if ch == "\\" {
                            try next()
                            if ch == "u" {
                                var lowHex = ""
                                for _ in 0..<4 {
                                    try next()
                                    if ch.isHexDigit {
                                        lowHex.append(ch)
                                    } else {
                                        // Not a valid low surrogate, restore position
                                        at = savedAt
                                        line = savedLine
                                        column = savedColumn
                                        ch = savedCh
                                        throw createError("Invalid surrogate pair: expected low surrogate")
                                    }
                                }
                                
                                if let lowCode = Int(lowHex, radix: 16),
                                   (0xDC00...0xDFFF).contains(lowCode) {
                                    // Valid surrogate pair - compose to single code point
                                    let high = codePoint - 0xD800
                                    let low = lowCode - 0xDC00
                                    let composed = 0x10000 + (high << 10) + low
                                    
                                    if let scalar = UnicodeScalar(composed) {
                                        result.append(Character(scalar))
                                    } else {
                                        throw createError("Invalid composed unicode code point")
                                    }
                                } else {
                                    // Not a valid low surrogate
                                    at = savedAt
                                    line = savedLine
                                    column = savedColumn
                                    ch = savedCh
                                    throw createError("Invalid surrogate pair: expected low surrogate (DC00-DFFF)")
                                }
                            } else {
                                // No \u following
                                at = savedAt
                                line = savedLine
                                column = savedColumn
                                ch = savedCh
                                throw createError("Invalid surrogate pair: high surrogate without low surrogate")
                            }
                        } else {
                            // No backslash following
                            at = savedAt
                            line = savedLine
                            column = savedColumn
                            ch = savedCh
                            throw createError("Invalid surrogate pair: high surrogate without low surrogate")
                        }
                    } else if (0xDC00...0xDFFF).contains(codePoint) {
                        // Lone low surrogate - invalid
                        throw createError("Invalid unicode code point: unexpected low surrogate")
                    } else {
                        // Normal BMP character
                        if let scalar = UnicodeScalar(codePoint) {
                            result.append(Character(scalar))
                        } else {
                            throw createError("Invalid unicode code point")
                        }
                    }
                default:
                    throw createError("Invalid escape sequence '\\(ch)'")
                }
            } else if ch.isNewline {
                throw createError("Unterminated string (started at line \(startLine), column \(startColumn))")
            } else {
                result.append(ch)
            }
            try next()
        }
        
        if ch != "\"" {
            throw createError("Unterminated string (started at line \(startLine), column \(startColumn))")
        }
        
        try next("\"")  // Closing quote
        return .string(result)
    }
    
    // MARK: - Number Parsing
    
    private func number() throws -> JSONNode {
        var numStr = ""
        let startColumn = column
        
        // Handle negative
        if ch == "-" {
            numStr.append(ch)
            try next()
            if !ch.isNumber {
                throw createError("Invalid number: expected digit after '-'")
            }
        }
        
        // Integer part
        if ch == "0" {
            numStr.append(ch)
            try next()
            // Leading zeros not allowed except for "0"
            if ch.isNumber {
                throw createError("Invalid number: leading zeros not allowed")
            }
        } else {
            while ch.isNumber {
                numStr.append(ch)
                try next()
            }
        }
        
        // Fractional part
        if ch == "." {
            numStr.append(ch)
            try next()
            if !ch.isNumber {
                throw createError("Invalid number: expected digit after decimal point")
            }
            while ch.isNumber {
                numStr.append(ch)
                try next()
            }
        }
        
        // Exponent part
        if ch == "e" || ch == "E" {
            numStr.append(ch)
            try next()
            if ch == "+" || ch == "-" {
                numStr.append(ch)
                try next()
            }
            if !ch.isNumber {
                throw createError("Invalid number: expected digit in exponent")
            }
            while ch.isNumber {
                numStr.append(ch)
                try next()
            }
        }
        
        guard let value = Double(numStr) else {
            throw createError("Invalid number format at column \(startColumn)")
        }
        
        return .number(value)
    }
    
    // MARK: - Boolean Parsing
    
    private func boolean() throws -> JSONNode {
        if ch == "t" {
            try expectWord("true")
            return .boolean(true)
        } else {
            try expectWord("false")
            return .boolean(false)
        }
    }
    
    // MARK: - Null Parsing
    
    private func null() throws -> JSONNode {
        try expectWord("null")
        return .null
    }
    
    // MARK: - Object Parsing
    
    private func object() throws -> JSONNode {
        var dict: [String: JSONNode] = [:]
        let startLine = line
        let startColumn = column
        
        try next("{")
        try white()
        
        if ch == "}" {
            try next("}")
            return .object(dict)
        }
        
        while true {
            // Parse key
            try white()
            if ch != "\"" {
                throw createError("Expected string key in object, found '\(ch)'")
            }
            
            guard case .string(let key) = try string() else {
                throw createError("Object key must be a string")
            }
            
            // Check for duplicate keys
            if dict[key] != nil {
                errors.append(createError("Duplicate key '\(key)' in object", severity: .warning))
            }
            
            try white()
            try next(":")
            
            // Parse value
            dict[key] = try value()
            
            try white()
            if ch == "}" {
                break
            }
            
            if ch != "," {
                throw createError("Expected ',' or '}' after object member, found '\(ch)'")
            }
            try next(",")
            try white()
            
            // Check for trailing comma
            if ch == "}" {
                throw createError("Trailing comma in object (started at line \(startLine), column \(startColumn))")
            }
        }
        
        try next("}")
        return .object(dict)
    }
    
    // MARK: - Array Parsing
    
    private func array() throws -> JSONNode {
        var items: [JSONNode] = []
        let startLine = line
        let startColumn = column
        
        try next("[")
        try white()
        
        if ch == "]" {
            try next("]")
            return .array(items)
        }
        
        while true {
            items.append(try value())
            
            try white()
            if ch == "]" {
                break
            }
            
            if ch != "," {
                throw createError("Expected ',' or ']' after array element, found '\(ch)'")
            }
            try next(",")
            try white()
            
            // Check for trailing comma
            if ch == "]" {
                throw createError("Trailing comma in array (started at line \(startLine), column \(startColumn))")
            }
        }
        
        try next("]")
        return .array(items)
    }
    
    // MARK: - Helper Methods
    
    private func expectWord(_ word: String) throws {
        for expectedChar in word {
            if ch != expectedChar {
                throw createError("Expected '\(word)' but found unexpected character '\(ch)'")
            }
            try next()
        }
    }
    
    private func createError(_ message: String, severity: ErrorSeverity = .error) -> JSONError {
        let suggestion = getSuggestion(for: message)
        return JSONError(
            line: line,
            column: column,
            message: message,
            severity: severity,
            suggestion: suggestion
        )
    }
    
    private func getSuggestion(for message: String) -> String? {
        if message.contains("Trailing comma") {
            return "Remove the trailing comma"
        } else if message.contains("Expected string key") {
            return "Add quotes around the property name"
        } else if message.contains("Unterminated string") {
            return "Add closing quote"
        } else if message.contains("Expected ',' or") {
            return "Add a comma between elements"
        } else if message.contains("Duplicate key") {
            return "Remove or rename the duplicate key"
        } else if message.contains("Invalid escape sequence") {
            return "Use a valid escape sequence"
        } else if message.contains("leading zeros") {
            return "Remove leading zeros from the number"
        }
        return "Use Auto-Fix to correct common JSON issues"
    }
    
    // MARK: - Error Recovery
    
    private func tryRecoverAndFindMoreErrors() {
        // Try to find more errors by continuing parsing
        // This is a simplified recovery mechanism
        while at < text.count {
            // Skip to next potential value start
            while at < text.count && !isValueStart(ch) {
                do {
                    try next()
                } catch {
                    break
                }
            }
            
            if at >= text.count {
                break
            }
            
            // Try to parse next value
            do {
                _ = try value()
            } catch let error as JSONError {
                errors.append(error)
            } catch {
                // Ignore other errors during recovery
            }
        }
    }
    
    private func isValueStart(_ char: Character) -> Bool {
        return char == "\"" || char == "{" || char == "[" ||
               char == "t" || char == "f" || char == "n" ||
               char == "-" || char.isNumber
    }
}

// MARK: - Error Types

public struct PreciseJSONParsingError: Error {
    public let errors: [JSONError]
    
    public var localizedDescription: String {
        errors.map { "Line \($0.line), Column \($0.column): \($0.message)" }.joined(separator: "\n")
    }
}

// MARK: - Extensions

extension Character {
    var isNewline: Bool {
        return self == "\n" || self == "\r"
    }
}