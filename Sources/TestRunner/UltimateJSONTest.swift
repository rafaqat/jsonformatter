import Foundation
import JSONFormatterFeature

// The ULTIMATE comprehensive JSON validation test suite
// This tests EVERY possible JSON error combination

@main
struct UltimateJSONTest {
    static func main() async {
        print("=" * 80)
        print("🚀 ULTIMATE JSON VALIDATION TEST SUITE")
        print("=" * 80)
        
        let fixer = ParseTreeJSONFixer()
        let parser = PreciseJSONParser()
        
        // COMPREHENSIVE test cases covering ALL JSON error types
        let testSuite = [
            // MISSING DELIMITERS
            ("Missing opening brace", #"  "key": "value" }"#),
            ("Missing closing brace", #"{ "key": "value" "#),
            ("Missing opening bracket", #"  1, 2, 3 ]"#),
            ("Missing closing bracket", #"[ 1, 2, 3 "#),
            ("Missing multiple closing", #"{ "a": [ { "b": 1 "#),
            
            // MISSING QUOTES - KEYS
            ("Key missing opening quote", #"{ key": "value" }"#),
            ("Key missing closing quote", #"{ "key: "value" }"#),
            ("Key missing both quotes", #"{ key: "value" }"#),
            ("Multiple keys unquoted", #"{ key1: "a", key2: "b" }"#),
            
            // MISSING QUOTES - VALUES
            ("Value missing opening quote", #"{ "key": value" }"#),
            ("Value missing closing quote", #"{ "key": "value }"#),
            ("Value missing both quotes", #"{ "key": value }"#),
            ("URL unquoted", #"{ "url": http://test.com }"#),
            
            // MISSING COMMAS
            ("Missing comma between object members", #"{ "a": 1 "b": 2 }"#),
            ("Missing comma between array elements", #"[ 1 2 3 ]"#),
            ("Missing comma in nested", #"{ "a": { "b": 1 "c": 2 } }"#),
            
            // MISSING COLONS
            ("Missing colon after key", #"{ "key" "value" }"#),
            ("Missing multiple colons", #"{ "a" 1, "b" 2 }"#),
            
            // EXTRA DELIMITERS
            ("Extra closing brace", #"{ "key": "value" }}"#),
            ("Extra closing bracket", #"[ 1, 2, 3 ]]"#),
            ("Trailing comma in object", #"{ "key": "value", }"#),
            ("Trailing comma in array", #"[ 1, 2, 3, ]"#),
            
            // WRONG DELIMITERS
            ("Brace closed with bracket", #"{ "key": "value" ]"#),
            ("Bracket closed with brace", #"[ 1, 2, 3 }"#),
            
            // UNTERMINATED STRINGS
            ("Unterminated key", #"{ "key: "value" }"#),
            ("Unterminated value", #"{ "key": "value }"#),
            ("Unterminated in nested", #"{ "a": { "b": "test } }"#),
            
            // INVALID VALUES
            ("Python True", #"{ "bool": True }"#),
            ("Python False", #"{ "bool": False }"#),
            ("Python None", #"{ "val": None }"#),
            ("JavaScript undefined", #"{ "val": undefined }"#),
            ("NaN value", #"{ "num": NaN }"#),
            ("Infinity value", #"{ "num": Infinity }"#),
            
            // SINGLE QUOTES
            ("Single quoted key", #"{ 'key': "value" }"#),
            ("Single quoted value", #"{ "key": 'value' }"#),
            ("All single quotes", #"{ 'key': 'value' }"#),
            
            // COMMENTS (invalid in JSON)
            ("C++ style comment", #"{ "key": "value" // comment }"#),
            ("C style comment", #"{ "key": /* comment */ "value" }"#),
            ("Hash comment", #"{ "key": "value" }"#),
            
            // COMPLEX REAL-WORLD CASES  
            ("Your exact GeoJSON case", #"{ "type": "Feature", "properties": { "name": "Waitrose } }"#),
            ("Missing bracket in coordinates", #"{ "geometry": { "coordinates": -0.1695, 51.4865] } }"#),
            ("Multiple nested issues", #"{ "user": { name": "John, "age: 25 } }"#),
            
            // EVERYTHING WRONG
            ("Maximum chaos", #"{ key1: value1 "key2 value2", key3": [1 2 3}, "key4": {nested: true }"#),
        ]
        
        var results = TestResults()
        
        for (index, test) in testSuite.enumerated() {
            print("\n" + "━" * 60)
            print("Test \(index + 1)/\(testSuite.count): \(test.0)")
            print("━" * 60)
            
            // First check if it's detected as invalid
            let initialErrors = await parser.validate(test.1)
            if initialErrors.isEmpty {
                print("⚠️ NOT detected as invalid JSON!")
                results.notDetected += 1
                continue
            }
            
            print("✅ Detected as invalid (\(initialErrors.count) errors)")
            
            // Try to fix it
            let fixResult = await fixer.fix(test.1)
            
            if fixResult.wasFixed {
                print("🔧 Fixes applied: \(fixResult.fixes.count)")
                for fix in fixResult.fixes.prefix(3) {
                    print("   • \(fix)")
                }
                if fixResult.fixes.count > 3 {
                    print("   ... and \(fixResult.fixes.count - 3) more")
                }
                
                // Validate fixed JSON
                let fixedErrors = await parser.validate(fixResult.fixed)
                
                if fixedErrors.isEmpty {
                    // Final check with JSONSerialization
                    if let data = fixResult.fixed.data(using: .utf8) {
                        do {
                            _ = try JSONSerialization.jsonObject(with: data, options: [])
                            print("✨ FULLY FIXED - Valid JSON!")
                            results.fullyFixed += 1
                        } catch {
                            print("⚠️ Parser says valid but JSONSerialization failed")
                            results.partiallyFixed += 1
                        }
                    }
                } else {
                    print("⚠️ Partially fixed - still has \(fixedErrors.count) errors")
                    results.partiallyFixed += 1
                }
            } else {
                print("❌ No fixes applied")
                results.notFixed += 1
            }
        }
        
        // Print summary
        print("\n" + "═" * 80)
        print("📊 ULTIMATE TEST RESULTS")
        print("═" * 80)
        print("Total test cases:     \(testSuite.count)")
        print("─" * 40)
        print("✅ Fully fixed:       \(results.fullyFixed) (\(results.percentage(results.fullyFixed))%)")
        print("⚠️ Partially fixed:   \(results.partiallyFixed) (\(results.percentage(results.partiallyFixed))%)")
        print("❌ Not fixed:         \(results.notFixed) (\(results.percentage(results.notFixed))%)")
        print("🚫 Not detected:      \(results.notDetected) (\(results.percentage(results.notDetected))%)")
        print("═" * 80)
        
        let successRate = (results.fullyFixed * 100) / testSuite.count
        if successRate >= 90 {
            print("🎉 EXCELLENT: \(successRate)% success rate!")
        } else if successRate >= 70 {
            print("👍 GOOD: \(successRate)% success rate")
        } else if successRate >= 50 {
            print("⚠️ NEEDS IMPROVEMENT: \(successRate)% success rate")
        } else {
            print("❌ POOR: \(successRate)% success rate")
        }
    }
    
    struct TestResults {
        var fullyFixed = 0
        var partiallyFixed = 0
        var notFixed = 0
        var notDetected = 0
        
        var total: Int {
            fullyFixed + partiallyFixed + notFixed + notDetected
        }
        
        func percentage(_ value: Int) -> Int {
            guard total > 0 else { return 0 }
            return (value * 100) / total
        }
    }
}

