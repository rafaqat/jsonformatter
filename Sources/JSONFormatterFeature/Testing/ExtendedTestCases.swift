import Foundation

/// Extended test cases covering critical gaps in the test suite
public struct ExtendedTestCases {
    
    // MARK: - Test Case Structure
    public struct ExtendedTestCase: Sendable {
        public let name: String
        public let category: String
        public let input: String
        public let expectedFixes: [String]  // Substrings we expect in fix messages
        public let forbiddenInOutput: [String]  // Strings that should NOT appear in output
        public let shouldBeValid: Bool  // Should be valid after fixing
        public let preserveExact: [String]  // Exact strings that must be preserved
    }
    
    // MARK: - Unicode & String Tests
    public static let unicodeStringTests = [
        ExtendedTestCase(
            name: "Invalid unicode escape - incomplete",
            category: "unicode",
            input: #"{"text": "bad \u12"}"#,
            expectedFixes: ["Invalid escape"],
            forbiddenInOutput: [],
            shouldBeValid: true,
            preserveExact: []
        ),
        ExtendedTestCase(
            name: "Invalid unicode escape - non-hex",
            category: "unicode",
            input: #"{"text": "bad \uZZZZ"}"#,
            expectedFixes: ["Invalid escape"],
            forbiddenInOutput: [],
            shouldBeValid: true,
            preserveExact: []
        ),
        ExtendedTestCase(
            name: "Lone high surrogate",
            category: "unicode",
            input: #"{"emoji": "\uD83D"}"#,
            expectedFixes: ["surrogate"],
            forbiddenInOutput: [],
            shouldBeValid: true,
            preserveExact: []
        ),
        ExtendedTestCase(
            name: "Lone low surrogate",
            category: "unicode",
            input: #"{"emoji": "\uDE00"}"#,
            expectedFixes: ["surrogate"],
            forbiddenInOutput: [],
            shouldBeValid: true,
            preserveExact: []
        ),
        ExtendedTestCase(
            name: "Control characters unescaped",
            category: "unicode",
            input: "{\"text\": \"bell\u{07}tab\u{09}vertical\u{0B}\"}",
            expectedFixes: ["control"],
            forbiddenInOutput: ["\u{07}", "\u{0B}"],  // Should be escaped
            shouldBeValid: true,
            preserveExact: []
        ),
        ExtendedTestCase(
            name: "Invalid escape sequences",
            category: "unicode",
            input: #"{"text": "bad \x20 \8 \9 escapes"}"#,
            expectedFixes: ["escape"],
            forbiddenInOutput: [],
            shouldBeValid: true,
            preserveExact: []
        ),
        ExtendedTestCase(
            name: "Mixed valid/invalid escapes",
            category: "unicode",
            input: #"{"text": "good\n bad\q good\t"}"#,
            expectedFixes: ["escape"],
            forbiddenInOutput: ["\\q"],
            shouldBeValid: true,
            preserveExact: ["\\n", "\\t"]
        ),
        ExtendedTestCase(
            name: "Brackets in strings should not be touched",
            category: "unicode",
            input: #"{"code": "if (x > 0) { return [1, 2, 3]; }"}"#,
            expectedFixes: [],
            forbiddenInOutput: [],
            shouldBeValid: true,
            preserveExact: ["if (x > 0) { return [1, 2, 3]; }"]
        ),
        ExtendedTestCase(
            name: "Comments in strings preserved",
            category: "unicode",
            input: #"{"url": "http://example.com/path // not a comment", "code": "/* not a comment */"}"#,
            expectedFixes: [],
            forbiddenInOutput: [],
            shouldBeValid: true,
            preserveExact: ["http://example.com/path // not a comment", "/* not a comment */"]
        ),
        ExtendedTestCase(
            name: "Non-breaking space handling",
            category: "unicode",
            input: "{\"text\":\u{00A0}\"value\"}",  // NBSP between : and "
            expectedFixes: ["whitespace"],
            forbiddenInOutput: [],
            shouldBeValid: true,
            preserveExact: []
        )
    ]
    
