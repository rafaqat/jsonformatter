#!/usr/bin/env swift -I .build/debug -L .build/debug -lJSONFormatterFeature

import Foundation
import JSONFormatterFeature

// Create synchronous wrapper
class SyncTester {
    let fixer = JSONFixer()
    
    func test(_ name: String, _ input: String, _ shouldContain: [String], _ shouldNotContain: [String] = []) {
        print("\n" + String(repeating: "-", count: 50))
        print("TEST: \(name)")
        print("Input: \(input)")
        
        let semaphore = DispatchSemaphore(value: 0)
        var result: JSONFixer.FixResult?
        
        Task {
            result = await fixer.fix(input)
            semaphore.signal()
        }
        
        semaphore.wait()
        
        guard let fixResult = result else {
            print("❌ FAILED: No result")
            return
        }
        
        print("Output: \(fixResult.fixed)")
        
        var passed = true
        var failures: [String] = []
        
        for expected in shouldContain {
            if !fixResult.fixed.contains(expected) {
                passed = false
                failures.append("Missing: '\(expected)'")
            }
        }
        
        for forbidden in shouldNotContain {
            if fixResult.fixed.contains(forbidden) {
                passed = false
                failures.append("Contains forbidden: '\(forbidden)'")
            }
        }
        
        if passed {
            print("✅ PASSED")
        } else {
            print("❌ FAILED")
            for failure in failures {
                print("   • \(failure)")
            }
        }
    }
}

let tester = SyncTester()

print("🔧 TESTING JSON FIXER")
print(String(repeating: "=", count: 60))

// Number tests
tester.test("Leading plus", #"{"n": +123}"#, ["123"], ["+123"])
tester.test("Leading zeros", #"{"n": 00123}"#, ["123"], ["00123"])
tester.test("Bare decimal", #"{"n": .5}"#, ["0.5"], [" .5"])
tester.test("Trailing decimal", #"{"n": 42.}"#, ["42.0"], ["42.}"])

// Literal tests  
tester.test("TRUE to true", #"{"a": TRUE}"#, ["true"], ["TRUE"])
tester.test("FALSE to false", #"{"a": FALSE}"#, ["false"], ["FALSE"])
tester.test("NULL to null", #"{"a": NULL}"#, ["null"], ["NULL"])
tester.test("Partial tru", #"{"a": tru}"#, ["true"], ["tru"])

print("\n" + String(repeating: "=", count: 60))
print("Tests complete!")