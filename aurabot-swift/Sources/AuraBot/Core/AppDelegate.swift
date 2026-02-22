import Cocoa
import KeyboardShortcuts
import SwiftUI

@available(macOS 12.3, *)
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var overlayWindow: OverlayWindow?
    var quickEnhancePanel: QuickEnhancePanel?
    var service: AppService?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon
        NSApp.setActivationPolicy(.accessory)
        
        // Setup menu bar
        setupStatusItem()
        
        // Setup services
        let config = AppConfig.load(from: configPath)
        service = AppService(config: config)
        service?.start()
        
        // Setup global hotkey
        setupGlobalHotkey()
        
        // Create overlay window
        overlayWindow = OverlayWindow()
        overlayWindow?.onClick = { [weak self] in
            self?.showQuickEnhance()
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        service?.stop()
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.image = NSImage(systemSymbolName: "brain", accessibilityDescription: "AuraBot")
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show AuraBot", action: #selector(showMainWindow), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quick Enhance", action: #selector(triggerQuickEnhance), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApp.terminate(_:)), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }
    
    private func setupGlobalHotkey() {
        KeyboardShortcuts.onKeyUp(for: .quickEnhance) { [weak self] in
            self?.triggerQuickEnhance()
        }
    }
    
    @objc private func showMainWindow() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        
        for window in NSApp.windows {
            window.makeKeyAndOrderFront(nil)
        }
    }
    
    @objc func triggerQuickEnhance() {
        // Get selected text
        let pasteboard = NSPasteboard.general
        let originalContent = pasteboard.string(forType: .string)
        
        // Simulate copy
        simulateCopy()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            let selectedText = pasteboard.string(forType: .string) ?? ""
            
            // Restore original
            if let original = originalContent {
                pasteboard.clearContents()
                pasteboard.setString(original, forType: .string)
            }
            
            // Show overlay at cursor
            self?.showOverlay()
            
            // Show quick enhance panel
            self?.showQuickEnhance(text: selectedText)
        }
    }
    
    private func showOverlay() {
        guard let overlay = overlayWindow else { return }
        
        let mouseLoc = NSEvent.mouseLocation
        overlay.show(at: mouseLoc)
        
        // Auto hide after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.overlayWindow?.hide()
        }
    }
    
    private func showQuickEnhance(text: String = "") {
        if quickEnhancePanel == nil {
            quickEnhancePanel = QuickEnhancePanel(service: service)
        }
        
        quickEnhancePanel?.setText(text)
        quickEnhancePanel?.show()
    }
    
    private func simulateCopy() {
        let source = CGEventSource(stateID: .combinedSessionState)
        
        let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: true)
        let cDown = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: true)
        let cUp = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: false)
        let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: false)
        
        cmdDown?.flags = .maskCommand
        cDown?.flags = .maskCommand
        
        cmdDown?.post(tap: .cghidEventTap)
        cDown?.post(tap: .cghidEventTap)
        cUp?.post(tap: .cghidEventTap)
        cmdUp?.post(tap: .cghidEventTap)
    }
    
    private var configPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".aurabot/config.json").path
    }
}

extension KeyboardShortcuts.Name {
    static let quickEnhance = Self("quickEnhance", default: .init(.e, modifiers: [.command, .option]))
}