    // MARK: - Number Tests
    public static let numberTests = [
        ExtendedTestCase(
            name: "Leading plus sign",
            category: "numbers",
            input: #"{"num": +123}"#,
            expectedFixes: ["number"],
            forbiddenInOutput: ["+123"],
            shouldBeValid: true,
            preserveExact: []
        ),
        ExtendedTestCase(
            name: "Leading zeros",
            category: "numbers",
            input: #"{"num": 00123}"#,
            expectedFixes: ["number"],
            forbiddenInOutput: [],
            shouldBeValid: true,
            preserveExact: []
        ),
        ExtendedTestCase(
            name: "Bare decimal",
            category: "numbers",
            input: #"{"num": .5}"#,
            expectedFixes: ["number"],
            forbiddenInOutput: [],
            shouldBeValid: true,
            preserveExact: []
        ),
        ExtendedTestCase(
            name: "Trailing decimal",
            category: "numbers",
            input: #"{"num": 42.}"#,
            expectedFixes: ["number"],
            forbiddenInOutput: [],
            shouldBeValid: true,
            preserveExact: []
        ),
        ExtendedTestCase(
            name: "Incomplete exponent",
            category: "numbers",
            input: #"{"nums": [1e, 1e+, 1e-]}"#,
            expectedFixes: ["number"],
            forbiddenInOutput: [],
            shouldBeValid: true,
            preserveExact: []
        ),
        ExtendedTestCase(
            name: "Large integer precision",
            category: "numbers",
            input: #"{"bigint": 9007199254740993}"#,  // 2^53 + 1
            expectedFixes: [],
            forbiddenInOutput: [],
            shouldBeValid: true,
            preserveExact: ["9007199254740993"]  // Must preserve exact
        ),
        ExtendedTestCase(
            name: "Numeric separators",
            category: "numbers",
            input: #"{"num": 1_000_000}"#,
            expectedFixes: ["number"],
            forbiddenInOutput: ["_"],
            shouldBeValid: true,
            preserveExact: []
        ),
        ExtendedTestCase(
            name: "Hex numbers",
            category: "numbers",
            input: #"{"hex": 0xFF, "oct": 0755}"#,
            expectedFixes: ["number"],
            forbiddenInOutput: ["0x", "0X"],
            shouldBeValid: true,
            preserveExact: []
        ),
        ExtendedTestCase(
            name: "Negative zero preservation",
            category: "numbers",
            input: #"{"negzero": -0, "negzerofloat": -0.0}"#,
            expectedFixes: [],
            forbiddenInOutput: [],
            shouldBeValid: true,
            preserveExact: ["-0", "-0.0"]
        ),
        ExtendedTestCase(
            name: "Number format preservation",
            category: "numbers",
            input: #"{"sci": 1.0e2, "dec": 1.00, "int": 42}"#,
            expectedFixes: [],
            forbiddenInOutput: [],
            shouldBeValid: true,
            preserveExact: ["1.0e2", "1.00", "42"]
        )
    ]
    
    // MARK: - Literal Tests
    public static let literalTests = [
        ExtendedTestCase(
            name: "Uppercase booleans",
            category: "literals",
            input: #"{"a": TRUE, "b": FALSE, "c": NULL}"#,
            expectedFixes: ["literal", "boolean", "null"],
            forbiddenInOutput: ["TRUE", "FALSE", "NULL"],
            shouldBeValid: true,
            preserveExact: []
        ),
        ExtendedTestCase(
            name: "Mixed case literals",
            category: "literals",
            input: #"{"a": True, "b": False, "c": Null}"#,
            expectedFixes: ["literal"],
            forbiddenInOutput: ["True", "False", "Null"],
            shouldBeValid: true,
            preserveExact: []
        ),
        ExtendedTestCase(
            name: "Partial literals with spaces",
            category: "literals",
            input: #"{"a": tr ue, "b": fal se, "c": nu ll}"#,
            expectedFixes: ["literal"],
            forbiddenInOutput: ["tr ue", "fal se", "nu ll"],
            shouldBeValid: true,
            preserveExact: []
        ),
        ExtendedTestCase(
            name: "Undefined keyword",
            category: "literals",
            input: #"{"value": undefined}"#,
            expectedFixes: ["undefined"],
            forbiddenInOutput: ["undefined"],
            shouldBeValid: true,
            preserveExact: []
        ),
        ExtendedTestCase(
            name: "nil keyword",
            category: "literals",
            input: #"{"value": nil}"#,
            expectedFixes: ["nil"],
            forbiddenInOutput: ["nil"],
            shouldBeValid: true,
            preserveExact: []
        )
    ]
    
