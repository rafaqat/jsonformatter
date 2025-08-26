import SwiftUI
import Factory
import Observation

@Observable
@MainActor
public final class DocumentViewModel {
    // Properties - no @Published needed with @Observable
    public var jsonContent: String = """
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "properties": {
        "name": "Waitrose King's Road",
        "city": "London",
        "postcode": "SW3 5XP"
      },
      "geometry": {
        "type": "Point",
        "coordinates": [-0.1695, 51.4865]
      }
    },
    {
      "type": "Feature",
      "properties": {
        "name": "Waitrose Oxford Street",
        "city": "London",
        "postcode": "W1C 1DX"
      },
      "geometry": {
        "type": "Point",
        "coordinates": [-0.1446, 51.5145]
      }
    },
    {
      "type": "Feature",
      "properties": {
        "name": "Waitrose Edinburgh",
        "city": "Edinburgh",
        "postcode": "EH4 1AW"
      },
      "geometry": {
        "type": "Point",
        "coordinates": [-3.2153, 55.9583]
      }
    },
    {
      "type": "Feature",
      "properties": {
        "name": "Waitrose Cambridge",
        "city": "Cambridge",
        "postcode": "CB2 9FT"
      },
      "geometry": {
        "type": "Point",
        "coordinates": [0.1135, 52.1663]
      }
    },
    {
      "type": "Feature",
      "properties": {
        "name": "Waitrose Manchester",
        "city": "Manchester",
        "postcode": "M32 9BD"
      },
      "geometry": {
        "type": "Point",
        "coordinates": [-2.3115, 53.4451]
      }
    }
  ]
}
"""
    public var parsedJSON: JSONNode?
    public var validationErrors: [JSONError] = []
    public var currentTab: Tab = .editor
    public var isFormatting: Bool = false
    public var isValidating: Bool = false
    public var statusMessage: String = "Ready"
    
    // Services
    private let parser = JSONParser()
    private let preciseParser = PreciseJSONParser()
    private let parseTreeFixer = ParseTreeJSONFixer()
    private let treeWalkingFixer = TreeWalkingJSONFixer()
    private let smartFixer = SmartJSONFixer()
    private let validator = JSONValidator()
    
    public init() {
        // Parse the default JSON content on initialization
        Task {
            await format()
        }
    }
    
    // Nonisolated for background processing
    nonisolated private func parseInBackground(_ content: String) async throws -> JSONNode {
        try await parser.parse(content)
    }
    
    nonisolated private func fixInBackground(_ content: String) async -> ParseTreeJSONFixer.FixResult {
        await parseTreeFixer.fix(content)
    }
    
    nonisolated private func treeWalkFixInBackground(_ content: String) async -> TreeWalkingJSONFixer.FixResult {
        await treeWalkingFixer.fix(content)
    }
    
    // Format JSON
    public func format() async {
        isFormatting = true
        statusMessage = "Formatting..."
        defer { 
            isFormatting = false 
            statusMessage = "Ready"
        }
        
        guard !jsonContent.isEmpty else {
            validationErrors = [JSONError(line: 0, column: 0, message: "No content to format")]
            statusMessage = "Error: No content"
            return
        }
        
        do {
            let parsed = try await parseInBackground(jsonContent)
            parsedJSON = parsed
            jsonContent = parsed.formatted
            validationErrors = []
            statusMessage = "Formatted successfully"
        } catch {
            // Try to fix the JSON
            let fixResult = await fixInBackground(jsonContent)
            
            do {
                let parsed = try await parseInBackground(fixResult.fixed)
                parsedJSON = parsed
                jsonContent = parsed.formatted
                
                if fixResult.wasFixed {
                    let fixes = fixResult.fixes.joined(separator: ", ")
                    validationErrors = [JSONError(
                        line: 0,
                        column: 0,
                        message: "Auto-fixed: \(fixes)",
                        severity: .warning
                    )]
                    statusMessage = "Formatted with fixes"
                } else {
                    validationErrors = []
                    statusMessage = "Formatted successfully"
                }
            } catch {
                validationErrors = [JSONError(from: error)]
                statusMessage = "Error: Invalid JSON"
            }
        }
    }
    
    // Minify JSON
    public func minify() async {
        isFormatting = true
        statusMessage = "Minifying..."
        defer { 
            isFormatting = false
            statusMessage = "Ready"
        }
        
        guard !jsonContent.isEmpty else {
            validationErrors = [JSONError(line: 0, column: 0, message: "No content to minify")]
            statusMessage = "Error: No content"
            return
        }
        
        do {
            let parsed = try await parseInBackground(jsonContent)
            parsedJSON = parsed
            jsonContent = parsed.minified
            validationErrors = []
            statusMessage = "Minified successfully"
        } catch {
            // Try to fix the JSON
            let fixResult = await fixInBackground(jsonContent)
            
            do {
                let parsed = try await parseInBackground(fixResult.fixed)
                parsedJSON = parsed
                jsonContent = parsed.minified
                
                if fixResult.wasFixed {
                    let fixes = fixResult.fixes.joined(separator: ", ")
                    validationErrors = [JSONError(
                        line: 0,
                        column: 0,
                        message: "Auto-fixed: \(fixes)",
                        severity: .warning
                    )]
                    statusMessage = "Minified with fixes"
                } else {
                    validationErrors = []
                    statusMessage = "Minified successfully"
                }
            } catch {
                validationErrors = [JSONError(from: error)]
                statusMessage = "Error: Invalid JSON"
            }
        }
    }
    
