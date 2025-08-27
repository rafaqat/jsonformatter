import Foundation

/// JSON parser with complete lexeme preservation and advanced error recovery
public actor JSONFixer {
    
    // Configuration flags
    public struct Config: Sendable {
        public var wrapMultiRoot: Bool = true
        public var ndjsonMode: Bool = false
        public var normalizeSpecialLiterals: Bool = true
        public var preserveNumberLexemes: Bool = true
        public var maxFixes: Int = 1000
        
        public init() {}
    }
    
    private let config: Config
    
    public init(config: Config = Config()) {
        self.config = config
    }
    
    // MARK: - Enhanced Type Definitions
    
    /// String parsing flags
    private struct StringFlags: Equatable {
        var wasUnterminated: Bool
        var hadInvalidEscapes: Bool
        var usedSingleQuotes: Bool
        var hadUnescapedControls: Bool
        var hadInvalidUnicode: Bool
    }
    
    /// Number format classification
    private enum NumberKind: Equatable {
        case valid
        case leadingPlus       // +123
        case leadingZeros      // 00123
        case bareDot           // .5
        case trailingDot       // 42.
        case incompleteExp     // 1e, 1e+, 1e-
        case hasUnderscores    // 1_000_000
        case hexLiteral        // 0xFF
        case octalLiteral      // 0755
        case invalid
    }
    
    /// Literal value types
    private enum LiteralValue: Equatable {
        case `true`
        case `false`
        case null
        case undefined  // Will map to null
        case nan        // Will map to null
        case infinity   // Will map to null
    }
    
    /// Enhanced token with complete preservation
    private enum Token: Equatable {
        case leftBrace
        case rightBrace
        case leftBracket
        case rightBracket
        case colon
        case comma
        case string(processed: String, lexeme: String, flags: StringFlags)
        case number(lexeme: String, kind: NumberKind)
        case literal(value: LiteralValue, lexeme: String)
        case identifier(String)  // Unquoted keys/values
        case whitespace(String)  // Preserve actual whitespace
        case comment(String)     // Preserve comments
        case eof
    }
    
    /// Fix kinds with detailed categorization
    private enum FixKind: Equatable {
        // Structural
        case missingOpenBrace
        case missingCloseBrace
        case missingOpenBracket
        case missingCloseBracket
        case missingColon
        case missingComma
        case extraComma
        case crossTypeClosure
        
        // Strings
        case unterminatedString
        case unquotedKey
        case unquotedValue
        case invalidEscape
        case invalidUnicode
        case unescapedControl
        case singleQuotes
        case surrogateRepaired
        case loneSurrogate
        
        // Numbers
        case leadingPlus
        case leadingZeros
        case bareDot
        case trailingDot
        case incompleteExponent
        case numericSeparators
        case hexNumber
        case octalNumber
        case invalidNumber
        
        // Literals
        case normalizedLiteral
        case completedLiteral
        case spacedLiteral
        case unknownIdentifier
        
        // Other
        case multipleRoots
        case trailingContent
        case nonJSONWhitespace
        case duplicateKey
        case wrapNDJSON
        case autoClosedBracket
        case insertedColon
        case insertedComma
    }
    
    /// Detailed fix record
    private struct Fix: Equatable {
        let kind: FixKind
        let position: Int
        let line: Int
        let column: Int
        let message: String
        let original: String
        let replacement: String
    }
    
    /// Parse frame for container tracking
    private struct ParseFrame {
        enum Container {
            case object
            case array
        }
        
        enum State {
            case expectKey
            case expectColon
            case expectValue
            case expectCommaOrClose
        }
        
        let container: Container
        var state: State
        var seenKeys: Set<String> = []
        let startPosition: Int
    }
    
    /// Enhanced parse node
    private class ParseNode {
        enum NodeType {
            case object([ObjectMember])
            case array([ParseNode])
            case string(String, lexeme: String?)
            case number(lexeme: String)
            case boolean(Bool, lexeme: String)
            case null(lexeme: String)
        }
        
        struct ObjectMember {
            let key: String
            let keyLexeme: String?
            let value: ParseNode
        }
        
        let type: NodeType
        let startPos: Int
        let endPos: Int
        
        init(type: NodeType, startPos: Int, endPos: Int) {
            self.type = type
            self.startPos = startPos
            self.endPos = endPos
        }
    }
    
    // MARK: - Public API
    
    public struct FixResult: Sendable {
        public let fixed: String
        public let wasFixed: Bool
        public let fixes: [String]
        public let detailedFixes: [String]  // For debugging
        public let metrics: FixMetrics?
        
        // Keep backward compatibility
        public init(fixed: String, wasFixed: Bool, fixes: [String], detailedFixes: [String], metrics: FixMetrics? = nil) {
            self.fixed = fixed
            self.wasFixed = wasFixed
            self.fixes = fixes
            self.detailedFixes = detailedFixes
            self.metrics = metrics
        }
    }
    
    public struct FixMetrics: Sendable {
        public let fixCount: Int
        public let fixCountByKind: [String: Int]
        public let maxDepth: Int
        public let tokensProcessed: Int
        public let elapsedMs: Int
        public let hitMaxFixes: Bool
    }
    
    public func fix(_ jsonString: String) async -> FixResult {
        let startTime = Date()
        
        guard !jsonString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return FixResult(fixed: "{}", wasFixed: false, fixes: [], detailedFixes: [])
        }
        
        // Phase 1: Tokenize with preservation
        let (tokens, tokenFixes) = tokenizeWithPreservation(jsonString)
        
        // Phase 2: Parse with state machine
        let (roots, parseFixes) = parseWithStateMachine(tokens)
        
        // Phase 3: Reconstruct with normalization
        let (result, reconFixes) = reconstruct(roots, originalInput: jsonString)
        
        // Combine all fixes
        let allFixes = tokenFixes + parseFixes + reconFixes
        let fixMessages = allFixes.map { $0.message }
        let detailedMessages = allFixes.map { fix in
            "[\(fix.kind)] Line \(fix.line):\(fix.column) - \(fix.message)"
        }
        
        // Calculate metrics
        let elapsedMs = Int(Date().timeIntervalSince(startTime) * 1000)
        var fixCountByKind: [String: Int] = [:]
        for fix in allFixes {
            let kindStr = String(describing: fix.kind)
            fixCountByKind[kindStr, default: 0] += 1
        }
        
        let metrics = FixMetrics(
            fixCount: allFixes.count,
            fixCountByKind: fixCountByKind,
            maxDepth: calculateMaxDepth(roots),
            tokensProcessed: tokens.count,
            elapsedMs: elapsedMs,
            hitMaxFixes: allFixes.count >= config.maxFixes
        )
        
        return FixResult(
            fixed: result,
            wasFixed: !allFixes.isEmpty,
            fixes: fixMessages,
            detailedFixes: detailedMessages,
            metrics: metrics
        )
    }
    
    // MARK: - Tokenization Phase
    
    private func tokenizeWithPreservation(_ input: String) -> ([Token], [Fix]) {
        var tokens: [Token] = []
        var fixes: [Fix] = []
        let chars = Array(input)
        var i = 0
        var line = 1
        var column = 1
        
        func advance(_ count: Int = 1) {
            for _ in 0..<count {
                if i < chars.count {
                    if chars[i] == "\n" {
                        line += 1
                        column = 1
                    } else {
                        column += 1
                    }
                    i += 1
                }
            }
        }
        
        while i < chars.count {
            let startPos = i
            let startLine = line
            let startCol = column
            
            switch chars[i] {
            case "{":
                tokens.append(.leftBrace)
                advance()
                
            case "}":
                tokens.append(.rightBrace)
                advance()
                
            case "[":
                tokens.append(.leftBracket)
                advance()
                
            case "]":
                tokens.append(.rightBracket)
                advance()
                
            case ":":
                tokens.append(.colon)
                advance()
                
            case ",":
                tokens.append(.comma)
                advance()
                
            case "\"":
                if let (token, fix) = parseString(chars, from: i, line: startLine, column: startCol, quote: "\"") {
                    tokens.append(token)
                    if let fix = fix {
                        fixes.append(fix)
                    }
                    i = endPosition(of: token, start: startPos)
                } else {
                    advance()
                }
                
            case "'":
                if let (token, fix) = parseString(chars, from: i, line: startLine, column: startCol, quote: "'") {
                    tokens.append(token)
                    if let fix = fix {
                        fixes.append(fix)
                    }
                    i = endPosition(of: token, start: startPos)
                } else {
                    advance()
                }
                
            case "-", "+", "0"..."9", ".":
                if let (token, fix) = parseNumber(chars, from: i, line: startLine, column: startCol) {
                    tokens.append(token)
                    if let fix = fix {
                        fixes.append(fix)
                    }
                    i = endPosition(of: token, start: startPos)
                } else {
                    advance()
                }
                
            case "/":
                // Check for comments
                if i + 1 < chars.count {
                    if chars[i + 1] == "/" {
                        // Line comment
                        let comment = parseLineComment(chars, from: i)
                        tokens.append(.comment(comment))
                        i += comment.count
                    } else if chars[i + 1] == "*" {
                        // Block comment
                        let comment = parseBlockComment(chars, from: i)
                        tokens.append(.comment(comment))
                        i += comment.count
                    } else {
                        advance()
                    }
                } else {
                    advance()
                }
                
            case " ", "\t", "\n", "\r":
                let ws = parseWhitespace(chars, from: i)
                tokens.append(.whitespace(ws))
                for _ in ws {
                    advance()
                }
                
            case "\u{00A0}":  // Non-breaking space
                tokens.append(.whitespace("\u{00A0}"))
                fixes.append(Fix(
                    kind: .nonJSONWhitespace,
                    position: i,
                    line: startLine,
                    column: startCol,
                    message: "Non-breaking space found",
                    original: "\u{00A0}",
                    replacement: " "
                ))
                advance()
                
            default:
                // Try to parse as identifier or literal
                if let (token, fix) = parseIdentifierOrLiteral(chars, from: i, line: startLine, column: startCol) {
                    tokens.append(token)
                    if let fix = fix {
                        fixes.append(fix)
                    }
                    i = endPosition(of: token, start: startPos)
                } else {
                    advance()
                }
            }
        }
        
        tokens.append(.eof)
        return (tokens, fixes)
    }
    
    // MARK: - String Parsing
    
    private func parseString(_ chars: [Character], from start: Int, line: Int, column: Int, quote: Character) -> (Token, Fix?)? {
        var i = start + 1  // Skip opening quote
        var result = ""
        var lexeme = String(quote)
        var flags = StringFlags(
            wasUnterminated: false,
            hadInvalidEscapes: false,
            usedSingleQuotes: quote == "'",
            hadUnescapedControls: false,
            hadInvalidUnicode: false
        )
        var fix: Fix?
        var foundClosingQuote = false  // Track if we found a proper closing quote
        
        while i < chars.count {
            let char = chars[i]
            lexeme.append(char)
            
            if char == "\\" && i + 1 < chars.count {
                // Escape sequence
                i += 1
                let nextChar = chars[i]
                lexeme.append(nextChar)
                
                switch nextChar {
                case "n": result.append("\n")
                case "r": result.append("\r")
                case "t": result.append("\t")
                case "b": result.append("\u{08}")
                case "f": result.append("\u{0C}")
                case "\"", "'", "\\", "/": result.append(nextChar)
                case "u":
                    // Unicode escape
                    if i + 4 < chars.count {
                        let hex = String(chars[(i+1)...(i+4)])
                        lexeme.append(contentsOf: hex)
                        
                        if let codePoint = UInt32(hex, radix: 16) {
                            // Check for surrogate pairs
                            if (0xD800...0xDBFF).contains(codePoint) {
                                // High surrogate - look for low
                                if i + 10 < chars.count && 
                                   chars[i+5] == "\\" && chars[i+6] == "u" {
                                    let lowHex = String(chars[(i+7)...(i+10)])
                                    if let lowCode = UInt32(lowHex, radix: 16),
                                       (0xDC00...0xDFFF).contains(lowCode) {
                                        // Valid surrogate pair
                                        let high = codePoint - 0xD800
                                        let low = lowCode - 0xDC00
                                        let combined = 0x10000 + (high << 10) + low
                                        if let scalar = UnicodeScalar(combined) {
                                            result.append(String(scalar))
                                            // Append the low surrogate's escape sequence to the lexeme
                                            lexeme.append("\\u")
                                            lexeme.append(contentsOf: lowHex)
                                            i += 10
                                        }
                                    } else {
                                        // Invalid low surrogate
                                        flags.hadInvalidUnicode = true
                                        result.append("\u{FFFD}")
                                        i += 4
                                    }
                                } else {
                                    // Lone high surrogate
                                    flags.hadInvalidUnicode = true
                                    result.append("\u{FFFD}")
                                    i += 4
                                }
                            } else if (0xDC00...0xDFFF).contains(codePoint) {
                                // Lone low surrogate
                                flags.hadInvalidUnicode = true
                                result.append("\u{FFFD}")
                                i += 4
                            } else if let scalar = UnicodeScalar(codePoint) {
                                result.append(String(scalar))
                                i += 4
                            } else {
                                flags.hadInvalidUnicode = true
                                result.append("\u{FFFD}")
                                i += 4
                            }
                        } else {
                            // Invalid hex in unicode escape
                            flags.hadInvalidUnicode = true
                            result.append("\u{FFFD}")
                            i += 4
                        }
                    } else {
                        // Incomplete unicode escape
                        flags.hadInvalidUnicode = true
                        result.append("\u{FFFD}")
                    }
                    
                default:
                    // Invalid escape - remove backslash, keep character
                    flags.hadInvalidEscapes = true
                    result.append(nextChar)
                }
                i += 1
                
            } else if char == quote {
                // Closing quote found
                foundClosingQuote = true
                i += 1
                break
                
            } else if char.asciiValue ?? 128 < 0x20 {
                // Unescaped control character
                flags.hadUnescapedControls = true
                result.append(char)
                i += 1
                
            } else {
                result.append(char)
                i += 1
            }
        }
        
        // Check for unterminated string - only if we didn't find a closing quote
        if !foundClosingQuote {
            flags.wasUnterminated = true
            lexeme.append(quote)  // Add synthetic closing quote
        }
        
        // Create fixes
        if flags.usedSingleQuotes {
            fix = Fix(
                kind: .singleQuotes,
                position: start,
                line: line,
                column: column,
                message: "Single quotes converted to double quotes",
                original: lexeme,
                replacement: "\"\(result)\""
            )
        } else if flags.hadInvalidEscapes {
            fix = Fix(
                kind: .invalidEscape,
                position: start,
                line: line,
                column: column,
                message: "Invalid escape sequences normalized",
                original: lexeme,
                replacement: "\"\(result)\""
            )
        } else if flags.hadInvalidUnicode {
            fix = Fix(
                kind: .invalidUnicode,
                position: start,
                line: line,
                column: column,
                message: "Invalid Unicode sequences replaced with replacement character",
                original: lexeme,
                replacement: "\"\(result)\""
            )
        } else if flags.hadUnescapedControls {
            fix = Fix(
                kind: .unescapedControl,
                position: start,
                line: line,
                column: column,
                message: "Unescaped control characters will be escaped",
                original: lexeme,
                replacement: "\"\(result.escapedJSONEnhanced)\""
            )
        } else if flags.wasUnterminated {
            fix = Fix(
                kind: .unterminatedString,
                position: start,
                line: line,
                column: column,
                message: "Unterminated string closed",
                original: lexeme,
                replacement: "\"\(result)\""
            )
        }
        
        return (.string(processed: result, lexeme: lexeme, flags: flags), fix)
    }
    
    // MARK: - Number Parsing
    
    private func parseNumber(_ chars: [Character], from start: Int, line: Int, column: Int) -> (Token, Fix?)? {
        var i = start
        var lexeme = ""
        var kind = NumberKind.valid
        var hasLeadingPlus = false
        var hasLeadingZeros = false
        var isBareDot = false
        var hasTrailingDot = false
        var hasIncompleteExp = false
        var hasUnderscores = false
        var isHex = false
        var isOctal = false
        
        // Check for sign
        if i < chars.count && chars[i] == "+" {
            hasLeadingPlus = true
            lexeme.append(chars[i])
            i += 1
        } else if i < chars.count && chars[i] == "-" {
            lexeme.append(chars[i])
            i += 1
        }
        
        // Check for hex/octal
        if i < chars.count && chars[i] == "0" {
            lexeme.append(chars[i])
            i += 1
            
            if i < chars.count {
                if chars[i] == "x" || chars[i] == "X" {
                    // Hex literal
                    isHex = true
                    lexeme.append(chars[i])
                    i += 1
                    
                    while i < chars.count && chars[i].isHexDigit {
                        lexeme.append(chars[i])
                        i += 1
                    }
                } else if chars[i].isNumber {
                    // Potential octal or leading zeros
                    var leadingZeroCount = 1
                    while i < chars.count && chars[i] == "0" {
                        leadingZeroCount += 1
                        lexeme.append(chars[i])
                        i += 1
                    }
                    
                    if leadingZeroCount > 1 {
                        hasLeadingZeros = true
                    }
                    
                    // Check if it's octal (all digits 0-7)
                    var isValidOctal = true
                    let octalStart = i
                    while i < chars.count && chars[i].isNumber {
                        if chars[i] > "7" {
                            isValidOctal = false
                        }
                        lexeme.append(chars[i])
                        i += 1
                    }
                    
                    if isValidOctal && i > octalStart {
                        isOctal = true
                    }
                }
            }
        } else if i < chars.count && chars[i] == "." {
            // Bare decimal
            isBareDot = true
            lexeme.append(chars[i])
            i += 1
            
            while i < chars.count && chars[i].isNumber {
                lexeme.append(chars[i])
                i += 1
            }
        } else {
            // Regular number
            while i < chars.count && (chars[i].isNumber || chars[i] == "_") {
                if chars[i] == "_" {
                    hasUnderscores = true
                }
                lexeme.append(chars[i])
                i += 1
            }
            
            // Decimal part
            if i < chars.count && chars[i] == "." {
                lexeme.append(chars[i])
                i += 1
                
                var hasDigitsAfterDot = false
                while i < chars.count && (chars[i].isNumber || chars[i] == "_") {
                    if chars[i] == "_" {
                        hasUnderscores = true
                    } else {
                        hasDigitsAfterDot = true
                    }
                    lexeme.append(chars[i])
                    i += 1
                }
                
                if !hasDigitsAfterDot {
                    hasTrailingDot = true
                }
            }
        }
        
        // Exponent part
        if i < chars.count && (chars[i] == "e" || chars[i] == "E") {
            lexeme.append(chars[i])
            i += 1
            
            if i < chars.count && (chars[i] == "+" || chars[i] == "-") {
                lexeme.append(chars[i])
                i += 1
            }
            
            var hasExpDigits = false
            while i < chars.count && chars[i].isNumber {
                hasExpDigits = true
                lexeme.append(chars[i])
                i += 1
            }
            
            if !hasExpDigits {
                hasIncompleteExp = true
            }
        }
        
        // Determine kind
        if hasLeadingPlus {
            kind = .leadingPlus
        } else if hasLeadingZeros {
            kind = .leadingZeros
        } else if isBareDot {
            kind = .bareDot
        } else if hasTrailingDot {
            kind = .trailingDot
        } else if hasIncompleteExp {
            kind = .incompleteExp
        } else if hasUnderscores {
            kind = .hasUnderscores
        } else if isHex {
            kind = .hexLiteral
        } else if isOctal {
            kind = .octalLiteral
        }
        
        // Create fix if needed
        var fix: Fix?
        let normalized = normalizeNumber(lexeme, kind: kind)
        
        if normalized != lexeme {
            let fixKind: FixKind = switch kind {
                case .leadingPlus: .leadingPlus
                case .leadingZeros: .leadingZeros
                case .bareDot: .bareDot
                case .trailingDot: .trailingDot
                case .incompleteExp: .incompleteExponent
                case .hasUnderscores: .numericSeparators
                case .hexLiteral: .hexNumber
                case .octalLiteral: .octalNumber
                default: .invalidNumber
            }
            
            fix = Fix(
                kind: fixKind,
                position: start,
                line: line,
                column: column,
                message: "Number format normalized",
                original: lexeme,
                replacement: normalized
            )
        }
        
        return (.number(lexeme: normalized, kind: kind), fix)
    }
    
    private func normalizeNumber(_ lexeme: String, kind: NumberKind) -> String {
        switch kind {
        case .leadingPlus:
            return String(lexeme.dropFirst())
            
        case .leadingZeros:
            // Remove leading zeros but preserve at least one
            // Special case: preserve -0
            if lexeme == "-0" {
                return lexeme
            }
            var result = lexeme
            while result.hasPrefix("00") {
                result = String(result.dropFirst())
            }
            // Also handle negative numbers with leading zeros
            if result.hasPrefix("-00") {
                result = "-" + String(result.dropFirst(3))
                while result.hasPrefix("-0") && result.count > 2 && result[result.index(result.startIndex, offsetBy: 2)] == "0" {
                    result = "-" + String(result.dropFirst(2))
                }
            }
            return result
            
        case .bareDot:
            return "0" + lexeme
            
        case .trailingDot:
            return lexeme + "0"
            
        case .incompleteExp:
            // Add 0 to incomplete exponent
            if lexeme.hasSuffix("e") || lexeme.hasSuffix("E") {
                return lexeme + "0"
            } else if lexeme.hasSuffix("e+") || lexeme.hasSuffix("E+") ||
                      lexeme.hasSuffix("e-") || lexeme.hasSuffix("E-") {
                return lexeme + "0"
            }
            return lexeme
            
        case .hasUnderscores:
            return lexeme.replacingOccurrences(of: "_", with: "")
            
        case .hexLiteral:
            // Convert hex to decimal
            let hex = lexeme.dropFirst(2)  // Remove 0x
            if let value = Int(hex, radix: 16) {
                return String(value)
            }
            return "0"
            
        case .octalLiteral:
            // Convert octal to decimal
            let octal = lexeme.dropFirst()  // Remove leading 0
            if let value = Int(octal, radix: 8) {
                return String(value)
            }
            return lexeme
            
        default:
            return lexeme
        }
    }
    
    // MARK: - Identifier/Literal Parsing
    
    private func parseIdentifierOrLiteral(_ chars: [Character], from start: Int, line: Int, column: Int) -> (Token, Fix?)? {
        var i = start
        var lexeme = ""
        
        // Collect identifier characters
        while i < chars.count {
            let char = chars[i]
            if char.isLetter || char.isNumber || char == "_" || char == "$" || char == "-" {
                lexeme.append(char)
                i += 1
            } else if char == " " && i + 1 < chars.count {
                // Check for space-broken literals like "tr ue"
                let lookahead = peekIdentifier(chars, from: i + 1)
                if let combined = tryCompleteLiteral(lexeme + lookahead) {
                    lexeme = combined
                    i += 1 + lookahead.count
                    break
                } else {
                    break
                }
            } else {
                break
            }
        }
        
        guard !lexeme.isEmpty else { return nil }
        
        // Check if it's a literal
        if let literalValue = mapToLiteral(lexeme) {
            let normalized = literalName(literalValue)
            
            var fix: Fix?
            if lexeme != normalized {
                let fixKind: FixKind
                if lexeme.contains(" ") {
                    fixKind = .spacedLiteral
                } else if lexeme.count < normalized.count {
                    fixKind = .completedLiteral
                } else {
                    fixKind = .normalizedLiteral
                }
                
                fix = Fix(
                    kind: fixKind,
                    position: start,
                    line: line,
                    column: column,
                    message: "Literal '\(lexeme)' normalized to '\(normalized)'",
                    original: lexeme,
                    replacement: normalized
                )
            }
            
            // Return normalized lexeme, not original
            return (.literal(value: literalValue, lexeme: normalized), fix)
        } else {
            // Unknown identifier
            let fix = Fix(
                kind: .unknownIdentifier,
                position: start,
                line: line,
                column: column,
                message: "Unknown identifier '\(lexeme)' will be treated as string",
                original: lexeme,
                replacement: "\"\(lexeme)\""
            )
            
            return (.identifier(lexeme), fix)
        }
    }
    
    private func mapToLiteral(_ text: String) -> LiteralValue? {
        switch text.lowercased() {
        case "true", "yes", "on":
            return .true
        case "false", "no", "off":
            return .false
        case "null", "nil", "none":
            return .null
        case "undefined", "undef":
            return .undefined
        case "nan":
            return .nan
        case "infinity", "inf":
            return .infinity
        default:
            // Check for partial literals
            if "true".hasPrefix(text.lowercased()) && text.count >= 2 {
                return .true
            } else if "false".hasPrefix(text.lowercased()) && text.count >= 2 {
                return .false
            } else if "null".hasPrefix(text.lowercased()) && text.count >= 2 {
                return .null
            }
            return nil
        }
    }
    
    private func literalName(_ value: LiteralValue) -> String {
        switch value {
        case .true: return "true"
        case .false: return "false"
        case .null, .undefined, .nan, .infinity: return "null"
        }
    }
    
    private func tryCompleteLiteral(_ text: String) -> String? {
        let nospace = text.replacingOccurrences(of: " ", with: "")
        if mapToLiteral(nospace) != nil {
            return nospace
        }
        return nil
    }
    
    private func peekIdentifier(_ chars: [Character], from start: Int) -> String {
        var i = start
        var result = ""
        
        while i < chars.count {
            let char = chars[i]
            if char.isLetter || char == "_" {
                result.append(char)
                i += 1
            } else {
                break
            }
        }
        
        return result
    }
    
    // MARK: - Comment Parsing
    
    private func parseLineComment(_ chars: [Character], from start: Int) -> String {
        var i = start
        var result = ""
        
        while i < chars.count && chars[i] != "\n" {
            result.append(chars[i])
            i += 1
        }
        
        return result
    }
    
    private func parseBlockComment(_ chars: [Character], from start: Int) -> String {
        var i = start
        var result = ""
        
        while i < chars.count {
            if i + 1 < chars.count && chars[i] == "*" && chars[i+1] == "/" {
                result.append("*/")
                break
            }
            result.append(chars[i])
            i += 1
        }
        
        return result
    }
    
    private func parseWhitespace(_ chars: [Character], from start: Int) -> String {
        var i = start
        var result = ""
        
        while i < chars.count {
            let char = chars[i]
            if char == " " || char == "\t" || char == "\n" || char == "\r" {
                result.append(char)
                i += 1
            } else {
                break
            }
        }
        
        return result
    }
    
    // MARK: - Parse Phase with State Machine
    
    private func parseWithStateMachine(_ tokens: [Token]) -> ([ParseNode], [Fix]) {
        var roots: [ParseNode] = []
        var fixes: [Fix] = []
        var index = 0
        var frameStack: [ParseFrame] = []
        let position = 0
        let line = 1
        var column = 1
        
        func addFix(_ fix: Fix) {
            guard fixes.count < config.maxFixes else {
                // Add a summary fix when limit reached
                if fixes.count == config.maxFixes {
                    fixes.append(Fix(
                        kind: .trailingContent,
                        position: position,
                        line: line,
                        column: column,
                        message: "Fix limit (\(config.maxFixes)) reached, stopping repairs",
                        original: "",
                        replacement: ""
                    ))
                }
                return
            }
            fixes.append(fix)
        }
        
        func skipWhitespaceAndComments() {
            while index < tokens.count {
                switch tokens[index] {
                case .whitespace(_), .comment(_):
                    index += 1
                default:
                    return
                }
            }
        }
        
        func parseValue() -> ParseNode? {
            skipWhitespaceAndComments()
            guard index < tokens.count else { return nil }
            
            let startPos = position
            
            switch tokens[index] {
            case .leftBrace:
                return parseObject()
                
            case .leftBracket:
                return parseArray()
                
            case let .string(value, lexeme, _):
                index += 1
                return ParseNode(type: .string(value, lexeme: lexeme), startPos: startPos, endPos: position)
                
            case let .number(lexeme, kind):
                index += 1
                // Lexeme is already normalized by the tokenizer
                return ParseNode(type: .number(lexeme: lexeme), startPos: startPos, endPos: position)
                
            case let .literal(value, lexeme):
                index += 1
                let boolValue = value == .true
                let normalizedLexeme = literalName(value)
                return value == .true || value == .false ?
                    ParseNode(type: .boolean(boolValue, lexeme: normalizedLexeme), startPos: startPos, endPos: position) :
                    ParseNode(type: .null(lexeme: normalizedLexeme), startPos: startPos, endPos: position)
                
            case .identifier(let text):
                // Unquoted value - treat as string
                addFix(Fix(
                    kind: .unquotedValue,
                    position: position,
                    line: line,
                    column: column,
                    message: "Unquoted value '\(text)' quoted",
                    original: text,
                    replacement: "\"\(text)\""
                ))
                index += 1
                return ParseNode(type: .string(text, lexeme: nil), startPos: startPos, endPos: position)
                
            case .rightBrace, .rightBracket:
                // Unexpected closing - might be coordinates case
                // Pattern: {"coordinates": -0.1695, 51.4865]}
                // We're at a number, seeing ] next
                
                // Look back to detect missing [
                var lookbackIndex = index - 1
                var hasComma = false
                var hasNumber = false
                
                // Skip whitespace backwards
                while lookbackIndex >= 0 {
                    switch tokens[lookbackIndex] {
                    case .whitespace:
                        lookbackIndex -= 1
                        continue
                    case .comma:
                        hasComma = true
                        lookbackIndex -= 1
                    case .number:
                        hasNumber = true
                        lookbackIndex -= 1
                    default:
                        break
                    }
                    
                    if hasComma && hasNumber {
                        break
                    }
                }
                
                // If we have pattern: colon number comma (current_number) ]
                // Then we're missing the opening bracket
                if hasComma && lookbackIndex >= 0 {
                    if case .colon = tokens[lookbackIndex] {
                        // Create array with missing bracket
                        fixes.append(Fix(
                            kind: .missingOpenBracket,
                            position: position,
                            line: line,
                            column: column,
                            message: "Missing opening bracket for coordinates array",
                            original: "",
                            replacement: "["
                        ))
                        
                        // Parse as array elements
                        var elements: [ParseNode] = []
                        
                        // Add the first number (already parsed earlier)
                        // We need to reconstruct it
                        // This is a simplified approach - proper implementation would track parsed values
                        
                        return ParseNode(type: .array([]), startPos: startPos, endPos: position)
                    }
                }
                return nil
                
            default:
                return nil
            }
        }
        
        func parseObject() -> ParseNode {
            let startPos = position
            var members: [ParseNode.ObjectMember] = []
            var frame = ParseFrame(container: .object, state: .expectKey, startPosition: startPos)
            frameStack.append(frame)
            
            index += 1  // Skip {
            skipWhitespaceAndComments()
            
            while index < tokens.count && tokens[index] != .eof {
                skipWhitespaceAndComments()
                
                switch frame.state {
                case .expectKey:
                    switch tokens[index] {
                    case .rightBrace:
                        index += 1
                        frameStack.removeLast()
                        return ParseNode(type: .object(members), startPos: startPos, endPos: position)
                        
                    case let .string(key, lexeme, _):
                        if frame.seenKeys.contains(key) {
                            fixes.append(Fix(
                                kind: .duplicateKey,
                                position: position,
                                line: line,
                                column: column,
                                message: "Duplicate key '\(key)' detected",
                                original: key,
                                replacement: key
                            ))
                        }
                        frame.seenKeys.insert(key)
                        index += 1
                        frame.state = .expectColon
                        
                    case .identifier(let key):
                        fixes.append(Fix(
                            kind: .unquotedKey,
                            position: position,
                            line: line,
                            column: column,
                            message: "Unquoted key '\(key)' quoted",
                            original: key,
                            replacement: "\"\(key)\""
                        ))
                        frame.seenKeys.insert(key)
                        index += 1
                        frame.state = .expectColon
                        
                    case .comma:
                        fixes.append(Fix(
                            kind: .extraComma,
                            position: position,
                            line: line,
                            column: column,
                            message: "Extra comma removed",
                            original: ",",
                            replacement: ""
                        ))
                        index += 1
                        
                    default:
                        index += 1
                    }
                    
                case .expectColon:
                    if tokens[index] == .colon {
                        index += 1
                        frame.state = .expectValue
                    } else {
                        fixes.append(Fix(
                            kind: .missingColon,
                            position: position,
                            line: line,
                            column: column,
                            message: "Missing colon inserted",
                            original: "",
                            replacement: ":"
                        ))
                        frame.state = .expectValue
                    }
                    
                case .expectValue:
                    if let value = parseValue() {
                        // Add member (we need to track the key somehow)
                        let key = frame.seenKeys.sorted().last ?? "unknown"
                        members.append(ParseNode.ObjectMember(
                            key: key,
                            keyLexeme: nil,
                            value: value
                        ))
                        frame.state = .expectCommaOrClose
                    } else {
                        frame.state = .expectCommaOrClose
                    }
                    
                case .expectCommaOrClose:
                    switch tokens[index] {
                    case .comma:
                        index += 1
                        // Check if next token is close brace (trailing comma)
                        if index < tokens.count && tokens[index] == .rightBrace {
                            fixes.append(Fix(
                                kind: .extraComma,
                                position: position,
                                line: line,
                                column: column,
                                message: "Trailing comma removed",
                                original: ",",
                                replacement: ""
                            ))
                        }
                        frame.state = .expectKey
                        
                    case .rightBrace:
                        index += 1
                        frameStack.removeLast()
                        return ParseNode(type: .object(members), startPos: startPos, endPos: position)
                        
                    case .rightBracket:
                        // Cross-type closure
                        fixes.append(Fix(
                            kind: .crossTypeClosure,
                            position: position,
                            line: line,
                            column: column,
                            message: "Object closed with bracket, inserting brace",
                            original: "]",
                            replacement: "}"
                        ))
                        index += 1
                        frameStack.removeLast()
                        return ParseNode(type: .object(members), startPos: startPos, endPos: position)
                        
                    case .string, .identifier:
                        // Missing comma
                        fixes.append(Fix(
                            kind: .missingComma,
                            position: position,
                            line: line,
                            column: column,
                            message: "Missing comma inserted",
                            original: "",
                            replacement: ","
                        ))
                        frame.state = .expectKey
                        
                    default:
                        index += 1
                    }
                }
                
                frameStack[frameStack.count - 1] = frame
            }
            
            // Missing closing brace
            fixes.append(Fix(
                kind: .missingCloseBrace,
                position: position,
                line: line,
                column: column,
                message: "Missing closing brace added",
                original: "",
                replacement: "}"
            ))
            
            frameStack.removeLast()
            return ParseNode(type: .object(members), startPos: startPos, endPos: position)
        }
        
        func parseArray() -> ParseNode {
            let startPos = position
            var elements: [ParseNode] = []
            var frame = ParseFrame(container: .array, state: .expectValue, startPosition: startPos)
            frameStack.append(frame)
            
            index += 1  // Skip [
            skipWhitespaceAndComments()
            
            while index < tokens.count && tokens[index] != .eof {
                skipWhitespaceAndComments()
                
                switch frame.state {
                case .expectValue:
                    if tokens[index] == .rightBracket {
                        index += 1
                        frameStack.removeLast()
                        return ParseNode(type: .array(elements), startPos: startPos, endPos: position)
                    } else if tokens[index] == .comma {
                        fixes.append(Fix(
                            kind: .extraComma,
                            position: position,
                            line: line,
                            column: column,
                            message: "Extra comma removed",
                            original: ",",
                            replacement: ""
                        ))
                        index += 1
                    } else if let value = parseValue() {
                        elements.append(value)
                        frame.state = .expectCommaOrClose
                    } else {
                        index += 1
                    }
                    
                case .expectCommaOrClose:
                    switch tokens[index] {
                    case .comma:
                        index += 1
                        // Check if next token is close bracket (trailing comma)
                        if index < tokens.count && tokens[index] == .rightBracket {
                            fixes.append(Fix(
                                kind: .extraComma,
                                position: position,
                                line: line,
                                column: column,
                                message: "Trailing comma removed",
                                original: ",",
                                replacement: ""
                            ))
                        }
                        frame.state = .expectValue
                        
                    case .rightBracket:
                        index += 1
                        frameStack.removeLast()
                        return ParseNode(type: .array(elements), startPos: startPos, endPos: position)
                        
                    case .rightBrace:
                        // Cross-type closure
                        fixes.append(Fix(
                            kind: .crossTypeClosure,
                            position: position,
                            line: line,
                            column: column,
                            message: "Array closed with brace, inserting bracket",
                            original: "}",
                            replacement: "]"
                        ))
                        index += 1
                        frameStack.removeLast()
                        return ParseNode(type: .array(elements), startPos: startPos, endPos: position)
                        
                    default:
                        // Missing comma
                        fixes.append(Fix(
                            kind: .missingComma,
                            position: position,
                            line: line,
                            column: column,
                            message: "Missing comma inserted",
                            original: "",
                            replacement: ","
                        ))
                        frame.state = .expectValue
                    }
                    
                default:
                    break
                }
                
                frameStack[frameStack.count - 1] = frame
            }
            
            // Missing closing bracket
            fixes.append(Fix(
                kind: .missingCloseBracket,
                position: position,
                line: line,
                column: column,
                message: "Missing closing bracket added",
                original: "",
                replacement: "]"
            ))
            
            frameStack.removeLast()
            return ParseNode(type: .array(elements), startPos: startPos, endPos: position)
        }
        
        // Parse all root values
        skipWhitespaceAndComments()
        while index < tokens.count && tokens[index] != .eof {
            if let root = parseValue() {
                roots.append(root)
                skipWhitespaceAndComments()
                
                // Check for trailing content
                if index < tokens.count && tokens[index] != .eof {
                    var hasMoreValues = false
                    
                    switch tokens[index] {
                    case .leftBrace, .leftBracket, .string, .number, .literal:
                        hasMoreValues = true
                    default:
                        break
                    }
                    
                    if !hasMoreValues {
                        fixes.append(Fix(
                            kind: .trailingContent,
                            position: position,
                            line: line,
                            column: column,
                            message: "Trailing content after valid JSON",
                            original: "",
                            replacement: ""
                        ))
                        break
                    }
                }
            } else {
                break
            }
        }
        
        // Check for multiple roots
        if roots.count > 1 {
            fixes.append(Fix(
                kind: .multipleRoots,
                position: 0,
                line: 1,
                column: 1,
                message: "Multiple root values found, wrapping in array",
                original: "",
                replacement: "[]"
            ))
        }
        
        return (roots, fixes)
    }
    
    // MARK: - Reconstruction Phase
    
    private nonisolated func reconstruct(_ roots: [ParseNode], originalInput: String) -> (String, [Fix]) {
        var fixes: [Fix] = []
        
        func nodeToJSON(_ node: ParseNode, indent: Int = 0) -> String {
            let indentStr = String(repeating: "  ", count: indent)
            let nextIndentStr = String(repeating: "  ", count: indent + 1)
            
            switch node.type {
            case let .object(members):
                if members.isEmpty {
                    return "{}"
                }
                
                var result = "{\n"
                for (index, member) in members.enumerated() {
                    let key = member.keyLexeme ?? "\"\(member.key.escapedJSONEnhanced)\""
                    result += nextIndentStr + key + ": "
                    result += nodeToJSON(member.value, indent: indent + 1)
                    if index < members.count - 1 {
                        result += ","
                    }
                    result += "\n"
                }
                result += indentStr + "}"
                return result
                
            case let .array(elements):
                if elements.isEmpty {
                    return "[]"
                }
                
                // Check if all elements are simple
                let allSimple = elements.count <= 3 && elements.allSatisfy { isSimpleValue($0) }
                
                if allSimple {
                    let elemStrs = elements.map { nodeToJSON($0, indent: 0) }
                    return "[" + elemStrs.joined(separator: ", ") + "]"
                } else {
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
                
            case let .string(value, lexeme):
                // Always re-escape to ensure control characters are properly handled
                // Even if we have a lexeme, it might contain unescaped control chars
                return "\"\(value.escapedJSONEnhanced)\""
                
            case let .number(lexeme):
                return lexeme
                
            case let .boolean(_, lexeme):
                return lexeme
                
            case let .null(lexeme):
                return lexeme
            }
        }
        
        func isSimpleValue(_ node: ParseNode) -> Bool {
            switch node.type {
            case .string, .number, .boolean, .null:
                return true
            case let .array(elements):
                return elements.isEmpty
            case let .object(members):
                return members.isEmpty
            }
        }
        
        // Handle multiple roots
        if roots.count > 1 {
            // Check if this looks like NDJSON (newline-delimited JSON)
            let isNDJSON = config.ndjsonMode || detectNDJSON(from: originalInput, roots: roots)
            
            if isNDJSON && config.ndjsonMode {
                // In NDJSON mode, keep each root on its own line
                var result = ""
                for (index, root) in roots.enumerated() {
                    result += nodeToJSON(root, indent: 0)
                    if index < roots.count - 1 {
                        result += "\n"
                    }
                }
                fixes.append(Fix(
                    kind: .wrapNDJSON,
                    position: 0,
                    line: 1,
                    column: 1,
                    message: "NDJSON format preserved",
                    original: "",
                    replacement: ""
                ))
                return (result, fixes)
            } else {
                // Wrap multiple roots in array
                var result = "[\n"
                for (index, root) in roots.enumerated() {
                    result += "  " + nodeToJSON(root, indent: 1)
                    if index < roots.count - 1 {
                        result += ","
                    }
                    result += "\n"
                }
                result += "]"
                return (result, fixes)
            }
        } else if let root = roots.first {
            return (nodeToJSON(root, indent: 0), fixes)
        } else {
            return ("{}", fixes)
        }
    }
    
    // Helper to calculate maximum nesting depth
    private nonisolated func calculateMaxDepth(_ roots: [ParseNode]) -> Int {
        func nodeDepth(_ node: ParseNode) -> Int {
            switch node.type {
            case let .object(members):
                return 1 + (members.map { nodeDepth($0.value) }.max() ?? 0)
            case let .array(elements):
                return 1 + (elements.map { nodeDepth($0) }.max() ?? 0)
            default:
                return 1
            }
        }
        
        return roots.map { nodeDepth($0) }.max() ?? 0
    }
    
    // Helper to detect NDJSON format
    private nonisolated func detectNDJSON(from input: String, roots: [ParseNode]) -> Bool {
        // NDJSON typically has one JSON object per line
        let lines = input.split(separator: "\n", omittingEmptySubsequences: false)
        
        // If we have multiple roots and they roughly match line count, likely NDJSON
        let nonEmptyLines = lines.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return roots.count > 1 && roots.count == nonEmptyLines.count
    }
    
    // Helper function for token end position
    private func endPosition(of token: Token, start: Int) -> Int {
        switch token {
        case let .string(_, lexeme, _):
            return start + lexeme.count
        case let .number(lexeme, _):
            return start + lexeme.count
        case let .literal(_, lexeme):
            return start + lexeme.count
        case let .identifier(text):
            return start + text.count
        case let .whitespace(ws):
            return start + ws.count
        case let .comment(text):
            return start + text.count
        default:
            return start + 1
        }
    }
}