    // MARK: - Delimiter Tests
    public static let delimiterTests = [
        ExtendedTestCase(
            name: "Array closed with brace",
            category: "delimiters",
            input: #"{"arr": [1, 2, 3}}"#,
            expectedFixes: ["bracket", "brace"],
            forbiddenInOutput: [],
            shouldBeValid: true,
            preserveExact: []
        ),
        ExtendedTestCase(
            name: "Object closed with bracket",
            category: "delimiters",
            input: #"{"obj": {"a": 1, "b": 2]}"#,
            expectedFixes: ["bracket", "brace"],
            forbiddenInOutput: [],
            shouldBeValid: true,
            preserveExact: []
        ),
        ExtendedTestCase(
            name: "Nested mismatch",
            category: "delimiters",
            input: #"{"a": [{"b": [1, 2]}]}"#,  // Extra closing bracket
            expectedFixes: ["bracket"],
            forbiddenInOutput: [],
            shouldBeValid: true,
            preserveExact: []
        ),
        ExtendedTestCase(
            name: "Complex cross-type closure",
            category: "delimiters",
            input: #"{"a": [{"b": 1}], "c": 2]}"#,  // Object ends with ]
            expectedFixes: ["bracket", "brace"],
            forbiddenInOutput: [],
            shouldBeValid: true,
            preserveExact: []
        ),
        ExtendedTestCase(
            name: "Missing opening bracket - coordinates",
            category: "delimiters",
            input: #"{"coordinates": -0.1695, 51.4865]}"#,
            expectedFixes: ["bracket"],
            forbiddenInOutput: [],
            shouldBeValid: true,
            preserveExact: ["-0.1695", "51.4865"]
        )
    ]
    
    // MARK: - Object/Array Semantics Tests
    public static let semanticsTests = [
        ExtendedTestCase(
            name: "Missing colon vs comma ambiguity 1",
            category: "semantics",
            input: #"{"a" "b": 1}"#,
            expectedFixes: ["colon"],
            forbiddenInOutput: [],
            shouldBeValid: true,
            preserveExact: []
        ),
        ExtendedTestCase(
            name: "Missing colon vs comma ambiguity 2",
            category: "semantics",
            input: #"{"a": 1 "b": 2}"#,
            expectedFixes: ["comma"],
            forbiddenInOutput: [],
            shouldBeValid: true,
            preserveExact: []
        ),
        ExtendedTestCase(
            name: "Unquoted key with spaces",
            category: "semantics",
            input: #"{first name: "Alice", last-name: "Bob"}"#,
            expectedFixes: ["quote", "key"],
            forbiddenInOutput: [],
            shouldBeValid: true,
            preserveExact: ["Alice", "Bob"]
        ),
        ExtendedTestCase(
            name: "Unicode unquoted keys",
            category: "semantics",
            input: #"{ключ: "value", 名前: "名前"}"#,
            expectedFixes: ["quote", "key"],
            forbiddenInOutput: [],
            shouldBeValid: true,
            preserveExact: ["value", "名前"]
        ),
        ExtendedTestCase(
            name: "Duplicate keys warning",
            category: "semantics",
            input: #"{"key": 1, "key": 2, "key": 3}"#,
            expectedFixes: ["duplicate"],
            forbiddenInOutput: [],
            shouldBeValid: true,  // Valid JSON, just a warning
            preserveExact: []
        )
    ]
    
    // MARK: - Multi-root Tests
    public static let multiRootTests = [
        ExtendedTestCase(
            name: "Multiple root objects",
            category: "multiroot",
            input: #"{"a": 1} {"b": 2} {"c": 3}"#,
            expectedFixes: ["multiple", "root"],
            forbiddenInOutput: [],
            shouldBeValid: true,
            preserveExact: []
        ),
        ExtendedTestCase(
            name: "NDJSON format",
            category: "multiroot",
            input: "{\"a\": 1}\n{\"b\": 2}\n{\"c\": 3}",
            expectedFixes: ["multiple", "root"],
            forbiddenInOutput: [],
            shouldBeValid: true,
            preserveExact: []
        ),
        ExtendedTestCase(
            name: "Trailing content after valid JSON",
            category: "multiroot",
            input: #"{"valid": true} trailing garbage here"#,
            expectedFixes: ["trailing"],
            forbiddenInOutput: ["trailing garbage here"],
            shouldBeValid: true,
            preserveExact: []
        ),
        ExtendedTestCase(
            name: "Mixed arrays and objects",
            category: "multiroot",
            input: #"[1, 2] {"a": 3} [4, 5]"#,
            expectedFixes: ["multiple", "root"],
            forbiddenInOutput: [],
            shouldBeValid: true,
            preserveExact: []
        )
    ]
    
