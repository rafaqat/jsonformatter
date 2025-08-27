import Foundation
import JSONFormatterFeature

// MARK: - Test Infrastructure

struct TestTimeout: Error {
    let testName: String
    let duration: TimeInterval
}

struct TestResult: Sendable {
    let name: String
    let passed: Bool
    let duration: TimeInterval
    let fixes: [String]
    let error: String?
    let timedOut: Bool
}

struct TestOutput: Sendable {
    let fixed: String
    let fixes: [String]
    let errors: [String]
}

// Simple timeout wrapper
func withTimeout<T: Sendable>(seconds: TimeInterval, operation: @escaping @Sendable () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T?.self) { group in
        group.addTask {
            try await operation()
        }
        
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            return nil
        }
        
        if let result = try await group.next() {
            group.cancelAll()
            if let value = result {
                return value
            } else {
                throw TestTimeout(testName: "unknown", duration: seconds)
            }
        }
        
        throw TestTimeout(testName: "unknown", duration: seconds)
    }
}

// MARK: - Main Test Suite

@main
struct ImprovedParserTest {
    
    enum TestCategory {
        case mustAccept    // y_ - should be valid without fixes
        case mustReject    // n_ - should need fixes to become valid
        case implDefined   // i_ - implementation specific
    }
    
    struct TestCase {
        let name: String
        let input: String
        let category: TestCategory
        let expectedFixes: Set<String>? // Expected fix types if known
        let timeout: TimeInterval
        
        init(name: String, input: String, category: TestCategory, 
             expectedFixes: Set<String>? = nil, timeout: TimeInterval = 0.5) {
            self.name = name
            self.input = input
            self.category = category
            self.expectedFixes = expectedFixes
            self.timeout = timeout
        }
    }
    
    static func main() async {
        print("🧪 IMPROVED PARSER TEST SUITE")
        print("Tolerant fixer with proper timeouts and oracles")
        print(String(repeating: "=", count: 80))
        
        // Check for env vars
        let seed = ProcessInfo.processInfo.environment["TEST_SEED"] ?? String(Date().timeIntervalSince1970.hashValue)
        let runPerfTests = ProcessInfo.processInfo.environment["RUN_PERF_TESTS"] == "true"
        
        print("Test seed: \(seed)")
        print("Performance tests: \(runPerfTests ? "enabled" : "disabled")")
        print("")
        
        var allResults: [TestResult] = []
        
        // Run test categories
        allResults += await runStructureTests()
        allResults += await runNumberTests()
        allResults += await runStringTests()
        allResults += await runLiteralTests()
        allResults += await runMultiRootTests()
        
        if runPerfTests {
            allResults += await runPerformanceTests()
        }
        
        // Summary
        printSummary(results: allResults)
    }
    
    // MARK: - Structure Tests
    
