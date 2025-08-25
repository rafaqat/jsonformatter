import SwiftUI
import Charts
import MapKit

// Graph View - Node visualization
struct GraphView: View {
    let json: JSONNode?
    @State private var selectedNode: String? = nil
    @State private var hoveredNode: String? = nil
    
    var body: some View {
        if let json = json {
            ScrollView([.horizontal, .vertical]) {
                ZStack {
                    // Draw connections first (behind nodes)
                    ForEach(getConnections(from: json), id: \.id) { connection in
                        Path { path in
                            path.move(to: connection.start)
                            path.addLine(to: connection.end)
                        }
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    }
                    
                    // Draw nodes
                    ForEach(getNodes(from: json), id: \.id) { node in
                        NodeView(
                            node: node,
                            isSelected: selectedNode == node.id,
                            isHovered: hoveredNode == node.id
                        )
                        .position(node.position)
                        .onTapGesture {
                            selectedNode = node.id
                        }
                        .onHover { hovering in
                            hoveredNode = hovering ? node.id : nil
                        }
                    }
                }
                .frame(width: 1200, height: 800)
                .padding(50)
            }
            .background(Color(NSColor.controlBackgroundColor))
        } else {
            ContentUnavailableView(
                "No JSON Data",
                systemImage: "doc.text",
                description: Text("Enter JSON in the Editor tab to visualize")
            )
        }
    }
    
    private func getNodes(from node: JSONNode, path: String = "root", depth: Int = 0, x: CGFloat = 600, y: CGFloat = 100) -> [GraphNode] {
        var nodes: [GraphNode] = []
        let nodeId = path
        
        // Add current node
        let graphNode = GraphNode(
            id: nodeId,
            label: path.components(separatedBy: ".").last ?? "root",
            value: getNodeValue(node),
            type: getNodeType(node),
            position: CGPoint(x: x, y: y)
        )
        nodes.append(graphNode)
        
        // Add child nodes
        switch node {
        case .object(let dict):
            let keys = Array(dict.keys).sorted()
            let spacing: CGFloat = 150
            let startX = x - (CGFloat(keys.count - 1) * spacing / 2)
            
            for (index, key) in keys.enumerated() {
                let childX = startX + CGFloat(index) * spacing
                let childY = y + 120
                let childPath = "\(path).\(key)"
                nodes.append(contentsOf: getNodes(from: dict[key]!, path: childPath, depth: depth + 1, x: childX, y: childY))
            }
            
        case .array(let items):
            let spacing: CGFloat = 120
            let startX = x - (CGFloat(items.count - 1) * spacing / 2)
            
            for (index, item) in items.enumerated() {
                let childX = startX + CGFloat(index) * spacing
                let childY = y + 120
                let childPath = "\(path)[\(index)]"
                nodes.append(contentsOf: getNodes(from: item, path: childPath, depth: depth + 1, x: childX, y: childY))
            }
            
        default:
            break
        }
        
        return nodes
    }
    
    private func getConnections(from node: JSONNode, path: String = "root", x: CGFloat = 600, y: CGFloat = 100) -> [GraphConnection] {
        var connections: [GraphConnection] = []
        
        switch node {
        case .object(let dict):
            let keys = Array(dict.keys).sorted()
            let spacing: CGFloat = 150
            let startX = x - (CGFloat(keys.count - 1) * spacing / 2)
            
            for (index, key) in keys.enumerated() {
                let childX = startX + CGFloat(index) * spacing
                let childY = y + 120
                
                connections.append(GraphConnection(
                    id: "\(path)->\(key)",
                    start: CGPoint(x: x, y: y + 30),
                    end: CGPoint(x: childX, y: childY - 30)
                ))
                
                connections.append(contentsOf: getConnections(from: dict[key]!, path: "\(path).\(key)", x: childX, y: childY))
            }
            
        case .array(let items):
            let spacing: CGFloat = 120
            let startX = x - (CGFloat(items.count - 1) * spacing / 2)
            
            for (index, item) in items.enumerated() {
                let childX = startX + CGFloat(index) * spacing
                let childY = y + 120
                
                connections.append(GraphConnection(
                    id: "\(path)->[\(index)]",
                    start: CGPoint(x: x, y: y + 30),
                    end: CGPoint(x: childX, y: childY - 30)
                ))
                
                connections.append(contentsOf: getConnections(from: item, path: "\(path)[\(index)]", x: childX, y: childY))
            }
            
        default:
            break
        }
        
        return connections
    }
    
