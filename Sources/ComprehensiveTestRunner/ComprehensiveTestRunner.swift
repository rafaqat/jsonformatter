import Foundation
import JSONFormatterFeature

@main
@MainActor
struct ComprehensiveTestRunner {
    @MainActor
    static func main() async {
        print("🚀 Starting Comprehensive JSON Test Suite")
        print("Testing with granular fix validation and idempotence checks\n")
        
        // Run the core 25 test cases with full validation
        await JSONAutoFixRunner.runCoreTestSuite()
        
        // Also run against the full consolidated test suite if desired
        await runFullTestSuite()
    }
    
    static func runFullTestSuite() async {
        print("\n" + "=" * 80)
        print("📚 RUNNING FULL TEST SUITE (200+ cases)")
        print("=" * 80)
        
        // Convert JSONTestCases to runner format
        let cases = JSONTestCases.allTests.map { testCase in
            JSONAutoFixRunner.TestCaseWithExpectations(
                name: testCase.name,
                input: testCase.input,
                expectedValid: testCase.shouldBeValid,
                expectFixKinds: testCase.expectedFixes,
                forbiddenInOutput: testCase.forbiddenInOutput,
                preserveExact: testCase.preserveExact,
                requireIdempotence: true  // Test idempotence for all
            )
        }
        
        let results = await JSONAutoFixRunner.runCases(cases)
        
        // Detailed analysis
        analyzeResults(results, cases: cases)
    }
    
    static func analyzeResults(_ results: [JSONAutoFixRunner.TestResult], 
                               cases: [JSONAutoFixRunner.TestCaseWithExpectations]) {
        // Group by category for analysis
        var categoryStats: [String: (passed: Int, failed: Int, slowest: Int)] = [:]
        
        for (index, result) in results.enumerated() {
            let category = extractCategory(from: cases[index].name)
            var stats = categoryStats[category] ?? (0, 0, 0)
            
            if result.passed {
                stats.passed += 1
            } else {
                stats.failed += 1
            }
            stats.slowest = max(stats.slowest, result.timeMs)
            
            categoryStats[category] = stats
        }
        
        print("\n📊 DETAILED CATEGORY ANALYSIS")
        print("-" * 60)
        
        for (category, stats) in categoryStats.sorted(by: { $0.key < $1.key }) {
            let total = stats.passed + stats.failed
            let percentage = stats.passed * 100 / max(total, 1)
            let bar = progressBar(percentage: percentage, width: 20)
            
            print("\(category.padding(toLength: 12, withPad: " ", startingAt: 0)) \(bar) \(stats.passed)/\(total) (\(percentage)%) | Max: \(stats.slowest)ms")
        }
        
        // Find problem areas
        let problemAreas = results.enumerated().compactMap { index, result -> (String, [String])? in
            if !result.passed {
                return (cases[index].name, result.failureReasons)
            }
            return nil
        }
        
        if !problemAreas.isEmpty {
            print("\n⚠️ PROBLEM AREAS (\(problemAreas.count) failures)")
            print("-" * 60)
            
            // Group by failure type
            var failureTypes: [String: Int] = [:]
            for (_, reasons) in problemAreas {
                for reason in reasons {
                    if reason.contains("Missing expected fix") {
                        failureTypes["Missing fixes", default: 0] += 1
                    } else if reason.contains("forbidden") {
                        failureTypes["Forbidden output", default: 0] += 1
                    } else if reason.contains("preserved") {
                        failureTypes["Not preserved", default: 0] += 1
                    } else if reason.contains("idempotent") {
                        failureTypes["Not idempotent", default: 0] += 1
                    } else if reason.contains("valid") {
                        failureTypes["Validation", default: 0] += 1
                    }
                }
            }
            
            for (type, count) in failureTypes.sorted(by: { $0.value > $1.value }) {
                print("   • \(type): \(count) occurrences")
            }
        }
        
        // Performance summary
        let times = results.map { $0.timeMs }
        let avgTime = times.reduce(0, +) / max(times.count, 1)
        let maxTime = times.max() ?? 0
        
        print("\n⚡ PERFORMANCE")
        print("-" * 60)
        print("Average: \(avgTime)ms | Max: \(maxTime)ms")
        
        if maxTime > 500 {
            print("⚠️ Some tests exceed 500ms - consider optimization")
        }
        
        // Idempotence check
        let nonIdempotent = results.filter { !$0.idempotent }
        if !nonIdempotent.isEmpty {
            print("\n🔄 IDEMPOTENCE FAILURES: \(nonIdempotent.count)")
            for result in nonIdempotent.prefix(5) {
                print("   • \(result.name)")
            }
        }
    }
    
    static func extractCategory(from name: String) -> String {
        let lowercased = name.lowercased()
        if lowercased.contains("unicode") || lowercased.contains("escape") || lowercased.contains("surrogate") {
            return "Unicode"
        } else if lowercased.contains("number") || lowercased.contains("decimal") || lowercased.contains("hex") || lowercased.contains("octal") {
            return "Numbers"
        } else if lowercased.contains("literal") || lowercased.contains("true") || lowercased.contains("false") || lowercased.contains("null") {
            return "Literals"
        } else if lowercased.contains("bracket") || lowercased.contains("brace") || lowercased.contains("comma") || lowercased.contains("colon") {
            return "Delimiters"
        } else if lowercased.contains("multi") || lowercased.contains("ndjson") || lowercased.contains("trailing") {
            return "Multi-root"
        } else if lowercased.contains("quote") || lowercased.contains("string") {
            return "Strings"
        } else if lowercased.contains("key") || lowercased.contains("duplicate") || lowercased.contains("whitespace") {
            return "Semantics"
        } else {
            return "Other"
        }
    }
    
    static func progressBar(percentage: Int, width: Int = 20) -> String {
        let filled = min(width, percentage * width / 100)
        let empty = width - filled
        return "[" + String(repeating: "█", count: filled) + String(repeating: "░", count: empty) + "]"
    }
}

private extension String {
    static func *(lhs: String, rhs: Int) -> String {
        String(repeating: lhs, count: rhs)
    }
}