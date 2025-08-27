import Foundation
import JSONFormatterFeature


/// Comprehensive parser test suite based on JSONTestSuite methodology
/// Categories: y_ (must accept), n_ (must reject), i_ (implementation defined)
@main
struct ParserTestSuite {
    
    // Test case structure
    struct TestCase {
        enum Category {
            case mustAccept    // y_ files
            case mustReject    // n_ files
            case implDefined   // i_ files
        }
        
        let name: String
        let input: String
        let category: Category
        let description: String
        let expectedFixes: [String] = []
    }
    
    static func main() async {
        print("🧪 JSON PARSER TEST SUITE")
        print("Based on JSONTestSuite methodology (github.com/nst/JSONTestSuite)")
        print(String(repeating: "=", count: 80))
        
        await runAllTests()
    }
    
    static func runAllTests() async {
        print("Starting test execution...")
        
        // Run each category
        print("Running structure tests...")
        await runStructureTests()
        
        print("Running number tests...")
        await runNumberTests()
        
        print("Running string tests...")
        await runStringTests()
        
        print("Running array tests...")
        await runArrayTests()
        
        print("Running object tests...")
        await runObjectTests()
        
        print("Running edge case tests...")
        await runEdgeCaseTests()
        
        print("Running performance tests...")
        await runPerformanceTests()
        
        print("Running differential tests...")
        await runDifferentialTests()
        
        print("\n" + String(repeating: "=", count: 80))
        print("✅ All test categories completed")
    }
    
    // MARK: - Structure Tests
    
    static func runStructureTests() async {
        print("\n📁 STRUCTURE TESTS")
        print(String(repeating: "-", count: 60))
        
        let tests = [
            // Valid structures (y_)
            TestCase(name: "y_object_empty", input: "{}", category: .mustAccept, 
                    description: "Empty object"),
            TestCase(name: "y_array_empty", input: "[]", category: .mustAccept,
                    description: "Empty array"),
            TestCase(name: "y_string_simple", input: #""hello""#, category: .mustAccept,
                    description: "Simple string"),
            TestCase(name: "y_number_simple", input: "123", category: .mustAccept,
                    description: "Simple number"),
            TestCase(name: "y_true", input: "true", category: .mustAccept,
                    description: "Boolean true"),
            TestCase(name: "y_false", input: "false", category: .mustAccept,
                    description: "Boolean false"),
            TestCase(name: "y_null", input: "null", category: .mustAccept,
                    description: "Null value"),
            
            // Invalid structures (n_)
            TestCase(name: "n_array_unclosed", input: "[1,2", category: .mustReject,
                    description: "Unclosed array"),
            TestCase(name: "n_object_unclosed", input: #"{"a":1"#, category: .mustReject,
                    description: "Unclosed object"),
            TestCase(name: "n_array_comma_after_close", input: "[1],", category: .mustReject,
                    description: "Comma after close"),
            TestCase(name: "n_array_double_comma", input: "[1,,2]", category: .mustReject,
                    description: "Double comma"),
            TestCase(name: "n_object_missing_colon", input: #"{"a" 1}"#, category: .mustReject,
                    description: "Missing colon"),
            
            // Implementation defined (i_)
            TestCase(name: "i_object_trailing_comma", input: #"{"a":1,}"#, category: .implDefined,
                    description: "Trailing comma in object"),
            TestCase(name: "i_array_trailing_comma", input: "[1,2,]", category: .implDefined,
                    description: "Trailing comma in array"),
            TestCase(name: "i_top_level_string", input: #""hello""#, category: .implDefined,
                    description: "Top-level string (RFC 7159 allows)")
        ]
        
        await runTestCategory(tests)
    }
    
    // MARK: - Number Tests
    
