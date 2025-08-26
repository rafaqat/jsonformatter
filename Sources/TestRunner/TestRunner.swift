import Foundation
import JSONFormatterFeature

struct TestRunner {
    static func mainOriginal() async {
        print("=" * 80)
        print("🧪 JSON FIXER TEST RUNNER")
        print("=" * 80)
        
        // The exact problematic case from the user
        let userCase = """
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
        """
        
        print("\n🔍 Testing User's Case: Missing [ in coordinates")
        print("-" * 60)
        
        // Test with ParseTreeJSONFixer
        let fixer = ParseTreeJSONFixer()
        let result = await fixer.fix(userCase)
        
        print("Fix attempted: \(result.wasFixed ? "YES" : "NO")")
        if result.wasFixed {
            print("Fixes applied: \(result.fixes.joined(separator: ", "))")
            
            // Validate the fixed JSON
            let parser = PreciseJSONParser()
            let errors = await parser.validate(result.fixed)
            
            if errors.isEmpty {
                print("✅ SUCCESS: Fixed JSON is valid!")
                
                // Show the fixed coordinates
                if let fixedData = result.fixed.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: fixedData) as? [String: Any],
                   let features = json["features"] as? [[String: Any]],
                   let geometry = features.first?["geometry"] as? [String: Any],
                   let coordinates = geometry["coordinates"] {
                    print("📍 Fixed coordinates: \(coordinates)")
                }
            } else {
                print("❌ FAIL: Fixed JSON still has errors:")
                for error in errors {
                    print("  - Line \(error.line), Col \(error.column): \(error.message)")
                }
            }
        } else {
            print("❌ FAIL: Fixer did not detect the issue")
        }
        
        print("\n" + "=" * 80)
        print("🔍 Additional Test Cases")
        print("=" * 80)
        
        // More test cases
        let additionalTests = [
            ("Simple missing [", """
            {"coordinates": -0.1695, 51.4865]}
            """),
            
            ("Missing { after key", """
            {"geometry": "type": "Point"}}
            """),
            
            ("Multiple issues", """
            {"data": "values": [1, 2, 3}
            """)
        ]
        
        for test in additionalTests {
            print("\n📝 Test: \(test.0)")
            let testResult = await fixer.fix(test.1)
            print("  Fixed: \(testResult.wasFixed ? "✅" : "❌")")
            if testResult.wasFixed {
                print("  Fixes: \(testResult.fixes.joined(separator: ", "))")
            }
        }
        
        print("\n" + "=" * 80)
        print("✨ Test run complete")
        print("=" * 80)
    }
}

