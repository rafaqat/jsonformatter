import Foundation
import JSONFormatterFeature

@main
struct FinalParserTest {
    static func main() async {
        print("🧪 FINAL PARSER TEST SUITE")
        print("Testing JSONFixer implementation based on codex requirements")
        print(String(repeating: "=", count: 80))
        
        let fixer = JSONFixer()
        let parser = JSONParser()
        var totalTests = 0
        var passedTests = 0
        
        // Test categories based on codex gaps
        
        print("\n📝 STRING & UNICODE TESTS")
        print(String(repeating: "-", count: 60))
        
        let stringTests = [
            // Invalid unicode escapes
            (#"{"test": "\u123"}"#, "Invalid \\u escape (3 digits)"),
            (#"{"test": "\uGHIJ"}"#, "Invalid \\u escape (non-hex)"),
            (#"{"test": "\uD834"}"#, "Lone high surrogate"),
            (#"{"test": "\uDD1E"}"#, "Lone low surrogate"),
            
            // Control characters
            (#"{"test": "line\nbreak"}"#, "Unescaped newline"),
            (#"{"test": "tab\there"}"#, "Unescaped tab"),
            
            // Invalid escapes
            (#"{"test": "\z"}"#, "Invalid escape \\z"),
            (#"{"test": "\1"}"#, "Invalid escape \\1"),
        ]
        
        for (input, description) in stringTests {
            totalTests += 1
            let result = await fixer.fix(input)
            let errors = await parser.validate(result.fixed)
            if errors.isEmpty {
                passedTests += 1
                print("✅ \(description)")
            } else {
                print("❌ \(description)")
                print("   Fixed: \(result.fixed)")
                print("   Errors: \(errors)")
            }
        }
        
        print("\n🔢 NUMBER TESTS")
        print(String(repeating: "-", count: 60))
        
        let numberTests = [
            // Leading plus/zeros
            (#"{"num": +123}"#, "Leading plus sign"),
            (#"{"num": 0123}"#, "Leading zeros"),
            
            // Incomplete decimals
            (#"{"num": .5}"#, "Missing integer part"),
            (#"{"num": 42.}"#, "Missing decimal part"),
            
            // Special values
            (#"{"num": -0}"#, "Negative zero"),
            (#"{"num": Infinity}"#, "Infinity literal"),
            (#"{"num": NaN}"#, "NaN literal"),
            
            // Hex/octal
            (#"{"num": 0x1F}"#, "Hexadecimal"),
            (#"{"num": 0o77}"#, "Octal"),
        ]
        
        for (input, description) in numberTests {
            totalTests += 1
            let result = await fixer.fix(input)
            let errors = await parser.validate(result.fixed)
            if errors.isEmpty {
                passedTests += 1
                print("✅ \(description)")
                if result.fixes.count > 0 {
                    print("   Applied \(result.fixes.count) fix(es)")
                }
            } else {
                print("❌ \(description)")
                print("   Fixed: \(result.fixed)")
            }
        }
        
        print("\n📚 LITERAL TESTS")
        print(String(repeating: "-", count: 60))
        
        let literalTests = [
            // Case variations
            (#"{"bool": TRUE}"#, "Uppercase TRUE"),
            (#"{"bool": False}"#, "Mixed case False"),
            (#"{"val": NULL}"#, "Uppercase NULL"),
            
            // Partial literals
            (#"{"val": tru}"#, "Partial 'tru'"),
            (#"{"val": fals}"#, "Partial 'fals'"),
            (#"{"val": nul}"#, "Partial 'nul'"),
            
            // Spaced literals
            (#"{"val": tr ue}"#, "Spaced 'tr ue'"),
        ]
        
        for (input, description) in literalTests {
            totalTests += 1
            let result = await fixer.fix(input)
            let errors = await parser.validate(result.fixed)
            if errors.isEmpty {
                passedTests += 1
                print("✅ \(description)")
            } else {
                print("❌ \(description)")
            }
        }
        
        print("\n🗂️ STRUCTURE TESTS")
        print(String(repeating: "-", count: 60))
        
        let structureTests = [
            // Missing delimiters
            (#"{"a" 1}"#, "Missing colon"),
            (#"{"a":1 "b":2}"#, "Missing comma"),
            (#"[1 2]"#, "Missing comma in array"),
            
            // Trailing commas
            (#"{"a":1,}"#, "Trailing comma in object"),
            (#"[1,2,]"#, "Trailing comma in array"),
            
            // Unterminated containers
            (#"{"a":1"#, "Unterminated object"),
            (#"[1,2"#, "Unterminated array"),
            
            // Single quotes
            (#"{'key':'value'}"#, "Single quotes"),
        ]
        
        for (input, description) in structureTests {
            totalTests += 1
            let result = await fixer.fix(input)
            let errors = await parser.validate(result.fixed)
            if errors.isEmpty {
                passedTests += 1
                print("✅ \(description)")
            } else {
                print("❌ \(description)")
            }
        }
        
        print("\n🔄 MULTI-ROOT & NDJSON TESTS")
        print(String(repeating: "-", count: 60))
        
        let multiRootTests = [
            // Multiple roots
            (#"{"a":1}{"b":2}"#, "Multiple objects"),
            (#"123 456"#, "Multiple numbers"),
            
            // NDJSON
            (#"{"a":1}\n{"b":2}"#, "NDJSON format"),
        ]
        
        for (input, description) in multiRootTests {
            totalTests += 1
            let result = await fixer.fix(input)
            let errors = await parser.validate(result.fixed)
            if errors.isEmpty {
                passedTests += 1
                print("✅ \(description)")
                if result.fixes.count > 0 {
                    print("   Applied \(result.fixes.count) fix(es)")
                }
            } else {
                print("❌ \(description)")
            }
        }
        
        print("\n" + String(repeating: "=", count: 80))
        print("📊 RESULTS: \(passedTests)/\(totalTests) tests passed")
        
        let percentage = Double(passedTests) / Double(totalTests) * 100
        print("Pass rate: \(String(format: "%.1f", percentage))%")
        
        if percentage >= 90 {
            print("✅ Target of >90% pass rate achieved!")
        } else {
            print("⚠️ Below target of 90% pass rate")
        }
    }
}