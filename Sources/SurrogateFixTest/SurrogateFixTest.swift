import Foundation
import JSONFormatterFeature

@main
struct SurrogateFixTest {
    static func main() async {
        let fixer = JSONFixer()
        let parser = JSONParser()
        
        let input = #"{"message":"Hello \uD83D\uDE00 World"}"#
        print("Input: \(input)")
        print()
        
        // First validate it's actually valid JSON
        let errors = await parser.validate(input)
        if errors.isEmpty {
            print("✅ Input is valid JSON")
        } else {
            print("❌ Validation errors:")
            for error in errors {
                print("   \(error.message)")
            }
        }
        print()
        
        // Now try to fix it
        let result = await fixer.fix(input)
        print("Output: \(result.fixed)")
        print()
        
        if !result.fixes.isEmpty {
            print("Fixes applied:")
            for fix in result.fixes {
                print("   - \(fix)")
            }
        } else {
            print("No fixes needed")
        }
        
        // Validate the output
        let outputErrors = await parser.validate(result.fixed)
        if outputErrors.isEmpty {
            print("\n✅ Output is valid JSON")
        } else {
            print("\n❌ Output validation errors:")
            for error in outputErrors {
                print("   \(error.message)")
            }
        }
    }
}