    private func getNodeType(_ node: JSONNode) -> String {
        switch node {
        case .object: return "object"
        case .array: return "array"
        case .string: return "string"
        case .number: return "number"
        case .boolean: return "boolean"
        case .null: return "null"
        }
    }
    
    private func getNodeValue(_ node: JSONNode) -> String {
        switch node {
        case .object(let dict): return "{\(dict.count) items}"
        case .array(let items): return "[\(items.count) items]"
        case .string(let str): return "\"\(str)\""
        case .number(let num): return "\(num)"
        case .boolean(let bool): return bool ? "true" : "false"
        case .null: return "null"
        }
    }
}

// Node representation for graph
struct GraphNode: Identifiable {
    let id: String
    let label: String
    let value: String
    let type: String
    let position: CGPoint
}

// Connection between nodes
struct GraphConnection: Identifiable {
    let id: String
    let start: CGPoint
    let end: CGPoint
}

// Individual node view
struct NodeView: View {
    let node: GraphNode
    let isSelected: Bool
    let isHovered: Bool
    
    var nodeColor: Color {
        switch node.type {
        case "object": return .blue
        case "array": return .purple
        case "string": return .green
        case "number": return .orange
        case "boolean": return .pink
        case "null": return .red
        default: return .gray
        }
    }
    
    var body: some View {
        VStack(spacing: 4) {
            Text(node.label)
                .font(.caption)
                .fontWeight(.semibold)
            Text(node.value)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(nodeColor.opacity(isSelected ? 0.3 : isHovered ? 0.2 : 0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(nodeColor, lineWidth: isSelected ? 2 : 1)
                )
        )
        .scaleEffect(isHovered ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
    }
}

// Chart View - Statistical visualization
struct ChartView: View {
    let json: JSONNode?
    
    var body: some View {
        if let json = json {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("JSON Statistics")
                        .font(.title2)
                        .padding(.horizontal)
                    
                    if let stats = calculateStats(json) {
                        Chart(stats, id: \.type) { item in
                            BarMark(
                                x: .value("Type", item.type),
                                y: .value("Count", item.count)
                            )
                            .foregroundStyle(by: .value("Type", item.type))
                        }
                        .frame(height: 300)
                        .padding()
                    }
                }
            }
        } else {
            ContentUnavailableView(
                "No JSON Data",
                systemImage: "chart.bar",
                description: Text("Enter JSON in the Editor tab to see statistics")
            )
        }
    }
    
    private func calculateStats(_ node: JSONNode) -> [(type: String, count: Int)]? {
        var stats: [String: Int] = [:]
        countTypes(node, stats: &stats)
        return stats.map { (type: $0.key, count: $0.value) }.sorted { $0.count > $1.count }
    }
    
    private func countTypes(_ node: JSONNode, stats: inout [String: Int]) {
        switch node {
        case .object(let dict):
            stats["Objects", default: 0] += 1
            dict.values.forEach { countTypes($0, stats: &stats) }
        case .array(let items):
            stats["Arrays", default: 0] += 1
            items.forEach { countTypes($0, stats: &stats) }
        case .string:
            stats["Strings", default: 0] += 1
        case .number:
            stats["Numbers", default: 0] += 1
        case .boolean:
            stats["Booleans", default: 0] += 1
        case .null:
            stats["Nulls", default: 0] += 1
        }
    }
}

