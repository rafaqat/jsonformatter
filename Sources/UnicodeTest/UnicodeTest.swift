import Foundation
import JSONFormatterFeature

struct UnicodeTest {
    static func main() async {
        print("=" * 80)
        print("🧪 UNICODE & ESCAPE SEQUENCE TEST")
        print("=" * 80)
        
        let fixer = JSONFixer()
        let parser = JSONParser()
        
        // Test cases for Unicode and control characters
        let testCases = [
            ("Control characters", """
            {"text": "Hello\\bWorld\\fTest\\u0000End"}
            """),
            
            ("Emoji as surrogate pair", """
            {"emoji": "\\uD83D\\uDE00"}
            """),
            
            ("Mixed control chars", """
            {"data": "Line1\\nLine2\\rLine3\\tTabbed\\b\\f"}
            """),
            
            ("Non-printable chars", """
            {"control": "\u{1}\u{2}\u{3}\u{4}\u{5}"}
            """),
            
            ("Backslash in path", """
            {"path": "C:\\\\Windows\\\\System32"}
            """),
            
            ("Quote in string", """
            {"quote": "He said \\"Hello\\""}
            """),
            
            ("Unicode chars", """
            {"chinese": "你好", "arabic": "مرحبا", "emoji": "😀🎉"}
            """),
        ]
        
        var passedTests = 0
        var failedTests = 0
        
        for (index, test) in testCases.enumerated() {
            print("\n" + "-" * 60)
            print("Test \(index + 1): \(test.0)")
            print("-" * 60)
            
            // Test parsing
            let errors = await parser.validate(test.1)
            if !errors.isEmpty {
                print("❌ Parser errors: \(errors.count)")
                for error in errors.prefix(3) {
                    print("   - \(error.message)")
                }
                failedTests += 1
                continue
            }
            
            // Test fixing (should preserve valid JSON)
            let fixResult = await fixer.fix(test.1)
            
            // Verify the output is still valid
            let fixedErrors = await parser.validate(fixResult.fixed)
            if fixedErrors.isEmpty {
                print("✅ Valid JSON maintained")
                
                // Check if escaping is preserved
                if let data = fixResult.fixed.data(using: .utf8) {
                    do {
                        let json = try JSONSerialization.jsonObject(with: data, options: [])
                        print("✨ Successfully parsed with JSONSerialization")
                        
                        // For emoji test, verify it actually contains the emoji
                        if test.0 == "Emoji as surrogate pair" {
                            if let dict = json as? [String: Any],
                               let emoji = dict["emoji"] as? String {
                                print("   Emoji value: \(emoji) (should be 😀)")
                                if emoji == "😀" {
                                    print("   ✅ Surrogate pair correctly handled!")
                                }
                            }
                        }
                        
                        passedTests += 1
                    } catch {
                        print("❌ JSONSerialization failed: \(error)")
                        failedTests += 1
                    }
                }
            } else {
                print("❌ Fixed JSON has errors: \(fixedErrors.count)")
                failedTests += 1
            }
        }
        
        print("\n" + "=" * 80)
        print("📊 RESULTS")
        print("=" * 80)
        print("Passed: \(passedTests)/\(testCases.count)")
        print("Failed: \(failedTests)/\(testCases.count)")
        
        if passedTests == testCases.count {
            print("🎉 All Unicode tests passed!")
        } else {
            print("⚠️ Some Unicode tests failed")
        }
        
        // Test that control characters are properly escaped in output
        print("\n" + "=" * 80)
        print("🧪 ESCAPE OUTPUT TEST")
        print("=" * 80)
        
        let testString = """
        {"text": "Tab:\tNewline:\nBackspace:\u{8}FormFeed:\u{C}"}
        """
        
        let escapeResult = await fixer.fix(testString)
        print("Input with control chars:")
        print(testString)
        print("\nFixed output (should have \\t, \\n, \\b, \\f):")
        print(escapeResult.fixed)
        
        // Check if control chars are escaped
        if escapeResult.fixed.contains("\\t") && 
           escapeResult.fixed.contains("\\n") &&
           escapeResult.fixed.contains("\\b") &&
           escapeResult.fixed.contains("\\f") {
            print("✅ Control characters properly escaped in output!")
        } else {
            print("❌ Control characters not properly escaped!")
        }
    }
}

extension String {
    static func *(lhs: String, rhs: Int) -> String {
        String(repeating: lhs, count: rhs)
    }
}

@main
struct UnicodeTestRunner {
    static func main() async {
        await UnicodeTest.main()
    }
}