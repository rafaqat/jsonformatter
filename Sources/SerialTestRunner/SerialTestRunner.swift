import Foundation
import JSONFormatterFeature

@main
struct SerialTestRunner {
    static func main() {
        print("Starting serial test runner...")
        
        Task { @MainActor in
            await runTests()
        }
        
        // Keep the program running
        RunLoop.main.run()
    }
    
    @MainActor
    static func runTests() async {
        print("🔧 SERIAL TEST RUNNER - Testing each case individually")
        print("=" * 60)
        
        let fixer = JSONFixer()
        let parser = JSONParser()
        
        // Test 1: Invalid unicode escape
        await runTest(
            name: "Invalid unicode escape \\u12Z4",
            input: #"{"s":"bad \u12Z4"}"#,
            fixer: fixer,
            parser: parser,
            shouldBeValid: true,
            shouldNotContain: [#"\u12Z4"#]
        )
        
        // Test 2: Lone high surrogate
        await runTest(
            name: "Lone high surrogate",
            input: #"{"s":"pair \uD83D"}"#,
            fixer: fixer,
            parser: parser,
            shouldBeValid: true
        )
        
        // Test 3: Leading plus
        await runTest(
            name: "Leading plus +123",
            input: #"{"n": +123}"#,
            fixer: fixer,
            parser: parser,
            shouldBeValid: true,
            shouldContain: ["123"],
            shouldNotContain: ["+123"]
        )
        
        // Test 4: Leading zeros
        await runTest(
            name: "Leading zeros 00123",
            input: #"{"n": 00123}"#,
            fixer: fixer,
            parser: parser,
            shouldBeValid: true,
            shouldContain: ["123"],
            shouldNotContain: ["00123"]
        )
        
        // Test 5: Bare decimal .5
        await runTest(
            name: "Bare decimal .5",
            input: #"{"n": .5}"#,
            fixer: fixer,
            parser: parser,
            shouldBeValid: true,
            shouldContain: ["0.5"],
            shouldNotContain: [" .5"]
        )
        
        // Test 6: Trailing decimal 42.
        await runTest(
            name: "Trailing decimal 42.",
            input: #"{"n": 42.}"#,
            fixer: fixer,
            parser: parser,
            shouldBeValid: true,
            shouldContain: ["42.0"],
            shouldNotContain: ["42.}"]
        )
        
        // Test 7: TRUE/FALSE/NULL
        await runTest(
            name: "Case variants TRUE/FALSE/NULL",
            input: #"{"a": TRUE, "b": FALSE, "c": NULL}"#,
            fixer: fixer,
            parser: parser,
            shouldBeValid: true,
            shouldContain: ["true", "false", "null"],
            shouldNotContain: ["TRUE", "FALSE", "NULL"]
        )
        
        // Test 8: Partial literals
        await runTest(
            name: "Partial literals tru/fals/nul",
            input: #"{"t": tru, "f": fals, "n": nul}"#,
            fixer: fixer,
            parser: parser,
            shouldBeValid: true,
            shouldContain: ["true", "false", "null"],
            shouldNotContain: ["tru", "fals", "nul"]
        )
        
        // Test 9: Spaced literals
        await runTest(
            name: "Spaced literals tr ue",
            input: #"{"t": tr ue, "n": nu ll}"#,
            fixer: fixer,
            parser: parser,
            shouldBeValid: true,
            shouldContain: ["true", "null"],
            shouldNotContain: ["tr ue", "nu ll"]
        )
        
        // Test 10: Missing comma
        await runTest(
            name: "Missing comma between members",
            input: #"{"a":1 "b":2}"#,
            fixer: fixer,
            parser: parser,
            shouldBeValid: true,
            shouldContain: ["1", "2", ","]
        )
        
        // Test 11: Coordinates missing bracket
        await runTest(
            name: "Coordinates missing bracket",
            input: #"{"coordinates": -0.1695, 51.4865]}"#,
            fixer: fixer,
            parser: parser,
            shouldBeValid: true,
            shouldContain: ["-0.1695", "51.4865", "["]
        )
        
        // Test 12: Hex number
        await runTest(
            name: "Hex number 0xFF",
            input: #"{"hex": 0xFF}"#,
            fixer: fixer,
            parser: parser,
            shouldBeValid: true,
            shouldContain: ["255"],
            shouldNotContain: ["0xFF", "0x"]
        )
        
        // Test 13: Octal number
        await runTest(
            name: "Octal number 0755",
            input: #"{"oct": 0755}"#,
            fixer: fixer,
            parser: parser,
            shouldBeValid: true,
            shouldContain: ["493"],
            shouldNotContain: ["0755"]
        )
        
        // Test 14: NDJSON
        await runTest(
            name: "NDJSON three lines",
            input: "{\"a\":1}\n{\"b\":2}\n{\"c\":3}",
            fixer: fixer,
            parser: parser,
            shouldBeValid: true,
            shouldContain: ["1", "2", "3"]
        )
        
        // Test 15: Invalid escape sequences
        await runTest(
            name: "Invalid escapes \\x and \\8",
            input: #"{"path":"C:\xUsers\8data\qfile"}"#,
            fixer: fixer,
            parser: parser,
            shouldBeValid: true,
            shouldNotContain: [#"\x"#, #"\8"#, #"\q"#]
        )
        
        print("\n" + "=" * 60)
        print("All tests complete!")
        exit(0)
    }
    
    static func runTest(
        name: String,
        input: String,
        fixer: JSONFixer,
        parser: JSONParser,
        shouldBeValid: Bool,
        shouldContain: [String] = [],
        shouldNotContain: [String] = []
    ) async {
        print("\n" + "-" * 50)
        print("TEST: \(name)")
        print("Input: \(input)")
        
        // Run fixer
        let fixResult = await fixer.fix(input)
        print("Fixed: \(fixResult.fixed)")
        
        // Validate
        let errors = await parser.validate(fixResult.fixed)
        let isValid = errors.isEmpty
        
        // Check conditions
        var passed = true
        var failures: [String] = []
        
        if shouldBeValid && !isValid {
            passed = false
            failures.append("Expected valid but got errors: \(errors)")
        } else if !shouldBeValid && isValid {
            passed = false
            failures.append("Expected invalid but was valid")
        }
        
        for expected in shouldContain {
            if !fixResult.fixed.contains(expected) {
                passed = false
                failures.append("Missing expected: '\(expected)'")
            }
        }
        
        for forbidden in shouldNotContain {
            if fixResult.fixed.contains(forbidden) {
                passed = false
                failures.append("Contains forbidden: '\(forbidden)'")
            }
        }
        
        if passed {
            print("✅ PASSED")
        } else {
            print("❌ FAILED")
            for failure in failures {
                print("   • \(failure)")
            }
        }
        
        if !fixResult.fixes.isEmpty {
            print("Fixes applied:")
            for fix in fixResult.fixes.prefix(3) {
                print("   • \(fix)")
            }
        }
    }
}

private extension String {
    static func *(lhs: String, rhs: Int) -> String {
        String(repeating: lhs, count: rhs)
    }
}