import Foundation

public actor JSONValidator {
    public init() {}
    
    public func validate(_ content: String) -> ValidationResult {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return ValidationResult(isValid: true, errors: [])
        }
        
        var errors: [JSONError] = []
        
        // Try to parse with JSONSerialization for detailed error info
        let data = Data(content.utf8)
        
        do {
            _ = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
            
            // If parsing succeeds, perform additional validation
            errors.append(contentsOf: performStructuralValidation(content))
            errors.append(contentsOf: performStyleValidation(content))
            
            return ValidationResult(isValid: errors.isEmpty, errors: errors)
        } catch let error as NSError {
            // Parse the error to get line and column information
            let errorInfo = parseJSONError(error, content: content)
            errors.append(errorInfo)
            
            // Try to provide helpful suggestions
            errors.append(contentsOf: suggestFixes(for: content, baseError: errorInfo))
            
            return ValidationResult(isValid: false, errors: errors)
        }
    }
    
    private func parseJSONError(_ error: NSError, content: String) -> JSONError {
        let description = error.localizedDescription
        
        // Try to extract line and column from error description
        var line = 1
        var column = 1
        
        // JSONSerialization often includes byte position in error
        if let debugDescription = error.userInfo[NSDebugDescriptionErrorKey] as? String {
            // Try to find byte position
            if let range = debugDescription.range(of: "around character ") ?? 
               debugDescription.range(of: "at position ") {
                let posStr = String(debugDescription[range.upperBound...])
                    .components(separatedBy: CharacterSet.decimalDigits.inverted)
                    .first ?? ""
                
                if let position = Int(posStr) {
                    let (foundLine, foundColumn) = getLineAndColumn(at: position, in: content)
                    line = foundLine
                    column = foundColumn
                }
            }
        }
        
        return JSONError(
            line: line,
            column: column,
            message: description,
            severity: .error
        )
    }
    
    private func getLineAndColumn(at position: Int, in content: String) -> (line: Int, column: Int) {
        var line = 1
        var column = 1
        var currentPos = 0
        
        for char in content {
            if currentPos == position {
                break
            }
            
            if char == "\n" {
                line += 1
                column = 1
            } else {
                column += 1
            }
            
            currentPos += 1
        }
        
        return (line, column)
    }
    
    private func performStructuralValidation(_ content: String) -> [JSONError] {
        var errors: [JSONError] = []
        
        // Check for common structural issues
        let lines = content.components(separatedBy: .newlines)
        
        for (index, line) in lines.enumerated() {
            let lineNumber = index + 1
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Check for trailing commas (last non-empty line before closing bracket)
            if trimmed.hasSuffix(",]") || trimmed.hasSuffix(",}") {
                errors.append(JSONError(
                    line: lineNumber,
                    column: line.count,
                    message: "Trailing comma before closing bracket",
                    severity: .warning
                ))
            }
            
            // Check for single quotes (common mistake)
            if trimmed.contains("'") && !trimmed.contains("\"") {
                let column = (line.firstIndex(of: "'")?.utf16Offset(in: line) ?? 0) + 1
                errors.append(JSONError(
                    line: lineNumber,
                    column: column,
                    message: "Single quotes are not valid in JSON, use double quotes",
                    severity: .error
                ))
            }
            
            // Check for comments
            if trimmed.hasPrefix("//") || trimmed.contains("/*") {
                errors.append(JSONError(
                    line: lineNumber,
                    column: 1,
                    message: "Comments are not allowed in standard JSON",
                    severity: .warning
                ))
            }
            
            // Check for unquoted keys
            let unquotedKeyPattern = "^\\s*([a-zA-Z_][a-zA-Z0-9_]*)\\s*:"
            if let regex = try? NSRegularExpression(pattern: unquotedKeyPattern),
               regex.firstMatch(in: line, range: NSRange(location: 0, length: line.count)) != nil {
                errors.append(JSONError(
                    line: lineNumber,
                    column: 1,
                    message: "Object keys must be quoted",
                    severity: .error
                ))
            }
        }
        
        return errors
    }
    
    private func performStyleValidation(_ content: String) -> [JSONError] {
        var warnings: [JSONError] = []
        
        // Check for inconsistent indentation
        let lines = content.components(separatedBy: .newlines)
        var indentationStyles = Set<Int>()
        
        for line in lines {
            if !line.trimmingCharacters(in: .whitespaces).isEmpty {
                let leadingSpaces = line.prefix(while: { $0 == " " }).count
                if leadingSpaces > 0 {
                    indentationStyles.insert(leadingSpaces)
                }
            }
        }
        
        if indentationStyles.count > 2 {
            warnings.append(JSONError(
                line: 0,
                column: 0,
                message: "Inconsistent indentation detected",
                severity: .info
            ))
        }
        
        // Check for very long lines
        for (index, line) in lines.enumerated() {
            if line.count > 120 {
                warnings.append(JSONError(
                    line: index + 1,
                    column: 120,
                    message: "Line exceeds recommended length of 120 characters",
                    severity: .info
                ))
            }
        }
        
        return warnings
    }
    
    private func suggestFixes(for content: String, baseError: JSONError) -> [JSONError] {
        var suggestions: [JSONError] = []
        
        // Analyze the content around the error position
        let lines = content.components(separatedBy: .newlines)
        guard baseError.line > 0 && baseError.line <= lines.count else {
            return suggestions
        }
        
        let errorLine = lines[baseError.line - 1]
        
        // Check for common issues and suggest fixes
        if errorLine.contains("'") {
            suggestions.append(JSONError(
                line: baseError.line,
                column: baseError.column,
                message: "Tip: Replace single quotes with double quotes",
                severity: .info
            ))
        }
        
        if errorLine.contains("undefined") || errorLine.contains("NaN") {
            suggestions.append(JSONError(
                line: baseError.line,
                column: baseError.column,
                message: "Tip: 'undefined' and 'NaN' are not valid JSON values. Use null instead",
                severity: .info
            ))
        }
        
        // Check for missing commas
        if baseError.line > 1 {
            let previousLine = lines[baseError.line - 2]
            if !previousLine.trimmingCharacters(in: .whitespaces).isEmpty &&
               !previousLine.trimmingCharacters(in: .whitespaces).hasSuffix(",") &&
               !previousLine.trimmingCharacters(in: .whitespaces).hasSuffix("{") &&
               !previousLine.trimmingCharacters(in: .whitespaces).hasSuffix("[") {
                suggestions.append(JSONError(
                    line: baseError.line - 1,
                    column: previousLine.count,
                    message: "Tip: Missing comma after this line",
                    severity: .info
                ))
            }
        }
        
        return suggestions
    }
}

public struct ValidationResult: Sendable {
    public let isValid: Bool
    public let errors: [JSONError]
    
    public var hasErrors: Bool {
        errors.contains { $0.severity == .error }
    }
    
    public var hasWarnings: Bool {
        errors.contains { $0.severity == .warning }
    }
}