import Foundation
import JSONFormatterFeature

@main
struct BracketTest {
    static func main() async {
        print("=" * 80)
        print("🔍 CRITICAL MISSING BRACKET TEST")
        print("=" * 80)
        
        let parser = PreciseJSONParser()
        let fixer = ParseTreeJSONFixer()
        
        // Focus on the critical missing bracket cases
        let criticalTests = [
            ("User's exact case - missing [ in coordinates", """
            {
              "features": [
                {
                  "properties": {
                    "name": "Waitrose King's Road",
                    "postcode": "SW3 5XP",
                    "city": "London"
                  },
                  "type": "Feature",
                  "geometry": {
                    "type": "Point",
                    "coordinates": -0.1695, 51.4865]
                  }
                }
              ]
            }
            """),
            
            ("Simple missing opening bracket", """
            {"coordinates": -0.1695, 51.4865]}
            """),
            
            ("Missing [ with positive numbers", """
            {"coords": 10.5, 20.3]}
            """),
            
            ("Missing [ in nested object", """
            {"data": {"location": {"coords": 1.23, 4.56]}}}
            """),
            
            ("Missing opening brace after key", """
            {"geometry": "type": "Point", "coordinates": [1, 2]}}
            """)
        ]
        
        for (index, test) in criticalTests.enumerated() {
            print("\n" + "─" * 60)
            print("Test \(index + 1): \(test.0)")
            print("─" * 60)
            
            // Check if parser detects error
            let errors = await parser.validate(test.1)
            
            if !errors.isEmpty {
                print("❌ Error detected: \(errors.first?.message ?? "")")
                print("   at line \(errors.first?.line ?? 0), column \(errors.first?.column ?? 0)")
                
                // Try to fix it
                let fixResult = await fixer.fix(test.1)
                
                if fixResult.wasFixed {
                    print("✨ Fixed: \(fixResult.fixes.joined(separator: ", "))")
                    
                    // Validate the fixed JSON
                    let validationErrors = await parser.validate(fixResult.fixed)
                    
                    if validationErrors.isEmpty {
                        print("✅ Fixed JSON is valid!")
                        
                        // Parse and show structure
                        do {
                            let parsed = try await parser.parse(fixResult.fixed)
                            print("📋 Structure verified")
                        } catch {
                            print("⚠️ Parse error: \(error)")
                        }
                    } else {
                        print("❌ Fixed JSON still has errors:")
                        for err in validationErrors {
                            print("   - \(err.message)")
                        }
                    }
                } else {
                    print("❌ Could not fix the error")
                }
            } else {
                print("⚠️ No error detected (might be valid JSON)")
            }
        }
        
        print("\n" + "=" * 80)
    }
}

extension String {
    static func *(lhs: String, rhs: Int) -> String {
        String(repeating: lhs, count: rhs)
    }
}