// Map View - Geographic data visualization
struct MapView: View {
    let json: JSONNode?
    @State private var cameraPosition = MapCameraPosition.region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 10, longitudeDelta: 10)
        )
    )
    @State private var selectedLocation: GeoLocation? = nil
    
    var body: some View {
        if let json = json {
            let locations = extractGeoLocations(from: json)
            
            if !locations.isEmpty {
                ZStack {
                    Map(position: $cameraPosition) {
                        ForEach(locations) { location in
                            Marker(location.name, coordinate: location.coordinate)
                                .tint(location.color)
                            
                            if let radius = location.radius {
                                MapCircle(center: location.coordinate, radius: radius)
                                    .foregroundStyle(location.color.opacity(0.2))
                                    .stroke(location.color, lineWidth: 2)
                            }
                        }
                    }
                    .onAppear {
                        if let firstLocation = locations.first {
                            cameraPosition = .region(
                                MKCoordinateRegion(
                                    center: firstLocation.coordinate,
                                    span: MKCoordinateSpan(latitudeDelta: 5, longitudeDelta: 5)
                                )
                            )
                        }
                    }
                    
                    // Location list overlay
                    VStack {
                        HStack {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Locations Found: \(locations.count)")
                                    .font(.headline)
                                
                                ScrollView {
                                    VStack(alignment: .leading, spacing: 4) {
                                        ForEach(locations) { location in
                                            Button(action: {
                                                selectedLocation = location
                                                cameraPosition = .region(
                                                    MKCoordinateRegion(
                                                        center: location.coordinate,
                                                        span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
                                                    )
                                                )
                                            }) {
                                                HStack {
                                                    Circle()
                                                        .fill(location.color)
                                                        .frame(width: 8, height: 8)
                                                    VStack(alignment: .leading) {
                                                        Text(location.name)
                                                            .font(.caption)
                                                        Text("\(location.coordinate.latitude, specifier: "%.4f"), \(location.coordinate.longitude, specifier: "%.4f")")
                                                            .font(.caption2)
                                                            .foregroundColor(.secondary)
                                                    }
                                                }
                                                .padding(.vertical, 2)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                                .frame(maxHeight: 200)
                            }
                            .padding()
                            .background(Color(NSColor.controlBackgroundColor).opacity(0.95))
                            .cornerRadius(8)
                            .shadow(radius: 4)
                            
                            Spacer()
                        }
                        .padding()
                        
                        Spacer()
                    }
                }
            } else {
                ContentUnavailableView(
                    "No Geographic Data Found",
                    systemImage: "map",
                    description: Text("No latitude/longitude coordinates detected in JSON.\nTry JSON with 'lat/latitude' and 'lon/lng/longitude' fields.")
                )
            }
        } else {
            ContentUnavailableView(
                "No JSON Data",
                systemImage: "map",
                description: Text("Enter JSON with geographic data to visualize on map")
            )
        }
    }
    
    private func extractGeoLocations(from node: JSONNode, path: String = "root") -> [GeoLocation] {
        var locations: [GeoLocation] = []
        
        switch node {
        case .object(let dict):
            // Check if this object contains coordinates
            if let location = extractLocationFromObject(dict, path: path) {
                locations.append(location)
            }
            
            // Recursively check nested objects
            for (key, value) in dict {
                locations.append(contentsOf: extractGeoLocations(from: value, path: "\(path).\(key)"))
            }
            
        case .array(let items):
            // Check each item in array
            for (index, item) in items.enumerated() {
                locations.append(contentsOf: extractGeoLocations(from: item, path: "\(path)[\(index)]"))
            }
            
        default:
            break
        }
        
        return locations
    }
    
    private func extractLocationFromObject(_ dict: [String: JSONNode], path: String) -> GeoLocation? {
        var latitude: Double? = nil
        var longitude: Double? = nil
        var name: String = path
        var radius: Double? = nil
        
        // Look for latitude
        for key in ["lat", "latitude", "Latitude", "LAT"] {
            if let node = dict[key], case .number(let num) = node {
                latitude = num
                break
            }
        }
        
        // Look for longitude
        for key in ["lon", "lng", "long", "longitude", "Longitude", "LON", "LNG"] {
            if let node = dict[key], case .number(let num) = node {
                longitude = num
                break
            }
        }
        
        // Look for location name
        for key in ["name", "title", "label", "place", "city", "location", "address"] {
            if let node = dict[key], case .string(let str) = node {
                name = str
                break
            }
        }
        
        // Look for radius (for circles)
        for key in ["radius", "range", "distance"] {
            if let node = dict[key], case .number(let num) = node {
                radius = num * 1000 // Convert to meters
                break
            }
        }
        
        // Check for coordinate object
        if latitude == nil && longitude == nil {
            if let coordNode = dict["coordinates"] ?? dict["coord"] ?? dict["position"] ?? dict["location"],
               case .object(let coordDict) = coordNode {
                
                for key in ["lat", "latitude", "y"] {
                    if let node = coordDict[key], case .number(let num) = node {
                        latitude = num
                        break
                    }
                }
                
                for key in ["lon", "lng", "longitude", "x"] {
                    if let node = coordDict[key], case .number(let num) = node {
                        longitude = num
                        break
                    }
                }
            }
            
            // Check for GeoJSON-style coordinates array [lng, lat]
            if let coordNode = dict["coordinates"],
               case .array(let coords) = coordNode,
               coords.count >= 2,
               case .number(let lng) = coords[0],
               case .number(let lat) = coords[1] {
                latitude = lat
                longitude = lng
            }
        }
        
        guard let lat = latitude, let lon = longitude else {
            return nil
        }
        
        // Validate coordinates
        guard lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180 else {
            return nil
        }
        
        return GeoLocation(
            name: name,
            coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
            radius: radius,
            color: .blue
        )
    }
}

// Geographic location model
struct GeoLocation: Identifiable {
    let id = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D
    let radius: Double?
    let color: Color
}

// Diff View - JSON comparison
struct DiffView: View {
    let json: JSONNode?
    @State private var secondJSON = ""
    
    var body: some View {
        if json != nil {
            HSplitView {
                VStack {
                    Text("Original JSON")
                        .font(.headline)
                        .padding()
                    ScrollView {
                        Text(json?.formatted ?? "")
                            .font(.system(.body, design: .monospaced))
                            .padding()
                    }
                }
                
                VStack {
                    Text("Compare With")
                        .font(.headline)
                        .padding()
                    TextEditor(text: $secondJSON)
                        .font(.system(.body, design: .monospaced))
                }
            }
        } else {
            ContentUnavailableView(
                "No JSON Data",
                systemImage: "doc.on.doc",
                description: Text("Enter JSON in the Editor tab to compare")
            )
        }
    }
}

// Stats View - Detailed statistics
struct StatsView: View {
    let json: JSONNode?
    
    var body: some View {
        if let json = json {
            List {
                Section("Overview") {
                    StatRow(label: "Total Size", value: "\(json.formatted.count) characters")
                    StatRow(label: "Minified Size", value: "\(json.minified.count) characters")
                    StatRow(label: "Compression Ratio", value: String(format: "%.1f%%", 
                        Double(json.minified.count) / Double(max(json.formatted.count, 1)) * 100))
                }
                
                Section("Structure") {
                    if let stats = calculateDetailedStats(json) {
                        ForEach(stats, id: \.label) { stat in
                            StatRow(label: stat.label, value: stat.value)
                        }
                    }
                }
            }
        } else {
            ContentUnavailableView(
                "No JSON Data",
                systemImage: "chart.pie",
                description: Text("Enter JSON in the Editor tab to see detailed statistics")
            )
        }
    }
    
    private func calculateDetailedStats(_ node: JSONNode) -> [(label: String, value: String)]? {
        var depth = 0
        var keys = Set<String>()
        calculateDepthAndKeys(node, currentDepth: 0, maxDepth: &depth, keys: &keys)
        
        return [
            (label: "Maximum Depth", value: String(depth)),
            (label: "Unique Keys", value: String(keys.count))
        ]
    }
    
    private func calculateDepthAndKeys(_ node: JSONNode, currentDepth: Int, maxDepth: inout Int, keys: inout Set<String>) {
        maxDepth = max(maxDepth, currentDepth)
        
        switch node {
        case .object(let dict):
            keys.formUnion(dict.keys)
            dict.values.forEach { calculateDepthAndKeys($0, currentDepth: currentDepth + 1, maxDepth: &maxDepth, keys: &keys) }
        case .array(let items):
            items.forEach { calculateDepthAndKeys($0, currentDepth: currentDepth + 1, maxDepth: &maxDepth, keys: &keys) }
        default:
            break
        }
    }
}

struct StatRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(.body, design: .monospaced))
        }
    }
}

