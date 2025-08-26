import Foundation

// Test cases for ParseTreeJSONFixer
@MainActor
public class TestParseTreeFixer {
    
    public static func runTests() async {
        let fixer = ParseTreeJSONFixer()
        
        // Test 1: Missing opening bracket
        let test1 = """
        {
          "coordinates": -0.1695, 51.4865]
        }
        """
        print("Test 1 - Missing opening bracket:")
        let result1 = await fixer.fix(test1)
        print("Fixed: \(result1.fixed)")
        print("Fixes applied: \(result1.fixes)")
        print("")
        
        // Test 2: Missing closing bracket  
        let test2 = """
        {
          "coordinates": [-0.1695, 51.4865
        }
        """
        print("Test 2 - Missing closing bracket:")
        let result2 = await fixer.fix(test2)
        print("Fixed: \(result2.fixed)")
        print("Fixes applied: \(result2.fixes)")
        print("")
        
        // Test 3: Missing comma between object members
        let test3 = """
        {
          "type": "Feature"
          "properties": {
            "name": "Test"
          }
        }
        """
        print("Test 3 - Missing comma between members:")
        let result3 = await fixer.fix(test3)
        print("Fixed: \(result3.fixed)")
        print("Fixes applied: \(result3.fixes)")
        print("")
        
        // Test 4: Unquoted keys
        let test4 = """
        {
          type: "Feature",
          properties: {
            name: "Test"
          }
        }
        """
        print("Test 4 - Unquoted keys:")
        let result4 = await fixer.fix(test4)
        print("Fixed: \(result4.fixed)")
        print("Fixes applied: \(result4.fixes)")
        print("")
        
        // Test 5: Complex case - missing commas in array
        let test5 = """
        {
          "numbers": [1 2 3 4 5]
        }
        """
        print("Test 5 - Missing commas in array:")
        let result5 = await fixer.fix(test5)
        print("Fixed: \(result5.fixed)")
        print("Fixes applied: \(result5.fixes)")
        print("")
        
        // Test 6: Wrong bracket type
        let test6 = """
        {
          "array": [1, 2, 3}
        }
        """
        print("Test 6 - Wrong bracket type:")
        let result6 = await fixer.fix(test6)
        print("Fixed: \(result6.fixed)")
        print("Fixes applied: \(result6.fixes)")
    }
}