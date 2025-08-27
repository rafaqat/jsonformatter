import Foundation
import JSONFormatterFeature

@main
struct SimpleParserTest {
    static func main() async {
        print("Starting simple parser test...")
        
        let fixer = JSONFixer()
        let parser = JSONParser()
        
        // Test 1: Simple valid JSON
        print("\nTest 1: Valid JSON")
        let valid = #"{"test": 123}"#
        let result1 = await fixer.fix(valid)
        print("Fixed: \(result1.fixed)")
        
        // Test 2: Invalid JSON
        print("\nTest 2: Invalid JSON")  
        let invalid = #"{"test": +123}"#
        let result2 = await fixer.fix(invalid)
        print("Fixed: \(result2.fixed)")
        print("Fixes applied: \(result2.fixes.count)")
        
        // Test 3: Validate
        print("\nTest 3: Validation")
        let errors = await parser.validate(result2.fixed)
        print("Validation errors: \(errors.count)")
        
        print("\n✅ Simple test completed")
    }
}