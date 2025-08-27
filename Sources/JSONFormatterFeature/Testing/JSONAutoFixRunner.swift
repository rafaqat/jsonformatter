import Foundation

/// Test runner for JSON auto-fix validation
@MainActor
public struct JSONAutoFixRunner {
    
    /// Test case with expectations
    public struct TestCaseWithExpectations {
        public let name: String
        public let input: String
        public let expectedValid: Bool
        public let expectFixKinds: [String]  // Substrings expected in fixes
        public let forbiddenInOutput: [String]  // Strings that must not appear
        public let preserveExact: [String]  // Strings that must be preserved
        public let requireIdempotence: Bool
        
        public init(
            name: String,
            input: String,
            expectedValid: Bool = true,
            expectFixKinds: [String] = [],
            forbiddenInOutput: [String] = [],
            preserveExact: [String] = [],
            requireIdempotence: Bool = false
        ) {
            self.name = name
            self.input = input
            self.expectedValid = expectedValid
            self.expectFixKinds = expectFixKinds
            self.forbiddenInOutput = forbiddenInOutput
            self.preserveExact = preserveExact
            self.requireIdempotence = requireIdempotence
        }
    }
    
    /// Test result
    public struct TestResult {
        public let name: String
        public let passed: Bool
        public let validationPassed: Bool
        public let fixesApplied: [String]
        public let idempotent: Bool
        public let timeMs: Int
        public let failureReasons: [String]
    }
    
    /// Run test cases with full validation
    public static func runCases(_ cases: [TestCaseWithExpectations]) async -> [TestResult] {
        let fixer = JSONFixer()
        let parser = JSONParser()
        var results: [TestResult] = []
        
        print("=" * 80)
        print("🧪 JSON AUTO-FIX TEST RUNNER")
        print("=" * 80)
        
        for (index, testCase) in cases.enumerated() {
            print("\n" + "-" * 60)
            print("[\(index + 1)/\(cases.count)] \(testCase.name)")
            
            let result = await runSingleCase(testCase, fixer: fixer, parser: parser)
            results.append(result)
            
            // Print result
            if result.passed {
                print("✅ PASSED")
            } else {
                print("❌ FAILED: \(result.failureReasons.joined(separator: ", "))")
            }
            
            if !result.fixesApplied.isEmpty {
                print("   Fixes: \(result.fixesApplied.joined(separator: ", "))")
            }
            print("   Time: \(result.timeMs)ms")
        }
        
        // Summary
        let passedCount = results.filter { $0.passed }.count
        let percentage = passedCount * 100 / max(cases.count, 1)
        
        print("\n" + "=" * 80)
        print("📊 SUMMARY: \(passedCount)/\(cases.count) tests passed (\(percentage)%)")
        
        // Category breakdown
        var categoryResults: [String: (passed: Int, total: Int)] = [:]
        for (index, testCase) in cases.enumerated() {
            let category = extractCategory(from: testCase.name)
            let passed = results[index].passed
            var stats = categoryResults[category] ?? (0, 0)
            if passed { stats.passed += 1 }
            stats.total += 1
            categoryResults[category] = stats
        }
        
        if !categoryResults.isEmpty {
            print("\n📈 By Category:")
            for (category, stats) in categoryResults.sorted(by: { $0.key < $1.key }) {
                let pct = stats.passed * 100 / max(stats.total, 1)
                print("   \(category): \(stats.passed)/\(stats.total) (\(pct)%)")
            }
        }
        
        print("=" * 80)
        return results
    }
    
    /// Run a single test case
    private static func runSingleCase(
        _ testCase: TestCaseWithExpectations,
        fixer: JSONFixer,
        parser: JSONParser
    ) async -> TestResult {
        let startTime = Date()
        var failureReasons: [String] = []
        
        // First pass: fix
        let fixResult = await fixer.fix(testCase.input)
        
        // Validate output
        let validationErrors = await parser.validate(fixResult.fixed)
        let isValid = validationErrors.isEmpty
        
        if testCase.expectedValid && !isValid {
            failureReasons.append("Expected valid but got errors")
        } else if !testCase.expectedValid && isValid {
            failureReasons.append("Expected invalid but passed validation")
        }
        
        // Check expected fixes
        for expectedFix in testCase.expectFixKinds {
            let found = fixResult.fixes.contains { fix in
                fix.lowercased().contains(expectedFix.lowercased())
            }
            if !found {
                failureReasons.append("Missing expected fix: '\(expectedFix)'")
            }
        }
        
        // Check forbidden strings
        for forbidden in testCase.forbiddenInOutput {
            if fixResult.fixed.contains(forbidden) {
                failureReasons.append("Output contains forbidden: '\(forbidden)'")
            }
        }
        
        // Check preserved strings
        for preserved in testCase.preserveExact {
            if !fixResult.fixed.contains(preserved) {
                failureReasons.append("Missing preserved: '\(preserved)'")
            }
        }
        
        // Idempotence check
        var idempotent = true
        if testCase.requireIdempotence {
            let secondFix = await fixer.fix(fixResult.fixed)
            if secondFix.fixed != fixResult.fixed {
                idempotent = false
                failureReasons.append("Not idempotent - output changed on second pass")
            }
            if secondFix.wasFixed {
                idempotent = false
                failureReasons.append("Not idempotent - new fixes on second pass")
            }
        }
        
        let timeMs = Int(Date().timeIntervalSince(startTime) * 1000)
        
        return TestResult(
            name: testCase.name,
            passed: failureReasons.isEmpty,
            validationPassed: isValid,
            fixesApplied: fixResult.fixes,
            idempotent: idempotent,
            timeMs: timeMs,
            failureReasons: failureReasons
        )
    }
    
