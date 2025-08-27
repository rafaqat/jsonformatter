import Foundation
import JSONFormatterFeature

@main
struct ExtendedTestRunner {
    static func main() async {
        print("=" * 80)
        print("🧪 EXTENDED JSON TEST SUITE")
        print("=" * 80)
        
        let fixer = JSONFixer()
        let parser = JSONParser()
        
        var passed = 0
        var failed = 0
        var categoryResults: [String: (passed: Int, failed: Int)] = [:]
        
        // Run all extended tests
        for testCase in ExtendedTestCases.allExtendedTests {
            print("\n📝 Testing: \(testCase.name)")
            print("   Category: \(testCase.category)")
            
            do {
                // Test the fix
                let fixResult = await fixer.fix(testCase.input)
                
                // Check if fixes were applied when expected
                var testPassed = true
                var failureReasons: [String] = []
                
                // Check expected fixes
                for expectedFix in testCase.expectedFixes {
                    let foundFix = fixResult.fixes.contains { fix in
                        fix.lowercased().contains(expectedFix.lowercased())
                    }
                    if !foundFix && !testCase.expectedFixes.isEmpty {
                        testPassed = false
                        failureReasons.append("Missing expected fix: '\(expectedFix)'")
                    }
                }
                
                // Check forbidden strings
                for forbidden in testCase.forbiddenInOutput {
                    if fixResult.fixed.contains(forbidden) {
                        testPassed = false
                        failureReasons.append("Found forbidden string: '\(forbidden)'")
                    }
                }
                
                // Check preserved strings
                for preserved in testCase.preserveExact {
                    if !fixResult.fixed.contains(preserved) {
                        testPassed = false
                        failureReasons.append("Missing preserved string: '\(preserved)'")
                    }
                }
                
                // Validate if should be valid
                if testCase.shouldBeValid {
                    let errors = await parser.validate(fixResult.fixed)
                    if !errors.isEmpty {
                        testPassed = false
                        failureReasons.append("Validation errors: \(errors.map { $0.message })")
                    }
                }
                
                // Test idempotence
                let secondFix = await fixer.fix(fixResult.fixed)
                if secondFix.wasFixed && secondFix.fixed != fixResult.fixed {
                    testPassed = false
                    failureReasons.append("Not idempotent - second fix changed output")
                }
                
                if testPassed {
                    print("   ✅ PASSED")
                    passed += 1
                    categoryResults[testCase.category, default: (0, 0)].passed += 1
                } else {
                    print("   ❌ FAILED")
                    for reason in failureReasons {
                        print("      - \(reason)")
                    }
                    failed += 1
                    categoryResults[testCase.category, default: (0, 0)].failed += 1
                    
                    // Show the actual output for debugging
                    if failed <= 3 {  // Only show first 3 failures in detail
                        print("      Input:  \(testCase.input)")
                        print("      Output: \(fixResult.fixed)")
                        print("      Fixes:  \(fixResult.fixes)")
                    }
                }
                
            } catch {
                print("   ❌ ERROR: \(error)")
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
            print("\(category.capitalized): \(results.passed)/\(total) passed (\(percentage)%)")
        }
        
        // Overall summary
        print("\n" + "=" * 80)
        print("📈 OVERALL RESULTS")
        print("=" * 80)
        
        let total = passed + failed
        let percentage = passed * 100 / max(total, 1)
        print("Total: \(passed)/\(total) tests passed (\(percentage)%)")
        
        if failed > 0 {
            print("⚠️  \(failed) tests failed - see details above")
        } else {
            print("🎉 All tests passed!")
        }
        
        // Performance test
        print("\n" + "=" * 80)
        print("⚡ PERFORMANCE TEST")
        print("=" * 80)
        
        // Test with increasingly large documents
        for size in [100, 1000, 10000] {
            let largeJSON = ExtendedTestCases.generateLargeJSON(nodes: size, errorRate: 0.01)
            let start = Date()
            let result = await fixer.fix(largeJSON)
            let elapsed = Date().timeIntervalSince(start)
            
            print("Size: \(size) nodes, Time: \(String(format: "%.3f", elapsed))s, Fixes: \(result.fixes.count)")
            
            if elapsed > 1.0 && size < 10000 {
                print("   ⚠️ Performance warning: took > 1s for \(size) nodes")
            }
        }
        
        print("\n" + "=" * 80)
        print("✅ Extended test suite complete")
        print("=" * 80)
    }
}

// Helper extension
extension String {
    static func *(lhs: String, rhs: Int) -> String {
        String(repeating: lhs, count: rhs)
    }
}