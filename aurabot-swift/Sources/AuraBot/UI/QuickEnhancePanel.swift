import Cocoa
import SwiftUI

@available(macOS 14.0, *)
class QuickEnhancePanel: NSPanel {
    private let service: AppService
    private var hostingView: NSHostingView<QuickEnhanceView>?
    
    init(service: AppService) {
        self.service = service
        
        let view = QuickEnhanceView(service: service, onClose: {})
        let hostingView = NSHostingView(rootView: view)
        
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 480),
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
        shadow?.shadowColor = NSColor.black.withAlphaComponent(0.2)
        collectionBehavior = [.canJoinAllSpaces, .transient]
        
        // Center on screen
        if let screen = NSScreen.main {
            let screenFrame = screen.frame
            let x = (screenFrame.width - 560) / 2
            let y = (screenFrame.height - 480) / 2
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

@available(macOS 14.0, *)
struct QuickEnhanceView: View {
    @StateObject var service: AppService
    let onClose: () -> Void
    
    @State private var originalText: String = ""
    @State private var enhancedText: String = ""
    @State private var isEnhancing: Bool = false
    @State private var memories: [String] = []
    @State private var showResult: Bool = false
    @State private var appearAnimation = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Glass header
            HeaderView(onClose: onClose)
            
            // Content
            ScrollView(showsIndicators: false) {
                VStack(spacing: Spacing.xl) {
                    // Original text
                    InputSection(
                        title: "Original Text",
                        text: $originalText,
                        placeholder: "Paste or type text to enhance with your memories...",
                        isEditable: !isEnhancing
                    )
                    
                    // Enhance button
                    EnhanceButton(
                        isEnhancing: isEnhancing,
                        isEnabled: !originalText.isEmpty,
                        action: enhance
                    )
                    
                    // Enhanced result
                    if showResult {
                        ResultSection(
                            text: $enhancedText,
                            memoryCount: memories.count,
                            onCopy: copyEnhanced,
                            onPasteReplace: pasteEnhanced
                        )
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .opacity
                        ))
                    }
                }
                .padding(Spacing.xl)
            }
        }
        .frame(width: 560, height: 480)
        .background(
            ZStack {
                // Glass background
                RoundedRectangle(cornerRadius: Radius.xxl)
                    .fill(.ultraThinMaterial)
                
                // Subtle gradient overlay
                RoundedRectangle(cornerRadius: Radius.xxl)
                    .fill(
                        LinearGradient(
                            colors: [
                                Colors.primary.opacity(0.05),
                                Colors.secondary.opacity(0.02)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // Border
                RoundedRectangle(cornerRadius: Radius.xxl)
                    .stroke(Colors.border, lineWidth: 1)
            }
        )
        .shadow(color: Shadows.xl.color, radius: Shadows.xl.radius, x: Shadows.xl.x, y: Shadows.xl.y)
        .opacity(appearAnimation ? 1 : 0)
        .scaleEffect(appearAnimation ? 1 : 0.9)
        .onAppear {
            withAnimation(AnimationPresets.spring) {
                appearAnimation = true
            }
        }
    }
    
    private func enhance() {
        isEnhancing = true
        showResult = false
        
        Task {
            do {
                let result = try await service.enhance(text: originalText)
                await MainActor.run {
                    withAnimation(AnimationPresets.spring) {
                        enhancedText = result.enhancedPrompt
                        memories = result.memoriesUsed
                        showResult = true
                        isEnhancing = false
                    }
                }
            } catch {
                await MainActor.run {
                    isEnhancing = false
                }
            }
        }
    }
    
    private func copyEnhanced() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(enhancedText, forType: .string)
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

@available(macOS 14.0, *)
struct HeaderView: View {
    let onClose: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        HStack {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Colors.primary)
                
                Text("Quick Enhance")
                    .font(Typography.headline)
                    .foregroundColor(Colors.textPrimary)
            }
            
            Spacer()
            
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Colors.textMuted)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(isHovered ? Colors.surfaceHover : Color.clear)
                    )
            }
            .buttonStyle(.plain)
            .scaleEffect(isHovered ? 1.1 : 1.0)
            .animation(AnimationPresets.hover, value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.vertical, Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: Radius.xxl)
                .fill(.ultraThinMaterial)
        )
    }
}

