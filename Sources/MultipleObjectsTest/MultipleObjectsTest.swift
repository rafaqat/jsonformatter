import Foundation
import JSONFormatterFeature

@main
struct MultipleObjectsTest {
    static func main() async {
        print("=" * 80)
        print("🧪 MULTIPLE JSON OBJECTS TEST")
        print("=" * 80)
        
        let fixer = JSONFixer()
        let parser = JSONParser()
        
        // The exact input from the user
        let userInput = """
        {"field1":"aa11","field2":"aa22", "structField":{"sf1" : "aaa11","sf2" : "aaa22"}},
        {"field1":"bb11","field2":"bb22","structField":{"sf1" : "bbb11","sf2" : "bbb22"}}, 
        {"field1" : "cc11","field2" : "cc22","structField" : {"sf1" : "ccc11","sf2" : "ccc22"}}
        """
        
        print("\n📝 ORIGINAL INPUT:")
        print("-" * 60)
        print(userInput)
        print("-" * 60)
        
        // First, check what the parser says
        print("\n🔍 VALIDATION BEFORE FIX:")
        let errorsBeforeFix = await parser.validate(userInput)
        if errorsBeforeFix.isEmpty {
            print("✅ Parser says it's valid JSON (but it's not - multiple root objects)")
        } else {
            print("❌ Parser found \(errorsBeforeFix.count) errors:")
            for error in errorsBeforeFix.prefix(5) {
                print("   Line \(error.line), Col \(error.column): \(error.message)")
            }
        }
        
        // Try to fix with JSONFixer
        print("\n🔧 ATTEMPTING FIX:")
        let fixResult = await fixer.fix(userInput)
        
        print("Debug - Fixes array count: \(fixResult.fixes.count)")
        print("Debug - wasFixed: \(fixResult.wasFixed)")
        
        if fixResult.wasFixed || !fixResult.fixes.isEmpty {
            print("✅ Fixer applied \(fixResult.fixes.count) fixes:")
            for fix in fixResult.fixes {
                print("   • \(fix)")
            }
        } else {
            print("❌ No fixes detected")
        }
        
        print("\n📤 OUTPUT AFTER FIX:")
        print("-" * 60)
        print(fixResult.fixed)
        print("-" * 60)
        
        // Validate the fixed result
        print("\n🔍 VALIDATION AFTER FIX:")
        let errorsAfterFix = await parser.validate(fixResult.fixed)
        if errorsAfterFix.isEmpty {
            print("✅ Fixed JSON is valid")
            
            // Try to parse it
            if let data = fixResult.fixed.data(using: .utf8) {
                do {
                    let json = try JSONSerialization.jsonObject(with: data, options: [])
                    print("\n✨ Successfully parsed!")
                    
                    // Check what we got
                    if let array = json as? [[String: Any]] {
                        print("   Result is an array with \(array.count) objects")
                    } else if let dict = json as? [String: Any] {
                        print("   Result is a single object with \(dict.count) keys")
                    } else {
                        print("   Result type: \(type(of: json))")
                    }
                } catch {
                    print("❌ JSONSerialization failed: \(error)")
                }
            }
        } else {
            print("❌ Still has \(errorsAfterFix.count) errors:")
            for error in errorsAfterFix.prefix(5) {
                print("   Line \(error.line), Col \(error.column): \(error.message)")
            }
        }
        
        print("\n" + "=" * 80)
        print("📊 ANALYSIS")
        print("=" * 80)
        
        // Count what remains
        let originalObjectCount = userInput.components(separatedBy: "\"field1\"").count - 1
        let fixedObjectCount = fixResult.fixed.components(separatedBy: "\"field1\"").count - 1
        
        print("Original had \(originalObjectCount) objects with 'field1'")
        print("Fixed has \(fixedObjectCount) objects with 'field1'")
        
        if fixedObjectCount < originalObjectCount {
            print("⚠️ PROBLEM: Lost \(originalObjectCount - fixedObjectCount) objects during fixing!")
        }
        
        // The correct fix should wrap in array
        print("\n✅ EXPECTED FIX:")
        print("Should wrap the multiple objects in an array: [ obj1, obj2, obj3 ]")
    }
}

extension String {
    static func *(lhs: String, rhs: Int) -> String {
        String(repeating: lhs, count: rhs)
    }
}