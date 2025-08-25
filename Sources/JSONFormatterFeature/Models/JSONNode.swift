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
        self
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
    }
}