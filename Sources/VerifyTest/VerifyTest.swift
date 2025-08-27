import Foundation
import JSONFormatterFeature

@main
struct VerifyTest {
    static func main() async {
        print("✅ VERIFY TEST - Testing in proper JSON context")
        print(String(repeating: "=", count: 80))
        
        let fixer = JSONFixer()
        
        print("\n1️⃣ TRAILING COMMAS IN CONTEXT")
        let trailingTests = [
            (#"{"a":1,"b":2,}"#, "Object trailing comma"),
            (#"{"arr":[1,2,]}"#, "Nested array trailing comma"),
        ]
        
        for (input, desc) in trailingTests {
            print("\n\(desc)")
            print("Input:  \(input)")
            let result = await fixer.fix(input)
            print("Output: \(result.fixed.replacingOccurrences(of: "\n", with: " "))")
            print("Fixes reported: \(result.fixes.count)")
            print("Has trailing comma: \(result.fixed.contains(",}") || result.fixed.contains(",]"))")
        }
        
        print("\n\n2️⃣ STRINGS IN PROPER CONTEXT")
        let stringTests = [
            (#"{"str":"hello"}"#, "Simple string in object"),
            (#"["hello","world"]"#, "Strings in array"),
            (#"{"str":"tab\there"}"#, "Tab character in string"),
        ]
        
        for (input, desc) in stringTests {
            print("\n\(desc)")
            print("Input:  \(input)")
            let result = await fixer.fix(input)
            print("Output: \(result.fixed.replacingOccurrences(of: "\n", with: " "))")
            print("Fixes: \(result.fixes)")
        }
        
        print("\n\n3️⃣ WHAT COUNTS AS A FIX?")
        print("Testing what gets reported in fixes array...")
        
        let fixTests = [
            (#"{"a":+123}"#, "Leading plus"),
            (#"{"a":.5}"#, "Missing integer part"),
            (#"{"a":TRUE}"#, "Uppercase literal"),
            (#"{"a" 1}"#, "Missing colon"),
            (#"{"a":1 "b":2}"#, "Missing comma"),
        ]
        
        for (input, desc) in fixTests {
            let result = await fixer.fix(input)
            print("\n\(desc): \(result.fixes.count) fixes")
            for fix in result.fixes {
                print("  - \(fix)")
            }
        }
    }
}