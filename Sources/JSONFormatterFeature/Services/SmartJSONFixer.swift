import Foundation

/// A smart JSON fixer that uses parser feedback to make targeted fixes
public actor SmartJSONFixer {
    
    public init() {}
    
    public struct FixResult: Sendable {
        public let fixed: String
        public let fixes: [String]
        public let wasFixed: Bool
    }
    
    /// Fix JSON based on parser errors
    public func fix(_ jsonString: String, errors: [JSONError]) async -> FixResult {
        guard !errors.isEmpty else {
            return FixResult(fixed: jsonString, fixes: [], wasFixed: false)
        }
        
        var result = jsonString
        var fixes: [String] = []
        
        // Sort errors by position (reverse order to fix from end to start)
        let sortedErrors = errors.sorted { 
            if $0.line == $1.line {
                return $0.column > $1.column
            }
            return $0.line > $1.line
        }
        
        for error in sortedErrors {
            if let fix = applyFix(to: &result, for: error) {
                fixes.append(fix)
            }
        }
        
        // Apply general fixes that don't depend on specific errors
        let generalFixes = applyGeneralFixes(to: &result)
        fixes.append(contentsOf: generalFixes)
        
        return FixResult(
            fixed: result,
            fixes: fixes,
            wasFixed: !fixes.isEmpty
        )
    }
    
    /// Apply a fix for a specific error
    private func applyFix(to json: inout String, for error: JSONError) -> String? {
        let lines = json.components(separatedBy: .newlines)
        guard error.line > 0 && error.line <= lines.count else { return nil }
        
        // Get context around the error
        let lineIndex = error.line - 1
        var modifiedLines = lines
        let errorLine = lines[lineIndex]
        
        // Parse the error message to determine fix type
        if error.message.contains("Expected ','") || error.message.contains("Expected ',' or") {
            // Missing comma
            if let fixedLine = fixMissingComma(errorLine, at: error.column - 1, message: error.message) {
                modifiedLines[lineIndex] = fixedLine
                json = modifiedLines.joined(separator: "\n")
                return "Added missing comma at line \(error.line)"
            }
        } else if error.message.contains("Expected string key") {
            // Fix unquoted key or invalid character where key expected
            if let fixedLine = fixKeyIssue(errorLine, at: error.column - 1, previousLine: lineIndex > 0 ? lines[lineIndex - 1] : nil) {
                modifiedLines[lineIndex] = fixedLine
                json = modifiedLines.joined(separator: "\n")
                return "Fixed key issue at line \(error.line)"
            }
        } else if error.message.contains("Trailing comma") {
            // Remove trailing comma
            if let fixedLine = removeTrailingComma(errorLine) {
                modifiedLines[lineIndex] = fixedLine
                json = modifiedLines.joined(separator: "\n")
                return "Removed trailing comma at line \(error.line)"
            }
        } else if error.message.contains("Unterminated string") {
            // Add closing quote
            if let fixedLine = fixUnterminatedString(errorLine) {
                modifiedLines[lineIndex] = fixedLine
                json = modifiedLines.joined(separator: "\n")
                return "Fixed unterminated string at line \(error.line)"
            }
        } else if error.message.contains("found ']'") && error.message.contains("after object member") {
            // Wrong bracket type or missing comma before bracket
            if let fixedLine = fixBracketIssue(errorLine, at: error.column - 1) {
                modifiedLines[lineIndex] = fixedLine
                json = modifiedLines.joined(separator: "\n")
                return "Fixed bracket issue at line \(error.line)"
            }
        }
        
        return nil
    }
    
    /// Fix missing comma at specific position
    private func fixMissingComma(_ line: String, at position: Int, message: String) -> String? {
        guard position >= 0 else { return nil }
        
        var result = line
        let index = min(position, line.count - 1)
        let strIndex = line.index(line.startIndex, offsetBy: index)
        
        // Look for the character mentioned in the error
        if message.contains("found '") {
            if let foundCharRange = message.range(of: "found '(.)+'", options: .regularExpression) {
                let foundChar = String(message[foundCharRange]).replacingOccurrences(of: "found '", with: "").replacingOccurrences(of: "'", with: "")
                
                // Insert comma before the found character
                if let charIndex = line.range(of: foundChar, options: .literal, range: strIndex..<line.endIndex)?.lowerBound {
                    result.insert(",", at: charIndex)
                    return result
                }
            }
        }
        
        // Default: insert comma at the error position
        if index < line.count {
            result.insert(",", at: strIndex)
            return result
        }
        
        return nil
    }
    
    /// Fix key issues (unquoted keys or wrong character where key expected)
    private func fixKeyIssue(_ line: String, at position: Int, previousLine: String?) -> String? {
        var result = line
        
        // If the line contains a number or other value where a key is expected,
        // we might need to add a comma to the previous line
        if let prevLine = previousLine,
           !prevLine.trimmingCharacters(in: .whitespaces).hasSuffix(",") &&
           !prevLine.trimmingCharacters(in: .whitespaces).hasSuffix("{") &&
           !prevLine.trimmingCharacters(in: .whitespaces).hasSuffix("[") {
            // This fix would need to be applied to the previous line
            return nil
        }
        
        // Check if there's an unquoted key
        let pattern = "^\\s*([a-zA-Z_][a-zA-Z0-9_]*)\\s*:"
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let range = NSRange(location: 0, length: result.utf16.count)
            if let match = regex.firstMatch(in: result, options: [], range: range),
               let keyRange = Range(match.range(at: 1), in: result) {
                let key = String(result[keyRange])
                result = result.replacingOccurrences(of: key + ":", with: "\"" + key + "\":")
                return result
            }
        }
        
        return nil
    }
    
    /// Remove trailing comma
    private func removeTrailingComma(_ line: String) -> String? {
        let pattern = ",\\s*([}\\]])"
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let range = NSRange(location: 0, length: line.utf16.count)
            let result = regex.stringByReplacingMatches(in: line, options: [], range: range, withTemplate: "$1")
            return result != line ? result : nil
        }
        return nil
    }
    
    /// Fix unterminated string
    private func fixUnterminatedString(_ line: String) -> String? {
        var quoteCount = 0
        var inEscape = false
        
        for char in line {
            if inEscape {
                inEscape = false
                continue
            }
            if char == "\\" {
                inEscape = true
                continue
            }
            if char == "\"" {
                quoteCount += 1
            }
        }
        
        // If odd number of quotes, add one at the end
        if quoteCount % 2 == 1 {
            return line + "\""
        }
        
        return nil
    }
    
    /// Fix bracket issues
    private func fixBracketIssue(_ line: String, at position: Int) -> String? {
        var result = line
        
        // If there's a ] where we expect a comma or }, it might be a wrong bracket
        if line.contains("]") {
            // Check if this should be a }
            let beforeBracket = line.prefix(while: { $0 != "]" })
            if beforeBracket.contains(":") && !beforeBracket.contains("[") {
                // Likely should be } not ]
                result = result.replacingOccurrences(of: "]", with: "}")
                return result
            }
            
            // Or it might need a comma before it
            if let bracketRange = line.range(of: "]") {
                let beforeIndex = line.index(before: bracketRange.lowerBound)
                let charBefore = line[beforeIndex]
                if charBefore != "," && !charBefore.isWhitespace && charBefore != "[" {
                    result.insert(",", at: bracketRange.lowerBound)
                    return result
                }
            }
        }
        
        return nil
    }
    
    /// Apply general fixes not tied to specific errors
    private func applyGeneralFixes(to json: inout String) -> [String] {
        var fixes: [String] = []
        
        // Fix smart quotes
        let leftDoubleQuote = "\u{201C}"  // "
        let rightDoubleQuote = "\u{201D}" // "
        let leftSingleQuote = "\u{2018}"  // '
        let rightSingleQuote = "\u{2019}" // '
        
        if json.contains(leftDoubleQuote) || json.contains(rightDoubleQuote) || 
           json.contains(leftSingleQuote) || json.contains(rightSingleQuote) {
            json = json.replacingOccurrences(of: leftDoubleQuote, with: "\"")
                      .replacingOccurrences(of: rightDoubleQuote, with: "\"")
                      .replacingOccurrences(of: leftSingleQuote, with: "'")
                      .replacingOccurrences(of: rightSingleQuote, with: "'")
            fixes.append("Fixed smart quotes")
        }
        
        // Fix missing array brackets - more careful approach
        let lines = json.components(separatedBy: .newlines)
        var fixedLines = lines
        var modified = false
        
        for (index, line) in lines.enumerated() {
            // Check for coordinates pattern missing opening bracket
            if line.contains("\"coordinates\"") && line.contains("]") && !line.contains("[") {
                if let colonIndex = line.range(of: ":")?.upperBound {
                    var newLine = line
                    newLine.insert("[", at: colonIndex)
                    fixedLines[index] = newLine
                    modified = true
                }
            }
        }
        
        if modified {
            json = fixedLines.joined(separator: "\n")
            fixes.append("Fixed missing array brackets")
        }
        
        // Count and balance brackets
        var openCurly = 0
        var openSquare = 0
        var inString = false
        var escapeNext = false
        
        for char in json {
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
            json += String(repeating: "}", count: openCurly)
            fixes.append("Added \(openCurly) closing brace(s)")
        }
        
        if openSquare > 0 {
            json += String(repeating: "]", count: openSquare)
            fixes.append("Added \(openSquare) closing bracket(s)")
        }
        
        return fixes
    }
}