import SwiftUI
import AppKit

// Xcode-style inline error display
struct XcodeStyleErrorView: View {
    let errors: [JSONError]
    let text: String
    let fontSize: CGFloat
    let onFixTapped: (JSONError) -> Void
    
    @State private var expandedError: JSONError?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                // Inline error indicators
                ForEach(errors, id: \.self) { error in
                    InlineErrorIndicator(
                        error: error,
                        text: text,
                        fontSize: fontSize,
                        isExpanded: expandedError == error,
                        onTap: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if expandedError == error {
                                    expandedError = nil
                                } else {
                                    expandedError = error
                                }
                            }
                        },
                        onFix: {
                            onFixTapped(error)
                            expandedError = nil
                        }
                    )
                }
            }
        }
        .allowsHitTesting(true)
    }
}

struct InlineErrorIndicator: View {
    let error: JSONError
    let text: String
    let fontSize: CGFloat
    let isExpanded: Bool
    let onTap: () -> Void
    let onFix: () -> Void
    
    private var position: CGPoint {
        calculateInlinePosition(for: error, in: text, fontSize: fontSize)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Inline error indicator with message
            HStack(spacing: 4) {
                // Red circle with X
                Button(action: onTap) {
                    ZStack {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 16, height: 16)
                        
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)
                
                // Error message inline (always visible like Xcode)
                Text(error.message)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Color.red)
                    .cornerRadius(3)
            }
            
            // Expanded error detail (appears below when clicked)
            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    // Error message box
                    HStack(alignment: .top, spacing: 8) {
                        // Red error icon
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.red)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            // Main error message
                            Text(error.message)
                                .font(.system(size: 13))
                                .foregroundColor(.primary)
                            
                            // Suggestion if available
                            if let suggestion = error.suggestion {
                                HStack(spacing: 8) {
                                    Image(systemName: "lightbulb.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(.orange)
                                    
                                    Text(suggestion)
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    Button("Apply") {
                                        onFix()
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.small)
                                }
                                .padding(.top, 4)
                            }
                            
                            // Location info
                            Text("Line \(error.line), Column \(error.column)")
                                .font(.system(size: 11))
                                .foregroundColor(Color.secondary.opacity(0.7))
                        }
                    }
                    .padding(12)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.red.opacity(0.3), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                }
                .frame(width: 400)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.8, anchor: .topLeading).combined(with: .opacity),
                    removal: .scale(scale: 0.8, anchor: .topLeading).combined(with: .opacity)
                ))
            }
        }
        .position(position)
    }
    
    private func calculateInlinePosition(for error: JSONError, in text: String, fontSize: CGFloat) -> CGPoint {
        // Use more accurate line height for CodeEditor
        let lineHeight: CGFloat = fontSize * 1.15  // Adjust based on actual font size
        
        // Split text into lines
        let lines = text.components(separatedBy: .newlines)
        
        // Calculate Y position (error.line is 1-based)
        // Center vertically on the line
        let y = CGFloat(error.line - 1) * lineHeight + lineHeight / 2
        
        // Calculate X position - position far to the right to avoid overlapping content
        var x: CGFloat = 500 // Start far to the right
        
        if error.line > 0 && error.line <= lines.count {
            let lineContent = lines[error.line - 1]
            // More accurate character width for monospace font at given size
            let charWidth = fontSize * 0.6
            // Position well after the line content
            let minX = CGFloat(lineContent.count) * charWidth + 100
            x = max(minX, 500) // Ensure it's far enough to the right
        }
        
        return CGPoint(x: x, y: y)
    }
}

// Helper view for error squiggly underlines (optional enhancement)
struct ErrorUnderlineView: View {
    let error: JSONError
    let text: String
    let fontSize: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let position = calculateUnderlinePosition(for: error, in: text, fontSize: fontSize)
                let startX = position.x
                let y = position.y
                let length: CGFloat = 40 // Default error underline length
                
                // Create squiggly line like Xcode
                path.move(to: CGPoint(x: startX, y: y))
                
                var x = startX
                var up = true
                while x < startX + length {
                    let nextX = min(x + 3, startX + length)
                    let nextY = y + (up ? -1 : 1)
                    path.addLine(to: CGPoint(x: nextX, y: nextY))
                    x = nextX
                    up.toggle()
                }
            }
            .stroke(Color.red, lineWidth: 1.5)
        }
        .allowsHitTesting(false)
    }
    
    private func calculateUnderlinePosition(for error: JSONError, in text: String, fontSize: CGFloat) -> CGPoint {
        let lineHeight = fontSize * 1.2
        let charWidth = fontSize * 0.6
        
        // Position underline below the text at error location
        let y = CGFloat(error.line - 1) * lineHeight + lineHeight + 2
        let x = CGFloat(error.column - 1) * charWidth + 60
        
        return CGPoint(x: x, y: y)
    }
}

