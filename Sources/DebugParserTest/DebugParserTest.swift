import Foundation
import JSONFormatterFeature

@main
struct DebugParserTest {
    static func main() async {
        print("Starting debug parser test...")
        
        // Test the string multiplication
        let separator = String(repeating: "-", count: 60)
        print(separator)
        
        // Test basic parser/fixer
        let fixer = JSONFixer()
        let parser = JSONParser()
        
        print("Created fixer and parser")
        
        // Test structure
        print("\n📁 STRUCTURE TESTS")
        print(separator)
        
        let tests = [
            (#"{"a":1}"#, "y_object_basic"),
            (#"["a"]"#, "y_array_basic"),
            (#"123"#, "y_number_basic"),
        ]
        
        for (input, name) in tests {
            print("Testing \(name)...")
            let result = await fixer.fix(input)
            let errors = await parser.validate(result.fixed)
            let passed = errors.isEmpty
            print("\(passed ? "✅" : "❌") \(name)")
        }
        
        print("\n✅ Debug test completed")
    }
}