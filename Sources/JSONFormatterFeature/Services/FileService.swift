import Foundation
import AppKit
import UniformTypeIdentifiers

@MainActor
public class FileService {
    static let shared = FileService()
    
    private init() {}
    
    func openFile(completion: @escaping @Sendable (String?) -> Void) {
        let openPanel = NSOpenPanel()
        openPanel.title = "Choose a JSON file"
        openPanel.showsResizeIndicator = true
        openPanel.showsHiddenFiles = false
        openPanel.canChooseDirectories = false
        openPanel.canCreateDirectories = false
        openPanel.allowsMultipleSelection = false
        openPanel.allowedContentTypes = [.json, .text]
        
        openPanel.begin { response in
            Task { @MainActor in
                if response == .OK, let url = openPanel.url {
                    do {
                        let content = try String(contentsOf: url, encoding: .utf8)
                        completion(content)
                    } catch {
                        print("Error reading file: \(error)")
                        completion(nil)
                    }
                } else {
                    completion(nil)
                }
            }
        }
    }
    
    func saveFile(content: String, completion: @escaping @Sendable (Bool) -> Void) {
        let savePanel = NSSavePanel()
        savePanel.title = "Save JSON File"
        savePanel.showsResizeIndicator = true
        savePanel.showsHiddenFiles = false
        savePanel.canCreateDirectories = true
        savePanel.allowedContentTypes = [.json]
        savePanel.nameFieldStringValue = "document.json"
        
        savePanel.begin { response in
            Task { @MainActor in
                if response == .OK, let url = savePanel.url {
                    do {
                        try content.write(to: url, atomically: true, encoding: .utf8)
                        completion(true)
                    } catch {
                        print("Error saving file: \(error)")
                        completion(false)
                    }
                } else {
                    completion(false)
                }
            }
        }
    }
    
    func exportAs(content: String, format: ExportFormat, completion: @escaping @Sendable (Bool) -> Void) {
        let savePanel = NSSavePanel()
        savePanel.title = "Export As \(format.name)"
        savePanel.showsResizeIndicator = true
        savePanel.showsHiddenFiles = false
        savePanel.canCreateDirectories = true
        savePanel.allowedContentTypes = [format.contentType]
        savePanel.nameFieldStringValue = "export.\(format.extension)"
        
        savePanel.begin { [weak self] response in
            Task { @MainActor in
                if response == .OK, let url = savePanel.url {
                    do {
                        let exportContent = self?.convertToFormat(content, format: format) ?? content
                        try exportContent.write(to: url, atomically: true, encoding: .utf8)
                        completion(true)
                    } catch {
                        print("Error exporting file: \(error)")
                        completion(false)
                    }
                } else {
                    completion(false)
                }
            }
        }
    }
    
    private func convertToFormat(_ jsonContent: String, format: ExportFormat) -> String {
        guard let data = jsonContent.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) else {
            return jsonContent
        }
        
        switch format {
        case .csv:
            return convertToCSV(json)
        case .xml:
            return convertToXML(json)
        case .yaml:
            return convertToYAML(json)
        case .plist:
            return convertToPlist(json)
        }
    }
    
    private func convertToCSV(_ json: Any) -> String {
        // Simple CSV conversion for arrays of objects
        if let array = json as? [[String: Any]] {
            guard let first = array.first else { return "" }
            
            let headers = first.keys.sorted()
            var csv = headers.joined(separator: ",") + "\n"
            
            for item in array {
                let values = headers.map { key in
                    if let value = item[key] {
                        return "\"\(value)\""
                    }
                    return ""
                }
                csv += values.joined(separator: ",") + "\n"
            }
            
            return csv
        }
        
        return "Unable to convert to CSV"
    }
    
    private func convertToXML(_ json: Any) -> String {
        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<root>\n"
        xml += convertToXMLRecursive(json, indent: 1)
        xml += "</root>"
        return xml
    }
    
    private func convertToXMLRecursive(_ value: Any, indent: Int) -> String {
        let indentString = String(repeating: "  ", count: indent)
        var xml = ""
        
        if let dict = value as? [String: Any] {
            for (key, val) in dict {
                xml += "\(indentString)<\(key)>"
                if let nested = val as? [String: Any], !nested.isEmpty {
                    xml += "\n\(convertToXMLRecursive(val, indent: indent + 1))\(indentString)"
                } else if let array = val as? [Any] {
                    xml += "\n"
                    for item in array {
                        xml += "\(indentString)  <item>"
                        if let nestedItem = item as? [String: Any], !nestedItem.isEmpty {
                            xml += "\n\(convertToXMLRecursive(item, indent: indent + 2))\(indentString)  "
                        } else {
                            xml += "\(item)"
                        }
                        xml += "</item>\n"
                    }
                    xml += indentString
                } else {
                    xml += "\(val)"
                }
                xml += "</\(key)>\n"
            }
        } else if let array = value as? [Any] {
            for item in array {
                xml += "\(indentString)<item>\(item)</item>\n"
            }
        } else {
            xml += "\(indentString)\(value)\n"
        }
        
        return xml
    }
    
    private func convertToYAML(_ json: Any) -> String {
        return convertToYAMLRecursive(json, indent: 0)
    }
    
    private func convertToYAMLRecursive(_ value: Any, indent: Int) -> String {
        let indentString = String(repeating: "  ", count: indent)
        var yaml = ""
        
        if let dict = value as? [String: Any] {
            for (key, val) in dict {
                yaml += "\(indentString)\(key):"
                if let nested = val as? [String: Any], !nested.isEmpty {
                    yaml += "\n\(convertToYAMLRecursive(val, indent: indent + 1))"
                } else if let array = val as? [Any] {
                    yaml += "\n"
                    for item in array {
                        yaml += "\(indentString)  - "
                        if let nestedItem = item as? [String: Any] {
                            yaml += "\n\(convertToYAMLRecursive(nestedItem, indent: indent + 2))"
                        } else {
                            yaml += "\(item)\n"
                        }
                    }
                } else if let str = val as? String {
                    yaml += " \"\(str)\"\n"
                } else {
                    yaml += " \(val)\n"
                }
            }
        } else if let array = value as? [Any] {
            for item in array {
                yaml += "\(indentString)- \(item)\n"
            }
        } else {
            yaml += "\(value)\n"
        }
        
        return yaml
    }
    
    private func convertToPlist(_ json: Any) -> String {
        do {
            let data = try PropertyListSerialization.data(fromPropertyList: json, format: .xml, options: 0)
            return String(data: data, encoding: .utf8) ?? "Unable to convert to plist"
        } catch {
            return "Error converting to plist: \(error)"
        }
    }
}

public enum ExportFormat: Sendable {
    case csv
    case xml
    case yaml
    case plist
    
    var name: String {
        switch self {
        case .csv: return "CSV"
        case .xml: return "XML"
        case .yaml: return "YAML"
        case .plist: return "Property List"
        }
    }
    
    var `extension`: String {
        switch self {
        case .csv: return "csv"
        case .xml: return "xml"
        case .yaml: return "yaml"
        case .plist: return "plist"
        }
    }
    
    var contentType: UTType {
        switch self {
        case .csv: return .commaSeparatedText
        case .xml: return .xml
        case .yaml: return .yaml
        case .plist: return .propertyList
        }
    }
}