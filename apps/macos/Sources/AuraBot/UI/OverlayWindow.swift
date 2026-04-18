import Cocoa

class OverlayWindow: NSWindow {
    var onClick: (() -> Void)?
    
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 48, height: 48),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        setupWindow()
    }
    
    private func setupWindow() {
        level = .floating
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        collectionBehavior = [.canJoinAllSpaces, .stationary]
        
        let button = NSButton(frame: NSRect(x: 0, y: 0, width: 48, height: 48))
        button.wantsLayer = true
        button.layer?.backgroundColor = NSColor.systemPurple.cgColor
        button.layer?.cornerRadius = 24
        button.image = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: nil)
        button.imageScaling = .scaleProportionallyDown
        button.contentTintColor = .white
        button.target = self
        button.action = #selector(buttonClicked)
        button.isBordered = false
        
        contentView = button
    }
    
    @objc private func buttonClicked() {
        onClick?()
        hide()
    }
    
    func show(at point: NSPoint) {
        let screenFrame = NSScreen.main?.frame ?? .zero
        let x = point.x - 24
        let y = screenFrame.height - point.y - 24
        
        setFrameOrigin(NSPoint(x: x, y: y))
        makeKeyAndOrderFront(nil)
    }
    
    func hide() {
        orderOut(nil)
    }
}