    static func runNumberTests() async {
        print("\n🔢 NUMBER TESTS")
        print(String(repeating: "-", count: 60))
        
        let tests = [
            // Valid numbers (y_)
            TestCase(name: "y_number_0", input: "[0]", category: .mustAccept,
                    description: "Zero"),
            TestCase(name: "y_number_negative_zero", input: "[-0]", category: .mustAccept,
                    description: "Negative zero"),
            TestCase(name: "y_number_real_exponent", input: "[1e1]", category: .mustAccept,
                    description: "Number with exponent"),
            TestCase(name: "y_number_negative_int", input: "[-123]", category: .mustAccept,
                    description: "Negative integer"),
            TestCase(name: "y_number_real_fraction", input: "[1.23]", category: .mustAccept,
                    description: "Decimal number"),
            
            // Invalid numbers (n_)
            TestCase(name: "n_number_++", input: "[++1234]", category: .mustReject,
                    description: "Double plus"),
            TestCase(name: "n_number_+1", input: "[+1]", category: .mustReject,
                    description: "Leading plus"),
            TestCase(name: "n_number_01", input: "[01]", category: .mustReject,
                    description: "Leading zero"),
            TestCase(name: "n_number_hex", input: "[0x42]", category: .mustReject,
                    description: "Hex number"),
            TestCase(name: "n_number_infinity", input: "[Infinity]", category: .mustReject,
                    description: "Infinity literal"),
            TestCase(name: "n_number_NaN", input: "[NaN]", category: .mustReject,
                    description: "NaN literal"),
            TestCase(name: "n_number_.2", input: "[.2]", category: .mustReject,
                    description: "Number starting with dot"),
            TestCase(name: "n_number_2.", input: "[2.]", category: .mustReject,
                    description: "Number ending with dot"),
            
            // Implementation defined (i_)
            TestCase(name: "i_number_huge", input: "[1e308]", category: .implDefined,
                    description: "Very large number"),
            TestCase(name: "i_number_very_negative", input: "[-1e308]", category: .implDefined,
                    description: "Very negative number"),
            TestCase(name: "i_number_precision", input: "[1.7976931348623157e308]", category: .implDefined,
                    description: "Max precision")
        ]
        
        await runTestCategory(tests)
    }
    
    // MARK: - String Tests
    
    static func runStringTests() async {
        print("\n📝 STRING TESTS")
        print(String(repeating: "-", count: 60))
        
        let tests = [
            // Valid strings (y_)
            TestCase(name: "y_string_escaped_quote", input: #"["\""]"#, category: .mustAccept,
                    description: "Escaped quote"),
            TestCase(name: "y_string_escaped_backslash", input: #"["\\"]"#, category: .mustAccept,
                    description: "Escaped backslash"),
            TestCase(name: "y_string_unicode", input: #"["\u0061"]"#, category: .mustAccept,
                    description: "Unicode escape"),
            TestCase(name: "y_string_surrogate_pair", input: #"["\uD801\uDC37"]"#, category: .mustAccept,
                    description: "Valid surrogate pair"),
            
            // Invalid strings (n_)
            TestCase(name: "n_string_unescaped_tab", input: "[\"\t\"]", category: .mustReject,
                    description: "Unescaped tab"),
            TestCase(name: "n_string_unescaped_newline", input: "[\"\n\"]", category: .mustReject,
                    description: "Unescaped newline"),
            TestCase(name: "n_string_unterminated", input: #"["unterminated]"#, category: .mustReject,
                    description: "Unterminated string"),
            TestCase(name: "n_string_invalid_escape", input: #"["\x"]"#, category: .mustReject,
                    description: "Invalid escape \\x"),
            TestCase(name: "n_string_single_quote", input: "['single quotes']", category: .mustReject,
                    description: "Single quotes"),
            TestCase(name: "n_string_lone_surrogate", input: #"["\uD800"]"#, category: .mustReject,
                    description: "Lone high surrogate"),
            TestCase(name: "n_string_invalid_unicode", input: #"["\u12Z4"]"#, category: .mustReject,
                    description: "Invalid unicode escape"),
            
            // Implementation defined (i_)
            TestCase(name: "i_string_null_byte", input: #"["\u0000"]"#, category: .implDefined,
                    description: "Null byte in string"),
            TestCase(name: "i_string_invalid_codepoint", input: #"["\uFFFF"]"#, category: .implDefined,
                    description: "Invalid codepoint U+FFFF"),
            TestCase(name: "i_string_bom", input: "\u{FEFF}[]", category: .implDefined,
                    description: "BOM at start")
        ]
        
        await runTestCategory(tests)
    }
    
    // MARK: - Array Tests
    
