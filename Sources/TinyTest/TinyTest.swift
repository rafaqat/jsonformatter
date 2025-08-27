import Foundation
import JSONFormatterFeature

@main
struct TinyTest {
    static func main() {
        print("Starting tiny test...")
        
        // Test without async
        let input = #"{"n": +123}"#
        print("Input: \(input)")
        
        // Just tokenize
        let fixer = JSONFixer()
        print("Created fixer")
        
        // Try to parse synchronously
        print("Test complete")
    }
}