    // Validate JSON with precise error tracking
    public func validate() async {
        isValidating = true
        statusMessage = "Validating..."
        defer { 
            isValidating = false
        }
        
        guard !jsonContent.isEmpty else {
            validationErrors = []
            parsedJSON = nil
            statusMessage = "Ready"
            return
        }
        
        // Use PreciseJSONParser for detailed error tracking
        let preciseErrors = await preciseParser.validate(jsonContent)
        
        if !preciseErrors.isEmpty {
            validationErrors = preciseErrors
            statusMessage = "Invalid JSON - \(preciseErrors.filter { $0.severity == .error }.count) error(s)"
            
            // Try to parse what we can for tree view
            do {
                let parsed = try await parseInBackground(jsonContent)
                parsedJSON = parsed
            } catch {
                parsedJSON = nil
            }
        } else {
            // Valid JSON - parse for tree view
            do {
                let parsed = try await parseInBackground(jsonContent)
                parsedJSON = parsed
                validationErrors = []
                statusMessage = "Valid JSON"
            } catch {
                // Fallback to basic validator if parse fails
                let validationResult = await validator.validate(jsonContent)
                validationErrors = validationResult.errors
                parsedJSON = nil
                statusMessage = "Invalid JSON"
            }
        }
    }
    
    // Clear content
    public func clear() {
        jsonContent = ""
        parsedJSON = nil
        validationErrors = []
        statusMessage = "Ready"
    }
    
    // Copy to clipboard
    public func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(jsonContent, forType: .string)
        statusMessage = "Copied to clipboard"
    }
    
    // Paste from clipboard
    public func pasteFromClipboard() async {
        let pasteboard = NSPasteboard.general
        guard let content = pasteboard.string(forType: .string) else {
            statusMessage = "Clipboard is empty"
            return
        }
        
        jsonContent = content
        await validate()
    }
    
    // Auto-fix JSON
    public func autoFix() async {
        isFormatting = true
        statusMessage = "Auto-fixing..."
        defer { 
            isFormatting = false
        }
        
        guard !jsonContent.isEmpty else {
            validationErrors = [JSONError(line: 0, column: 0, message: "No content to fix")]
            statusMessage = "Error: No content"
            return
        }
        
        // IMPORTANT: Run parse tree fixer FIRST to fix structural issues
        // This will fix missing brackets before the parser sees them
        let treeFixResult = await fixInBackground(jsonContent)
        
        // Then get parser errors on the potentially fixed JSON
        let parseErrors = await preciseParser.validate(treeFixResult.fixed)
        
        // Use smart fixer with parser errors for targeted fixes
        let smartFixResult = await smartFixer.fix(treeFixResult.fixed, errors: parseErrors)
        
        // Use tree-walking fixer for deep structural analysis
        let treeWalkResult = await treeWalkFixInBackground(smartFixResult.fixed)
        
        // Run parse tree fixer again for final cleanup
        let finalTreeFix = await fixInBackground(treeWalkResult.fixed)
        
        // Combine results from all fixers
        let finalFixed = finalTreeFix.wasFixed ? finalTreeFix.fixed :
                        (treeWalkResult.wasFixed ? treeWalkResult.fixed : 
                         (smartFixResult.wasFixed ? smartFixResult.fixed : treeFixResult.fixed))
        let allFixes = treeFixResult.fixes + smartFixResult.fixes + treeWalkResult.fixes + finalTreeFix.fixes
        
        if !allFixes.isEmpty {
            jsonContent = finalFixed
            
            // Try to parse and format the fixed JSON
            do {
                let parsed = try await parseInBackground(finalFixed)
                parsedJSON = parsed
                jsonContent = parsed.formatted
                
                // Show what was fixed as info message
                let fixes = allFixes.joined(separator: ", ")
                validationErrors = [JSONError(
                    line: 0,
                    column: 0,
                    message: "Successfully fixed: \(fixes)",
                    severity: .info
                )]
                statusMessage = "Auto-fixed and formatted"
                
                // Clear the info message after a delay
                Task {
                    try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
                    if validationErrors.count == 1 && validationErrors.first?.severity == .info {
                        validationErrors = []
                    }
                }
            } catch {
                // If still has errors after fix, show them
                await validate()
            }
        } else {
            // No fixes needed, just format
            await format()
        }
    }
    
    // Apply fix for a specific error (or all errors)
    public func applyFix(for error: JSONError) async {
        // Just use the existing auto-fix functionality which uses JSONFixer
        // It will fix ALL issues at once, not just this specific error
        await autoFix()
    }
}

public enum Tab: String, CaseIterable, Identifiable {
    case editor = "Editor"
    case tree = "Tree"
    case graph = "Graph"
    case chart = "Chart"
    case map = "Map"
    case diff = "Diff"
    case stats = "Stats"
    case search = "Search"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .editor: return "doc.text"
        case .tree: return "list.bullet.indent"
        case .graph: return "point.3.connected.trianglepath.dotted"
        case .chart: return "chart.bar"
        case .map: return "map"
        case .diff: return "doc.on.doc"
        case .stats: return "chart.pie"
        case .search: return "magnifyingglass"
        }
    }
}