@available(macOS 14.0, *)
struct InputSection: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    let isEditable: Bool
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(title)
                .font(Typography.caption)
                .fontWeight(.medium)
                .foregroundColor(Colors.textMuted)
                .textCase(.uppercase)
            
            TextEditor(text: $text)
                .font(Typography.body)
                .foregroundColor(Colors.textPrimary)
                .focused($isFocused)
                .disabled(!isEditable)
                .scrollContentBackground(.hidden)
                .padding(Spacing.md)
                .frame(minHeight: 100)
                .background(
                    RoundedRectangle(cornerRadius: Radius.lg)
                        .fill(Colors.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.lg)
                                .stroke(isFocused ? Colors.borderFocus : Colors.border, lineWidth: isFocused ? 2 : 1)
                        )
                )
                .overlay(
                    Group {
                        if text.isEmpty {
                            Text(placeholder)
                                .font(Typography.body)
                                .foregroundColor(Colors.textMuted)
                                .padding(Spacing.md)
                                .allowsHitTesting(false)
                        }
                    },
                    alignment: .topLeading
                )
        }
    }
}

@available(macOS 14.0, *)
struct EnhanceButton: View {
    let isEnhancing: Bool
    let isEnabled: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    @State private var pulseScale: CGFloat = 1
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.md) {
                if isEnhancing {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 18, weight: .semibold))
                }
                
                Text(isEnhancing ? "Enhancing..." : "Enhance with Memories")
                    .font(.system(size: 15, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.lg)
            .background(
                ZStack {
                    // Gradient background
                    RoundedRectangle(cornerRadius: Radius.lg)
                        .fill(
                            LinearGradient(
                                colors: isEnabled
                                    ? [Colors.primary, Colors.secondary]
                                    : [Colors.textMuted, Colors.textMuted.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    // Pulse effect when idle and enabled
                    if isEnabled && !isEnhancing && !isHovered {
                        RoundedRectangle(cornerRadius: Radius.lg)
                            .stroke(Colors.primary.opacity(0.5), lineWidth: 2)
                            .scaleEffect(pulseScale)
                            .opacity(2 - pulseScale)
                    }
                }
            )
            .foregroundColor(.white)
            .shadow(
                color: isEnabled ? Colors.primary.opacity(0.4) : Color.clear,
                radius: isHovered ? 20 : 12,
                x: 0,
                y: isHovered ? 8 : 4
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || isEnhancing)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(AnimationPresets.hover, value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .onAppear {
            if isEnabled && !isEnhancing {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                    pulseScale = 1.5
                }
            }
        }
    }
}

@available(macOS 14.0, *)
struct ResultSection: View {
    @Binding var text: String
    let memoryCount: Int
    let onCopy: () -> Void
    let onPasteReplace: () -> Void
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Header with memory chips
            HStack {
                HStack(spacing: Spacing.xs) {
                    Text("Enhanced")
                        .font(Typography.caption)
                        .fontWeight(.medium)
                        .foregroundColor(Colors.textMuted)
                        .textCase(.uppercase)
                    
                    Text("\(memoryCount)")
                        .font(Typography.caption)
                        .fontWeight(.bold)
                        .foregroundColor(Colors.primary)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, 2)
                        .background(Colors.primary.opacity(0.1))
                        .cornerRadius(Radius.sm)
                    
                    Text("memories used")
                        .font(Typography.caption)
                        .foregroundColor(Colors.textMuted)
                }
                
                Spacer()
            }
            
            // Enhanced text
            TextEditor(text: $text)
                .font(Typography.body)
                .foregroundColor(Colors.textPrimary)
                .focused($isFocused)
                .scrollContentBackground(.hidden)
                .padding(Spacing.md)
                .frame(minHeight: 100)
                .background(
                    RoundedRectangle(cornerRadius: Radius.lg)
                        .fill(Colors.primary.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.lg)
                                .stroke(Colors.primary.opacity(0.2), lineWidth: 1)
                        )
                )
            
            // Action buttons
            HStack(spacing: Spacing.md) {
                SecondaryButton("Copy", icon: "doc.on.doc") {
                    onCopy()
                }
                
                GradientButton("Paste & Replace", icon: "arrow.down.doc") {
                    onPasteReplace()
                }
            }
        }
    }
}

@available(macOS 14.0, *)
struct QuickEnhanceView_Previews: PreviewProvider {
    static var previews: some View {
        QuickEnhanceView(service: AppService(), onClose: {})
            .frame(width: 560, height: 480)
    }
}
