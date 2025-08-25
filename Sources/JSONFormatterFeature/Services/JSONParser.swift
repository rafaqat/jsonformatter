import Foundation

public actor JSONParser {
    public init() {}
    
    public func parse(_ content: String) throws -> JSONNode {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw JSONParsingError.emptyContent
        }
        
        let data = Data(content.utf8)
        let json = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        return convertToNode(json)
    }
    
    public func parseWithProgress(_ content: String) -> AsyncStream<ParseProgress> {
        AsyncStream { continuation in
            Task {
                continuation.yield(.started)
                
                do {
                    let result = try parse(content)
                    continuation.yield(.completed(result))
                } catch {
                    continuation.yield(.failed(error))
                }
                
                continuation.finish()
            }
        }
    }
    
    private func convertToNode(_ value: Any) -> JSONNode {
        switch value {
        case let dict as [String: Any]:
            let converted = dict.mapValues { convertToNode($0) }
            return .object(converted)
            
        case let array as [Any]:
            return .array(array.map { convertToNode($0) })
            
        case let string as String:
            return .string(string)
            
        case let number as NSNumber:
            if number.isBool {
                return .boolean(number.boolValue)
            } else {
                return .number(number.doubleValue)
            }
            
        case is NSNull:
            return .null
            
        default:
            return .null
        }
    }
}

public enum ParseProgress: Sendable {
    case started
    case progress(Double)
    case completed(JSONNode)
    case failed(Error)
}

public enum JSONParsingError: LocalizedError, Sendable {
    case emptyContent
    case invalidFormat(String)
    
    public var errorDescription: String? {
        switch self {
        case .emptyContent:
            return "No content to parse"
        case .invalidFormat(let details):
            return "Invalid JSON format: \(details)"
        }
    }
}

extension NSNumber {
    fileprivate var isBool: Bool {
        String(cString: self.objCType) == "c"
    }
}