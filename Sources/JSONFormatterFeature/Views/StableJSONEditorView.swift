import SwiftUI
import CodeEditor

struct StableJSONEditorView: View {
    @Bindable var viewModel: DocumentViewModel
    
    // Local state to prevent re-renders
    @State private var localContent: String = ""
    @State private var isInternalUpdate = false
    @State private var debounceTask: Task<Void, Never>?
    @State private var currentTheme: CodeEditor.ThemeName = CodeEditor.ThemeName(rawValue: "ocean")
    @State private var fontSize: CGFloat = 13
    @State private var showErrors = false
    @State private var errorPanelHeight: CGFloat = 0
    
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
                    Text("Agate").tag(CodeEditor.ThemeName(rawValue: "agate"))
                    Text("Atom One Dark").tag(CodeEditor.ThemeName(rawValue: "atom-one-dark"))
                    Text("GitHub").tag(CodeEditor.ThemeName(rawValue: "github"))
                    Text("Xcode").tag(CodeEditor.ThemeName(rawValue: "xcode"))
                    Text("Pojoaque").tag(CodeEditor.ThemeName(rawValue: "pojoaque"))
                    Text("Tomorrow Night").tag(CodeEditor.ThemeName(rawValue: "tomorrow-night"))
                }
                .pickerStyle(.menu)
                .frame(width: 120)
                
                Divider()
                    .frame(height: 20)
                    .padding(.horizontal, 8)
                
                // Font size controls
                Button(action: { fontSize = max(10, fontSize - 1) }) {
                    Image(systemName: "textformat.size.smaller")
                }
                .buttonStyle(.plain)
                
                Text("\(Int(fontSize))pt")
                    .font(.caption)
                    .monospacedDigit()
                    .frame(width: 35)
                
                Button(action: { fontSize = min(24, fontSize + 1) }) {
                    Image(systemName: "textformat.size.larger")
                }
                .buttonStyle(.plain)
                
                Divider()
                    .frame(height: 20)
                    .padding(.horizontal, 8)
                
                // Validation status with toggle
                if !viewModel.validationErrors.isEmpty {
                    Button(action: { 
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showErrors.toggle()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Label("\(viewModel.validationErrors.count) issues", systemImage: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                            Image(systemName: showErrors ? "chevron.up" : "chevron.down")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                
                if viewModel.isValidating {
                    ProgressView()
                        .scaleEffect(0.5)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Main content area with stable layout
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    // JSON Code Editor
                    CodeEditor(
                        source: $localContent,
                        language: CodeEditor.Language(rawValue: "json"),
                        theme: currentTheme,
                        fontSize: .init(get: { fontSize }, set: { fontSize = $0 }),
                        flags: [.selectable, .editable, .smartIndent],
                        indentStyle: .softTab(width: 2)
                    )
                    .frame(height: geometry.size.height - errorPanelHeight)
                    
                    // Error panel with fixed space
                    if !viewModel.validationErrors.isEmpty {
                        Divider()
                            .opacity(showErrors ? 1 : 0)
                        
                        ErrorDetailsView(errors: viewModel.validationErrors)
                            .frame(height: errorPanelHeight)
                            .opacity(showErrors ? 1 : 0)
                            .background(Color(NSColor.controlBackgroundColor))
                    }
                }
            }
            .onAppear {
                // Initialize local content
                localContent = viewModel.jsonContent
            }
            .onChange(of: localContent) { _, newValue in
                // Update view model only when local content changes
                if !isInternalUpdate {
                    viewModel.jsonContent = newValue
                    
                    // Debounced validation
                    debounceTask?.cancel()
                    debounceTask = Task {
                        try? await Task.sleep(nanoseconds: 500_000_000)
                        if !Task.isCancelled {
                            await viewModel.validate()
                        }
                    }
                }
            }
            .onChange(of: viewModel.jsonContent) { _, newValue in
                // Update local content when view model changes externally
                if localContent != newValue {
                    isInternalUpdate = true
                    localContent = newValue
                    isInternalUpdate = false
                }
            }
            .onChange(of: viewModel.validationErrors) { _, newErrors in
                // Show errors panel when new errors appear
                if !newErrors.isEmpty && !showErrors {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showErrors = true
                        errorPanelHeight = 100
                    }
                } else if newErrors.isEmpty {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showErrors = false
                        errorPanelHeight = 0
                    }
                }
            }
            .onChange(of: showErrors) { _, show in
                withAnimation(.easeInOut(duration: 0.2)) {
                    errorPanelHeight = show && !viewModel.validationErrors.isEmpty ? 100 : 0
                }
            }
        }
    }
}