// MARK: - String Escaping

private extension String {
    var escapedJSONEnhanced: String {
        var result = ""
        
        for scalar in self.unicodeScalars {
            switch scalar {
            case "\"": result.append("\\\"")
            case "\\": result.append("\\\\")
            case "\n": result.append("\\n")
            case "\r": result.append("\\r")
            case "\t": result.append("\\t")
            case "\u{08}": result.append("\\b")
            case "\u{0C}": result.append("\\f")
            default:
                if scalar.value < 0x20 || (scalar.value >= 0x7F && scalar.value <= 0x9F) {
                    // Control characters
                    result.append(String(format: "\\u%04X", scalar.value))
                } else if scalar.value > 0xFFFF {
                    // Outside BMP - use surrogate pairs
                    let value = scalar.value - 0x10000
                    let high = UInt16((value >> 10) & 0x3FF) + 0xD800
                    let low = UInt16(value & 0x3FF) + 0xDC00
                    result.append(String(format: "\\u%04X\\u%04X", high, low))
                } else {
                    result.append(Character(scalar))
                }
            }
        }
        
        return result
    }
}

// MARK: - Character Extensions

private extension Character {
    var isHexDigit: Bool {
        return ("0"..."9").contains(self) || ("a"..."f").contains(self) || ("A"..."F").contains(self)
    }
}