    static func runArrayTests() async {
        print("\n📚 ARRAY TESTS")
        print(String(repeating: "-", count: 60))
        
        let tests = [
            // Valid arrays (y_)
            TestCase(name: "y_array_heterogeneous", input: #"[1, "two", null, true]"#, category: .mustAccept,
                    description: "Mixed types"),
            TestCase(name: "y_array_nested", input: "[[1], [2, [3]]]", category: .mustAccept,
                    description: "Nested arrays"),
            
            // Invalid arrays (n_)
            TestCase(name: "n_array_extra_close", input: "[1]]]", category: .mustReject,
                    description: "Extra closing brackets"),
            TestCase(name: "n_array_missing_comma", input: "[1 2]", category: .mustReject,
                    description: "Missing comma"),
            TestCase(name: "n_array_colon", input: "[1:2]", category: .mustReject,
                    description: "Colon instead of comma"),
            
            // Implementation defined (i_)
            TestCase(name: "i_array_deep_nesting", input: String(repeating: "[", count: 100) + 
                                                        String(repeating: "]", count: 100), 
                    category: .implDefined,
                    description: "Deep nesting (100 levels)")
        ]
        
        await runTestCategory(tests)
    }
    
    // MARK: - Object Tests
    
    static func runObjectTests() async {
        print("\n📦 OBJECT TESTS")
        print(String(repeating: "-", count: 60))
        
        let tests = [
            // Valid objects (y_)
            TestCase(name: "y_object_simple", input: #"{"a": 1}"#, category: .mustAccept,
                    description: "Simple object"),
            TestCase(name: "y_object_nested", input: #"{"a": {"b": 2}}"#, category: .mustAccept,
                    description: "Nested object"),
            
            // Invalid objects (n_)
            TestCase(name: "n_object_unquoted_key", input: "{a: 1}", category: .mustReject,
                    description: "Unquoted key"),
            TestCase(name: "n_object_single_quote_key", input: "{'a': 1}", category: .mustReject,
                    description: "Single-quoted key"),
            TestCase(name: "n_object_number_key", input: "{1: 1}", category: .mustReject,
                    description: "Number as key"),
            TestCase(name: "n_object_missing_value", input: #"{"a":}"#, category: .mustReject,
                    description: "Missing value"),
            TestCase(name: "n_object_comma_instead_colon", input: #"{"a", 1}"#, category: .mustReject,
                    description: "Comma instead of colon"),
            
            // Implementation defined (i_)
            TestCase(name: "i_object_duplicate_key", input: #"{"a": 1, "a": 2}"#, category: .implDefined,
                    description: "Duplicate keys"),
            TestCase(name: "i_object_unicode_key", input: #"{"\u0061": 1}"#, category: .implDefined,
                    description: "Unicode escaped key")
        ]
        
        await runTestCategory(tests)
    }
    
    // MARK: - Edge Case Tests
    
    static func runEdgeCaseTests() async {
        print("\n⚠️ EDGE CASE TESTS")
        print(String(repeating: "-", count: 60))
        
        let tests = [
            // Whitespace edge cases
            TestCase(name: "i_ws_nbsp", input: "[\u{00A0}1]", category: .implDefined,
                    description: "Non-breaking space"),
            TestCase(name: "i_ws_line_separator", input: "[\u{2028}1]", category: .implDefined,
                    description: "Line separator U+2028"),
            
            // Multiple values
            TestCase(name: "n_multiple_json", input: "{} {}", category: .mustReject,
                    description: "Multiple root values"),
            TestCase(name: "i_ndjson", input: "{\"a\":1}\n{\"b\":2}", category: .implDefined,
                    description: "NDJSON format"),
            
            // Comments (not standard JSON)
            TestCase(name: "n_comment_single_line", input: "// comment\n{}", category: .mustReject,
                    description: "Single line comment"),
            TestCase(name: "n_comment_multi_line", input: "/* comment */{}", category: .mustReject,
                    description: "Multi-line comment"),
            
            // Extreme values
            TestCase(name: "i_string_1mb", input: #"["\#(String(repeating: "a", count: 1_000_000))"]"#, 
                    category: .implDefined,
                    description: "1MB string"),
            TestCase(name: "i_array_1000_elements", input: "[" + (1...1000).map { String($0) }.joined(separator: ",") + "]",
                    category: .implDefined,
                    description: "1000 element array")
        ]
        
        await runTestCategory(tests)
    }
    
