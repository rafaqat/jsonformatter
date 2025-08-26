import Foundation
import JSONFormatterFeature

struct QuoteFixerTest {
    static func main() async {
        print("=" * 80)
        print("🧪 QUOTE FIXER TEST - Testing ParseTreeJSONFixer")
        print("=" * 80)
        
        let fixer = ParseTreeJSONFixer()
        let parser = PreciseJSONParser()
        
        // Critical test cases for missing quotes
        let testCases = [
            ("Missing opening quote on key", 
             #"{ name": "value" }"#),
            
            ("Missing closing quote on key", 
             #"{ "name: "value" }"#),
            
            ("Unquoted key", 
             #"{ name: "value" }"#),
            
            ("Missing opening quote on value", 
             #"{ "key": value" }"#),
            
            ("Missing closing quote on value", 
             #"{ "key": "value }"#),
            
            ("Unquoted value", 
             #"{ "key": value }"#),
            
            ("Your exact case - unterminated value", 
             #"{ "type": "Feature }"#),
            
            ("Complex nested with multiple issues",
             #"{ "user": { name": "John", "age: 25, city: "NYC" } }"#),
            
            ("Array with quote issues",
             #"[ "first", second", "third ]"#),
            
            ("Deep nesting with quote issues",
             #"{ "a": { "b": { c": { "d": "value" } } } }"#),
        ]
        
        var passedTests = 0
        var failedTests = 0
        var partiallyFixed = 0
        
        for (index, test) in testCases.enumerated() {
            print("\n" + "─" * 60)
            print("Test \(index + 1): \(test.0)")
            print("─" * 60)
            print("Input: \(test.1)")
            
            // Try to fix with ParseTreeJSONFixer
            let fixResult = await fixer.fix(test.1)
            
            if fixResult.wasFixed {
                print("\n✅ Fixes applied:")
                for fix in fixResult.fixes {
                    print("   • \(fix)")
                }
                
                // Validate the fixed JSON
                let errors = await parser.validate(fixResult.fixed)
                
                if errors.isEmpty {
                    // Try to actually parse it
                    if let data = fixResult.fixed.data(using: .utf8) {
                        do {
                            let json = try JSONSerialization.jsonObject(with: data, options: [])
                            print("\n✨ SUCCESS: Fixed JSON is valid!")
                            
                            // Pretty print the result
                            if let prettyData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted]),
                               let prettyString = String(data: prettyData, encoding: .utf8) {
                                print("Fixed output:")
                                print(prettyString)
                            }
                            
                            passedTests += 1
                        } catch {
                            print("\n⚠️ JSONSerialization failed: \(error)")
                            partiallyFixed += 1
                        }
                    }
                } else {
                    print("\n⚠️ Fixed JSON still has errors:")
                    for error in errors.prefix(3) {
                        print("   - Line \(error.line): \(error.message)")
                    }
                    partiallyFixed += 1
                }
            } else {
                print("\n❌ No fixes detected - parser couldn't handle this case")
                failedTests += 1
            }
        }
        
        print("\n" + "═" * 80)
        print("📊 RESULTS")
        print("═" * 80)
        print("✅ Fully fixed: \(passedTests)/\(testCases.count)")
        print("⚠️ Partially fixed: \(partiallyFixed)/\(testCases.count)")
        print("❌ Not fixed: \(failedTests)/\(testCases.count)")
        
        if passedTests == testCases.count {
            print("\n🎉 SUCCESS: All quote issues were fixed!")
        } else if passedTests + partiallyFixed == testCases.count {
            print("\n⚠️ PARTIAL SUCCESS: All issues detected but some need better fixes")
        } else {
            print("\n❌ NEEDS IMPROVEMENT: Some quote issues were not detected")
        }
        print("═" * 80)
    }
}

