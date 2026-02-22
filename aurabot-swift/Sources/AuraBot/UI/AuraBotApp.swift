import SwiftUI
import KeyboardShortcuts

@main
@available(macOS 12.3, *)
struct AuraBotApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .frame(minWidth: 1000, minHeight: 700)
        }
        .windowStyle(.hiddenTitleBar)
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
            }
        }
        
        Settings {
            SettingsView()
        }
    }
}

extension Notification.Name {
    static let showNewMemory = Notification.Name("showNewMemory")
    static let triggerQuickEnhance = Notification.Name("triggerQuickEnhance")
}
