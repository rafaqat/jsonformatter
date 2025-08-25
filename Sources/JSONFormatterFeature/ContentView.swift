import SwiftUI
import AppKit
import CodeEditor

// View hierarchy debugging
@MainActor
func printCompleteHierarchy(_ view: NSView?, indent: String = "") {
    guard let view = view else { return }
    
    let className = String(describing: type(of: view))
    print("\(indent)📦 \(className)")
    print("\(indent)   Frame: \(view.frame)")
    print("\(indent)   Hidden: \(view.isHidden), Alpha: \(view.alphaValue)")
    
    // Special info for text views
    if let textView = view as? NSTextView {
        print("\(indent)   🔤 [TextView]")
        print("\(indent)      String length: \(textView.string.count)")
        print("\(indent)      First 50 chars: \(String(textView.string.prefix(50)))")
        print("\(indent)      Font: \(String(describing: textView.font))")
        print("\(indent)      Text color: \(String(describing: textView.textColor))")
        print("\(indent)      BG color: \(String(describing: textView.backgroundColor))")
        print("\(indent)      Draws BG: \(textView.drawsBackground)")
        print("\(indent)      Is editable: \(textView.isEditable)")
        print("\(indent)      Is selectable: \(textView.isSelectable)")
    }
    
    // Special info for scroll views
    if let scrollView = view as? NSScrollView {
        print("\(indent)   📜 [ScrollView]")
        print("\(indent)      Has doc view: \(scrollView.documentView != nil)")
        print("\(indent)      Draws BG: \(scrollView.drawsBackground)")
        print("\(indent)      BG color: \(String(describing: scrollView.backgroundColor))")
        
        if let docView = scrollView.documentView {
            print("\(indent)      Doc view type: \(String(describing: type(of: docView)))")
        }
    }
    
    // Check for web view (Highlightr uses WKWebView)
    if className.contains("WKWebView") || className.contains("WebView") {
        print("\(indent)   🌐 [WebView detected!]")
    }
    
    // Recursively print subviews
    for subview in view.subviews {
        printCompleteHierarchy(subview, indent: indent + "  ")
    }
}

public struct ContentView: View {
    @State private var viewModel = DocumentViewModel()
    @State private var showExamplePicker = false
    @State private var editorTheme: CodeEditor.ThemeName = CodeEditor.ThemeName(rawValue: "ocean")
    @State private var editorFontSize: CGFloat = 13
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Tab Bar
            TabBarView(selectedTab: $viewModel.currentTab)
                .padding(.horizontal)
                .padding(.vertical, 8)
            
            Divider()
            
