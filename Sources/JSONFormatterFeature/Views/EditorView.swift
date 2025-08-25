import SwiftUI
import AppKit

struct EditorView: View {
    @Bindable var viewModel: DocumentViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Editor toolbar
            HStack {
                Text("JSON Editor")
                    .font(.headline)
                Spacer()
                
                if viewModel.isValidating {
                    ProgressView()
                        .scaleEffect(0.5)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
            
            // Text editor
            JSONTextEditor(text: $viewModel.jsonContent, onChange: {
                Task { await viewModel.validate() }
            })
        }
    }
}

// NSViewRepresentable for NSTextView
struct JSONTextEditor: NSViewRepresentable {
    @Binding var text: String
    let onChange: () -> Void
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        
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
        textView.textContainer?.containerSize = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        
        if textView.string != text {
            textView.string = text
            highlightJSON(in: textView)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func highlightJSON(in textView: NSTextView) {
        let text = textView.string
        let textStorage = textView.textStorage!
        
        // Clear existing attributes
        textStorage.removeAttribute(.foregroundColor, range: NSRange(location: 0, length: text.count))
        textStorage.addAttribute(.foregroundColor, value: NSColor.labelColor, range: NSRange(location: 0, length: text.count))
        
        // Define colors
        let keyColor = NSColor.systemBlue
        let stringColor = NSColor.systemGreen
        let numberColor = NSColor.systemPurple
        let boolColor = NSColor.systemOrange
        let nullColor = NSColor.systemRed
        
        // Simple regex-based highlighting
        do {
            // Highlight strings
            let stringPattern = "\"[^\"]*\""
            let stringRegex = try NSRegularExpression(pattern: stringPattern)
            let stringMatches = stringRegex.matches(in: text, range: NSRange(location: 0, length: text.count))
            
            for match in stringMatches {
                // Check if this is a key (followed by colon)
                let endOfMatch = match.range.location + match.range.length
                if endOfMatch < text.count {
                    let nextCharIndex = text.index(text.startIndex, offsetBy: endOfMatch)
                    let remainingText = String(text[nextCharIndex...])
                    if remainingText.trimmingCharacters(in: .whitespaces).hasPrefix(":") {
                        textStorage.addAttribute(.foregroundColor, value: keyColor, range: match.range)
                    } else {
                        textStorage.addAttribute(.foregroundColor, value: stringColor, range: match.range)
                    }
                } else {
                    textStorage.addAttribute(.foregroundColor, value: stringColor, range: match.range)
                }
            }
            
            // Highlight numbers
            let numberPattern = "\\b-?\\d+(\\.\\d+)?([eE][+-]?\\d+)?\\b"
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
            print("Regex error: \(error)")
        }
    }
    
    @MainActor
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: JSONTextEditor
        private var debounceTimer: Timer?
        
        init(_ parent: JSONTextEditor) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            
            parent.text = textView.string
            
            // Debounce the onChange callback
            debounceTimer?.invalidate()
            
            // Use Task for async work instead of Timer to avoid concurrency issues
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                self?.parent.onChange()
            }
            
            // Apply syntax highlighting
            parent.highlightJSON(in: textView)
        }
    }
}