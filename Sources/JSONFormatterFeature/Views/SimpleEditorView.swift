import SwiftUI
import AppKit

// Simple working editor view
struct SimpleEditorView: View {
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
            
            // Simple text editor
            SimpleJSONTextEditor(
                text: $viewModel.jsonContent,
                onChange: {
                    Task { await viewModel.validate() }
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// Simplified NSViewRepresentable
struct SimpleJSONTextEditor: NSViewRepresentable {
    @Binding var text: String
    let onChange: () -> Void
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        
        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }
        
        // Configure text view
        textView.delegate = context.coordinator
        textView.string = text
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isRichText = true // Enable rich text for syntax highlighting
        textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textColor = NSColor.labelColor
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.allowsUndo = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        
        // Set up line numbers
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = true
        
        let lineNumberView = SimpleLineNumberView(textView: textView)
        scrollView.verticalRulerView = lineNumberView
        
        // Initial syntax highlighting
        context.coordinator.highlightSyntax(in: textView)
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        
        // Only update if text changed externally
        if !context.coordinator.isInternalUpdate && textView.string != text {
            textView.string = text
            context.coordinator.highlightSyntax(in: textView)
        }
        context.coordinator.isInternalUpdate = false
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: SimpleJSONTextEditor
        var isInternalUpdate = false
        private var validationTask: Task<Void, Never>?
        
        init(_ parent: SimpleJSONTextEditor) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            
            // Update binding
            isInternalUpdate = true
            parent.text = textView.string
            
            // Cancel previous validation
            validationTask?.cancel()
            
            // Debounce validation
            validationTask = Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 500_000_000)
                guard !Task.isCancelled else { return }
                self?.parent.onChange()
            }
            
            // Apply syntax highlighting asynchronously
            DispatchQueue.main.async { [weak self] in
                self?.highlightSyntax(in: textView)
            }
        }
        
        @MainActor
        func highlightSyntax(in textView: NSTextView) {
            let text = textView.string
            guard !text.isEmpty else { return }
            
            let textStorage = textView.textStorage!
            let selectedRange = textView.selectedRange()
            
            // Begin editing
            textStorage.beginEditing()
            
            // Reset to default
            let fullRange = NSRange(location: 0, length: text.count)
            textStorage.removeAttribute(.foregroundColor, range: fullRange)
            textStorage.addAttribute(.foregroundColor, value: NSColor.labelColor, range: fullRange)
            textStorage.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular), range: fullRange)
            
            // Apply highlighting
            highlightJSONSyntax(text: text, textStorage: textStorage)
            
            // End editing
            textStorage.endEditing()
            
            // Restore selection
            textView.setSelectedRange(selectedRange)
        }
        
        private func highlightJSONSyntax(text: String, textStorage: NSTextStorage) {
            // Colors
            let keyColor = NSColor.systemBlue
            let stringColor = NSColor.systemGreen
            let numberColor = NSColor.systemPurple
            let boolColor = NSColor.systemOrange
            let nullColor = NSColor.systemRed
            
            do {
                // Highlight strings (both keys and values)
                let stringPattern = "\"[^\"\\\\]*(?:\\\\.[^\"\\\\]*)*\""
                let stringRegex = try NSRegularExpression(pattern: stringPattern)
                let stringMatches = stringRegex.matches(in: text, range: NSRange(location: 0, length: text.count))
                
                for match in stringMatches {
                    // Check if it's a key (followed by colon)
                    var isKey = false
                    let endIndex = match.range.location + match.range.length
                    if endIndex < text.count {
                        let afterRange = NSRange(location: endIndex, length: min(10, text.count - endIndex))
                        let afterText = (text as NSString).substring(with: afterRange)
                        if afterText.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix(":") {
                            isKey = true
                        }
                    }
                    
                    textStorage.addAttribute(.foregroundColor, 
                                            value: isKey ? keyColor : stringColor,
                                            range: match.range)
                }
                
                // Highlight numbers
                let numberPattern = "(?<=[\\[,:{}\\s])-?\\d+(\\.\\d+)?([eE][+-]?\\d+)?(?=[\\],}\\s])"
                let numberRegex = try NSRegularExpression(pattern: numberPattern)
                let numberMatches = numberRegex.matches(in: text, range: NSRange(location: 0, length: text.count))
                
                for match in numberMatches {
                    textStorage.addAttribute(.foregroundColor, value: numberColor, range: match.range)
                }
                
                // Highlight booleans
                let boolPattern = "\\b(true|false)\\b"
                let boolRegex = try NSRegularExpression(pattern: boolPattern)
                let boolMatches = boolRegex.matches(in: text, range: NSRange(location: 0, length: text.count))
                
                for match in boolMatches {
                    textStorage.addAttribute(.foregroundColor, value: boolColor, range: match.range)
                }
                
                // Highlight null
                let nullPattern = "\\bnull\\b"
                let nullRegex = try NSRegularExpression(pattern: nullPattern)
                let nullMatches = nullRegex.matches(in: text, range: NSRange(location: 0, length: text.count))
                
                for match in nullMatches {
                    textStorage.addAttribute(.foregroundColor, value: nullColor, range: match.range)
                }
                
            } catch {
                print("Syntax highlighting error: \(error)")
            }
        }
    }
}

// Simple line number view
class SimpleLineNumberView: NSRulerView {
    weak var textView: NSTextView?
    
    init(textView: NSTextView) {
        self.textView = textView
        super.init(scrollView: textView.enclosingScrollView, orientation: .verticalRuler)
        self.clientView = textView
        self.ruleThickness = 50
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView = self.textView,
              let textContainer = textView.textContainer,
              let layoutManager = textView.layoutManager else { return }
        
        // Clear background
        NSColor.controlBackgroundColor.set()
        rect.fill()
        
        // Draw separator
        NSColor.separatorColor.set()
        NSRect(x: rect.maxX - 1, y: rect.minY, width: 1, height: rect.height).fill()
        
        let content = textView.string
        let lines = content.components(separatedBy: .newlines)
        
        let visibleGlyphRange = layoutManager.glyphRange(forBoundingRect: textView.visibleRect, in: textContainer)
        let visibleCharacterRange = layoutManager.characterRange(forGlyphRange: visibleGlyphRange, actualGlyphRange: nil)
        
        var lineNumber = 1
        var charIndex = 0
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        
        for line in lines {
            if charIndex > visibleCharacterRange.location + visibleCharacterRange.length {
                break
            }
            
            if charIndex + line.count >= visibleCharacterRange.location {
                let glyphIndex = layoutManager.glyphIndexForCharacter(at: charIndex)
                let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)
                
                if lineRect.minY < textView.visibleRect.maxY && lineRect.maxY > textView.visibleRect.minY {
                    let y = lineRect.minY - textView.visibleRect.minY
                    let lineString = "\(lineNumber)"
                    let size = lineString.size(withAttributes: attributes)
                    let drawRect = NSRect(x: rect.width - size.width - 5, y: y, width: size.width, height: size.height)
                    lineString.draw(in: drawRect, withAttributes: attributes)
                }
            }
            
            charIndex += line.count + 1
            lineNumber += 1
        }
    }
    
    override var requiredThickness: CGFloat {
        return 50
    }
}