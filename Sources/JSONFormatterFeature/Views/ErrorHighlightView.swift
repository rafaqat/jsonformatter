import SwiftUI
import AppKit

struct ErrorHighlightView: View {
    let errors: [JSONError]
    let text: String
    let onFixTapped: (JSONError) -> Void
    
    @State private var hoveredError: JSONError?
    @State private var selectedError: JSONError?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                ForEach(errors, id: \.self) { error in
                    ErrorAnnotationView(
                        error: error,
                        text: text,
                        isHovered: hoveredError == error,
                        isSelected: selectedError == error,
                        onHover: { isHovering in
                            hoveredError = isHovering ? error : nil
                        },
                        onTap: {
                            selectedError = error
                        },
                        onFix: {
                            onFixTapped(error)
                        }
                    )
                }
            }
        }
        .allowsHitTesting(true)
    }
}

struct ErrorAnnotationView: View {
    let error: JSONError
    let text: String
    let isHovered: Bool
    let isSelected: Bool
    let onHover: (Bool) -> Void
    let onTap: () -> Void
    let onFix: () -> Void
    
    @State private var showPopover = false
    
    private var errorPosition: CGPoint {
        calculatePosition(for: error, in: text)
    }
    
    var body: some View {
        HStack(spacing: 0) {
            Image(systemName: error.severity == .error ? "xmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundColor(error.severity == .error ? .red : .orange)
                .font(.system(size: 14))
                .onHover { hovering in
                    onHover(hovering)
                }
                .onTapGesture {
                    onTap()
                    showPopover = true
                }
                .popover(isPresented: $showPopover) {
                    ErrorPopoverView(
                        error: error,
                        onFix: {
                            onFix()
                            showPopover = false
                        }
                    )
                }
        }
        .position(errorPosition)
        .opacity(isHovered || isSelected ? 1.0 : 0.7)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
    }
    
    private func calculatePosition(for error: JSONError, in text: String) -> CGPoint {
        // CodeEditor uses approximately 14px line height with the default font size
        let lineHeight: CGFloat = 14
        let characterWidth: CGFloat = 7.2
        
        // Calculate Y position - error.line is 1-based, so subtract 1
        // Position at the actual line, not offset
        let y = CGFloat(error.line - 1) * lineHeight + 8
        
        // Calculate X position - add some offset for line numbers gutter
        let x = CGFloat(error.column - 1) * characterWidth + 50
        
        return CGPoint(x: x, y: y)
    }
}

struct ErrorPopoverView: View {
    let error: JSONError
    let onFix: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: error.severity == .error ? "xmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(error.severity == .error ? .red : .orange)
                Text(error.severity == .error ? "Error" : "Warning")
                    .font(.headline)
                Spacer()
            }
            
            Text(error.message)
                .font(.system(.body, design: .monospaced))
                .fixedSize(horizontal: false, vertical: true)
            
            Text("Line \(error.line), Column \(error.column)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Divider()
            
            if error.suggestion != nil {
                HStack {
                    Button(action: onFix) {
                        Label("Fix", systemImage: "wand.and.stars")
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Spacer()
                }
            }
        }
        .padding()
        .frame(width: 300)
    }
}

extension JSONError: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(line)
        hasher.combine(column)
        hasher.combine(message)
    }
}