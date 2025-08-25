import SwiftUI
import AppKit

// Improved editor view with line numbers and better performance
struct ImprovedEditorView: View {
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
            
            // Text editor with line numbers
            ImprovedJSONEditor(
                text: $viewModel.jsonContent,
                errors: viewModel.validationErrors,
                onChange: {
                    Task { await viewModel.validate() }
                }
            )
        }
    }
}

// Custom NSTextStorage for better performance
class JSONTextStorage: NSTextStorage {
    private let backingStore = NSMutableAttributedString()
    private var needsHighlight = false
    
    override var string: String {
        return backingStore.string
    }
    
    override func attributes(at location: Int, effectiveRange range: NSRangePointer?) -> [NSAttributedString.Key : Any] {
        return backingStore.attributes(at: location, effectiveRange: range)
    }
    
    override func replaceCharacters(in range: NSRange, with str: String) {
        beginEditing()
        backingStore.replaceCharacters(in: range, with: str)
        edited(.editedCharacters, range: range, changeInLength: str.count - range.length)
        needsHighlight = true
        endEditing()
    }
    
    override func setAttributes(_ attrs: [NSAttributedString.Key : Any]?, range: NSRange) {
        beginEditing()
        backingStore.setAttributes(attrs, range: range)
        edited(.editedAttributes, range: range, changeInLength: 0)
        endEditing()
    }
    
    override func processEditing() {
        super.processEditing()
        // Don't highlight here - it causes cursor issues
    }
    
    func performHighlighting() {
        guard needsHighlight else { return }
        needsHighlight = false
        
        let text = string
        let fullRange = NSRange(location: 0, length: text.count)
        
        // Begin batch editing
        beginEditing()
        
        // Reset to default color
        removeAttribute(.foregroundColor, range: fullRange)
        addAttribute(.foregroundColor, value: NSColor.labelColor, range: fullRange)
        
        // Define colors
        let keyColor = NSColor.systemBlue
        let stringColor = NSColor.systemGreen
        let numberColor = NSColor.systemPurple
        let boolColor = NSColor.systemOrange
        let nullColor = NSColor.systemRed
        
        // Apply highlighting
        do {
            // Strings and keys
            let stringPattern = "\"[^\"]*\""
            let stringRegex = try NSRegularExpression(pattern: stringPattern)
            let stringMatches = stringRegex.matches(in: text, range: fullRange)
            
            for match in stringMatches {
                // let matchString = (text as NSString).substring(with: match.range)
                let endOfMatch = match.range.location + match.range.length
                
                // Check if it's a key (followed by colon)
                var isKey = false
                if endOfMatch < text.count {
                    let remainingRange = NSRange(location: endOfMatch, length: min(10, text.count - endOfMatch))
                    let remaining = (text as NSString).substring(with: remainingRange)
                    if remaining.trimmingCharacters(in: .whitespaces).hasPrefix(":") {
                        isKey = true
                    }
                }
                
                addAttribute(.foregroundColor, 
                           value: isKey ? keyColor : stringColor, 
                           range: match.range)
            }
            
            // Numbers
            let numberPattern = "\\b-?\\d+(\\.\\d+)?([eE][+-]?\\d+)?\\b"
            let numberRegex = try NSRegularExpression(pattern: numberPattern)
            let numberMatches = numberRegex.matches(in: text, range: fullRange)
            
            for match in numberMatches {
                addAttribute(.foregroundColor, value: numberColor, range: match.range)
            }
            
            // Booleans
            let boolPattern = "\\b(true|false)\\b"
            let boolRegex = try NSRegularExpression(pattern: boolPattern)
            let boolMatches = boolRegex.matches(in: text, range: fullRange)
            
            for match in boolMatches {
                addAttribute(.foregroundColor, value: boolColor, range: match.range)
            }
            
            // Null
            let nullPattern = "\\bnull\\b"
            let nullRegex = try NSRegularExpression(pattern: nullPattern)
            let nullMatches = nullRegex.matches(in: text, range: fullRange)
            
            for match in nullMatches {
                addAttribute(.foregroundColor, value: nullColor, range: match.range)
            }
            
        } catch {
            print("Regex error: \(error)")
        }
        
        // End batch editing
        endEditing()
    }
}

