import Foundation
import JSONFormatterFeature

@main
struct MinimalTest {
    static func main() async {
        print("Creating JSONFixer...")
        let fixer = JSONFixer()
        print("JSONFixer created")
        
        print("Testing simple input...")
        let input = #"{"n": 123}"#
        print("Input: \(input)")
        
        print("Starting fix operation...")
        let result = await fixer.fix(input)
        print("Fix completed: \(result.fixed)")
        print("✅ Completed successfully")
        
        print("\nTesting problem cases...")
        
        let tests = [
            ("+123", "123"),
            (".5", "0.5"),
            ("TRUE", "true")
        ]
        
        for (test, expected) in tests {
            let testInput = #"{"test": \#(test)}"#
            let fixed = await fixer.fix(testInput)
            let passed = fixed.fixed.contains(expected)
            print("\(passed ? "✅" : "❌") \(test) -> \(expected) | Got: \(fixed.fixed)")
        }
        
        print("\nDone")
    }
}