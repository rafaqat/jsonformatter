import Foundation

public actor JSONFixer {
    public init() {}
    
    public struct FixResult: Sendable {
        public let fixed: String
        public let fixes: [String]
        public let wasFixed: Bool
    }
    
    public func fix(_ jsonString: String) -> FixResult {
        var fixed = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
        var fixes: [String] = []
        
        // Remove BOM if present
        if fixed.first?.unicodeScalars.first?.value == 0xFEFF {
            fixed.removeFirst()
            fixes.append("Removed BOM character")
        }
        
        // Fix multiple opening/closing braces
        if fixed.hasPrefix("{{") {
            fixed = fixed.replacingOccurrences(of: "^\\{+", with: "{", options: .regularExpression)
            fixes.append("Fixed multiple opening braces")
        }
        
        if fixed.hasSuffix("}}") {
            fixed = fixed.replacingOccurrences(of: "\\}+$", with: "}", options: .regularExpression)
            fixes.append("Fixed multiple closing braces")
        }
        
        // Fix smart quotes
        let smartSingleQuotes = ["\u{2018}", "\u{2019}"]  // Left and right single quotes
        let smartDoubleQuotes = ["\u{201C}", "\u{201D}"]  // Left and right double quotes
        
        var hasSmartQuotes = false
        for quote in smartSingleQuotes {
            if fixed.contains(quote) {
                fixed = fixed.replacingOccurrences(of: quote, with: "'")
                hasSmartQuotes = true
            }
        }
        
        for quote in smartDoubleQuotes {
            if fixed.contains(quote) {
                fixed = fixed.replacingOccurrences(of: quote, with: "\"")
                hasSmartQuotes = true
            }
        }
        
        if hasSmartQuotes {
            fixes.append("Fixed smart quotes")
        }
        
        // Convert single quotes to double quotes
        fixed = fixSingleQuotes(fixed, fixes: &fixes)
        
        // Remove comments
        fixed = removeComments(fixed, fixes: &fixes)
        
        // Fix unquoted keys
        fixed = fixUnquotedKeys(fixed, fixes: &fixes)
        
        // Fix trailing commas
        fixed = fixTrailingCommas(fixed, fixes: &fixes)
        
        // Fix missing commas between elements
        fixed = fixMissingCommas(fixed, fixes: &fixes)
        
        // Fix missing array brackets for coordinates and similar patterns
        fixed = fixMissingArrayBrackets(fixed, fixes: &fixes)
        
        // Fix leading zeros in numbers
        fixed = fixLeadingZeros(fixed, fixes: &fixes)
        
        // Fix unterminated strings
        fixed = fixUnterminatedStrings(fixed, fixes: &fixes)
        
        // Fix invalid escape sequences
        fixed = fixInvalidEscapes(fixed, fixes: &fixes)
        
        // Fix missing brackets (must be last)
        fixed = fixMissingBrackets(fixed, fixes: &fixes)
        
        return FixResult(
            fixed: fixed,
            fixes: fixes,
            wasFixed: !fixes.isEmpty
        )
    }
    
    private func fixSingleQuotes(_ input: String, fixes: inout [String]) -> String {
        var result = input
        
        // Simple approach: replace ' with " for string delimiters
        // This is a simplified version - a full implementation would need more sophisticated parsing
        let pattern = "'([^']*?)'"
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))
            
            if !matches.isEmpty {
                for match in matches.reversed() {
                    if let range = Range(match.range, in: result) {
                        let content = String(result[range]).dropFirst().dropLast()
                        result.replaceSubrange(range, with: "\"\(content)\"")
                    }
                }
                fixes.append("Converted single quotes to double quotes")
            }
        }
        
        return result
    }
    
    private func removeComments(_ input: String, fixes: inout [String]) -> String {
        var result = input
        
        // Remove multi-line comments
        if result.contains("/*") {
            result = result.replacingOccurrences(
                of: "/\\*[\\s\\S]*?\\*/",
                with: "",
                options: .regularExpression
            )
            fixes.append("Removed multi-line comments")
        }
        
        // Remove single-line comments
        if result.contains("//") {
            // Use NSRegularExpression for more control
            if let regex = try? NSRegularExpression(pattern: "//.*$", options: .anchorsMatchLines) {
                let range = NSRange(location: 0, length: result.utf16.count)
                result = regex.stringByReplacingMatches(
                    in: result,
                    options: [],
                    range: range,
                    withTemplate: ""
                )
                fixes.append("Removed single-line comments")
            }
        }
        
        return result
    }
    
    private func fixUnquotedKeys(_ input: String, fixes: inout [String]) -> String {
        var result = input
        
        // Match unquoted keys (simplified pattern)
        let pattern = "([{,]\\s*)([a-zA-Z_$][a-zA-Z0-9_$]*)\\s*:"
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))
            
            if !matches.isEmpty {
                for match in matches.reversed() {
                    if let range = Range(match.range, in: result),
                       let prefixRange = Range(match.range(at: 1), in: result),
                       let keyRange = Range(match.range(at: 2), in: result) {
                        let prefix = String(result[prefixRange])
                        let key = String(result[keyRange])
                        result.replaceSubrange(range, with: "\(prefix)\"\(key)\":")
                    }
                }
                fixes.append("Fixed unquoted property names")
            }
        }
        
        return result
    }
    
    private func fixTrailingCommas(_ input: String, fixes: inout [String]) -> String {
        var result = input
        
        // Remove trailing commas before closing brackets/braces
        let pattern = ",\\s*([}\\]])"
        if result.range(of: pattern, options: .regularExpression) != nil {
            result = result.replacingOccurrences(
                of: pattern,
                with: "$1",
                options: .regularExpression
            )
            fixes.append("Removed trailing commas")
        }
        
        return result
    }
    
    private func fixMissingArrayBrackets(_ input: String, fixes: inout [String]) -> String {
        var result = input
        var fixed = false
        
        // Pattern 1: Fix "coordinates": number, number ] - missing opening [
        // Look for patterns where we have : followed by numbers/values and a closing ] without opening [
        let missingOpenBracketPattern = "(\"[^\"]+\"\\s*:\\s*)(-?\\d+(?:\\.\\d+)?(?:[eE][+-]?\\d+)?\\s*,\\s*-?\\d+(?:\\.\\d+)?(?:[eE][+-]?\\d+)?\\s*\\])"
        if let regex = try? NSRegularExpression(pattern: missingOpenBracketPattern, options: []) {
            let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))
            for match in matches.reversed() {
                if let range = Range(match.range, in: result),
                   let keyRange = Range(match.range(at: 1), in: result),
                   let valueRange = Range(match.range(at: 2), in: result) {
                    let key = String(result[keyRange])
                    let value = String(result[valueRange])
                    result.replaceSubrange(range, with: key + "[" + value)
                    fixed = true
                }
            }
        }
        
        // Pattern 2: Fix "coordinates": [ number, number - missing closing ]
        // Look for opening [ followed by values but no closing ] before }, or next property
        let missingCloseBracketPattern = "(\"[^\"]+\"\\s*:\\s*\\[)([^\\]]*?)(?=\\s*[,}]\\s*(?:\"[^\"]+\"\\s*:|\\}|$))"
        if let regex = try? NSRegularExpression(pattern: missingCloseBracketPattern, options: []) {
            let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))
            for match in matches.reversed() {
                if let range = Range(match.range, in: result),
                   let keyWithBracketRange = Range(match.range(at: 1), in: result),
                   let valueRange = Range(match.range(at: 2), in: result) {
                    let keyWithBracket = String(result[keyWithBracketRange])
                    let value = String(result[valueRange])
                    // Check if this is actually missing a closing bracket
                    let openCount = value.filter { $0 == "[" }.count
                    let closeCount = value.filter { $0 == "]" }.count
                    if closeCount < openCount || (openCount == 0 && closeCount == 0 && value.contains(",")) {
                        result.replaceSubrange(range, with: keyWithBracket + value + "]")
                        fixed = true
                    }
                }
            }
        }
        
        // Pattern 3: Fix arrays that have values but are missing closing bracket at end of object/array
        // Like: "array": [1, 2, 3 } or "array": ["a", "b" },
        let arrayMissingClosePattern = "(\\[[^\\]]*?)\\s*([,}])"
        if let regex = try? NSRegularExpression(pattern: arrayMissingClosePattern, options: []) {
            let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))
            for match in matches.reversed() {
                if let range = Range(match.range, in: result),
                   let arrayRange = Range(match.range(at: 1), in: result),
                   let endRange = Range(match.range(at: 2), in: result) {
                    let array = String(result[arrayRange])
                    let end = String(result[endRange])
                    // Count brackets to ensure we need a closing one
                    let openCount = array.filter { $0 == "[" }.count
                    let closeCount = array.filter { $0 == "]" }.count
                    if openCount > closeCount {
                        result.replaceSubrange(range, with: array + "]" + end)
                        fixed = true
                    }
                }
            }
        }
        
        // Pattern 4: Generic pattern - if we see ": followed by comma-separated values and ]" without [
        let genericMissingOpenPattern = "(:\\s*)([^\\[\\{\\\"]*?,.*?\\])"
        if let regex = try? NSRegularExpression(pattern: genericMissingOpenPattern, options: []) {
            let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))
            for match in matches.reversed() {
                if let range = Range(match.range, in: result),
                   let colonRange = Range(match.range(at: 1), in: result),
                   let valueRange = Range(match.range(at: 2), in: result) {
                    let colon = String(result[colonRange])
                    let value = String(result[valueRange])
                    // Check if value looks like array contents without opening bracket
                    if !value.contains("[") && value.contains(",") && value.contains("]") {
                        result.replaceSubrange(range, with: colon + "[" + value)
                        fixed = true
                    }
                }
            }
        }
        
        if fixed {
            fixes.append("Fixed missing array brackets")
        }
        
        return result
    }
    
    private func fixMissingCommas(_ input: String, fixes: inout [String]) -> String {
        var result = input
        var fixed = false
        
        // Fix missing commas in arrays: detect patterns like ] [, } {, " ", number number, etc.
        // Pattern 1: String followed by string
        let stringStringPattern = "\"\\s*\"(?=[^:])"  // Make sure it's not a key
        result = result.replacingOccurrences(
            of: stringStringPattern,
            with: "\", \"",
            options: .regularExpression
        )
        if result != input {
            fixed = true
        }
        
        // Pattern 2: Number/boolean/null followed by string
        let valueStringPattern = "(true|false|null|\\d+(?:\\.\\d+)?(?:[eE][+-]?\\d+)?)\\s+\""
        if let regex = try? NSRegularExpression(pattern: valueStringPattern, options: []) {
            let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))
            for match in matches.reversed() {
                if let range = Range(match.range, in: result),
                   let valueRange = Range(match.range(at: 1), in: result) {
                    let value = String(result[valueRange])
                    let replacement = value + ", \""
                    result.replaceSubrange(range, with: replacement)
                    fixed = true
                }
            }
        }
        
        // Pattern 3: Closing bracket/brace followed by opening bracket/brace or value
        let bracketPattern = "([}\\]])\\s*([{\\[]|\"|true|false|null|-?\\d)"
        if let regex = try? NSRegularExpression(pattern: bracketPattern, options: []) {
            let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))
            for match in matches.reversed() {
                if let range = Range(match.range, in: result),
                   let closeRange = Range(match.range(at: 1), in: result),
                   let openRange = Range(match.range(at: 2), in: result) {
                    let closeBracket = String(result[closeRange])
                    let openBracket = String(result[openRange])
                    result.replaceSubrange(range, with: closeBracket + ", " + openBracket)
                    fixed = true
                }
            }
        }
        
        // Pattern 4: Number followed by number
        let numberNumberPattern = "(\\d+(?:\\.\\d+)?(?:[eE][+-]?\\d+)?)\\s+(-?\\d)"
        if let regex = try? NSRegularExpression(pattern: numberNumberPattern, options: []) {
            let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))
            for match in matches.reversed() {
                if let range = Range(match.range, in: result),
                   let num1Range = Range(match.range(at: 1), in: result),
                   let num2Range = Range(match.range(at: 2), in: result) {
                    let num1 = String(result[num1Range])
                    let num2 = String(result[num2Range])
                    result.replaceSubrange(range, with: num1 + ", " + num2)
                    fixed = true
                }
            }
        }
        
        // Pattern 5: String followed by number/boolean/null
        let stringValuePattern = "\"\\s+(true|false|null|-?\\d)"
        if let regex = try? NSRegularExpression(pattern: stringValuePattern, options: []) {
            let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))
            for match in matches.reversed() {
                if let range = Range(match.range, in: result),
                   let valueRange = Range(match.range(at: 1), in: result) {
                    let value = String(result[valueRange])
                    result.replaceSubrange(range, with: "\", " + value)
                    fixed = true
                }
            }
        }
        
        if fixed {
            fixes.append("Added missing commas between elements")
        }
        
        return result
    }
    
    private func fixLeadingZeros(_ input: String, fixes: inout [String]) -> String {
        var result = input
        
        // Fix numbers with leading zeros (but not decimals like 0.5)
        let pattern = "(?<=[\\[{,:\\s])0+(\\d+)(?![.])"
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))
            if !matches.isEmpty {
                for match in matches.reversed() {
                    if let range = Range(match.range, in: result),
                       let numRange = Range(match.range(at: 1), in: result) {
                        let number = String(result[numRange])
                        result.replaceSubrange(range, with: number)
                    }
                }
                fixes.append("Removed leading zeros from numbers")
            }
        }
        
        return result
    }
    
    private func fixUnterminatedStrings(_ input: String, fixes: inout [String]) -> String {
        var result = input
        var inString = false
        var stringStart = -1
        var escapeNext = false
        var fixed = false
        
        for (index, char) in result.enumerated() {
            if escapeNext {
                escapeNext = false
                continue
            }
            
            if char == "\\" {
                escapeNext = true
                continue
            }
            
            if char == "\"" {
                if inString {
                    inString = false
                    stringStart = -1
                } else {
                    inString = true
                    stringStart = index
                }
            }
            
            // Check for newline in string (indicates unterminated string)
            if inString && (char == "\n" || char == "\r") {
                // Insert closing quote before newline
                let insertIndex = result.index(result.startIndex, offsetBy: index)
                result.insert("\"", at: insertIndex)
                fixed = true
                inString = false
                stringStart = -1
            }
        }
        
        // If still in string at end of file, close it
        if inString && stringStart >= 0 {
            result.append("\"")
            fixed = true
        }
        
        if fixed {
            fixes.append("Fixed unterminated strings")
        }
        
        return result
    }
    
    private func fixInvalidEscapes(_ input: String, fixes: inout [String]) -> String {
        var result = input
        
        // Fix invalid escape sequences by removing the backslash for unknown escapes
        let validEscapes = Set(["\"", "\\", "/", "b", "f", "n", "r", "t", "u"])
        var fixed = false
        
        if let regex = try? NSRegularExpression(pattern: "\\\\(.)", options: []) {
            let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))
            for match in matches.reversed() {
                if let range = Range(match.range, in: result),
                   let escapeCharRange = Range(match.range(at: 1), in: result) {
                    let escapeChar = String(result[escapeCharRange])
                    if !validEscapes.contains(escapeChar) && !escapeChar.first!.isNumber {
                        // Invalid escape - keep the character but remove the backslash
                        result.replaceSubrange(range, with: escapeChar)
                        fixed = true
                    }
                }
            }
        }
        
        if fixed {
            fixes.append("Fixed invalid escape sequences")
        }
        
        return result
    }
    
    private func fixMissingBrackets(_ input: String, fixes: inout [String]) -> String {
        var result = input
        
        // Count brackets
        var openCurly = 0
        var openSquare = 0
        var inString = false
        var escapeNext = false
        
        for char in result {
            if escapeNext {
                escapeNext = false
                continue
            }
            
            if char == "\\" {
                escapeNext = true
                continue
            }
            
            if char == "\"" {
                inString.toggle()
            }
            
            if !inString {
                switch char {
                case "{": openCurly += 1
                case "}": openCurly -= 1
                case "[": openSquare += 1
                case "]": openSquare -= 1
                default: break
                }
            }
        }
        
        // Add missing closing brackets
        if openCurly > 0 {
            result += String(repeating: "}", count: openCurly)
            fixes.append("Added \(openCurly) closing brace(s)")
        }
        
        if openSquare > 0 {
            result += String(repeating: "]", count: openSquare)
            fixes.append("Added \(openSquare) closing bracket(s)")
        }
        
        // Add missing opening brackets
        if openCurly < 0 {
            result = String(repeating: "{", count: -openCurly) + result
            fixes.append("Added \(-openCurly) opening brace(s)")
        }
        
        if openSquare < 0 {
            result = String(repeating: "[", count: -openSquare) + result
            fixes.append("Added \(-openSquare) opening bracket(s)")
        }
        
        return result
    }
}