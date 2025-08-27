import Foundation

public enum JSONNode: Sendable, Hashable {
    case object([String: JSONNode])
    case array([JSONNode])
    case string(String)
    case number(Double)
    case boolean(Bool)
    case null
    
    public var formatted: String {
        formatJSON(indentLevel: 0)
    }
    
    public var minified: String {
        switch self {
        case .object(let dict):
            let pairs = dict.map { "\"\($0.key)\":\($0.value.minified)" }
            return "{\(pairs.joined(separator: ","))}"
        case .array(let items):
            return "[\(items.map { $0.minified }.joined(separator: ","))]"
        case .string(let value):
            return "\"\(value.escapedJSON)\""
        case .number(let value):
            return String(value)
        case .boolean(let value):
            return value ? "true" : "false"
        case .null:
            return "null"
        }
    }
    
    private func formatJSON(indentLevel: Int) -> String {
        let indent = String(repeating: "  ", count: indentLevel)
        let nextIndent = String(repeating: "  ", count: indentLevel + 1)
        
        switch self {
        case .object(let dict):
            if dict.isEmpty { return "{}" }
            let pairs = dict.map { key, value in
                "\(nextIndent)\"\(key)\": \(value.formatJSON(indentLevel: indentLevel + 1))"
            }
            return "{\n\(pairs.joined(separator: ",\n"))\n\(indent)}"
            
        case .array(let items):
            if items.isEmpty { return "[]" }
            let elements = items.map { item in
                "\(nextIndent)\(item.formatJSON(indentLevel: indentLevel + 1))"
            }
            return "[\n\(elements.joined(separator: ",\n"))\n\(indent)]"
            
        case .string(let value):
            return "\"\(value.escapedJSON)\""
            
        case .number(let value):
            return String(value)
            
        case .boolean(let value):
            return value ? "true" : "false"
            
        case .null:
            return "null"
        }
    }
}

extension String {
    var escapedJSON: String {
        var result = ""
        result.reserveCapacity(self.count * 2) // Reserve space for potential escaping
        
        for char in self {
            switch char {
            case "\\":
                result.append("\\\\")
            case "\"":
                result.append("\\\"")
            case "\n":
                result.append("\\n")
            case "\r":
                result.append("\\r")
            case "\t":
                result.append("\\t")
            case "\u{8}":  // Backspace
                result.append("\\b")
            case "\u{C}":  // Form feed
                result.append("\\f")
            default:
                // Handle other control characters and non-printable Unicode
                let scalar = char.unicodeScalars.first!
                if scalar.value < 0x20 || (scalar.value >= 0x7F && scalar.value <= 0x9F) {
                    // Control characters - escape as \uXXXX
                    result.append(String(format: "\\u%04X", scalar.value))
                } else if scalar.value > 0xFFFF {
                    // Characters outside BMP need surrogate pairs
                    let codePoint = scalar.value
                    let high = UInt16((codePoint - 0x10000) >> 10) + 0xD800
                    let low = UInt16((codePoint - 0x10000) & 0x3FF) + 0xDC00
                    result.append(String(format: "\\u%04X\\u%04X", high, low))
                } else {
                    result.append(char)
                }
            }
        }
        
        return result
    }
}