    // MARK: - Whitespace Tests
    public static let whitespaceTests = [
        ExtendedTestCase(
            name: "CRLF line endings",
            category: "whitespace",
            input: "{\r\n  \"key\": \"value\"\r\n}",
            expectedFixes: [],
            forbiddenInOutput: [],
            shouldBeValid: true,
            preserveExact: []
        ),
        ExtendedTestCase(
            name: "Mixed tabs and spaces",
            category: "whitespace",
            input: "{\n\t  \"key\": \"value\",\n  \t\"key2\": \"value2\"\n}",
            expectedFixes: [],
            forbiddenInOutput: [],
            shouldBeValid: true,
            preserveExact: []
        ),
        ExtendedTestCase(
            name: "Non-breaking spaces between tokens",
            category: "whitespace",
            input: "{\u{00A0}\"key\":\u{00A0}\"value\"\u{00A0}}",
            expectedFixes: ["whitespace"],
            forbiddenInOutput: [],
            shouldBeValid: true,
            preserveExact: []
        )
    ]
    
    // MARK: - All Tests Combined
    public static var allExtendedTests: [ExtendedTestCase] {
        return unicodeStringTests + numberTests + literalTests + 
               delimiterTests + semanticsTests + multiRootTests + whitespaceTests
    }
    
    // MARK: - Test Helpers
    public struct TestHelpers {
        /// Run auto-fix and validate result
        public static func assertValidAfterFix(
            _ testCase: ExtendedTestCase,
            fixer: JSONFixer,
            parser: JSONParser
        ) async throws {
            // Run the fixer
            let fixResult = await fixer.fix(testCase.input)
            
            // Check expected fixes were applied
            for expectedFix in testCase.expectedFixes {
                let foundFix = fixResult.fixes.contains { fix in
                    fix.lowercased().contains(expectedFix.lowercased())
                }
                assert(foundFix, "Expected fix containing '\(expectedFix)' not found in: \(fixResult.fixes)")
            }
            
            // Check forbidden strings are not in output
            for forbidden in testCase.forbiddenInOutput {
                assert(!fixResult.fixed.contains(forbidden), 
                       "Forbidden string '\(forbidden)' found in output")
            }
            
            // Check preserved strings remain exact
            for preserved in testCase.preserveExact {
                assert(fixResult.fixed.contains(preserved),
                       "Expected preserved string '\(preserved)' not found in output")
            }
            
            // Validate the result
            if testCase.shouldBeValid {
                let errors = await parser.validate(fixResult.fixed)
                assert(errors.isEmpty, 
                       "Fixed JSON should be valid but has errors: \(errors)")
            }
        }
        
        /// Test idempotence - running fix twice should produce same result
        public static func assertIdempotent(
            _ input: String,
            fixer: JSONFixer
        ) async throws {
            let firstFix = await fixer.fix(input)
            let secondFix = await fixer.fix(firstFix.fixed)
            
            assert(firstFix.fixed == secondFix.fixed,
                   "Fix is not idempotent - output changed on second run")
            assert(secondFix.fixes.isEmpty || !secondFix.wasFixed,
                   "Second fix pass reported changes: \(secondFix.fixes)")
        }
        
        /// Performance test helper
        public static func measureFixTime(
            _ input: String,
            fixer: JSONFixer,
            maxSeconds: Double = 1.0
        ) async throws {
            let start = Date()
            _ = await fixer.fix(input)
            let elapsed = Date().timeIntervalSince(start)
            
            assert(elapsed < maxSeconds,
                   "Fix took \(elapsed)s, expected < \(maxSeconds)s")
        }
    }
}

// MARK: - Large/Performance Test Cases
extension ExtendedTestCases {
    /// Generate a large JSON with periodic errors for performance testing
    public static func generateLargeJSON(nodes: Int, errorRate: Double = 0.01) -> String {
        var result = "{\n"
        for i in 0..<nodes {
            let hasError = Double.random(in: 0...1) < errorRate
            
            if hasError {
                // Inject an error
                let errorType = Int.random(in: 0...4)
                switch errorType {
                case 0: result += "  unquoted_key_\(i): \(i)"  // Unquoted key
                case 1: result += "  \"key_\(i)\" \(i)"        // Missing colon
                case 2: result += "  \"key_\(i)\": \(i)"       // Valid (will miss comma)
                case 3: result += "  \"key_\(i)\": "           // Missing value
                default: result += "  \"key_\(i)\": undefined" // Invalid literal
                }
            } else {
                result += "  \"key_\(i)\": \(i)"
            }
            
            if i < nodes - 1 {
                result += ","
            }
            result += "\n"
        }
        result += "}"
        return result
    }
}