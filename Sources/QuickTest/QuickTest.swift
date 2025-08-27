import Foundation
import JSONFormatterFeature

@main
@MainActor
struct QuickTest {
    static func main() async {
        let fixer = JSONFixer()
        
        let tests: [(name: String, input: String, shouldContain: [String])] = [
            // Number normalization
            ("Leading plus", #"{"n": +123}"#, ["123"]),
            ("Leading zeros", #"{"n": 00123}"#, ["123"]),
            ("Bare decimal", #"{"n": .5}"#, ["0.5"]),
            ("Trailing decimal", #"{"n": 42.}"#, ["42.0"]),
            
            // Literal normalization  
            ("TRUE to true", #"{"a": TRUE}"#, ["true"]),
            ("FALSE to false", #"{"a": FALSE}"#, ["false"]),
            ("NULL to null", #"{"a": NULL}"#, ["null"]),
            ("Partial tru", #"{"a": tru}"#, ["true"]),
            ("Spaced tr ue", #"{"a": tr ue}"#, ["true"])
        ]
        
        print("Quick test of fixes:")
        print(String(repeating: "-", count: 40))
        
        var passed = 0
        for test in tests {
            let result = await fixer.fix(test.input)
            let allFound = test.shouldContain.allSatisfy { result.fixed.contains($0) }
            
            if allFound {
                print("✅ \(test.name)")
                passed += 1
            } else {
                print("❌ \(test.name)")
                print("   Expected: \(test.shouldContain)")
                print("   Got: \(result.fixed)")
            }
        }
        
        print(String(repeating: "=", count: 40))
        print("Results: \(passed)/\(tests.count) passed")
    }
}