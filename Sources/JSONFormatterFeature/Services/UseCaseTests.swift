import Foundation

/// Comprehensive use case tests for JSON autofix functionality
@MainActor
public class UseCaseTests {
    
    struct TestCase {
        let name: String
        let input: String
        let expectedValid: Bool
        let description: String
    }
    
    public static func runAllTests() async {
        print("=" * 80)
        print("🧪 JSON AUTOFIX USE CASE TESTS")
        print("=" * 80)
        
        let testCases = [
            // Missing opening bracket
            TestCase(
                name: "Missing opening bracket [",
                input: """
                {
                  "type": "Feature",
                  "geometry": {
                    "type": "Point",
                    "coordinates": -0.1695, 51.4865]
                  }
                }
                """,
                expectedValid: true,
                description: "Array missing opening bracket with closing bracket present"
            ),
            
            // Missing closing bracket
            TestCase(
                name: "Missing closing bracket ]",
                input: """
                {
                  "type": "Feature",
                  "geometry": {
                    "type": "Point",
                    "coordinates": [-0.1695, 51.4865
                  }
                }
                """,
                expectedValid: true,
                description: "Array missing closing bracket"
            ),
            
            // Missing comma between object members
            TestCase(
                name: "Missing comma in object",
                input: """
                {
                  "name": "Test"
                  "age": 25
                  "city": "London"
                }
                """,
                expectedValid: true,
                description: "Object members missing commas"
            ),
            
            // Missing comma between array elements
            TestCase(
                name: "Missing comma in array",
                input: """
                {
                  "numbers": [1 2 3 4 5],
                  "values": [10, 20 30, 40]
                }
                """,
                expectedValid: true,
                description: "Array elements missing commas"
            ),
            
            // Trailing commas
            TestCase(
                name: "Trailing commas",
                input: """
                {
                  "items": [1, 2, 3,],
                  "data": {
                    "x": 10,
                    "y": 20,
                  },
                }
                """,
                expectedValid: true,
                description: "Trailing commas in arrays and objects"
            ),
            
            // Unquoted keys
            TestCase(
                name: "Unquoted object keys",
                input: """
                {
                  name: "John",
                  age: 30,
                  city: "New York"
                }
                """,
                expectedValid: true,
                description: "Object keys without quotes"
            ),
            
            // Single quotes instead of double
            TestCase(
                name: "Single quotes",
                input: """
                {
                  'name': 'Alice',
                  'location': 'Wonderland'
                }
                """,
                expectedValid: true,
                description: "Single quotes instead of double quotes"
            ),
            
            // Smart quotes
            TestCase(
                name: "Smart quotes",
                input: """
                {
                  "name": "Bob",
                  "description": "Bob's place"
                }
                """,
                expectedValid: true,
                description: "Smart quotes that need conversion"
            ),
            
            // Comments in JSON
            TestCase(
                name: "Comments",
                input: """
                {
                  // This is a comment
                  "name": "Test", // inline comment
                  /* Multi-line
                     comment */
                  "value": 123
                }
                """,
                expectedValid: true,
                description: "JavaScript-style comments in JSON"
            ),
            
            // Missing both brackets on coordinates
            TestCase(
                name: "Missing both brackets",
                input: """
                {
                  "location": {
                    "coordinates": 10.5, 20.3
                  }
                }
                """,
                expectedValid: true,
                description: "Coordinates without any brackets"
            ),
            
            // Wrong bracket type
            TestCase(
                name: "Wrong bracket type",
                input: """
                {
                  "array": [1, 2, 3},
                  "object": {"a": 1]
                }
                """,
                expectedValid: true,
                description: "Arrays/objects with wrong closing bracket type"
            ),
            
            // Complex nested missing brackets
            TestCase(
                name: "Complex nested structure",
                input: """
                {
                  "features": [
                    {
                      "type": "Feature"
                      "properties": {
                        "name": "Place1"
                      },
                      "geometry": {
                        "coordinates": -1.5, 50.0]
                      }
                    },
                    {
                      "type": "Feature",
                      "properties": {
                        "name": "Place2"
                      },
                      "geometry": {
                        "coordinates": [2.5, 48.0
                      }
                    }
                  ]
                }
                """,
                expectedValid: true,
                description: "Complex nested structure with multiple errors"
            ),
            
            // Missing closing brace
            TestCase(
                name: "Missing closing brace }",
                input: """
                {
                  "data": {
                    "value": 100,
                    "status": "ok"
                }
                """,
                expectedValid: true,
                description: "Object missing closing brace"
            ),
            
            // Extra closing brackets
            TestCase(
                name: "Extra closing brackets",
                input: """
                {
                  "array": [1, 2, 3]],
                  "value": 5
                }
                """,
                expectedValid: true,
                description: "Extra closing bracket in array"
            ),
            
            // Numbers with leading zeros
            TestCase(
                name: "Leading zeros",
                input: """
                {
                  "values": [001, 002, 003],
                  "price": 00123.45
                }
                """,
                expectedValid: true,
                description: "Numbers with leading zeros"
            ),
            
            // Unterminated string
            TestCase(
                name: "Unterminated string",
                input: """
                {
                  "message": "Hello world,
                  "status": "ok"
                }
                """,
                expectedValid: true,
                description: "String missing closing quote"
            ),
            
            // Invalid escape sequences
            TestCase(
                name: "Invalid escapes",
                input: """
                {
                  "path": "C:\\Users\\test\\file.txt",
                  "regex": "\\d+\\w+"
                }
                """,
                expectedValid: true,
                description: "Invalid escape sequences"
            ),
            
            // Mixed issues
            TestCase(
                name: "Multiple mixed issues",
                input: """
                {
                  name: 'Test User'
                  "coordinates": -0.5, 51.5],
                  tags: ["one", "two" "three"],
                  "active": true,
                }
                """,
                expectedValid: true,
                description: "Multiple different issues in one JSON"
            ),
            
            // Empty edge cases
            TestCase(
                name: "Empty structures",
                input: """
                {
                  "empty_array": [,
                  "empty_object": {,
                  "valid_empty": []
                }
                """,
                expectedValid: true,
                description: "Empty or nearly empty structures"
            )
        ]
        
        // Create the view model and run tests
        let viewModel = DocumentViewModel()
        var passedTests = 0
        var failedTests = 0
        var testResults: [(name: String, passed: Bool, details: String)] = []
        
        for (index, testCase) in testCases.enumerated() {
            print("\n" + "-" * 60)
            print("Test \(index + 1)/\(testCases.count): \(testCase.name)")
            print("Description: \(testCase.description)")
            print("-" * 60)
            
            // Set the JSON content
            viewModel.jsonContent = testCase.input
            
            // Run autofix
            await viewModel.autoFix()
            
            // Try to parse the result
            let parser = JSONParser()
            let isValid: Bool
            do {
                _ = try await parser.parse(viewModel.jsonContent)
                isValid = true
                print("✅ PASSED: JSON is now valid")
                passedTests += 1
            } catch {
                isValid = false
                print("❌ FAILED: JSON is still invalid")
                print("Error: \(error)")
                failedTests += 1
            }
            
            // Store result
            testResults.append((
                name: testCase.name,
                passed: isValid,
                details: isValid ? "Successfully fixed and validated" : "Failed to fix: \(viewModel.validationErrors.first?.message ?? "Unknown error")"
            ))
            
            // Show the fixed JSON (first 200 chars)
            let preview = String(viewModel.jsonContent.prefix(200))
            print("Fixed JSON preview:")
            print(preview + (viewModel.jsonContent.count > 200 ? "..." : ""))
        }
        
        // Print summary
        print("\n" + "=" * 80)
        print("📊 TEST SUMMARY")
        print("=" * 80)
        print("Total tests: \(testCases.count)")
        print("✅ Passed: \(passedTests)")
        print("❌ Failed: \(failedTests)")
        print("Success rate: \(String(format: "%.1f", Double(passedTests) / Double(testCases.count) * 100))%")
        
        print("\n📋 Detailed Results:")
        for result in testResults {
            let icon = result.passed ? "✅" : "❌"
            print("\(icon) \(result.name): \(result.details)")
        }
        
        print("\n" + "=" * 80)
        print("🏁 TEST COMPLETE")
        print("=" * 80)
    }
}

// Helper extension for string repetition
extension String {
    static func *(lhs: String, rhs: Int) -> String {
        return String(repeating: lhs, count: rhs)
    }
}