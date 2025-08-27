import Foundation
import JSONFormatterFeature

@main
struct RegressionTest {
    static func main() async {
        print("🔒 REGRESSION TEST - EOF Unterminated String False Positive")
        print(String(repeating: "=", count: 80))
        
        let fixer = JSONFixer()
        let parser = JSONParser()
        
        print("\n📋 Test Cases for Standalone Strings at EOF:")
        print(String(repeating: "-", count: 60))
        
        // Test cases that should NOT be marked as unterminated
        let validStrings = [
            // Basic cases
            (#""hello""#, "Simple string"),
            (#""test value""#, "String with space"),
            (#""""#, "Empty string"),
            
            // Escape sequences
            (#""line\nbreak""#, "Newline escape"),
            (#""tab\there""#, "Tab escape"),
            (#""quote\"here""#, "Escaped quote"),
            (#""backslash\\here""#, "Escaped backslash"),
            
            // Unicode
            (#""\u0041""#, "Unicode escape"),
            (#""\uD83D\uDE00""#, "Surrogate pair (emoji)"),
            
            // Edge cases
            (#""a\\""#, "Ends with escaped backslash"),
            (#""\"""#, "Just an escaped quote"),
            (#""\\""#, "Just an escaped backslash"),
        ]
        
        var passed = 0
        var failed = 0
        
        for (input, description) in validStrings {
            let result = await fixer.fix(input)
            let hasUnterminatedFix = result.fixes.contains { $0.contains("Unterminated") }
            
            if hasUnterminatedFix {
                failed += 1
                print("❌ \(description)")
                print("   Input: \(input)")
                print("   Incorrectly marked as unterminated")
                print("   Fixes: \(result.fixes)")
            } else {
                passed += 1
                print("✅ \(description)")
            }
            
            // Verify the output is valid
            let errors = await parser.validate(result.fixed)
            if !errors.isEmpty {
                print("   ⚠️ Output is invalid: \(errors.map { $0.message })")
            }
        }
        
        print("\n📋 Test Cases for Actually Unterminated Strings:")
        print(String(repeating: "-", count: 60))
        
        // Test cases that SHOULD be marked as unterminated
        let unterminatedStrings = [
            (#""hello"#, "Missing closing quote"),
            (#""test\n"#, "Newline before close"),
            (#""incomplete\"#, "Ends with escape"),
        ]
        
        for (input, description) in unterminatedStrings {
            let result = await fixer.fix(input)
            let hasUnterminatedFix = result.fixes.contains { $0.contains("Unterminated") }
            
            if hasUnterminatedFix {
                passed += 1
                print("✅ \(description) - Correctly identified as unterminated")
            } else {
                failed += 1
                print("❌ \(description) - Failed to identify as unterminated")
            }
        }
        
        print("\n📋 In-Container String Tests (Should Never Be Marked Unterminated):")
        print(String(repeating: "-", count: 60))
        
        let containerTests = [
            (#"{"key":"value"}"#, "String in object"),
            (#"["hello","world"]"#, "Strings in array"),
            (#"{"nested":{"key":"value"}}"#, "Nested string"),
            (#"{"escape":"test\nvalue"}"#, "String with escape in object"),
        ]
        
        for (input, description) in containerTests {
            let result = await fixer.fix(input)
            let hasUnterminatedFix = result.fixes.contains { $0.contains("Unterminated string") }
            
            if hasUnterminatedFix {
                failed += 1
                print("❌ \(description) - Incorrectly marked string as unterminated")
            } else {
                passed += 1
                print("✅ \(description)")
            }
        }
        
        print("\n" + String(repeating: "=", count: 80))
        print("📊 RESULTS: \(passed)/\(passed + failed) tests passed")
        
        if failed == 0 {
            print("✅ All regression tests passed - EOF unterminated bug is fixed")
        } else {
            print("⚠️ \(failed) regression test(s) failed")
        }
    }
}