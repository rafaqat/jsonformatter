import Foundation
import JSONFormatterFeature

@main
struct ParserVsFixerTest {
    static func main() async {
        let parser = JSONParser()
        let fixer = JSONFixer()
        
        print("📊 PARSER vs FIXER TEST RESULTS")
        print("=" + String(repeating: "=", count: 79))
        print()
        
        // Test cases that parser should REJECT but fixer should FIX
        let testCases: [(name: String, json: String, shouldParserAccept: Bool)] = [
            // Structure errors
            ("Missing comma", #"{"a":1 "b":2}"#, false),
            ("Missing colon", #"{"a" 1}"#, false),
            ("Trailing comma object", #"{"a":1,}"#, false),
            ("Trailing comma array", #"[1,2,]"#, false),
            ("Single quotes", #"{'key':'value'}"#, false),
            ("Unquoted keys", #"{key: "value"}"#, false),
            
            // Number errors  
            ("Leading zeros", "01234", false),
            ("Plus sign", "+123", false),
            ("Hex number", "0xFF", false),
            ("Infinity", "Infinity", false),
            ("NaN", "NaN", false),
            
            // String errors
            ("Unterminated string", #""hello"#, false),
            ("Invalid escape", #""\x""#, false),
            ("Control character", "\"hello\tworld\"", false),
            ("Lone high surrogate", #""\uD800""#, false),
            
            // Literal errors
            ("Uppercase true", "TRUE", false),
            ("Uppercase false", "FALSE", false),
            ("Uppercase null", "NULL", false),
            ("Undefined", "undefined", false),
            
            // Valid JSON
            ("Valid object", #"{"key":"value"}"#, true),
            ("Valid array", "[1,2,3]", true),
            ("Valid string", #""hello""#, true),
            ("Valid number", "123.456", true),
            ("Valid true", "true", true),
            ("Valid false", "false", true),
            ("Valid null", "null", true),
            ("Valid surrogate pair", #""\uD83D\uDE00""#, true),
        ]
        
        var parserResults: [(name: String, accepted: Bool, errors: Int)] = []
        var fixerResults: [(name: String, fixed: Bool, fixCount: Int, valid: Bool)] = []
        
        print("🔍 PARSER VALIDATION RESULTS")
        print("-" + String(repeating: "-", count: 79))
        
        for (name, json, shouldAccept) in testCases {
            let errors = await parser.validate(json)
            let accepted = errors.isEmpty
            let correct = accepted == shouldAccept
            parserResults.append((name, accepted, errors.count))
            
            let icon = correct ? "✅" : "❌"
            let status = accepted ? "ACCEPTED" : "REJECTED (\(errors.count) errors)"
            print("\(icon) \(name.padding(toLength: 25, withPad: " ", startingAt: 0)) \(status)")
        }
        
        print()
        print("🔧 FIXER AUTO-CORRECTION RESULTS")
        print("-" + String(repeating: "-", count: 79))
        
        for (name, json, _) in testCases {
            let result = await fixer.fix(json)
            let validationErrors = await parser.validate(result.fixed)
            let isValidAfterFix = validationErrors.isEmpty
            fixerResults.append((name, true, result.fixes.count, isValidAfterFix))
            
            let icon = isValidAfterFix ? "✅" : "❌"
            let fixInfo = result.fixes.count > 0 ? "(\(result.fixes.count) fixes)" : "(no fixes needed)"
            print("\(icon) \(name.padding(toLength: 25, withPad: " ", startingAt: 0)) \(fixInfo.padding(toLength: 20, withPad: " ", startingAt: 0)) Valid: \(isValidAfterFix)")
        }
        
        print()
        print("=" + String(repeating: "=", count: 79))
        print("📊 SUMMARY")
        print()
        
        // Parser summary
        let parserCorrect = testCases.enumerated().filter { i, test in
            parserResults[i].accepted == test.shouldParserAccept
        }.count
        let parserAccuracy = Double(parserCorrect) / Double(testCases.count) * 100
        
        print("PARSER:")
        print("  • Total tests: \(testCases.count)")
        print("  • Correctly validated: \(parserCorrect)/\(testCases.count)")
        print("  • Accuracy: \(String(format: "%.1f%%", parserAccuracy))")
        
        // Fixer summary
        let fixerSuccesses = fixerResults.filter { $0.valid }.count
        let fixerSuccessRate = Double(fixerSuccesses) / Double(testCases.count) * 100
        let totalFixes = fixerResults.reduce(0) { $0 + $1.fixCount }
        
        print()
        print("FIXER:")
        print("  • Total tests: \(testCases.count)")
        print("  • Successfully fixed: \(fixerSuccesses)/\(testCases.count)")
        print("  • Success rate: \(String(format: "%.1f%%", fixerSuccessRate))")
        print("  • Total fixes applied: \(totalFixes)")
        
        print()
        print(fixerSuccessRate == 100 ? "✅ FIXER ACHIEVES 100% SUCCESS RATE!" : "⚠️ Some cases could not be fixed")
        print(parserAccuracy == 100 ? "✅ PARSER ACHIEVES 100% ACCURACY!" : "⚠️ Parser has validation issues")
    }
}