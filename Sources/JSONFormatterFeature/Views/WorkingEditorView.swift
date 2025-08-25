import SwiftUI
import AppKit

// Working editor view that properly displays
struct WorkingEditorView: View {
    @Bindable var viewModel: DocumentViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Editor toolbar
            HStack {
                Text("JSON Editor")
                    .font(.headline)
                Spacer()
                
                if !viewModel.validationErrors.isEmpty {
                    Label("\(viewModel.validationErrors.count) issues", systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                }
                
                if viewModel.isValidating {
                    ProgressView()
                        .scaleEffect(0.5)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
            
            // Use TextEditor for now - it works reliably
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    // Line numbers
                    LineNumbersView(text: viewModel.jsonContent)
                        .frame(width: 50)
                        .background(Color(NSColor.controlBackgroundColor))
                    
                    Divider()
                    
                    // Text editor
                    TextEditor(text: $viewModel.jsonContent)
                        .font(.system(.body, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .background(Color(NSColor.textBackgroundColor))
                        .onChange(of: viewModel.jsonContent) { _, _ in
                            Task { await viewModel.validate() }
                        }
                }
            }
        }
    }
}

// Line numbers view
struct LineNumbersView: View {
    let text: String
    
    var lineCount: Int {
        text.isEmpty ? 1 : text.components(separatedBy: .newlines).count
    }
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .trailing, spacing: 0) {
                ForEach(1...lineCount, id: \.self) { lineNumber in
                    Text("\(lineNumber)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(height: 20, alignment: .trailing)
                        .padding(.trailing, 8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}

// Alternative: Custom NSTextView that definitely works
struct CustomJSONEditor: NSViewRepresentable {
    @Binding var text: String
    let onChange: () -> Void
    
    func makeNSView(context: Context) -> NSView {
        let containerView = NSView()
        
        // Create scroll view
        let scrollView = NSTextView.scrollableTextView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(scrollView)
        
        // Add constraints
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: containerView.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        // Configure text view
        if let textView = scrollView.documentView as? NSTextView {
            textView.string = text
            textView.delegate = context.coordinator
            textView.isAutomaticQuoteSubstitutionEnabled = false
            textView.isAutomaticSpellingCorrectionEnabled = false
            textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
            textView.isRichText = false
            textView.importsGraphics = false
            textView.isEditable = true
            textView.isSelectable = true
            textView.allowsUndo = true
            textView.isVerticallyResizable = true
            textView.isHorizontallyResizable = false
            textView.textContainer?.widthTracksTextView = true
            textView.textContainer?.containerSize = CGSize(
                width: CGFloat.greatestFiniteMagnitude,
                height: CGFloat.greatestFiniteMagnitude
            )
            
            // Add line numbers
            scrollView.hasVerticalRuler = true
            scrollView.rulersVisible = true
            
            let rulerView = JSONLineNumberRulerView(textView: textView)
            scrollView.verticalRulerView = rulerView
        }
        
        return containerView
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        guard let scrollView = nsView.subviews.first as? NSScrollView,
              let textView = scrollView.documentView as? NSTextView else { return }
        
        if !context.coordinator.isUpdating && textView.string != text {
            textView.string = text
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    @MainActor
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CustomJSONEditor
        var isUpdating = false
        private var validationTask: Task<Void, Never>?
        
        init(_ parent: CustomJSONEditor) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            
            isUpdating = true
            parent.text = textView.string
            isUpdating = false
            
            // Cancel previous task and create new one
            validationTask?.cancel()
            validationTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 500_000_000)
                if !Task.isCancelled {
                    self?.parent.onChange()
                }
            }
        }
    }
}

// Line number ruler
class JSONLineNumberRulerView: NSRulerView {
    weak var textView: NSTextView?
    
    init(textView: NSTextView) {
        self.textView = textView
        super.init(scrollView: textView.enclosingScrollView, orientation: .verticalRuler)
        self.clientView = textView
        self.ruleThickness = 50
    }
    
    required init(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView = textView else { return }
        
        // Background
        NSColor.controlBackgroundColor.set()
        rect.fill()
        
        // Separator
        NSColor.separatorColor.set()
        NSRect(x: rect.maxX - 1, y: 0, width: 1, height: rect.height).fill()
        
        // Get visible range
        let visibleRect = textView.visibleRect
        let textContainer = textView.textContainer!
        let layoutManager = textView.layoutManager!
        let textStorage = textView.textStorage!
        
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        let characterRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
        
        // Count lines
        let text = textStorage.string as NSString
        var lineNumber = 0
        
        text.enumerateSubstrings(
            in: NSRange(location: 0, length: characterRange.location + characterRange.length),
            options: [.byLines, .substringNotRequired]
        ) { _, range, _, _ in
            lineNumber += 1
            
            if NSLocationInRange(range.location, characterRange) {
                let lineRect = layoutManager.lineFragmentRect(
                    forGlyphAt: layoutManager.glyphIndexForCharacter(at: range.location),
                    effectiveRange: nil
                )
                
                let y = lineRect.origin.y - visibleRect.origin.y
                
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular),
                    .foregroundColor: NSColor.secondaryLabelColor
                ]
                
                let lineString = "\(lineNumber)"
                let size = lineString.size(withAttributes: attrs)
                let drawRect = NSRect(
                    x: rect.width - size.width - 5,
                    y: y,
                    width: size.width,
                    height: size.height
                )
                
                lineString.draw(in: drawRect, withAttributes: attrs)
            }
        }
    }
    
    override var requiredThickness: CGFloat {
        return 50
    }
}

// Alternative simple working editor
struct FallbackEditorView: View {
    @Bindable var viewModel: DocumentViewModel
    @State private var debounceTask: Task<Void, Never>?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("JSON Editor")
                    .font(.headline)
                Spacer()
                if !viewModel.validationErrors.isEmpty {
                    Label("\(viewModel.validationErrors.count) issues", systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            // Editor with basic TextEditor
            TextEditor(text: $viewModel.jsonContent)
                .font(.system(size: 13, design: .monospaced))
                .onChange(of: viewModel.jsonContent) { _, newValue in
                    debounceTask?.cancel()
                    debounceTask = Task {
                        try? await Task.sleep(nanoseconds: 500_000_000)
                        if !Task.isCancelled {
                            await viewModel.validate()
                        }
                    }
                }
        }
    }
}