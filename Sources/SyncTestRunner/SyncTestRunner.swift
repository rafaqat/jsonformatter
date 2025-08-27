import Foundation
import JSONFormatterFeature

@main
struct SyncTestRunner {
    static func main() {
        print("🔧 SYNCHRONOUS TEST RUNNER")
        print(String(repeating: "=", count: 60))
        
        let group = DispatchGroup()
        let fixer = JSONFixer()
        
        // Test cases
        let tests: [(name: String, input: String, shouldContain: [String], shouldNotContain: [String])] = [
            // Numbers
            ("Leading plus", #"{"n": +123}"#, ["123"], ["+123"]),
            ("Leading zeros", #"{"n": 00123}"#, ["123"], ["00123"]),
            ("Bare decimal", #"{"n": .5}"#, ["0.5"], [".5"]),
            ("Trailing decimal", #"{"n": 42.}"#, ["42.0"], ["42."]),
            ("Hex number", #"{"hex": 0xFF}"#, ["255"], ["0xFF", "0x"]),
            ("Octal number", #"{"oct": 0755}"#, ["493"], ["0755"]),
            
            // Literals
            ("TRUE to true", #"{"a": TRUE}"#, ["true"], ["TRUE"]),
            ("FALSE to false", #"{"a": FALSE}"#, ["false"], ["FALSE"]),
            ("NULL to null", #"{"a": NULL}"#, ["null"], ["NULL"]),
            ("Partial tru", #"{"a": tru}"#, ["true"], ["tru"]),
            ("Partial fals", #"{"a": fals}"#, ["false"], ["fals"]),
            ("Partial nul", #"{"a": nul}"#, ["null"], ["nul"]),
            ("Spaced tr ue", #"{"a": tr ue}"#, ["true"], ["tr ue"]),
            ("Spaced nu ll", #"{"a": nu ll}"#, ["null"], ["nu ll"]),
            
            // Structure
            ("Missing comma", #"{"a":1 "b":2}"#, ["1", ",", "2"], []),
            ("Missing colon", #"{"a" 1}"#, [":", "1"], []),
            
            // Strings
            ("Invalid escape \\x", #"{"s":"test\x"}"#, [], [#"\x"#]),
            ("Invalid escape \\8", #"{"s":"test\8"}"#, [], [#"\8"#]),
            
            // Multi-root
            ("NDJSON", "{\"a\":1}\n{\"b\":2}", ["[", "]"], [])
        ]
        
        var passCount = 0
        
        for test in tests {
            print("\n" + String(repeating: "-", count: 50))
            print("TEST: \(test.name)")
            print("Input: \(test.input)")
            
            group.enter()
            var result: JSONFixer.FixResult?
            
            Task {
                result = await fixer.fix(test.input)
                group.leave()
            }
            
            _ = group.wait(timeout: .now() + 2)
            
            guard let fixResult = result else {
                print("❌ FAILED: Timeout or no result")
                continue
            }
            
            print("Output: \(fixResult.fixed)")
            
            var passed = true
            var failures: [String] = []
            
            for expected in test.shouldContain {
                if !fixResult.fixed.contains(expected) {
                    passed = false
                    failures.append("Missing: '\(expected)'")
                }
            }
            
            for forbidden in test.shouldNotContain {
                if fixResult.fixed.contains(forbidden) {
                    passed = false
                    failures.append("Contains forbidden: '\(forbidden)'")
                }
            }
            
            if passed {
                print("✅ PASSED")
                passCount += 1
            } else {
                print("❌ FAILED")
                for failure in failures {
                    print("   • \(failure)")
                }
            }
            
            if !fixResult.fixes.isEmpty {
                print("Fixes: \(fixResult.fixes.count) applied")
            }
        }
        
        print("\n" + String(repeating: "=", count: 60))
        print("SUMMARY: \(passCount)/\(tests.count) tests passed")
        print(String(repeating: "=", count: 60))
    }
}