            // Content Area
            Group {
                switch viewModel.currentTab {
                case .editor:
                    CodeEditor(
                        source: $viewModel.jsonContent,
                        language: CodeEditor.Language(rawValue: "json"),
                        theme: editorTheme,
                        fontSize: .init(get: { editorFontSize }, set: { editorFontSize = $0 }),
                        flags: [.selectable, .editable, .smartIndent],
                        indentStyle: .softTab(width: 2)
                    )
                    .onAppear {
                        print("🚀 CodeEditor appeared")
                        print("  - Content length: \(viewModel.jsonContent.count)")
                        print("  - Theme: \(editorTheme.rawValue)")
                        
                        // Print view hierarchy after a delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            if let window = NSApp.mainWindow {
                                print("\n🔍 COMPLETE VIEW HIERARCHY:")
                                printCompleteHierarchy(window.contentView)
                            }
                        }
                    }
                case .tree:
                    TreeView(json: viewModel.parsedJSON)
                case .graph:
                    GraphView(json: viewModel.parsedJSON)
                case .chart:
                    ChartView(json: viewModel.parsedJSON)
                case .map:
                    MapView(json: viewModel.parsedJSON)
                case .diff:
                    DiffView(json: viewModel.parsedJSON)
                case .stats:
                    StatsView(json: viewModel.parsedJSON)
                case .search:
                    SearchView(json: viewModel.parsedJSON)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Status Bar
            StatusBarView(message: viewModel.statusMessage, errors: viewModel.validationErrors)
        }
        .frame(minWidth: 800, minHeight: 600)
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                // File operations
                Button(action: {
                    FileService.shared.openFile { content in
                        Task { @MainActor in
                            if let content = content {
                                viewModel.jsonContent = content
                                await viewModel.format()
                            }
                        }
                    }
                }) {
                    Label("Open", systemImage: "doc")
                }
                .keyboardShortcut("o", modifiers: .command)
                
                Button(action: {
                    FileService.shared.saveFile(content: viewModel.jsonContent) { success in
                        Task { @MainActor in
                            viewModel.statusMessage = success ? "File saved" : "Save failed"
                        }
                    }
                }) {
                    Label("Save", systemImage: "square.and.arrow.down")
                }
                .keyboardShortcut("s", modifiers: .command)
                
                Divider()
                
                Button(action: {
                    Task { await viewModel.format() }
                }) {
                    Label("Format", systemImage: "text.alignleft")
                }
                .disabled(viewModel.isFormatting)
                .keyboardShortcut("f", modifiers: .command)
                
                Button(action: {
                    Task { await viewModel.minify() }
                }) {
                    Label("Minify", systemImage: "text.append")
                }
                .disabled(viewModel.isFormatting)
                .keyboardShortcut("m", modifiers: .command)
                
                Button(action: {
                    Task { await viewModel.autoFix() }
                }) {
                    Label("Auto Fix", systemImage: "wand.and.stars")
                }
                .disabled(viewModel.isFormatting)
                
                Divider()
                
                Button(action: { viewModel.copyToClipboard() }) {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                
                Button(action: {
                    Task { await viewModel.pasteFromClipboard() }
                }) {
                    Label("Paste", systemImage: "doc.on.clipboard")
                }
                .keyboardShortcut("v", modifiers: [.command, .shift])
                
                Button(action: { viewModel.clear() }) {
                    Label("Clear", systemImage: "trash")
                }

                Divider()

                Button(action: { showExamplePicker = true }) {
                    Label("Examples", systemImage: "book")
                }

                Divider()

                Picker("Theme", selection: $editorTheme) {
                    Text("Ocean").tag(CodeEditor.ThemeName(rawValue: "ocean"))
                    Text("Agate").tag(CodeEditor.ThemeName(rawValue: "agate"))
                    Text("GitHub").tag(CodeEditor.ThemeName(rawValue: "github"))
                    Text("Xcode").tag(CodeEditor.ThemeName(rawValue: "xcode"))
                }
                .pickerStyle(.menu)
                .frame(width: 120)

                Divider()

                Button(action: { editorFontSize = max(10, editorFontSize - 1) }) {
                    Image(systemName: "textformat.size.smaller")
                }
                .buttonStyle(.plain)

                Text("\(Int(editorFontSize))pt")
                    .font(.caption)
                    .monospacedDigit()
                    .frame(width: 35)

                Button(action: { editorFontSize = min(24, editorFontSize + 1) }) {
                    Image(systemName: "textformat.size.larger")
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $showExamplePicker) {
            ExamplePickerView { example in
                viewModel.jsonContent = example
                Task { await viewModel.format() }
            }
        }
    }
}

// Tab Bar Component
struct TabBarView: View {
    @Binding var selectedTab: Tab
    
    var body: some View {
        HStack(spacing: 16) {
            ForEach(Tab.allCases) { tab in
                TabButton(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    action: { selectedTab = tab }
                )
            }
        }
    }
}

struct TabButton: View {
    let tab: Tab
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 20))
                Text(tab.rawValue)
                    .font(.caption)
            }
            .foregroundColor(isSelected ? .accentColor : .secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

// Status Bar Component
struct StatusBarView: View {
    let message: String
    let errors: [JSONError]
    
    var body: some View {
        HStack {
            if !errors.isEmpty {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text(errors.first?.message ?? "")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .background(Color(NSColor.controlBackgroundColor))
    }
}
