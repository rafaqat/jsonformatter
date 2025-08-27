import Foundation
import JSONFormatterFeature

/// Property-based testing for JSON parser
/// Tests invariants that should hold for all inputs
struct PropertyBasedTests {
    
    // MARK: - Properties to Test
    
    /// Property 1: Idempotence - fixing twice produces same result
    static func testIdempotence() async {
        print("\n🔄 IDEMPOTENCE PROPERTY TEST")
        print(String(repeating: "-", count: 60))
        
        let fixer = JSONFixer()
        let testCases = generateRandomJSON(count: 100)
        var failures = 0
        
        for (index, json) in testCases.enumerated() {
            let result1 = await fixer.fix(json)
            let result2 = await fixer.fix(result1.fixed)
            
            if result1.fixed != result2.fixed {
                failures += 1
                print("❌ Idempotence failed for case \(index)")
                print("   Input: \(json.prefix(50))...")
                print("   First fix: \(result1.fixed.prefix(50))...")
                print("   Second fix: \(result2.fixed.prefix(50))...")
            }
        }
        
        if failures == 0 {
            print("✅ All \(testCases.count) cases passed idempotence test")
        } else {
            print("⚠️ \(failures)/\(testCases.count) cases failed idempotence")
        }
    }
    
    /// Property 2: Fixed output is always valid JSON
    static func testValidOutput() async {
        print("\n✓ VALID OUTPUT PROPERTY TEST")
        print(String(repeating: "-", count: 60))
        
        let fixer = JSONFixer()
        let parser = JSONParser()
        let testCases = generateMalformedJSON(count: 100)
        var failures = 0
        
        for (index, json) in testCases.enumerated() {
            let result = await fixer.fix(json)
            let errors = await parser.validate(result.fixed)
            
            if !errors.isEmpty {
                failures += 1
                print("❌ Invalid output for case \(index)")
                print("   Input: \(json.prefix(50))...")
                print("   Output: \(result.fixed.prefix(50))...")
                print("   Errors: \(errors)")
            }
        }
        
        if failures == 0 {
            print("✅ All \(testCases.count) fixed outputs are valid JSON")
        } else {
            print("⚠️ \(failures)/\(testCases.count) outputs were invalid")
        }
    }
    
    /// Property 3: Preservation - valid JSON remains unchanged (except formatting)
    static func testPreservation() async {
        print("\n🔒 PRESERVATION PROPERTY TEST")
        print(String(repeating: "-", count: 60))
        
        let fixer = JSONFixer()
        let validCases = [
            #"{"name": "test"}"#,
            "[1, 2, 3]",
            #"{"nested": {"key": "value"}}"#,
            "true",
            "false",
            "null",
            "123.456",
            #""simple string""#
        ]
        
        for json in validCases {
            let result = await fixer.fix(json)
            
            // Parse both to compare structure (ignoring whitespace)
            let original = try? JSONSerialization.jsonObject(with: json.data(using: .utf8)!)
            let fixed = try? JSONSerialization.jsonObject(with: result.fixed.data(using: .utf8)!)
            
            if !isEqual(original, fixed) {
                print("❌ Structure changed: \(json)")
                print("   Output: \(result.fixed)")
            } else {
                print("✅ Structure preserved: \(json)")
            }
        }
    }
    
    /// Property 4: Determinism - same input always produces same output
    static func testDeterminism() async {
        print("\n🎯 DETERMINISM PROPERTY TEST")
        print(String(repeating: "-", count: 60))
        
        let fixer = JSONFixer()
        let testCases = generateMalformedJSON(count: 50)
        var failures = 0
        
        for (index, json) in testCases.enumerated() {
            let results = await withTaskGroup(of: String.self) { group in
                // Run the same input 5 times in parallel
                for _ in 0..<5 {
                    group.addTask {
                        let result = await fixer.fix(json)
                        return result.fixed
                    }
                }
                
                var outputs: [String] = []
                for await output in group {
                    outputs.append(output)
                }
                return outputs
            }
            
            // Check all outputs are identical
            if Set(results).count > 1 {
                failures += 1
                print("❌ Non-deterministic output for case \(index)")
                print("   Input: \(json.prefix(50))...")
                print("   Different outputs: \(Set(results).count)")
            }
        }
        
        if failures == 0 {
            print("✅ All \(testCases.count) cases produced deterministic output")
        } else {
            print("⚠️ \(failures)/\(testCases.count) cases were non-deterministic")
        }
    }
    
