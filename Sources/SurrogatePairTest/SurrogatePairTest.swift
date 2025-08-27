import Foundation
import JSONFormatterFeature

@main
struct SurrogatePairTest {
    static func main() async {
        print("🔍 SURROGATE PAIR TEST")
        print("Testing UTF-16 surrogate pair handling in JSONParser")
        print(String(repeating: "=", count: 80))
        
        let parser = JSONParser()
        let fixer = JSONFixer()
        
        print("\n📋 Valid Surrogate Pairs:")
        print(String(repeating: "-", count: 60))
        
        // Test cases with valid surrogate pairs
        let validPairs = [
            (#""\uD83D\uDE00""#, "😀", "Grinning face emoji"),
            (#""\uD83D\uDC4D""#, "👍", "Thumbs up emoji"),
            (#""\uD834\uDD1E""#, "𝄞", "Musical symbol G clef"),
            (#"{"emoji":"\uD83D\uDE00"}"#, "😀", "Emoji in object"),
            (#"["\uD83D\uDC4D"]"#, "👍", "Emoji in array"),
        ]
        
        var passed = 0
        var failed = 0
        
        for (input, expectedChar, description) in validPairs {
            // Test with parser
            let errors = await parser.validate(input)
            
            if errors.isEmpty {
                passed += 1
                print("✅ \(description)")
                
                // Verify the actual character is correct
                if input.starts(with: "\"") {
                    // Standalone string - parse it
                    do {
                        let data = input.data(using: .utf8)!
                        let parsed = try JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed) as? String
                        if let parsed = parsed, parsed == expectedChar {
                            print("   Character matches: \(expectedChar)")
                        } else {
                            print("   ⚠️ Character mismatch: expected \(expectedChar), got \(parsed ?? "nil")")
                        }
                    } catch {
                        print("   ⚠️ JSONSerialization failed: \(error)")
                    }
                }
            } else {
                failed += 1
                print("❌ \(description)")
                print("   Errors: \(errors.map { $0.message })")
            }
            
            // Test with fixer
            let fixResult = await fixer.fix(input)
            if fixResult.fixes.contains(where: { $0.contains("surrogate") || $0.contains("unicode") }) {
                print("   ⚠️ Fixer reported issues: \(fixResult.fixes)")
            }
        }
        
        print("\n📋 Invalid Surrogate Cases:")
        print(String(repeating: "-", count: 60))
        
        // Test cases with invalid surrogates
        let invalidSurrogates = [
            (#""\uD83D""#, "Lone high surrogate"),
            (#""\uDE00""#, "Lone low surrogate"),
            (#""\uD83D\u0041""#, "High surrogate + non-surrogate"),
            (#""\uD83D\uD83D""#, "High surrogate + high surrogate"),
            (#""\uDE00\uD83D""#, "Low surrogate + high surrogate (wrong order)"),
        ]
        
        for (input, description) in invalidSurrogates {
            let errors = await parser.validate(input)
            
            if !errors.isEmpty {
                passed += 1
                print("✅ \(description) - Correctly rejected")
                print("   Error: \(errors.first?.message ?? "")")
            } else {
                failed += 1
                print("❌ \(description) - Should have been rejected")
            }
        }
        
        print("\n📋 Edge Cases:")
        print(String(repeating: "-", count: 60))
        
        // Edge cases
        let edgeCases = [
            (#""\uD7FF""#, "Max non-surrogate BMP", true),  // Should be valid
            (#""\uE000""#, "Min non-surrogate after surrogates", true),  // Should be valid
            (#""Test \uD83D\uDE00 Text""#, "Surrogate pair in middle", true),
            (#""\uD83D\uDE00\uD83D\uDC4D""#, "Multiple surrogate pairs", true),
        ]
        
        for (input, description, shouldBeValid) in edgeCases {
            let errors = await parser.validate(input)
            let isValid = errors.isEmpty
            
            if isValid == shouldBeValid {
                passed += 1
                print("✅ \(description)")
            } else {
                failed += 1
                print("❌ \(description)")
                if shouldBeValid {
                    print("   Should be valid but got errors: \(errors.map { $0.message })")
                } else {
                    print("   Should be invalid but was accepted")
                }
            }
        }
        
        print("\n📋 Round-trip Test:")
        print(String(repeating: "-", count: 60))
        
        // Test that surrogate pairs survive the fix/validate cycle
        let roundTripTest = #"{"message":"Hello \uD83D\uDE00 World"}"#
        
        print("Original: \(roundTripTest)")
        
        // Fix it
        let fixed = await fixer.fix(roundTripTest)
        print("Fixed: \(fixed.fixed)")
        print("Fixes applied: \(fixed.fixes.count)")
        
        // Validate the fixed version
        let validationErrors = await parser.validate(fixed.fixed)
        
        if validationErrors.isEmpty && fixed.fixes.isEmpty {
            passed += 1
            print("✅ Round-trip successful - no spurious fixes")
        } else {
            failed += 1
            print("❌ Round-trip failed")
            if !fixed.fixes.isEmpty {
                print("   Unexpected fixes: \(fixed.fixes)")
            }
            if !validationErrors.isEmpty {
                print("   Validation errors: \(validationErrors.map { $0.message })")
            }
        }
        
        print("\n" + String(repeating: "=", count: 80))
        print("📊 RESULTS: \(passed)/\(passed + failed) tests passed")
        
        if failed == 0 {
            print("✅ All surrogate pair tests passed!")
        } else {
            print("⚠️ \(failed) surrogate pair test(s) failed")
        }
    }
}