    static func runStructureTests() async -> [TestResult] {
        print("\n📁 STRUCTURE TESTS")
        print(String(repeating: "-", count: 60))
        
        let tests = [
            // Must accept (valid JSON)
            TestCase(name: "y_object_basic", input: #"{"key":"value"}"#, category: .mustAccept),
            TestCase(name: "y_array_basic", input: #"[1,2,3]"#, category: .mustAccept),
            TestCase(name: "y_empty_object", input: #"{}"#, category: .mustAccept),
            TestCase(name: "y_empty_array", input: #"[]"#, category: .mustAccept),
            
            // Must reject (needs fixes)
            TestCase(name: "n_missing_colon", input: #"{"a" 1}"#, category: .mustReject, 
                    expectedFixes: ["missingColon"]),
            TestCase(name: "n_missing_comma", input: #"{"a":1 "b":2}"#, category: .mustReject,
                    expectedFixes: ["missingComma"]),
            TestCase(name: "n_trailing_comma_object", input: #"{"a":1,}"#, category: .mustReject,
                    expectedFixes: ["trailingComma"]),
            TestCase(name: "n_trailing_comma_array", input: #"[1,2,]"#, category: .mustReject,
                    expectedFixes: ["trailingComma"]),
            TestCase(name: "n_unterminated_object", input: #"{"a":1"#, category: .mustReject,
                    expectedFixes: ["unterminatedObject"]),
            TestCase(name: "n_unterminated_array", input: #"[1,2"#, category: .mustReject,
                    expectedFixes: ["unterminatedArray"]),
            
            // Implementation defined
            TestCase(name: "i_single_quotes", input: #"{'key':'value'}"#, category: .implDefined),
            TestCase(name: "i_duplicate_keys", input: #"{"a":1,"a":2}"#, category: .implDefined),
        ]
        
        return await runTestCategory(tests: tests, categoryName: "Structure")
    }
    
    // MARK: - Number Tests
    
    static func runNumberTests() async -> [TestResult] {
        print("\n🔢 NUMBER TESTS")
        print(String(repeating: "-", count: 60))
        
        let tests = [
            // Must accept
            TestCase(name: "y_number_integer", input: "123", category: .mustAccept),
            TestCase(name: "y_number_negative", input: "-456", category: .mustAccept),
            TestCase(name: "y_number_decimal", input: "3.14159", category: .mustAccept),
            TestCase(name: "y_number_exponent", input: "1.23e10", category: .mustAccept),
            TestCase(name: "y_number_negative_zero", input: "-0", category: .mustAccept),
            
            // Must reject (needs normalization)
            TestCase(name: "n_number_plus_sign", input: "+123", category: .mustReject,
                    expectedFixes: ["leadingPlus"]),
            TestCase(name: "n_number_leading_zeros", input: "0123", category: .mustReject,
                    expectedFixes: ["leadingZeros"]),
            TestCase(name: "n_number_missing_integer", input: ".5", category: .mustReject,
                    expectedFixes: ["missingIntegerPart"]),
            TestCase(name: "n_number_missing_fraction", input: "42.", category: .mustReject,
                    expectedFixes: ["missingFractionPart"]),
            TestCase(name: "n_number_hex", input: "0x1F", category: .mustReject,
                    expectedFixes: ["hexNumber"]),
            
            // Implementation defined
            TestCase(name: "i_number_infinity", input: "Infinity", category: .implDefined),
            TestCase(name: "i_number_nan", input: "NaN", category: .implDefined),
        ]
        
        return await runTestCategory(tests: tests, categoryName: "Numbers")
    }
    
    // MARK: - String Tests
    
    static func runStringTests() async -> [TestResult] {
        print("\n📝 STRING TESTS")
        print(String(repeating: "-", count: 60))
        
        let tests = [
            // Must accept
            TestCase(name: "y_string_simple", input: #""hello world""#, category: .mustAccept),
            TestCase(name: "y_string_escaped", input: #""line\nbreak""#, category: .mustAccept),
            TestCase(name: "y_string_unicode", input: #""\u0041""#, category: .mustAccept),
            
            // Must reject (needs fixes)
            TestCase(name: "n_string_invalid_escape", input: #""\z""#, category: .mustReject,
                    expectedFixes: ["invalidEscape"]),
            TestCase(name: "n_string_invalid_unicode", input: #""\u123""#, category: .mustReject,
                    expectedFixes: ["invalidUnicode"]),
            TestCase(name: "n_string_lone_surrogate", input: #""\uD834""#, category: .mustReject,
                    expectedFixes: ["loneSurrogate"]),
            TestCase(name: "n_string_unterminated", input: #""unterminated"#, category: .mustReject,
                    expectedFixes: ["unterminatedString"]),
            
            // Implementation defined
            TestCase(name: "i_string_control_char", input: "\"tab\there\"", category: .implDefined),
        ]
        
        return await runTestCategory(tests: tests, categoryName: "Strings")
    }
    
    // MARK: - Literal Tests
    
    static func runLiteralTests() async -> [TestResult] {
        print("\n📚 LITERAL TESTS")
        print(String(repeating: "-", count: 60))
        
        let tests = [
            // Must accept
            TestCase(name: "y_literal_true", input: "true", category: .mustAccept),
            TestCase(name: "y_literal_false", input: "false", category: .mustAccept),
            TestCase(name: "y_literal_null", input: "null", category: .mustAccept),
            
            // Must reject (needs normalization)
            TestCase(name: "n_literal_uppercase_true", input: "TRUE", category: .mustReject,
                    expectedFixes: ["uppercaseLiteral"]),
            TestCase(name: "n_literal_mixed_false", input: "False", category: .mustReject,
                    expectedFixes: ["mixedCaseLiteral"]),
            TestCase(name: "n_literal_partial_true", input: "tru", category: .mustReject,
                    expectedFixes: ["partialLiteral"]),
            TestCase(name: "n_literal_spaced", input: "tr ue", category: .mustReject,
                    expectedFixes: ["spacedLiteral"]),
            
            // Implementation defined
            TestCase(name: "i_literal_undefined", input: "undefined", category: .implDefined),
        ]
        
        return await runTestCategory(tests: tests, categoryName: "Literals")
    }
    
    // MARK: - Multi-Root Tests
    
    static func runMultiRootTests() async -> [TestResult] {
        print("\n🔄 MULTI-ROOT & NDJSON TESTS")
        print(String(repeating: "-", count: 60))
        
        let tests = [
            // Must reject (multiple roots need wrapping)
            TestCase(name: "n_multi_object", input: #"{"a":1}{"b":2}"#, category: .mustReject,
                    expectedFixes: ["multiRoot"]),
            TestCase(name: "n_multi_number", input: "123 456", category: .mustReject,
                    expectedFixes: ["multiRoot"]),
            
            // Implementation defined (NDJSON)
            TestCase(name: "i_ndjson", input: "{\"a\":1}\n{\"b\":2}\n", category: .implDefined),
        ]
        
        return await runTestCategory(tests: tests, categoryName: "Multi-Root")
    }
    
    // MARK: - Performance Tests
    
    static func runPerformanceTests() async -> [TestResult] {
        print("\n⚡ PERFORMANCE TESTS")
        print(String(repeating: "-", count: 60))
        
        let tests = [
            // Large but bounded tests
            TestCase(name: "perf_nested_10", 
                    input: generateNested(depth: 10), 
                    category: .implDefined, 
                    timeout: 2.0),
            TestCase(name: "perf_array_1000", 
                    input: "[" + (1...1000).map { String($0) }.joined(separator: ",") + "]",
                    category: .implDefined,
                    timeout: 2.0),
            TestCase(name: "perf_string_10kb",
                    input: "\"" + String(repeating: "a", count: 10_000) + "\"",
                    category: .implDefined,
                    timeout: 2.0),
        ]
        
        return await runTestCategory(tests: tests, categoryName: "Performance")
    }
    
    // MARK: - Test Execution
    
    static func runTestCategory(tests: [TestCase], categoryName: String) async -> [TestResult] {
        let fixer = JSONFixer()
        let parser = JSONParser()
        var results: [TestResult] = []
        
        for test in tests {
            let startTime = Date()
            var result: TestResult
            
            do {
                // Run test with timeout
                let testOutput = try await withTimeout(seconds: test.timeout) {
                    let fixed = await fixer.fix(test.input)
                    let validationErrors = await parser.validate(fixed.fixed)
                    return TestOutput(
                        fixed: fixed.fixed,
                        fixes: fixed.fixes,
                        errors: validationErrors.map { $0.message }
                    )
                }
                
                let duration = Date().timeIntervalSince(startTime)
                
                // Evaluate based on category
                let passed: Bool
                let error: String?
                
                switch test.category {
                case .mustAccept:
                    // Should be valid without fixes (or only formatting)
                    passed = testOutput.errors.isEmpty && testOutput.fixes.isEmpty
                    error = !passed ? "Expected no fixes but got \(testOutput.fixes.count)" : nil
                    
                case .mustReject:
                    // Original is invalid, should be fixed to valid
                    let originalErrors = await parser.validate(test.input)
                    passed = !originalErrors.isEmpty && testOutput.errors.isEmpty && !testOutput.fixes.isEmpty
                    error = !passed ? "Expected fixes but got \(testOutput.fixes.count)" : nil
                    
                case .implDefined:
                    // Always pass, just log
                    passed = true
                    error = nil
                }
                
                result = TestResult(
                    name: test.name,
                    passed: passed,
                    duration: duration,
                    fixes: testOutput.fixes,
                    error: error,
                    timedOut: false
                )
                
            } catch is TestTimeout {
                result = TestResult(
                    name: test.name,
                    passed: false,
                    duration: test.timeout,
                    fixes: [],
                    error: "Timeout after \(test.timeout)s",
                    timedOut: true
                )
            } catch {
                result = TestResult(
                    name: test.name,
                    passed: false,
                    duration: Date().timeIntervalSince(startTime),
                    fixes: [],
                    error: error.localizedDescription,
                    timedOut: false
                )
            }
            
            // Print result
            let statusIcon = result.timedOut ? "⏱️" : (result.passed ? "✅" : "❌")
            print("\(statusIcon) \(result.name) (\(Int(result.duration * 1000))ms)")
            if let error = result.error {
                print("   \(error)")
            }
            if !result.fixes.isEmpty {
                print("   Fixes: \(result.fixes.count)")
            }
            
            results.append(result)
        }
        
        return results
    }
    
    // MARK: - Summary
    
    static func printSummary(results: [TestResult]) {
        print("\n" + String(repeating: "=", count: 80))
        print("📊 TEST SUMMARY")
        
        let passed = results.filter { $0.passed }.count
        let failed = results.filter { !$0.passed }.count
        let timedOut = results.filter { $0.timedOut }.count
        
        print("Total: \(results.count)")
        print("Passed: \(passed)")
        print("Failed: \(failed)")
        print("Timed out: \(timedOut)")
        
        let passRate = Double(passed) / Double(results.count) * 100
        print("Pass rate: \(String(format: "%.1f", passRate))%")
        
        if passRate >= 90 {
            print("✅ Target of >90% pass rate achieved!")
        } else {
            print("⚠️ Below target of 90% pass rate")
        }
        
        // Show failures
        let failures = results.filter { !$0.passed }
        if !failures.isEmpty {
            print("\nFailed tests:")
            for failure in failures {
                print("  - \(failure.name): \(failure.error ?? "unknown error")")
            }
        }
    }
    
    // MARK: - Helpers
    
    static func generateNested(depth: Int) -> String {
        if depth <= 0 {
            return "1"
        }
        return #"{"a":\#(generateNested(depth: depth - 1))}"#
    }
}