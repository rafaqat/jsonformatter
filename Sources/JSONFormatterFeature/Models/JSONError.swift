import Foundation

public struct JSONError: Error, Sendable, Identifiable, Equatable {
    public let id = UUID()
    public let line: Int
    public let column: Int
    public let message: String
    public let severity: ErrorSeverity
    
    public static func == (lhs: JSONError, rhs: JSONError) -> Bool {
        lhs.line == rhs.line && 
        lhs.column == rhs.column && 
        lhs.message == rhs.message && 
        lhs.severity == rhs.severity
    }
    
    public init(line: Int, column: Int, message: String, severity: ErrorSeverity = .error) {
        self.line = line
        self.column = column
        self.message = message
        self.severity = severity
    }
    
    public init(from error: Error) {
        self.line = 0
        self.column = 0
        self.message = error.localizedDescription
        self.severity = .error
    }
}

public enum ErrorSeverity: Sendable, Equatable {
    case warning
    case error
    case info
}