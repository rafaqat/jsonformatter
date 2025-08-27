import Foundation

/// Consolidated test cases for JSON parsing and fixing
/// Total: ~200 test cases covering all edge cases and error scenarios
public enum JSONTestCases {
    
    /// Test case structure for all tests
    public struct TestCase: Sendable {
        public let name: String
        public let category: String
        public let input: String
        public let expectedOutput: String?
        public let shouldBeValid: Bool
        public let expectedFixes: [String]
        public let forbiddenInOutput: [String]
        public let preserveExact: [String]
        
        public init(
            name: String,
            category: String,
            input: String,
            expectedOutput: String? = nil,
            shouldBeValid: Bool = true,
            expectedFixes: [String] = [],
            forbiddenInOutput: [String] = [],
            preserveExact: [String] = []
        ) {
            self.name = name
            self.category = category
            self.input = input
            self.expectedOutput = expectedOutput
            self.shouldBeValid = shouldBeValid
            self.expectedFixes = expectedFixes
            self.forbiddenInOutput = forbiddenInOutput
            self.preserveExact = preserveExact
        }
    }
    
    /// All test cases organized by category
    public static let allTests: [TestCase] = 
        unicodeTests + 
        numberTests + 
        literalTests + 
        delimiterTests + 
        semanticTests + 
        multiRootTests + 
        whitespaceTests +
        stringTests +
        quoteTests +
        bracketTests +
        structureTests +
        comprehensiveTests
    
    // MARK: - Unicode & Escape Tests (From ExtendedTestCases + UnicodeTest)
    