// Improved NSViewRepresentable with line numbers
struct ImprovedJSONEditor: NSViewRepresentable {
    @Binding var text: String
    let errors: [JSONError]
    let onChange: () -> Void
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        
        // Create line number ruler
        let lineNumberView = LineNumberRulerView(textView: nil)
        scrollView.verticalRulerView = lineNumberView
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = true
        
        // Create text view with custom text storage
        let textStorage = JSONTextStorage()
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        
        let textContainer = NSTextContainer()
        textContainer.widthTracksTextView = true
        textContainer.containerSize = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        layoutManager.addTextContainer(textContainer)
        
        let textView = NSTextView(frame: .zero, textContainer: textContainer)
        textView.delegate = context.coordinator
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isRichText = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textColor = NSColor.labelColor
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.allowsUndo = true
        
        scrollView.documentView = textView
        lineNumberView.textView = textView
        
        // Set initial text
        textView.string = text
        
        // Perform initial highlighting
        DispatchQueue.main.async {
            textStorage.performHighlighting()
        }
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        
        // Only update if text actually changed from external source
        if !context.coordinator.isUpdatingFromUI && textView.string != text {
            let selectedRange = textView.selectedRange()
            textView.string = text
            
            // Restore selection if possible
            if selectedRange.location <= text.count {
                textView.setSelectedRange(selectedRange)
            }
            
            // Update highlighting
            if let textStorage = textView.textStorage as? JSONTextStorage {
                DispatchQueue.main.async {
                    textStorage.performHighlighting()
                }
            }
        }
        
        context.coordinator.isUpdatingFromUI = false
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    @MainActor
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: ImprovedJSONEditor
        var isUpdatingFromUI = false
        private var validationTask: Task<Void, Never>?
        
        init(_ parent: ImprovedJSONEditor) {
            self.parent = parent
            super.init()
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            
            isUpdatingFromUI = true
            parent.text = textView.string
            
            // Cancel previous validation task
            validationTask?.cancel()
            
            // Debounce validation
            validationTask = Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                guard !Task.isCancelled else { return }
                self?.parent.onChange()
            }
            
            // Apply highlighting after text change
            if let textStorage = textView.textStorage as? JSONTextStorage {
                // Use async to avoid blocking UI
                DispatchQueue.main.async {
                    textStorage.performHighlighting()
                }
            }
        }
    }
}

// Line number ruler view
class LineNumberRulerView: NSRulerView {
    weak var textView: NSTextView?
    
    init(textView: NSTextView?) {
        self.textView = textView
        super.init(scrollView: nil, orientation: .verticalRuler)
        self.clientView = textView
        self.ruleThickness = 50
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView = textView,
              let textStorage = textView.textStorage,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }
        
        // Clear background
        NSColor.controlBackgroundColor.set()
        rect.fill()
        
        // Draw separator line
        NSColor.separatorColor.set()
        let separatorRect = NSRect(x: rect.maxX - 1, y: rect.minY, width: 1, height: rect.height)
        separatorRect.fill()
        
        let content = textStorage.string
        let lines = content.components(separatedBy: .newlines)
        
        let textVisibleRect = textView.visibleRect
        let glyphRange = layoutManager.glyphRange(forBoundingRect: textVisibleRect, in: textContainer)
        let characterRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
        
        var lineNumber = 1
        var charIndex = 0
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        
        for line in lines {
            let lineRange = NSRange(location: charIndex, length: line.count)
            
            if NSLocationInRange(lineRange.location, characterRange) ||
               NSLocationInRange(NSMaxRange(lineRange), characterRange) ||
               (lineRange.location <= characterRange.location && NSMaxRange(lineRange) >= NSMaxRange(characterRange)) {
                
                let lineRect = layoutManager.lineFragmentRect(forGlyphAt: layoutManager.glyphIndexForCharacter(at: charIndex), effectiveRange: nil)
                let y = lineRect.minY - textVisibleRect.minY
                
                let lineNumberString = "\(lineNumber)"
                let size = lineNumberString.size(withAttributes: attributes)
                let drawRect = NSRect(x: rect.width - size.width - 5, y: y, width: size.width, height: size.height)
                
                lineNumberString.draw(in: drawRect, withAttributes: attributes)
            }
            
            charIndex += line.count + 1 // +1 for newline
            lineNumber += 1
        }
    }
    
    override var requiredThickness: CGFloat {
        return 50
    }
}