import SwiftUI
import JSONFormatterFeature

@main
struct JSONFormatterApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 900, minHeight: 700)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            // Add Edit menu commands
            CommandGroup(after: .pasteboard) {
                Divider()
                Button("Clear All") {
                    NotificationCenter.default.post(name: NSNotification.Name("ClearContent"), object: nil)
                }
                .keyboardShortcut("k", modifiers: .command)
                
                Button("Copy JSON to Clipboard") {
                    NotificationCenter.default.post(name: NSNotification.Name("CopyToClipboard"), object: nil)
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                
                Button("Paste from Clipboard") {
                    NotificationCenter.default.post(name: NSNotification.Name("PasteFromClipboard"), object: nil)
                }
                .keyboardShortcut("v", modifiers: [.command, .shift])
            }
            
            // Add Format menu
            CommandMenu("Format") {
                Button("Format JSON") {
                    NotificationCenter.default.post(name: NSNotification.Name("FormatJSON"), object: nil)
                }
                .keyboardShortcut("f", modifiers: .command)
                
                Button("Minify JSON") {
                    NotificationCenter.default.post(name: NSNotification.Name("MinifyJSON"), object: nil)
                }
                .keyboardShortcut("m", modifiers: .command)
                
                Divider()
                
                Button("Auto Fix") {
                    NotificationCenter.default.post(name: NSNotification.Name("AutoFixJSON"), object: nil)
                }
                .keyboardShortcut("r", modifiers: .command)
                
                Button("Validate") {
                    NotificationCenter.default.post(name: NSNotification.Name("ValidateJSON"), object: nil)
                }
            }
        }
    }
}