// Search View - Search within JSON
struct SearchView: View {
    let json: JSONNode?
    @State private var searchText = ""
    @State private var searchResults: [SearchResult] = []
    
    var body: some View {
        if json != nil {
            VStack {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search in JSON...", text: $searchText)
                        .textFieldStyle(.plain)
                        .onSubmit {
                            performSearch()
                        }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                
                List(searchResults) { result in
                    VStack(alignment: .leading) {
                        Text(result.path)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(result.value)
                            .font(.system(.body, design: .monospaced))
                    }
                    .padding(.vertical, 4)
                }
            }
        } else {
            ContentUnavailableView(
                "No JSON Data",
                systemImage: "magnifyingglass",
                description: Text("Enter JSON in the Editor tab to search")
            )
        }
    }
    
    private func performSearch() {
        // Search implementation would go here
        searchResults = []
    }
}

struct SearchResult: Identifiable {
    let id = UUID()
    let path: String
    let value: String
}

// Example Picker View
struct ExamplePickerView: View {
    let onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    
    let examples = ExampleJSON.examples
    
    var body: some View {
        VStack {
            Text("Select Example JSON")
                .font(.title2)
                .padding()
            
            List(examples, id: \.name) { example in
                Button(action: {
                    onSelect(example.json)
                    dismiss()
                }) {
                    VStack(alignment: .leading) {
                        Text(example.name)
                            .font(.headline)
                        Text(String(example.json.prefix(100)) + "...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
            
            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
            }
            .padding()
        }
        .frame(width: 400, height: 300)
    }
}