    /// Property 5: Minimal changes - fixes should be minimal
    static func testMinimalChanges() async {
        print("\n📏 MINIMAL CHANGES PROPERTY TEST")
        print(String(repeating: "-", count: 60))
        
        let fixer = JSONFixer()
        let testCases = [
            (#"{"a":+123}"#, #"{"a":123}"#),           // Only remove +
            (#"{"b":.5}"#, #"{"b":0.5}"#),            // Only add 0
            (#"{"c":TRUE}"#, #"{"c":true}"#),         // Only lowercase
            (#"[1 2]"#, "[1, 2]"),                    // Only add comma
            (#"{"d" 1}"#, #"{"d": 1}"#),              // Only add colon
        ]
        
        for (input, _) in testCases {
            let result = await fixer.fix(input)
            
            // Calculate edit distance (simplified)
            let distance = editDistance(input, result.fixed)
            
            print("Input: \(input)")
            print("Output: \(result.fixed)")
            print("Edit distance: \(distance)")
            print(distance <= 5 ? "✅ Minimal change" : "⚠️ Large change")
        }
    }
    
    // MARK: - Fuzzing
    
    /// Fuzz testing with random inputs
    static func fuzzTest() async {
        print("\n🎲 FUZZ TESTING")
        print(String(repeating: "-", count: 60))
        
        let fixer = JSONFixer()
        let parser = JSONParser()
        var successes = 0
        var failures = 0
        
        for _ in 0..<100 {
            let fuzzInput = generateFuzzInput()
            
            let result = await fixer.fix(fuzzInput)
            let errors = await parser.validate(result.fixed)
            
            if errors.isEmpty {
                successes += 1
            } else {
                failures += 1
            }
        }
        
        print("\nFuzz Results:")
        print("✅ Successful: \(successes)")
        print("❌ Failed validation: \(failures)")
    }
    
    // MARK: - Test Data Generators
    
    static func generateRandomJSON(count: Int) -> [String] {
        var results: [String] = []
        
        for _ in 0..<count {
            let depth = Int.random(in: 1...3)
            results.append(generateJSON(depth: depth))
        }
        
        return results
    }
    
    static func generateMalformedJSON(count: Int) -> [String] {
        let mutations = [
            { (s: String) in s.replacingOccurrences(of: ":", with: "") },      // Remove colons
            { (s: String) in s.replacingOccurrences(of: ",", with: "") },      // Remove commas
            { (s: String) in s.replacingOccurrences(of: "\"", with: "'") },    // Single quotes
            { (s: String) in s.replacingOccurrences(of: "true", with: "TRUE") }, // Uppercase
            { (s: String) in "+\(s)" },                                         // Add plus
            { (s: String) in s.replacingOccurrences(of: "}", with: "") },      // Remove close
            { (s: String) in s.replacingOccurrences(of: "]", with: "") },      // Remove close
        ]
        
        var results: [String] = []
        let validJSON = generateRandomJSON(count: count)
        
        for json in validJSON {
            let mutation = mutations.randomElement()!
            results.append(mutation(json))
        }
        
        return results
    }
    
    static func generateJSON(depth: Int) -> String {
        if depth <= 0 {
            // Leaf values
            switch Int.random(in: 0...4) {
            case 0: return String(Int.random(in: -100...100))
            case 1: return String(Double.random(in: -100...100))
            case 2: return Bool.random() ? "true" : "false"
            case 3: return "null"
            default: return #""string\(Int.random(in: 0...100))""#
            }
        }
        
        if Bool.random() {
            // Generate object
            let keyCount = Int.random(in: 1...3)
            var members: [String] = []
            for i in 0..<keyCount {
                let key = #""key\(i)""#
                let value = generateJSON(depth: depth - 1)
                members.append("\(key): \(value)")
            }
            return "{\(members.joined(separator: ", "))}"
        } else {
            // Generate array
            let elementCount = Int.random(in: 1...3)
            var elements: [String] = []
            for _ in 0..<elementCount {
                elements.append(generateJSON(depth: depth - 1))
            }
            return "[\(elements.joined(separator: ", "))]"
        }
    }
    
    static func generateFuzzInput() -> String {
        let chars = "{}[],:\"'0123456789truefalselnul+-.e \n\t"
        let length = Int.random(in: 1...100)
        return String((0..<length).map { _ in chars.randomElement()! })
    }
    
    // MARK: - Helpers
    
    static func isEqual(_ a: Any?, _ b: Any?) -> Bool {
        if let dictA = a as? [String: Any], let dictB = b as? [String: Any] {
            return NSDictionary(dictionary: dictA).isEqual(to: dictB)
        }
        if let arrayA = a as? [Any], let arrayB = b as? [Any] {
            return NSArray(array: arrayA).isEqual(to: arrayB)
        }
        if let numA = a as? NSNumber, let numB = b as? NSNumber {
            return numA == numB
        }
        if let strA = a as? String, let strB = b as? String {
            return strA == strB
        }
        return false
    }
    
    static func editDistance(_ s1: String, _ s2: String) -> Int {
        let len1 = s1.count
        let len2 = s2.count
        
        if len1 == 0 { return len2 }
        if len2 == 0 { return len1 }
        
        // Simple character difference count (not true Levenshtein)
        var distance = abs(len1 - len2)
        for (c1, c2) in zip(s1, s2) {
            if c1 != c2 {
                distance += 1
            }
        }
        
        return distance
    }
    
    // Run all property tests
    static func runAll() async {
        print("🧪 PROPERTY-BASED TESTING")
        print(String(repeating: "=", count: 80))
        
        await testIdempotence()
        await testValidOutput()
        await testPreservation()
        await testDeterminism()
        await testMinimalChanges()
        await fuzzTest()
        
        print("\n" + String(repeating: "=", count: 80))
        print("Property-based testing complete")
    }
}


