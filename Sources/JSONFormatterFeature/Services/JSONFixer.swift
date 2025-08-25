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
        
        // Fix missing brackets
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