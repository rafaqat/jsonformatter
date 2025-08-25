import SwiftUI

struct TreeView: View {
    let json: JSONNode?
    @State private var expandedNodes = Set<String>()
    @State private var searchText = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with search
            HStack {
                Text("JSON Tree")
                    .font(.headline)
                Spacer()
                
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
                
                Button(action: expandAll) {
                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                        .help("Expand All")
                }
                .buttonStyle(.plain)
                
                Button(action: collapseAll) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .help("Collapse All")
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Tree content
            ScrollView {
                if let json = json {
                    VStack(alignment: .leading, spacing: 0) {
                        TreeNodeView(
                            node: json,
                            key: "root",
                            path: "root",
                            expandedNodes: $expandedNodes,
                            searchText: searchText,
                            level: 0
                        )
                    }
                    .padding()
                } else {
                    Text("No valid JSON to display")
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    private func expandAll() {
        expandedNodes = getAllPaths(from: json, at: "root")
    }
    
    private func collapseAll() {
        expandedNodes.removeAll()
    }
    
    private func getAllPaths(from node: JSONNode?, at path: String) -> Set<String> {
        var paths = Set<String>()
        guard let node = node else { return paths }
        
        switch node {
        case .object(let dict):
            paths.insert(path)
            for (key, value) in dict {
                let childPath = "\(path).\(key)"
                paths.insert(childPath)
                paths.formUnion(getAllPaths(from: value, at: childPath))
            }
        case .array(let items):
            paths.insert(path)
            for (index, item) in items.enumerated() {
                let childPath = "\(path)[\(index)]"
                paths.insert(childPath)
                paths.formUnion(getAllPaths(from: item, at: childPath))
            }
        default:
            break
        }
        return paths
    }
}

struct TreeNodeView: View {
    let node: JSONNode
    let key: String
    let path: String
    @Binding var expandedNodes: Set<String>
    let searchText: String
    let level: Int
    
    @State private var isHovering = false
    
    private var isExpanded: Bool {
        expandedNodes.contains(path)
    }
    
    private var isHighlighted: Bool {
        !searchText.isEmpty && (
            key.localizedCaseInsensitiveContains(searchText) ||
            nodeValue.localizedCaseInsensitiveContains(searchText)
        )
    }
    
    private var nodeValue: String {
        switch node {
        case .string(let value):
            return "\"\(value)\""
        case .number(let value):
            return String(value)
        case .boolean(let value):
            return value ? "true" : "false"
        case .null:
            return "null"
        case .object(let dict):
            return "{\(dict.count)}"
        case .array(let items):
            return "[\(items.count)]"
        }
    }
    
    private var nodeColor: Color {
        switch node {
        case .string:
            return .green
        case .number:
            return .purple
        case .boolean:
            return .orange
        case .null:
            return .red
        case .object, .array:
            return .blue
        }
    }
    
    private var nodeIcon: String {
        switch node {
        case .object, .array:
            return isExpanded ? "chevron.down" : "chevron.right"
        default:
            return "circle.fill"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Node row
            HStack(spacing: 4) {
                // Indentation
                ForEach(0..<level, id: \.self) { _ in
                    Color.clear
                        .frame(width: 20)
                }
                
                // Expand/collapse button
                if isContainer {
                    Button(action: toggleExpanded) {
                        Image(systemName: nodeIcon)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 16, height: 16)
                    }
                    .buttonStyle(.plain)
                } else {
                    Image(systemName: nodeIcon)
                        .font(.caption2)
                        .foregroundColor(nodeColor)
                        .frame(width: 16, height: 16)
                }
                
                // Key
                if key != "root" {
                    Text("\(key):")
                        .font(.system(size: 13, design: .monospaced))
                        .fontWeight(isHighlighted ? .bold : .regular)
                        .foregroundColor(isHighlighted ? .accentColor : .primary)
                }
                
                // Value
                if !isContainer || !isExpanded {
                    Text(nodeValue)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(nodeColor)
                }
                
                // Type badge
                if isContainer && isExpanded {
                    Text(containerTypeBadge)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(4)
                }
                
                Spacer()
                
                // Copy button on hover
                if isHovering {
                    Button(action: copyValue) {
                        Image(systemName: "doc.on.doc")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
            .padding(.horizontal, 4)
            .background(isHighlighted ? Color.accentColor.opacity(0.1) : Color.clear)
            .background(isHovering ? Color.secondary.opacity(0.05) : Color.clear)
            .cornerRadius(4)
            .onHover { hovering in
                isHovering = hovering
            }
            
            // Children (if expanded)
            if isExpanded {
                switch node {
                case .object(let dict):
                    ForEach(dict.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                        TreeNodeView(
                            node: value,
                            key: key,
                            path: "\(path).\(key)",
                            expandedNodes: $expandedNodes,
                            searchText: searchText,
                            level: level + 1
                        )
                    }
                case .array(let items):
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        TreeNodeView(
                            node: item,
                            key: "[\(index)]",
                            path: "\(path)[\(index)]",
                            expandedNodes: $expandedNodes,
                            searchText: searchText,
                            level: level + 1
                        )
                    }
                default:
                    EmptyView()
                }
            }
        }
    }
    
    private var isContainer: Bool {
        switch node {
        case .object, .array:
            return true
        default:
            return false
        }
    }
    
    private var containerTypeBadge: String {
        switch node {
        case .object(let dict):
            return "Object (\(dict.count))"
        case .array(let items):
            return "Array (\(items.count))"
        default:
            return ""
        }
    }
    
    private func toggleExpanded() {
        if isExpanded {
            expandedNodes.remove(path)
        } else {
            expandedNodes.insert(path)
        }
    }
    
    private func copyValue() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        let jsonValue: String
        switch node {
        case .object, .array:
            jsonValue = node.formatted
        default:
            jsonValue = nodeValue
        }
        
        pasteboard.setString(jsonValue, forType: .string)
    }
}