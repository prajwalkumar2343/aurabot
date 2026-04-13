import SwiftUI

@main
@available(macOS 14.0, *)
struct AuraBotApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView(service: appDelegate.service)
                .frame(minWidth: 1100, minHeight: 750)
                .background(Colors.background)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultPosition(.center)
        .commands {
            CommandMenu("AuraBot") {
                Button("New Memory") {
                    NotificationCenter.default.post(name: .showNewMemory, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
                
                Button("Quick Enhance") {
                    NotificationCenter.default.post(name: .triggerQuickEnhance, object: nil)
                }
                .keyboardShortcut("e", modifiers: [.command, .option])
                
                Divider()
                
                Button("Toggle Capture") {
                    NotificationCenter.default.post(name: .toggleCapture, object: nil)
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
            }
            
            CommandGroup(after: .windowArrangement) {
                Button("Show Sidebar") {
                    NotificationCenter.default.post(name: .showSidebar, object: nil)
                }
                .keyboardShortcut("b", modifiers: .command)
            }
        }
        
        Settings {
            SettingsView(service: appDelegate.service)
                .frame(width: 600, height: 600)
        }
    }
}

// MARK: - Notifications
extension Notification.Name {
    static let showNewMemory = Notification.Name("showNewMemory")
    static let triggerQuickEnhance = Notification.Name("triggerQuickEnhance")
    static let toggleCapture = Notification.Name("toggleCapture")
    static let showSidebar = Notification.Name("showSidebar")
}
