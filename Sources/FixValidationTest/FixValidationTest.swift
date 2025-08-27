import Foundation
import JSONFormatterFeature

@main
struct FixValidationTest {
    static func main() async {
        print("🔧 FIX VALIDATION TEST")
        print("Testing that fixes are properly reported")
        print(String(repeating: "=", count: 80))
        
        let fixer = JSONFixer()
        
        // Test 1: Trailing comma should be reported as a fix
        print("\n1️⃣ TRAILING COMMA FIX REPORTING")
        let trailingTests = [
            (#"{"a":1,}"#, "Object trailing comma"),
            (#"[1,2,]"#, "Array trailing comma"),
        ]
        
        for (input, desc) in trailingTests {
            let result = await fixer.fix(input)
            print("\n\(desc)")
            print("Input:  \(input)")
            print("Output: \(result.fixed.replacingOccurrences(of: "\n", with: " "))")
            print("Fixes:  \(result.fixes)")
            
            let hasTrailingComma = input.contains(",}") || input.contains(",]")
            let outputHasTrailingComma = result.fixed.contains(",}") || result.fixed.contains(",]")
            
            if hasTrailingComma && !outputHasTrailingComma && result.fixes.isEmpty {
                print("❌ ISSUE: Trailing comma was removed but not reported in fixes!")
            } else if hasTrailingComma && !outputHasTrailingComma && !result.fixes.isEmpty {
                print("✅ Trailing comma removed and reported")
            }
        }
        
        // Test 2: Control characters must be escaped
        print("\n\n2️⃣ CONTROL CHARACTER ESCAPING")
        
        // Create a string with an actual tab character
        let tabChar = "\t"
        let newlineChar = "\n"
        
        let controlTests = [
            (#"{"str":"hello\#(tabChar)world"}"#, "Literal tab in object"),
            (#"{"str":"line\#(newlineChar)break"}"#, "Literal newline in object"),
        ]
        
        for (input, desc) in controlTests {
            let result = await fixer.fix(input)
            print("\n\(desc)")
            print("Input has literal control char: \(input.contains(tabChar) || input.contains(newlineChar))")
            print("Output: \(result.fixed)")
            
            // Check if control chars are properly escaped
            let hasLiteralTab = result.fixed.contains(tabChar)
            let hasLiteralNewline = result.fixed.contains(newlineChar) && !result.fixed.contains("\\n")
            
            if hasLiteralTab {
                print("❌ ISSUE: Output still contains literal tab character!")
            }
            if hasLiteralNewline {
                print("❌ ISSUE: Output still contains unescaped newline!")
            }
            
            if result.fixed.contains("\\t") || result.fixed.contains("\\u0009") {
                print("✅ Tab properly escaped")
            }
            if result.fixed.contains("\\n") || result.fixed.contains("\\u000A") {
                print("✅ Newline properly escaped")
            }
        }
        
        // Test 3: Standalone strings
        print("\n\n3️⃣ STANDALONE STRING HANDLING")
        
        let standaloneTests = [
            (#""hello""#, "Simple standalone string"),
            (#""test\nvalue""#, "Standalone with escape"),
        ]
        
        for (input, desc) in standaloneTests {
            let result = await fixer.fix(input)
            print("\n\(desc)")
            print("Input:  \(input)")
            print("Output: \(result.fixed)")
            print("Fixes:  \(result.fixes)")
            
            // Count quotes
            let inputQuotes = input.filter { $0 == "\"" }.count
            let outputQuotes = result.fixed.filter { $0 == "\"" }.count
            
            if outputQuotes > inputQuotes {
                print("❌ ISSUE: Extra quotes added (input: \(inputQuotes), output: \(outputQuotes))")
            } else {
                print("✅ Quote count correct")
            }
        }
        
        // Test 4: Fix reporting consistency
        print("\n\n4️⃣ FIX REPORTING CONSISTENCY")
        
        let fixTests = [
            (#"{"a":+123}"#, "Leading plus", ["Number format normalized"]),
            (#"{"a":.5}"#, "Missing integer", ["Number format normalized"]),
            (#"{"a":TRUE}"#, "Uppercase literal", ["Literal 'TRUE' normalized to 'true'"]),
            (#"{"a" 1}"#, "Missing colon", ["Missing colon inserted"]),
            (#"{"a":1 "b":2}"#, "Missing comma", ["Missing comma inserted"]),
            (#"{"a":1,}"#, "Trailing comma", []),  // Currently not reported!
        ]
        
        for (input, desc, expectedFixes) in fixTests {
            let result = await fixer.fix(input)
            print("\n\(desc)")
            print("Expected fixes: \(expectedFixes)")
            print("Actual fixes:   \(result.fixes)")
            
            if expectedFixes.isEmpty && !result.fixes.isEmpty {
                print("⚠️ Unexpected fixes reported")
            } else if !expectedFixes.isEmpty && result.fixes.isEmpty {
                print("❌ Expected fixes not reported")
            } else if Set(expectedFixes).isSubset(of: Set(result.fixes)) {
                print("✅ Expected fixes found")
            } else {
                print("⚠️ Different fixes than expected")
            }
        }
    }
}