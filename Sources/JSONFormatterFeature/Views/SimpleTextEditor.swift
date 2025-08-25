import SwiftUI
import AppKit
import CodeEditor

// Helper function to print view hierarchy
@MainActor
func printViewHierarchy(_ view: NSView?, indent: String) {
    guard let view = view else { return }
    
    let className = String(describing: type(of: view))
    print("\(indent)├─ \(className)")
    print("\(indent)│  Frame: \(view.frame)")
    print("\(indent)│  Hidden: \(view.isHidden), Alpha: \(view.alphaValue)")
    
    // Special cases for different view types
    if let textView = view as? NSTextView {
        print("\(indent)│  [TextView] String length: \(textView.string.count)")
        print("\(indent)│  [TextView] First 30 chars: \(String(textView.string.prefix(30)))")
    }
    
    if let scrollView = view as? NSScrollView {
        print("\(indent)│  [ScrollView] Has doc view: \(scrollView.documentView != nil)")
    }
    
    // Recursively print subviews
    for subview in view.subviews {
        printViewHierarchy(subview, indent: indent + "  ")
    }
}

/// Simple text editor using native SwiftUI TextEditor
struct SimpleTextEditor: View {
    @Bindable var viewModel: DocumentViewModel
    @State private var localContent: String
    @State private var debounceTask: Task<Void, Never>?
    @Binding var currentTheme: CodeEditor.ThemeName
    @Binding var fontSize: CGFloat
    
    init(viewModel: DocumentViewModel, theme: Binding<CodeEditor.ThemeName>, fontSize: Binding<CGFloat>) {
        self.viewModel = viewModel
        self._localContent = State(initialValue: viewModel.jsonContent)
        self._currentTheme = theme
        self._fontSize = fontSize
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Editor toolbar
            HStack {
                Text("JSON Editor")
                    .font(.headline)
                
                Spacer()
                
                // Theme selector
                Picker("Theme", selection: $currentTheme) {
                    Text("Ocean").tag(CodeEditor.ThemeName(rawValue: "ocean"))
                    Text("GitHub").tag(CodeEditor.ThemeName(rawValue: "github"))
                }
                .pickerStyle(.menu)
                .frame(width: 120)
                
                // Font size controls
                HStack(spacing: 4) {
                    Button(action: { fontSize = max(10, fontSize - 1) }) {
                        Image(systemName: "textformat.size.smaller")
                    }
                    Text("\(Int(fontSize))pt")
                        .frame(width: 40)
                    Button(action: { fontSize = min(24, fontSize + 1) }) {
                        Image(systemName: "textformat.size.larger")
                    }
                }
                
                // Validation status
                if viewModel.isValidating {
                    ProgressView()
                        .scaleEffect(0.7)
                } else if !viewModel.validationErrors.isEmpty {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .help("\(viewModel.validationErrors.count) validation issues")
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .help("Valid JSON")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Simple TextEditor with monospace font
            TextEditor(text: $localContent)
                .font(.system(size: fontSize, weight: .regular, design: .monospaced))
                .padding(8)
                .background(backgroundColor)
                .foregroundColor(textColor)
                .scrollContentBackground(.hidden)
                .onChange(of: localContent) { oldValue, newValue in
                    handleContentChange(newValue)
                }
                .onAppear {
                    print("📝 SimpleTextEditor onAppear")
                    print("  - Content length: \(localContent.count)")
                    print("  - First 50 chars: \(String(localContent.prefix(50)))")
                    localContent = viewModel.jsonContent
                    
                    // Print view hierarchy
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        if let window = NSApp.windows.first {
                            print("\n🔍 VIEW HIERARCHY FROM WINDOW:")
                            printViewHierarchy(window.contentView, indent: "")
                        }
                    }
                }
        }
    }
    
    private var backgroundColor: Color {
        switch currentTheme.rawValue {
        case "ocean":
            return Color(red: 0.16, green: 0.17, blue: 0.21)
        case "github":
            return Color.white
        default:
            return Color(red: 0.16, green: 0.17, blue: 0.21)
        }
    }
    
    private var textColor: Color {
        switch currentTheme.rawValue {
        case "ocean":
            return Color(red: 0.65, green: 0.70, blue: 0.75)
        case "github":
            return Color(red: 0.20, green: 0.20, blue: 0.20)
        default:
            return Color(red: 0.65, green: 0.70, blue: 0.75)
        }
    }
    
    private func handleContentChange(_ newValue: String) {
        print("📝 Content changed - length: \(newValue.count)")
        
        // Cancel previous debounce task
        debounceTask?.cancel()
        
        // Create new debounce task
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms
            
            if !Task.isCancelled {
                await MainActor.run {
                    viewModel.jsonContent = newValue
                    Task {
                        await viewModel.validate()
                    }
                }
            }
        }
    }
}