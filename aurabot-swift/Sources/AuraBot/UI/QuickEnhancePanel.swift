import Cocoa
import SwiftUI

@available(macOS 12.3, *)
class QuickEnhancePanel: NSPanel {
    private let service: AppService?
    private var hostingView: NSHostingView<QuickEnhanceView>?
    
    init(service: AppService?) {
        self.service = service
        
        let view = QuickEnhanceView(service: service, onClose: {})
        let hostingView = NSHostingView(rootView: view)
        
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 400),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        setupWindow()
        self.hostingView = hostingView
        contentView = hostingView
    }
    
    private func setupWindow() {
        level = .floating
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        collectionBehavior = [.canJoinAllSpaces, .transient]
        
        // Center on screen
        if let screen = NSScreen.main {
            let screenFrame = screen.frame
            let x = (screenFrame.width - 520) / 2
            let y = (screenFrame.height - 400) / 2
            setFrameOrigin(NSPoint(x: x, y: y))
        }
    }
    
    func setText(_ text: String) {
        // Update the view with text
    }
    
    func show() {
        makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@available(macOS 12.3, *)
struct QuickEnhanceView: View {
    @StateObject var service: AppService?
    let onClose: () -> Void
    
    @State private var originalText: String = ""
    @State private var enhancedText: String = ""
    @State private var isEnhancing: Bool = false
    @State private var memories: [String] = []
    @State private var showResult: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Label("Quick Enhance", systemImage: "bolt.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color.purple)
            
            // Content
            VStack(spacing: 16) {
                // Original text
                VStack(alignment: .leading, spacing: 4) {
                    Text("Original")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextEditor(text: $originalText)
                        .frame(height: 80)
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
                
                // Enhance button
                Button(action: enhance) {
                    HStack {
                        if isEnhancing {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "bolt.fill")
                        }
                        Text(isEnhancing ? "Enhancing..." : "Enhance with Memories")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(isEnhancing || originalText.isEmpty)
                
                // Enhanced text
                if showResult {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Enhanced")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text("\(memories.count) memories")
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.yellow.opacity(0.2))
                                .cornerRadius(4)
                        }
                        
                        TextEditor(text: $enhancedText)
                            .frame(height: 80)
                            .padding(8)
                            .background(Color.purple.opacity(0.05))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.purple.opacity(0.2), lineWidth: 1)
                            )
                    }
                    
                    // Action buttons
                    HStack {
                        Button("Copy") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(enhancedText, forType: .string)
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Paste & Replace") {
                            pasteEnhanced()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .padding()
            
            Spacer()
        }
        .frame(width: 520, height: 400)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 20)
    }
    
    private func enhance() {
        guard let service = service else { return }
        
        isEnhancing = true
        showResult = false
        
        Task {
            do {
                let result = try await service.enhance(text: originalText)
                await MainActor.run {
                    enhancedText = result.enhancedPrompt
                    memories = result.memoriesUsed
                    showResult = true
                    isEnhancing = false
                }
            } catch {
                await MainActor.run {
                    isEnhancing = false
                }
            }
        }
    }
    
    private func pasteEnhanced() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(enhancedText, forType: .string)
        
        // Simulate paste
        let source = CGEventSource(stateID: .combinedSessionState)
        let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: true)
        let vDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        let vUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: false)
        
        cmdDown?.flags = .maskCommand
        vDown?.flags = .maskCommand
        
        cmdDown?.post(tap: .cghidEventTap)
        vDown?.post(tap: .cghidEventTap)
        vUp?.post(tap: .cghidEventTap)
        cmdUp?.post(tap: .cghidEventTap)
        
        onClose()
    }
}
