#!/usr/bin/env swift

import Foundation

// Test tokenizer logic directly without async
print("Testing tokenizer fixes...")

// Simulate number normalization
func normalizeNumber(_ lexeme: String) -> String {
    // Leading plus
    if lexeme.hasPrefix("+") {
        return String(lexeme.dropFirst())
    }
    
    // Leading zeros
    var result = lexeme
    while result.hasPrefix("00") {
        result = String(result.dropFirst())
    }
    
    // Bare decimal
    if result.hasPrefix(".") {
        return "0" + result
    }
    
    // Trailing decimal
    if result.hasSuffix(".") {
        return result + "0"
    }
    
    // Hex
    if result.lowercased().hasPrefix("0x") {
        let hex = String(result.dropFirst(2))
        if let value = Int(hex, radix: 16) {
            return String(value)
        }
    }
    
    // Octal
    if result.hasPrefix("0") && result.count > 1 && !result.contains(".") {
        let octal = String(result.dropFirst())
        if let value = Int(octal, radix: 8) {
            return String(value)
        }
    }
    
    return result
}

// Simulate literal normalization
func normalizeLiteral(_ lexeme: String) -> String {
    let lower = lexeme.lowercased().replacingOccurrences(of: " ", with: "")
    
    if lower == "true" || lower.hasPrefix("tru") {
        return "true"
    }
    if lower == "false" || lower.hasPrefix("fals") {
        return "false"
    }
    if lower == "null" || lower.hasPrefix("nul") {
        return "null"
    }
    if lower == "undefined" || lower == "nil" {
        return "null"
    }
    
    return lexeme
}

// Test cases
let numberTests = [
    ("+123", "123"),
    ("00123", "0123"),
    (".5", "0.5"),
    ("42.", "42.0"),
    ("0xFF", "255"),
    ("0755", "493")
]

let literalTests = [
    ("TRUE", "true"),
    ("FALSE", "false"),
    ("NULL", "null"),
    ("tru", "true"),
    ("fals", "false"),
    ("nul", "null"),
    ("tr ue", "true"),
    ("nu ll", "null"),
    ("undefined", "null"),
    ("nil", "null")
]

print("\nNumber normalization tests:")
for (input, expected) in numberTests {
    let result = normalizeNumber(input)
    let passed = result == expected
    print("\(passed ? "✅" : "❌") \(input) -> \(result) (expected \(expected))")
}

print("\nLiteral normalization tests:")
for (input, expected) in literalTests {
    let result = normalizeLiteral(input)
    let passed = result == expected
    print("\(passed ? "✅" : "❌") \(input) -> \(result) (expected \(expected))")
}

print("\nDone!")