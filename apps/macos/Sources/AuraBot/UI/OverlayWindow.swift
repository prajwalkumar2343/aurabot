import Cocoa
import SwiftUI

@available(macOS 14.0, *)
class OverlayWindow: NSWindow {
    private let overlaySize = NSSize(width: 132, height: 132)
    private let screenInset: CGFloat = 24
    private var position: OverlayPosition
    
    init(position: OverlayPosition = .bottomRight) {
        self.position = position
        super.init(
            contentRect: NSRect(origin: .zero, size: overlaySize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        setupWindow()
    }
    
    private func setupWindow() {
        level = .screenSaver
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
        animationBehavior = .none
        collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .ignoresCycle,
            .stationary
        ]
        
        contentView = NSHostingView(
            rootView: AuraOverlayLayer()
        )
    }

    override var canBecomeKey: Bool {
        false
    }

    override var canBecomeMain: Bool {
        false
    }

    func update(position: OverlayPosition) {
        self.position = position
        reposition()
    }

    func showPersistent() {
        setContentSize(overlaySize)
        reposition()
        orderFrontRegardless()
    }
    
    func hide() {
        orderOut(nil)
    }

    private func reposition() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }

        let visibleFrame = screen.visibleFrame
        let x = visibleFrame.maxX - overlaySize.width - screenInset
        let y: CGFloat

        switch position {
        case .topRight:
            y = visibleFrame.maxY - overlaySize.height - screenInset
        case .bottomRight:
            y = visibleFrame.minY + screenInset
        }

        setFrameOrigin(NSPoint(x: x, y: y))
    }
}

@available(macOS 14.0, *)
private struct AuraOverlayLayer: View {
    @State private var pulse = false
    @State private var orbit = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Colors.primary.opacity(0.14))
                .frame(width: 112, height: 112)
                .scaleEffect(pulse ? 1.08 : 0.88)
                .opacity(pulse ? 0.2 : 0.55)

            Circle()
                .stroke(
                    AngularGradient(
                        colors: [Colors.primary, Colors.secondary, Colors.accent, Colors.primary],
                        center: .center
                    ),
                    lineWidth: 2
                )
                .frame(width: 82, height: 82)
                .rotationEffect(.degrees(orbit ? 360 : 0))

            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 64, height: 64)
                .overlay(
                    Circle()
                        .stroke(Colors.border.opacity(0.8), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.14), radius: 18, x: 0, y: 8)

            Image(systemName: "brain.head.profile")
                .font(.system(size: 27, weight: .semibold))
                .foregroundStyle(Colors.primary)

            ForEach(0..<3) { index in
                Capsule()
                    .fill(index == 1 ? Colors.secondary : Colors.primary)
                    .frame(width: 4, height: pulse ? CGFloat(16 + index * 5) : CGFloat(8 + index * 4))
                    .offset(x: CGFloat(index - 1) * 12, y: 46)
                    .animation(
                        .easeInOut(duration: 0.8)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.12),
                        value: pulse
                    )
            }
        }
        .frame(width: 132, height: 132)
        .allowsHitTesting(false)
        .onAppear {
            pulse = true
            withAnimation(.linear(duration: 5.5).repeatForever(autoreverses: false)) {
                orbit = true
            }
        }
    }
}
