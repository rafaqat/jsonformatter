import Foundation
import JSONFormatterFeature

struct UnterminatedStringTest {
    static func main() async {
        print("=" * 80)
        print("🧪 UNTERMINATED STRING FIXER TEST")
        print("=" * 80)
        
        let fixer = JSONFixer()
        let parser = JSONParser()
        
        // Test cases for unterminated strings
        let testCases = [
            ("Simple unterminated at end", """
            {"name": "test
            """),
            
            ("Unterminated in middle", """
            {"name": "test, "age": 25}
            """),
            
            ("Your exact case", """
            {
              "geometry": {
                "type": "Point",
                "coordinates": [
                  -0.1695,
                  51.4865
                ]
              },
              "type": "Feature
            }
            """),
            
            ("Complex nested unterminated", """
            {
              "features": [
                {
                  "properties": {
                    "name": "Waitrose King's Road,
                    "postcode": "SW3 5XP",
                    "city": "London"
                  },
                  "type": "Feature",
                  "geometry": {
                    "type": "Point",
                    "coordinates": [-0.1695, 51.4865]
                  }
                }
              ]
            }
            """)
        ]
        
        var passedTests = 0
        var failedTests = 0
        
        for (index, test) in testCases.enumerated() {
            print("\n" + "-" * 60)
            print("Test \(index + 1): \(test.0)")
            print("-" * 60)
            
            // Try to fix with JSONFixer
            let fixResult = await fixer.fix(test.1)
            
            if fixResult.wasFixed {
                print("✅ Detected issues: \(fixResult.fixes.joined(separator: ", "))")
                
                // Validate the fixed JSON
                let errors = await parser.validate(fixResult.fixed)
                
                if errors.isEmpty {
                    print("✨ Fixed JSON is valid!")
                    passedTests += 1
                } else {
                    print("❌ Fixed JSON still has errors:")
                    for error in errors.prefix(3) {
                        print("   - \(error.message)")
                    }
                    failedTests += 1
                }
            } else {
                print("❌ No fixes applied")
                failedTests += 1
            }
        }
        
        print("\n" + "=" * 80)
        print("📊 RESULTS")
        print("=" * 80)
        print("Passed: \(passedTests)/\(testCases.count)")
        print("Failed: \(failedTests)/\(testCases.count)")
        
        if passedTests == testCases.count {
            print("🎉 All unterminated string tests passed!")
        } else {
            print("⚠️ Some tests failed - unterminated string handling needs improvement")
        }
    }
}

extension String {
    static func *(lhs: String, rhs: Int) -> String {
        String(repeating: lhs, count: rhs)
    }
}