import Foundation
import JSONFormatterFeature

@main
struct QuickParserTest {
    static func main() async {
        print("🧪 QUICK PARSER TEST")
        print(String(repeating: "=", count: 80))
        
        await runStructureTests()
        
        print("\n✅ Tests completed")
    }
    
    static func runStructureTests() async {
        print("\n📁 STRUCTURE TESTS")
        print(String(repeating: "-", count: 60))
        
        print("Creating fixer and parser...")
        let fixer = JSONFixer()
        let parser = JSONParser()
        print("Created successfully")
        
        // Test just one simple case
        let testInput = #"{"key":"value"}"#
        print("Testing: \(testInput)")
        
        print("Calling fixer.fix()...")
        let result = await fixer.fix(testInput)
        print("Fixed: \(result.fixed)")
        
        print("Calling parser.validate()...")
        let errors = await parser.validate(result.fixed)
        print("Validation errors: \(errors.count)")
        
        print("\n✅ Structure test completed")
    }
}