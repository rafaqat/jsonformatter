import SwiftUI
import CodeEditor

struct NoFlashEditorView: View {
    @Bindable var viewModel: DocumentViewModel
    
    // Local state to prevent re-renders
    @State private var localContent: String = ""
    @State private var isInternalUpdate = false
    @State private var debounceTask: Task<Void, Never>?
    @State private var currentTheme: CodeEditor.ThemeName = CodeEditor.ThemeName(rawValue: "ocean")
    @State private var fontSize: CGFloat = 13
    
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
                
                // Validation status - only show count, no progress view
                if !viewModel.validationErrors.isEmpty {
                    Label("\(viewModel.validationErrors.count) issues", systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // JSON Code Editor
            CodeEditor(
                source: $localContent,
                language: CodeEditor.Language(rawValue: "json"),
                theme: currentTheme,
                fontSize: .init(get: { fontSize }, set: { fontSize = $0 }),
                flags: [.selectable, .editable, .smartIndent],
                indentStyle: .softTab(width: 2)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                        try? await Task.sleep(nanoseconds: 750_000_000) // Increased debounce time
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
            
            // Error panel - always present with fixed height
            Divider()
            
            ScrollView {
                if viewModel.validationErrors.isEmpty {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("Valid JSON")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding()
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(viewModel.validationErrors.enumerated()), id: \.offset) { index, error in
                            HStack(alignment: .top) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Line \(error.line), Column \(error.column)")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                    Text(error.message)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 4)
                            
                            if index < viewModel.validationErrors.count - 1 {
                                Divider()
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .frame(height: 80) // Fixed height - no layout shifts
            .background(Color(NSColor.controlBackgroundColor))
        }
    }
}