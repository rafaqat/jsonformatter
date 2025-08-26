import Foundation
import JSONFormatterFeature

struct FinalUnterminatedTest {
    static func main() async {
        print("=" * 80)
        print("🧪 COMPREHENSIVE UNTERMINATED STRUCTURE TEST")
        print("=" * 80)
        
        let fixer = ParseTreeJSONFixer()
        let parser = PreciseJSONParser()
        
        // Test cases for all types of unterminated structures
        let testCases = [
            ("Your exact case - unterminated string in key", """
            {
              "features": [
                {
                  "properties": {
                    "name": "Waitrose King's Road",
                    "postcode": "SW3 5XP",
                    "city": "London"
                  },
                  "type": "Feature
                  "geometry": {
                    "type": "Point",
                    "coordinates": [-0.1695, 51.4865]
                  }
                }
              ]
            }
            """),
            
            ("Unterminated object - missing }", """
            {
              "name": "test",
              "nested": {
                "value": 123
            }
            """),
            
            ("Unterminated array - missing ]", """
            {
              "items": [1, 2, 3
            }
            """),
            
            ("Multiple unterminated structures", """
            {
              "data": {
                "items": [
                  "one",
                  "two
                ]
            """),
            
            ("Unterminated string value", """
            {
              "name": "unterminated value
            }
            """),
            
            ("Complex nested unterminated", """
            {
              "level1": {
                "level2": {
                  "items": [
                    {"name": "item1"},
                    {"name": "item2
                  ]
                }
            }
            """)
        ]
        
        var passedTests = 0
        var failedTests = 0
        
        for (index, test) in testCases.enumerated() {
            print("\n" + "─" * 60)
            print("Test \(index + 1): \(test.0)")
            print("─" * 60)
            
            // Try to fix with ParseTreeJSONFixer
            let fixResult = await fixer.fix(test.1)
            
            if fixResult.wasFixed {
                print("✅ Issues detected and fixed:")
                for fix in fixResult.fixes {
                    print("   • \(fix)")
                }
                
                // Validate the fixed JSON
                let errors = await parser.validate(fixResult.fixed)
                
                if errors.isEmpty {
                    print("✨ Fixed JSON is valid!")
                    
                    // Try to parse it
                    if let data = fixResult.fixed.data(using: .utf8) {
                        do {
                            _ = try JSONSerialization.jsonObject(with: data, options: [])
                            print("✅ Successfully parsed by JSONSerialization")
                            passedTests += 1
                        } catch {
                            print("⚠️ JSONSerialization failed: \(error)")
                            failedTests += 1
                        }
                    }
                } else {
                    print("❌ Fixed JSON still has errors:")
                    for error in errors.prefix(3) {
                        print("   - Line \(error.line): \(error.message)")
                    }
                    failedTests += 1
                }
            } else {
                print("❌ No fixes detected")
                failedTests += 1
            }
        }
        
        print("\n" + "═" * 80)
        print("📊 TEST RESULTS")
        print("═" * 80)
        print("Passed: \(passedTests)/\(testCases.count)")
        print("Failed: \(failedTests)/\(testCases.count)")
        
        if passedTests == testCases.count {
            print("🎉 SUCCESS: All unterminated structure tests passed!")
        } else {
            print("⚠️ WARNING: Some tests failed - need to improve detection/fixing")
        }
        print("═" * 80)
    }
}