    // MARK: - Performance Tests
    
    static func runPerformanceTests() async {
        print("\n⚡ PERFORMANCE TESTS")
        print(String(repeating: "-", count: 60))
        
        let fixer = JSONFixer()
        let iterations = 1000
        
        // Test 1: Simple JSON parsing speed
        let simpleJSON = #"{"name": "test", "value": 123, "active": true}"#
        let start1 = Date()
        for _ in 0..<iterations {
            _ = await fixer.fix(simpleJSON)
        }
        let elapsed1 = Date().timeIntervalSince(start1)
        print("Simple JSON (\(iterations) iterations): \(String(format: "%.3f", elapsed1))s")
        
        // Test 2: Complex nested JSON
        let nestedJSON = generateNestedJSON(depth: 10)
        let start2 = Date()
        for _ in 0..<100 {
            _ = await fixer.fix(nestedJSON)
        }
        let elapsed2 = Date().timeIntervalSince(start2)
        print("Nested JSON (depth=10, 100 iterations): \(String(format: "%.3f", elapsed2))s")
        
        // Test 3: Large array
        let largeArray = "[" + (1...1000).map { String($0) }.joined(separator: ",") + "]"
        let start3 = Date()
        for _ in 0..<100 {
            _ = await fixer.fix(largeArray)
        }
        let elapsed3 = Date().timeIntervalSince(start3)
        print("Large array (1000 elements, 100 iterations): \(String(format: "%.3f", elapsed3))s")
        
        // Test 4: Malformed JSON recovery speed
        let malformedJSON = #"{"a":+123,"b":.5,"c":TRUE,"d":undefined}"#
        let start4 = Date()
        for _ in 0..<iterations {
            _ = await fixer.fix(malformedJSON)
        }
        let elapsed4 = Date().timeIntervalSince(start4)
        print("Malformed JSON recovery (\(iterations) iterations): \(String(format: "%.3f", elapsed4))s")
    }
    
    // MARK: - Differential Testing
    
    static func runDifferentialTests() async {
        print("\n🔄 DIFFERENTIAL TESTS")
        print(String(repeating: "-", count: 60))
        
        let fixer = JSONFixer()
        let parser = JSONParser()
        
        // Test that our fixer produces valid JSON according to strict parser
        let testCases = [
            #"{"broken":+123}"#,
            #"{"decimal":.5}"#,
            #"{"literal":TRUE}"#,
            #"[1 2 3]"#,  // Missing commas
            #"{"a" 1}"#,  // Missing colon
        ]
        
        for testCase in testCases {
            let fixResult = await fixer.fix(testCase)
            let errors = await parser.validate(fixResult.fixed)
            
            if errors.isEmpty {
                print("✅ Fixed JSON validates: \(testCase.prefix(30))...")
            } else {
                print("❌ Fixed JSON invalid: \(testCase.prefix(30))...")
                print("   Errors: \(errors)")
            }
        }
    }
    
    // MARK: - Test Runner
    
    static func runTestCategory(_ tests: [TestCase]) async {
        let fixer = JSONFixer()
        let parser = JSONParser()
        
        var passed = 0
        var failed = 0
        
        for test in tests {
            let result = await fixer.fix(test.input)
            let errors = await parser.validate(result.fixed)
            let isValid = errors.isEmpty
            
            let expectedResult: Bool
            switch test.category {
            case .mustAccept:
                expectedResult = isValid
            case .mustReject:
                expectedResult = !result.fixes.isEmpty || !isValid
            case .implDefined:
                expectedResult = true  // Any result is acceptable
            }
            
            if expectedResult {
                passed += 1
                print("✅ \(test.name): \(test.description)")
            } else {
                failed += 1
                print("❌ \(test.name): \(test.description)")
                if test.category == .mustAccept && !isValid {
                    print("   Expected valid but got errors: \(errors)")
                } else if test.category == .mustReject && isValid {
                    print("   Expected invalid but was accepted")
                }
            }
        }
        
        print("Results: \(passed) passed, \(failed) failed")
    }
    
    // MARK: - Helpers
    
    static func generateNestedJSON(depth: Int) -> String {
        if depth <= 0 {
            return "1"
        }
        return #"{"a": \#(generateNestedJSON(depth: depth - 1))}"#
    }
}