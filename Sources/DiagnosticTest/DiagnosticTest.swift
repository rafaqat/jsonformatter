import Foundation
import JSONFormatterFeature

@main
struct DiagnosticTest {
    static func main() async {
        print("🔍 DIAGNOSTIC TEST - Understanding JSONFixer Behavior")
        print(String(repeating: "=", count: 80))
        
        let fixer = JSONFixer()
        let parser = JSONParser()
        
        // Issue 1: Trailing commas
        print("\n1️⃣ TRAILING COMMA ISSUE")
        print(String(repeating: "-", count: 60))
        
        let trailingCommaTests = [
            (#"{"a":1,}"#, "Object with trailing comma"),
            (#"[1,2,]"#, "Array with trailing comma"),
        ]
        
        for (input, description) in trailingCommaTests {
            print("\nTest: \(description)")
            print("Input:  \(input)")
            
            let result = await fixer.fix(input)
            print("Output: \(result.fixed.replacingOccurrences(of: "\n", with: ""))")
            print("Fixes:  \(result.fixes)")
            
            let errors = await parser.validate(result.fixed)
            print("Valid:  \(errors.isEmpty)")
            
            // Check if trailing comma still exists
            let stillHasTrailingComma = result.fixed.contains(",}") || result.fixed.contains(",]")
            print("Still has trailing comma: \(stillHasTrailingComma)")
        }
        
        // Issue 2: String formatting
        print("\n\n2️⃣ STRING FORMATTING ISSUE")
        print(String(repeating: "-", count: 60))
        
        let stringTests = [
            (#""hello world""#, "Simple string"),
            (#""line\nbreak""#, "String with escaped newline"),
            (#""\u0041""#, "String with unicode escape"),
            (#""quote\"here""#, "String with escaped quote"),
        ]
        
        for (input, description) in stringTests {
            print("\nTest: \(description)")
            print("Input:  \(input)")
            
            let result = await fixer.fix(input)
            print("Output: \(result.fixed)")
            print("Fixes:  \(result.fixes)")
            print("Changed: \(input != result.fixed)")
        }
        
        // Issue 3: String escape handling
        print("\n\n3️⃣ STRING ESCAPE HANDLING")
        print(String(repeating: "-", count: 60))
        
        let escapeTests = [
            (#""\z""#, "Invalid escape \\z"),
            (#""\u123""#, "Invalid unicode (3 digits)"),
            (#""\uD834""#, "Lone high surrogate"),
            (#""tab\there""#, "Literal tab character"),
            (#""newline\nhere""#, "Literal newline"),
        ]
        
        for (input, description) in escapeTests {
            print("\nTest: \(description)")
            print("Input:  \(input)")
            
            let result = await fixer.fix(input)
            print("Output: \(result.fixed)")
            print("Fixes:  \(result.fixes)")
            
            // Check what actually happened
            if input.contains("\\z") && !result.fixed.contains("\\z") {
                print("→ Invalid escape removed/fixed")
            }
            if input.contains("\\u") && result.fixed.contains("\\uFFFD") {
                print("→ Invalid unicode replaced with \\uFFFD")
            }
            if input.contains("\t") && result.fixed.contains("\\u0009") {
                print("→ Tab escaped as \\u0009")
            }
            if input.contains("\n") && result.fixed.contains("\\u000A") {
                print("→ Newline escaped as \\u000A")
            }
        }
        
        // Check the actual TokenKind for strings
        print("\n\n4️⃣ TOKEN ANALYSIS")
        print(String(repeating: "-", count: 60))
        
        // This would require access to the tokenizer, but we can infer from behavior
        let simpleString = #"{"test": "hello"}"#
        let result = await fixer.fix(simpleString)
        
        print("Simple object: \(simpleString)")
        print("Fixed output:  \(result.fixed)")
        print("Fix count:     \(result.fixes.count)")
        
        if result.fixes.count > 0 {
            print("\nWhy fixes on valid JSON?")
            print("Likely cause: Formatter always applies pretty-printing")
            print("- Adds newlines and indentation")
            print("- This counts as a 'fix' even though input was valid")
        }
    }
}