    public static let unicodeTests = [
        TestCase(
            name: "Invalid unicode escape - incomplete",
            category: "unicode",
            input: #"{"text": "bad \u12"}"#,
            expectedFixes: ["Invalid escape", "unicode"],
            forbiddenInOutput: [#"\u12"#]
        ),
        TestCase(
            name: "Invalid unicode escape - non-hex",
            category: "unicode",
            input: #"{"text": "bad \uZZZZ"}"#,
            expectedFixes: ["Invalid escape", "unicode"],
            forbiddenInOutput: [#"\uZZZZ"#]
        ),
        TestCase(
            name: "Lone high surrogate",
            category: "unicode",
            input: #"{"emoji": "\uD83D"}"#,
            expectedFixes: ["surrogate", "unicode"],
            forbiddenInOutput: []
        ),
        TestCase(
            name: "Lone low surrogate",
            category: "unicode",
            input: #"{"emoji": "\uDE00"}"#,
            expectedFixes: ["surrogate", "unicode"],
            forbiddenInOutput: []
        ),
        TestCase(
            name: "Valid surrogate pair",
            category: "unicode",
            input: #"{"emoji": "\uD83D\uDE00"}"#,
            expectedFixes: [],
            preserveExact: [#"\uD83D\uDE00"#]
        ),
        TestCase(
            name: "Control characters unescaped",
            category: "unicode",
            input: "{\"text\": \"bell\\u0007tab\\ttab\\u0009vertical\\u000B\"}",
            expectedFixes: ["control", "escape"],
            forbiddenInOutput: ["\u{0007}", "\u{000B}"]
        ),
        TestCase(
            name: "Invalid escape sequences",
            category: "unicode",
            input: #"{"text": "bad \x20 \8 \9 escapes"}"#,
            expectedFixes: ["escape", "invalid"],
            forbiddenInOutput: [#"\x"#, #"\8"#, #"\9"#]
        ),
        TestCase(
            name: "Mixed valid/invalid escapes",
            category: "unicode",
            input: #"{"text": "good\n bad\q good\t"}"#,
            expectedFixes: ["escape"],
            forbiddenInOutput: [#"\q"#],
            preserveExact: [#"\n"#, #"\t"#]
        ),
        TestCase(
            name: "Null character",
            category: "unicode",
            input: #"{"text": "null\u0000char"}"#,
            expectedFixes: ["control", "null"],
            forbiddenInOutput: []
        ),
        TestCase(
            name: "Complex emoji sequences",
            category: "unicode",
            input: #"{"emoji": "👨‍👩‍👧‍👦"}"#,
            expectedFixes: [],
            preserveExact: ["👨‍👩‍👧‍👦"]
        ),
        // From UnicodeTest.swift
        TestCase(
            name: "Control characters in string",
            category: "unicode",
            input: #"{"text": "Hello\bWorld\fTest\u0000End"}"#,
            expectedFixes: [],
            preserveExact: [#"\b"#, #"\f"#, #"\u0000"#]
        ),
        TestCase(
            name: "Invalid hex escape",
            category: "unicode",
            input: #"{"text": "Invalid \xGG escape"}"#,
            expectedFixes: ["escape"],
            forbiddenInOutput: [#"\xGG"#]
        ),
        TestCase(
            name: "Mixed quotes in string",
            category: "unicode",
            input: #"{"text": "He said \"hello\" and 'goodbye'"}"#,
            expectedFixes: [],
            preserveExact: [#"\""#, "'"]
        )
    ]
    
    // MARK: - Number Tests (From ExtendedTestCases)
    
    public static let numberTests = [
        TestCase(
            name: "Leading plus sign",
            category: "numbers",
            input: #"{"num": +123}"#,
            expectedFixes: ["plus", "sign"],
            forbiddenInOutput: ["+123"],
            preserveExact: ["123"]
        ),
        TestCase(
            name: "Leading zeros",
            category: "numbers",
            input: #"{"num": 00123}"#,
            expectedFixes: ["zero", "leading"],
            forbiddenInOutput: ["00123"],
            preserveExact: ["123"]
        ),
        TestCase(
            name: "Bare decimal",
            category: "numbers",
            input: #"{"num": .5}"#,
            expectedFixes: ["decimal", "bare"],
            forbiddenInOutput: [".5"],
            preserveExact: ["0.5"]
        ),
        TestCase(
            name: "Trailing decimal",
            category: "numbers",
            input: #"{"num": 42.}"#,
            expectedFixes: ["decimal", "trailing"],
            forbiddenInOutput: ["42."],
            preserveExact: ["42.0"]
        ),
        TestCase(
            name: "Incomplete exponent",
            category: "numbers",
            input: #"{"nums": [1e, 1e+, 1e-]}"#,
            expectedFixes: ["exponent", "incomplete"],
            forbiddenInOutput: ["1e,", "1e+,", "1e-"],
            preserveExact: ["1e0"]
        ),
        TestCase(
            name: "Numeric separators",
            category: "numbers",
            input: #"{"num": 1_000_000}"#,
            expectedFixes: ["separator", "underscore"],
            forbiddenInOutput: ["_"],
            preserveExact: ["1000000"]
        ),
        TestCase(
            name: "Hex numbers",
            category: "numbers",
            input: #"{"hex": 0xFF, "oct": 0755}"#,
            expectedFixes: ["hex", "octal"],
            forbiddenInOutput: ["0x", "0755"],
            preserveExact: ["255", "493"]
        ),
        TestCase(
            name: "Infinity and NaN",
            category: "numbers",
            input: #"{"inf": Infinity, "ninf": -Infinity, "nan": NaN}"#,
            expectedFixes: ["infinity", "nan"],
            forbiddenInOutput: ["Infinity", "NaN"],
            preserveExact: ["null"]
        ),
        TestCase(
            name: "Negative zero preservation",
            category: "numbers",
            input: #"{"negzero": -0, "negzerofloat": -0.0}"#,
            expectedFixes: [],
            preserveExact: ["-0", "-0.0"]
        ),
        TestCase(
            name: "Exponent preservation",
            category: "numbers",
            input: #"{"sci": 1.23e-10, "big": 9.8E+30}"#,
            expectedFixes: [],
            preserveExact: ["1.23e-10", "9.8E+30"]
        )
    ]
    
    // MARK: - Literal Tests (From ExtendedTestCases)
    
    public static let literalTests = [
        TestCase(
            name: "Uppercase booleans",
            category: "literals",
            input: #"{"a": TRUE, "b": FALSE, "c": NULL}"#,
            expectedFixes: ["boolean", "literal"],
            forbiddenInOutput: ["TRUE", "FALSE", "NULL"],
            preserveExact: ["true", "false", "null"]
        ),
        TestCase(
            name: "Mixed case literals",
            category: "literals",
            input: #"{"a": True, "b": False, "c": Null}"#,
            expectedFixes: ["literal"],
            forbiddenInOutput: ["True", "False", "Null"],
            preserveExact: ["true", "false", "null"]
        ),
        TestCase(
            name: "Undefined to null",
            category: "literals",
            input: #"{"value": undefined}"#,
            expectedFixes: ["undefined"],
            forbiddenInOutput: ["undefined"],
            preserveExact: ["null"]
        ),
        TestCase(
            name: "Partial literals",
            category: "literals",
            input: #"{"a": tru, "b": fals, "c": nul}"#,
            expectedFixes: ["literal", "complete"],
            forbiddenInOutput: ["tru", "fals", "nul"],
            preserveExact: ["true", "false", "null"]
        ),
        TestCase(
            name: "Partial literals with spaces",
            category: "literals",
            input: #"{"a": tr ue, "b": fal se, "c": nu ll}"#,
            expectedFixes: ["literal", "space"],
            forbiddenInOutput: ["tr ue", "fal se", "nu ll"],
            preserveExact: ["true", "false", "null"]
        )
    ]
    
    // MARK: - Delimiter Tests (From ExtendedTestCases + BracketTest)
    
    public static let delimiterTests = [
        TestCase(
            name: "Missing comma in object",
            category: "delimiters",
            input: #"{"a": 1 "b": 2}"#,
            expectedFixes: ["comma"],
            preserveExact: ["1", "2"]
        ),
        TestCase(
            name: "Extra comma in array",
            category: "delimiters",
            input: #"[1, 2, 3,]"#,
            expectedFixes: ["comma", "trailing"],
            preserveExact: ["1", "2", "3"]
        ),
        TestCase(
            name: "Cross-type closure",
            category: "delimiters",
            input: #"{"a": [1, 2, 3}}"#,
            expectedFixes: ["bracket", "mismatch"],
            preserveExact: ["1", "2", "3"]
        ),
        TestCase(
            name: "Nested mismatch",
            category: "delimiters",
            input: #"{"a": [{"b": [1, 2]}]}"#,
            expectedFixes: ["bracket"],
            preserveExact: ["1", "2"]
        ),
        TestCase(
            name: "Missing opening bracket - coordinates",
            category: "delimiters",
            input: #"{"coordinates": -0.1695, 51.4865]}"#,
            expectedFixes: ["bracket"],
            preserveExact: ["-0.1695", "51.4865"]
        ),
        // From BracketTest.swift - critical user case
        TestCase(
            name: "User's exact coordinates case",
            category: "delimiters",
            input: """
            {
              "features": [
                {
                  "properties": {
                    "name": "Hyde Park"
                  },
                  "geometry": {
                    "type": "Point",
                    "coordinates": -0.1695, 51.4865]
                  }
                }
              ]
            }
            """,
            expectedFixes: ["bracket", "missing"],
            preserveExact: ["-0.1695", "51.4865", "Hyde Park"]
        ),
        TestCase(
            name: "Missing closing bracket",
            category: "delimiters",
            input: #"{"items": [1, 2, 3}"#,
            expectedFixes: ["bracket", "closing"],
            preserveExact: ["1", "2", "3"]
        ),
        TestCase(
            name: "Missing opening brace",
            category: "delimiters",
            input: #""key": "value"}"#,
            expectedFixes: ["brace", "opening"]
        ),
        TestCase(
            name: "Double closing brackets",
            category: "delimiters",
            input: #"[1, 2, 3]]"#,
            expectedFixes: ["bracket", "extra"]
        )
    ]
    
    // MARK: - Semantic Tests (From ExtendedTestCases)
    
    public static let semanticTests = [
        TestCase(
            name: "Duplicate keys",
            category: "semantics",
            input: #"{"key": 1, "key": 2, "key": 3}"#,
            expectedFixes: ["duplicate", "key"],
            preserveExact: ["1", "2", "3"]
        ),
        TestCase(
            name: "Missing colon vs comma ambiguity",
            category: "semantics",
            input: #"{"a" 1, "b": 2}"#,
            expectedFixes: ["colon"],
            preserveExact: ["1", "2"]
        ),
        TestCase(
            name: "Unquoted keys",
            category: "semantics",
            input: #"{unquoted: "value", another_key: "test"}"#,
            expectedFixes: ["quote", "key"],
            preserveExact: ["value", "test"]
        ),
        TestCase(
            name: "Unquoted key with spaces",
            category: "semantics",
            input: #"{first name: "Alice", last-name: "Bob"}"#,
            expectedFixes: ["quote", "key"],
            preserveExact: ["Alice", "Bob"]
        ),
        TestCase(
            name: "Mixed quoted/unquoted",
            category: "semantics",
            input: #"{"good": 1, bad: 2, "ok": 3}"#,
            expectedFixes: ["quote"],
            preserveExact: ["1", "2", "3"]
        )
    ]
    
    // MARK: - Multi-root Tests (From ExtendedTestCases + MultipleObjectsTest)
    
    public static let multiRootTests = [
        TestCase(
            name: "Multiple objects",
            category: "multiroot",
            input: #"{"a": 1} {"b": 2}"#,
            expectedFixes: ["multiple", "root"],
            preserveExact: ["1", "2"]
        ),
        TestCase(
            name: "NDJSON format",
            category: "multiroot",
            input: """
            {"event": "start", "time": 1}
            {"event": "data", "time": 2}
            {"event": "end", "time": 3}
            """,
            expectedFixes: ["ndjson", "multiple"],
            preserveExact: ["start", "data", "end", "1", "2", "3"]
        ),
        TestCase(
            name: "Mixed arrays and objects",
            category: "multiroot",
            input: #"[1, 2] {"a": 3} [4, 5]"#,
            expectedFixes: ["multiple"],
            preserveExact: ["1", "2", "3", "4", "5"]
        ),
        TestCase(
            name: "Comma-separated roots",
            category: "multiroot",
            input: #"{"a": 1}, {"b": 2}, {"c": 3}"#,
            expectedFixes: [],
            preserveExact: ["1", "2", "3"]
        ),
        // From MultipleObjectsTest.swift - user's exact case
        TestCase(
            name: "User's multiple objects case",
            category: "multiroot",
            input: """
            {"field1":"aa11","field2":"aa22", "structField":{"sf1" : "aaa11","sf2" : "aaa22"}},
            {"field1":"bb11","field2":"bb22","structField":{"sf1" : "bbb11","sf2" : "bbb22"}}, 
            {"field1" : "cc11","field2" : "cc22","structField" : {"sf1" : "ccc11","sf2" : "ccc22"}}
            """,
            expectedFixes: [],
            preserveExact: ["aa11", "bb11", "cc11"]
        )
    ]
    
    // MARK: - Whitespace Tests (From ExtendedTestCases)
    
    public static let whitespaceTests = [
        TestCase(
            name: "BOM at start",
            category: "whitespace",
            input: "\u{FEFF}{\"a\": 1}",
            expectedFixes: ["bom"],
            preserveExact: ["1"]
        ),
        TestCase(
            name: "Mixed line endings",
            category: "whitespace",
            input: "{\"a\":\r\n1,\r\"b\":\n2}",
            expectedFixes: [],
            preserveExact: ["1", "2"]
        ),
        TestCase(
            name: "Unicode whitespace",
            category: "whitespace",
            input: "{\u{00A0}\"a\":\u{2009}1\u{3000}}",
            expectedFixes: [],
            preserveExact: ["1"]
        )
    ]
    
    // MARK: - String Tests (From UnterminatedStringTest + FinalUnterminatedTest)
    
    public static let stringTests = [
        TestCase(
            name: "Simple unterminated at end",
            category: "strings",
            input: #"{"name": "test"#,
            expectedFixes: ["unterminated", "string"],
            preserveExact: ["test"]
        ),
        TestCase(
            name: "Unterminated in middle",
            category: "strings",
            input: #"{"name": "test, "age": 25}"#,
            expectedFixes: ["unterminated"],
            preserveExact: ["test", "25"]
        ),
        TestCase(
            name: "Unterminated key",
            category: "strings",
            input: #"{"name: "value"}"#,
            expectedFixes: ["unterminated", "key"],
            preserveExact: ["value"]
        ),
        TestCase(
            name: "Multiple unterminated",
            category: "strings",
            input: #"{"a": "one, "b": "two, "c": "three"}"#,
            expectedFixes: ["unterminated"],
            preserveExact: ["one", "two", "three"]
        ),
        TestCase(
            name: "Unterminated with escape",
            category: "strings",
            input: #"{"text": "line1\nline2"#,
            expectedFixes: ["unterminated"],
            preserveExact: ["line1", "line2"]
        ),
        TestCase(
            name: "Unterminated with quote inside",
            category: "strings",
            input: #"{"text": "He said \"hello"#,
            expectedFixes: ["unterminated"],
            preserveExact: ["hello"]
        ),
        TestCase(
            name: "Complex nested unterminated",
            category: "strings",
            input: """
            {
              "user": {
                "name": "John,
                "details": {
                  "city": "NYC
                }
              }
            }
            """,
            expectedFixes: ["unterminated"],
            preserveExact: ["John", "NYC"]
        ),
        TestCase(
            name: "Unterminated at various positions",
            category: "strings",
            input: #"{"start": "good", "middle": "bad, "end": "ok"}"#,
            expectedFixes: ["unterminated"],
            preserveExact: ["good", "bad", "ok"]
        )
    ]
    
    // MARK: - Quote Tests (From QuoteFixerTest)
    
    public static let quoteTests = [
        TestCase(
            name: "Missing opening quote on key",
            category: "quotes",
            input: #"{ name": "value" }"#,
            expectedFixes: ["quote", "opening"],
            preserveExact: ["value"]
        ),
        TestCase(
            name: "Missing closing quote on key",
            category: "quotes",
            input: #"{ "name: "value" }"#,
            expectedFixes: ["quote", "closing"],
            preserveExact: ["value"]
        ),
        TestCase(
            name: "Missing opening quote on value",
            category: "quotes",
            input: #"{ "name": value" }"#,
            expectedFixes: ["quote", "opening"],
            preserveExact: ["name"]
        ),
        TestCase(
            name: "Missing closing quote on value",
            category: "quotes",
            input: #"{ "name": "value }"#,
            expectedFixes: ["quote", "closing"],
            preserveExact: ["name"]
        ),
        TestCase(
            name: "Single quotes",
            category: "quotes",
            input: "{ 'name': 'value' }",
            expectedFixes: ["single", "quote"],
            preserveExact: ["name", "value"]
        ),
        TestCase(
            name: "Mixed single/double quotes",
            category: "quotes",
            input: #"{ "name': 'value" }"#,
            expectedFixes: ["quote", "mismatch"],
            preserveExact: ["name", "value"]
        ),
        TestCase(
            name: "Backticks",
            category: "quotes",
            input: "{ `name`: `value` }",
            expectedFixes: ["backtick"],
            preserveExact: ["name", "value"]
        ),
        TestCase(
            name: "Smart quotes",
            category: "quotes",
            input: #"{ "name": "value" }"#,
            expectedFixes: ["smart", "quote"],
            preserveExact: ["name", "value"]
        ),
        TestCase(
            name: "Missing quotes entirely",
            category: "quotes",
            input: "{ name: value }",
            expectedFixes: ["unquoted"],
            preserveExact: ["name", "value"]
        ),
        TestCase(
            name: "Escaped quotes handling",
            category: "quotes",
            input: #"{ "name": "va\"lue" }"#,
            expectedFixes: [],
            preserveExact: [#"va\"lue"#]
        )
    ]
    
    // MARK: - Bracket Tests (From BracketTest - specific bracket issues)
    
    public static let bracketTests = [
        TestCase(
            name: "Array closed with brace",
            category: "brackets",
            input: "[1, 2, 3}",
            expectedFixes: ["bracket", "mismatch"],
            preserveExact: ["1", "2", "3"]
        ),
        TestCase(
            name: "Object closed with bracket",
            category: "brackets",
            input: #"{"a": 1, "b": 2]"#,
            expectedFixes: ["bracket", "mismatch"],
            preserveExact: ["1", "2"]
        ),
        TestCase(
            name: "Missing multiple closures",
            category: "brackets",
            input: #"{"a": [1, {"b": 2"#,
            expectedFixes: ["bracket", "brace", "missing"],
            preserveExact: ["1", "2"]
        ),
        TestCase(
            name: "Extra closures",
            category: "brackets",
            input: #"{"a": 1}}}]"#,
            expectedFixes: ["bracket", "brace", "extra"],
            preserveExact: ["1"]
        ),
        TestCase(
            name: "Wrong nesting order",
            category: "brackets",
            input: "[{]}",
            expectedFixes: ["bracket", "order"],
            preserveExact: []
        ),
        TestCase(
            name: "Coordinates with number pattern",
            category: "brackets",
            input: #"{"location": 12.34, 56.78]}"#,
            expectedFixes: ["bracket", "coordinates"],
            preserveExact: ["12.34", "56.78"]
        )
    ]
    
    // MARK: - Structure Tests (From FinalUnterminatedTest)
    
    public static let structureTests = [
        TestCase(
            name: "Unterminated object",
            category: "structure",
            input: #"{"key": "value""#,
            expectedFixes: ["brace", "closing"],
            preserveExact: ["value"]
        ),
        TestCase(
            name: "Unterminated array",
            category: "structure",
            input: "[1, 2, 3",
            expectedFixes: ["bracket", "closing"],
            preserveExact: ["1", "2", "3"]
        ),
        TestCase(
            name: "Deeply nested unterminated",
            category: "structure",
            input: #"{"a": {"b": {"c": {"d": "value""#,
            expectedFixes: ["brace", "multiple"],
            preserveExact: ["value"]
        ),
        TestCase(
            name: "Mixed unterminated structures",
            category: "structure",
            input: #"{"array": [1, 2, "object": {"key": "value"#,
            expectedFixes: ["bracket", "brace"],
            preserveExact: ["1", "2", "value"]
        )
    ]
    
    // MARK: - Comprehensive Tests (From UltimateJSONTest - edge cases)
    
    public static let comprehensiveTests = [
        TestCase(
            name: "Everything wrong",
            category: "comprehensive",
            input: "{unquoted: 'single', missing 'colon', extra,, +123, .5, [1, 2}",
            expectedFixes: ["quote", "colon", "comma", "number", "bracket"],
            preserveExact: ["single", "123", "0.5", "1", "2"]
        ),
        TestCase(
            name: "Comments in JSON",
            category: "comprehensive",
            input: """
            {
              // This is a comment
              "key": "value", // inline comment
              /* block comment */
              "number": 42
            }
            """,
            expectedFixes: ["comment"],
            forbiddenInOutput: ["//", "/*", "*/"],
            preserveExact: ["value", "42"]
        ),
        TestCase(
            name: "Trailing data after valid JSON",
            category: "comprehensive",
            input: #"{"valid": true} garbage text here"#,
            expectedFixes: ["trailing"],
            forbiddenInOutput: ["garbage"],
            preserveExact: ["true"]
        ),
        TestCase(
            name: "Binary/special characters",
            category: "comprehensive",
            input: #"{"binary": "\u0000\u0001\u0002"}"#,
            expectedFixes: ["control"],
            preserveExact: []
        ),
        TestCase(
            name: "Empty structures",
            category: "comprehensive",
            input: "{, [], {}, [,], {:}}",
            expectedFixes: ["empty", "comma", "colon"],
            preserveExact: []
        ),
        TestCase(
            name: "JavaScript object notation",
            category: "comprehensive",
            input: "{key: value, func: function() {}, regex: /test/}",
            expectedFixes: ["unquoted", "function", "regex"],
            forbiddenInOutput: ["function", "regex", "/test/"],
            preserveExact: ["key", "value"]
        ),
        TestCase(
            name: "URL as unquoted value",
            category: "comprehensive",
            input: #"{"website": https://example.com}"#,
            expectedFixes: ["unquoted", "url"],
            preserveExact: ["https://example.com"]
        ),
        TestCase(
            name: "Date as raw value",
            category: "comprehensive",
            input: #"{"date": 2024-01-15T10:30:00Z}"#,
            expectedFixes: ["unquoted", "date"],
            preserveExact: ["2024-01-15T10:30:00Z"]
        ),
        TestCase(
            name: "Mixed everything",
            category: "comprehensive",
            input: """
            {
              name: John Doe,
              'age': +30,
              "skills": [JavaScript, "Python", 'C++'],
              address: {
                street: "Main St,
                number: .5
              },
              "active": TRUE
            }
            """,
            expectedFixes: ["quote", "number", "unterminated", "literal"],
            preserveExact: ["John Doe", "30", "JavaScript", "Python", "C++", "Main St", "0.5", "true"]
        )
    ]
}