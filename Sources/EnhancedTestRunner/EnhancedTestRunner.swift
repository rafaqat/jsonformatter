import Foundation
import JSONFormatterFeature

@main
struct EnhancedTestRunner {
    static func main() async {
        print("=" * 80)
        print("🚀 ENHANCED JSON PARSER TEST")
        print("=" * 80)
        
        let enhancedFixer = JSONFixer()
        let parser = JSONParser()
        
        var passed = 0
        var failed = 0
        var categoryResults: [String: (passed: Int, failed: Int)] = [:]
        
        // Run all extended tests
        for testCase in ExtendedTestCases.allExtendedTests {
            let result = await runTest(testCase, fixer: enhancedFixer, parser: parser)
            
            if result {
                passed += 1
                categoryResults[testCase.category, default: (0, 0)].passed += 1
            } else {
                failed += 1
                categoryResults[testCase.category, default: (0, 0)].failed += 1
            }
        }
        
        // Summary by category
        print("\n" + "=" * 80)
        print("📊 RESULTS BY CATEGORY")
        print("=" * 80)
        
        for (category, results) in categoryResults.sorted(by: { $0.key < $1.key }) {
            let total = results.passed + results.failed
            let percentage = results.passed * 100 / max(total, 1)
            let bar = progressBar(percentage: percentage)
            print("\(category.capitalized.padding(toLength: 12, withPad: " ", startingAt: 0)) \(bar) \(results.passed)/\(total) (\(percentage)%)")
        }
        
        // Overall summary
        print("\n" + "=" * 80)
        print("📈 OVERALL RESULTS")
        print("=" * 80)
        
        let total = passed + failed
        let percentage = passed * 100 / max(total, 1)
        let improvement = percentage - 23  // Previous was 23%
        
        print("Total: \(passed)/\(total) tests passed (\(percentage)%)")
        
        if improvement > 0 {
            print("📈 Improvement: +\(improvement)% from baseline (23%)")
        }
        
        if percentage >= 85 {
            print("🎯 Target achieved! (>85%)")
        } else if percentage >= 55 {
            print("📊 Good progress (target: 85%)")
        }
        
        if failed > 0 {
            print("⚠️  \(failed) tests still failing")
        } else {
            print("🎉 All tests passed!")
        }
        
        // Performance test
        print("\n" + "=" * 80)
        print("⚡ PERFORMANCE TEST")
        print("=" * 80)
        
        for size in [100, 1000, 10000] {
            let largeJSON = ExtendedTestCases.generateLargeJSON(nodes: size, errorRate: 0.01)
            let start = Date()
            let result = await enhancedFixer.fix(largeJSON)
            let elapsed = Date().timeIntervalSince(start)
            
            print("Size: \(String(format: "%6d", size)) nodes | Time: \(String(format: "%.3f", elapsed))s | Fixes: \(result.fixes.count)")
            
            if elapsed > 0.5 && size <= 10000 {
                print("   ⚠️ Performance warning: took > 0.5s")
            }
        }
        
        // Idempotence test
        print("\n" + "=" * 80)
        print("🔄 IDEMPOTENCE TEST")
        print("=" * 80)
        
        let idempotenceTests = [
            "{\"a\": 1 \"b\": 2}",  // Missing comma
            "{unquoted: true}",      // Unquoted key
            "{\"num\": .5}",         // Bare decimal
            "[1, 2, 3}",            // Cross-type closure
            "{\"coordinates\": -0.1695, 51.4865]}"  // Missing bracket
        ]
        
        var idempotentCount = 0
        for test in idempotenceTests {
            let first = await enhancedFixer.fix(test)
            let second = await enhancedFixer.fix(first.fixed)
            
            if first.fixed == second.fixed && !second.wasFixed {
                idempotentCount += 1
                print("✅ Idempotent: \(test.prefix(30))...")
            } else {
                print("❌ Not idempotent: \(test)")
            }
        }
        
        print("\nIdempotence: \(idempotentCount)/\(idempotenceTests.count) tests passed")
        
        print("\n" + "=" * 80)
        print("✅ Enhanced parser test complete")
        print("=" * 80)
    }
    
    static func runTest(_ testCase: ExtendedTestCases.ExtendedTestCase, 
                       fixer: JSONFixer,
                       parser: JSONParser) async -> Bool {
        
        print("\n📝 \(testCase.name)")
        
        let fixResult = await fixer.fix(testCase.input)
        var testPassed = true
        var failureReasons: [String] = []
        
        // Check expected fixes
        for expectedFix in testCase.expectedFixes {
            let foundFix = fixResult.fixes.contains { fix in
                fix.lowercased().contains(expectedFix.lowercased())
            } || fixResult.detailedFixes.contains { fix in
                fix.lowercased().contains(expectedFix.lowercased())
            }
            
            if !foundFix && !testCase.expectedFixes.isEmpty {
                testPassed = false
                failureReasons.append("Missing fix: '\(expectedFix)'")
            }
        }
        
        // Check forbidden strings
        for forbidden in testCase.forbiddenInOutput {
            if fixResult.fixed.contains(forbidden) {
                testPassed = false
                failureReasons.append("Contains forbidden: '\(forbidden)'")
            }
        }
        
        // Check preserved strings
        for preserved in testCase.preserveExact {
            if !fixResult.fixed.contains(preserved) {
                testPassed = false
                failureReasons.append("Missing preserved: '\(preserved)'")
            }
        }
        
        // Validate if should be valid
        if testCase.shouldBeValid {
            let errors = await parser.validate(fixResult.fixed)
            if !errors.isEmpty {
                testPassed = false
                failureReasons.append("Invalid: \(errors.first?.message ?? "unknown")")
            }
        }
        
        if testPassed {
            print("   ✅ PASSED")
        } else {
            print("   ❌ FAILED: \(failureReasons.joined(separator: ", "))")
            if failureReasons.count <= 2 {
                print("      Input:  \(testCase.input)")
                print("      Output: \(fixResult.fixed.replacingOccurrences(of: "\n", with: "\\n"))")
            }
        }
        
        return testPassed
    }
    
    static func progressBar(percentage: Int, width: Int = 20) -> String {
        let filled = percentage * width / 100
        let empty = width - filled
        let bar = String(repeating: "█", count: filled) + String(repeating: "░", count: empty)
        return "[\(bar)]"
    }
}

// Helper extensions
extension String {
    static func *(lhs: String, rhs: Int) -> String {
        String(repeating: lhs, count: rhs)
    }
}