    /// Extract category from test name
    private static func extractCategory(from name: String) -> String {
        if name.lowercased().contains("unicode") || name.lowercased().contains("escape") {
            return "Unicode"
        } else if name.lowercased().contains("number") || name.lowercased().contains("decimal") {
            return "Numbers"
        } else if name.lowercased().contains("literal") || name.lowercased().contains("true") || 
                  name.lowercased().contains("false") || name.lowercased().contains("null") {
            return "Literals"
        } else if name.lowercased().contains("delimiter") || name.lowercased().contains("bracket") || 
                  name.lowercased().contains("brace") || name.lowercased().contains("comma") {
            return "Delimiters"
        } else if name.lowercased().contains("multi") || name.lowercased().contains("ndjson") || 
                  name.lowercased().contains("trailing") {
            return "Multi-root"
        } else if name.lowercased().contains("key") || name.lowercased().contains("duplicate") {
            return "Semantics"
        } else {
            return "Other"
        }
    }
}

// MARK: - Convenience Extensions

private extension String {
    static func *(lhs: String, rhs: Int) -> String {
        String(repeating: lhs, count: rhs)
    }
}

// MARK: - Quick Test Suite

public extension JSONAutoFixRunner {
    
    /// Run the 25 core test cases
    static func runCoreTestSuite() async {
        let cases = [
            // Unicode/Strings (6)
            TestCaseWithExpectations(
                name: "Invalid unicode escape short",
                input: #"{"s":"bad \u12Z4"}"#,
                expectFixKinds: ["unicode", "escape"],
                forbiddenInOutput: [#"\u12Z4"#],
                requireIdempotence: true
            ),
            TestCaseWithExpectations(
                name: "Lone high surrogate",
                input: #"{"s":"pair \uD83D"}"#,
                expectFixKinds: ["surrogate"],
                requireIdempotence: true
            ),
            TestCaseWithExpectations(
                name: "Unescaped control BEL",
                input: "{\"s\":\"hello\\u0007world\"}",
                expectFixKinds: ["control"],
                forbiddenInOutput: ["\u{0007}"],
                requireIdempotence: true
            ),
            TestCaseWithExpectations(
                name: "Invalid escapes \\x and \\8",
                input: #"{"path":"C:\xUsers\8data\qfile"}"#,
                expectFixKinds: ["escape"],
                forbiddenInOutput: [#"\x"#, #"\8"#, #"\q"#],
                requireIdempotence: true
            ),
            TestCaseWithExpectations(
                name: "NBSP outside strings",
                input: "{\u{00A0}\"a\"\u{00A0}:\u{00A0}1\u{00A0}}",
                expectFixKinds: ["whitespace"],
                requireIdempotence: true
            ),
            TestCaseWithExpectations(
                name: "Comment markers inside strings",
                input: #"{"t":"http://x/y // not comment","x":"/* not comment */"}"#,
                preserveExact: ["// not comment", "/* not comment */"],
                requireIdempotence: true
            ),
            
            // Numbers (7)
            TestCaseWithExpectations(
                name: "Leading plus",
                input: #"{"n": +123}"#,
                expectFixKinds: ["plus", "number"],
                forbiddenInOutput: ["+123"],
                preserveExact: ["123"],
                requireIdempotence: true
            ),
            TestCaseWithExpectations(
                name: "Leading zeros",
                input: #"{"n": 00123}"#,
                expectFixKinds: ["zero", "number"],
                forbiddenInOutput: ["00123"],
                preserveExact: ["123"],
                requireIdempotence: true
            ),
            TestCaseWithExpectations(
                name: "Bare decimal",
                input: #"{"n": .5}"#,
                expectFixKinds: ["decimal", "number"],
                forbiddenInOutput: [" .5"],
                preserveExact: ["0.5"],
                requireIdempotence: true
            ),
            TestCaseWithExpectations(
                name: "Trailing decimal",
                input: #"{"n": 42.}"#,
                expectFixKinds: ["decimal", "number"],
                forbiddenInOutput: ["42.}"],
                preserveExact: ["42.0"],
                requireIdempotence: true
            ),
            TestCaseWithExpectations(
                name: "Incomplete exponent",
                input: #"{"n": 1e+}"#,
                expectFixKinds: ["exponent", "number"],
                forbiddenInOutput: ["1e+"],
                requireIdempotence: true
            ),
            TestCaseWithExpectations(
                name: "Numeric separators",
                input: #"{"n": 1_000_000}"#,
                expectFixKinds: ["separator", "number"],
                forbiddenInOutput: ["_"],
                preserveExact: ["1000000"],
                requireIdempotence: true
            ),
            TestCaseWithExpectations(
                name: "Hex and octal",
                input: #"{"hex": 0xFF, "oct": 0755}"#,
                expectFixKinds: ["hex", "octal", "number"],
                forbiddenInOutput: ["0x", "0755"],
                preserveExact: ["255", "493"],
                requireIdempotence: true
            ),
            
            // Literals (4)
            TestCaseWithExpectations(
                name: "Case variants TRUE/FALSE/NULL",
                input: #"{"a": TRUE, "b": FALSE, "c": NULL}"#,
                expectFixKinds: ["literal"],
                forbiddenInOutput: ["TRUE", "FALSE", "NULL"],
                preserveExact: ["true", "false", "null"],
                requireIdempotence: true
            ),
            TestCaseWithExpectations(
                name: "JS literals undefined/nil",
                input: #"{"u": undefined, "n": nil}"#,
                expectFixKinds: ["literal"],
                forbiddenInOutput: ["undefined", "nil"],
                preserveExact: ["null"],
                requireIdempotence: true
            ),
            TestCaseWithExpectations(
                name: "Partial literals",
                input: #"{"t": tru, "f": fals, "n": nul}"#,
                expectFixKinds: ["literal", "complete"],
                forbiddenInOutput: ["tru", "fals", "nul"],
                preserveExact: ["true", "false", "null"],
                requireIdempotence: true
            ),
            TestCaseWithExpectations(
                name: "Spaced literals",
                input: #"{"t": tr ue, "n": nu ll}"#,
                expectFixKinds: ["literal", "space"],
                forbiddenInOutput: ["tr ue", "nu ll"],
                preserveExact: ["true", "null"],
                requireIdempotence: true
            ),
            
            // Delimiters (4)
            TestCaseWithExpectations(
                name: "Colon vs comma after key",
                input: #"{"a" "b": 1}"#,
                expectFixKinds: ["colon"],
                preserveExact: ["\"a\"", "\"b\"", "1"],
                requireIdempotence: true
            ),
            TestCaseWithExpectations(
                name: "Missing comma between members",
                input: #"{"a":1 "b":2}"#,
                expectFixKinds: ["comma"],
                preserveExact: ["1", "2"],
                requireIdempotence: true
            ),
            TestCaseWithExpectations(
                name: "Cross-type closure",
                input: #"{"x":[1,2}}"#,
                expectFixKinds: ["bracket", "mismatch"],
                preserveExact: ["1", "2"],
                requireIdempotence: true
            ),
            TestCaseWithExpectations(
                name: "Coordinates missing bracket",
                input: #"{"coordinates": -0.1695, 51.4865]}"#,
                expectFixKinds: ["bracket", "array"],
                preserveExact: ["-0.1695", "51.4865"],
                requireIdempotence: true
            ),
            
            // Multi-root (2)
            TestCaseWithExpectations(
                name: "NDJSON three lines",
                input: "{\"a\":1}\n{\"b\":2}\n{\"c\":3}",
                expectFixKinds: ["multi", "root"],
                preserveExact: ["1", "2", "3"],
                requireIdempotence: true
            ),
            TestCaseWithExpectations(
                name: "Trailing garbage",
                input: #"{"a":1} trailing"#,
                expectFixKinds: ["trailing"],
                forbiddenInOutput: ["trailing"],
                preserveExact: ["1"],
                requireIdempotence: true
            ),
            
            // Keys (2)
            TestCaseWithExpectations(
                name: "Unquoted keys with spaces",
                input: "{first name: \"A\", last-name: \"B\"}",
                expectFixKinds: ["quote", "key"],
                preserveExact: ["\"first name\"", "\"last-name\"", "\"A\"", "\"B\""],
                requireIdempotence: true
            ),
            TestCaseWithExpectations(
                name: "Duplicate keys",
                input: #"{"name":"John","name":"Jane"}"#,
                expectFixKinds: ["duplicate"],
                preserveExact: ["John", "Jane"],
                requireIdempotence: true
            )
        ]
        
        let results = await runCases(cases)
        
        // Additional analysis
        let failedCases = results.enumerated().compactMap { index, result in
            result.passed ? nil : cases[index].name
        }
        
        if !failedCases.isEmpty {
            print("\n⚠️ Failed cases:")
            for name in failedCases {
                print("   • \(name)")
            }
        }
        
        // Performance check
        let slowCases = results.enumerated().compactMap { index, result in
            result.timeMs > 100 ? (cases[index].name, result.timeMs) : nil
        }
        
        if !slowCases.isEmpty {
            print("\n⚡ Slow cases (>100ms):")
            for (name, time) in slowCases {
                print("   • \(name): \(time)ms")
            }
        }
    }
}