import Foundation
import CoreGraphics
@preconcurrency import ScreenCaptureKit
import AppKit

@available(macOS 14.0, *)
@MainActor
class ScreenCaptureService {
    private let config: CaptureConfig
    private var isRunning = false
    private var timer: Timer?
    private var hasPermission = false
    
    var onCapture: ((ScreenCapture) async -> Void)?
    
    init(config: CaptureConfig) {
        self.config = config
    }
    
    func checkPermission() async -> Bool {
        // If we already have permission, return true
        if hasPermission {
            return true
        }
        
        do {
            // Try to get shareable content - this will trigger permission dialog if needed
            _ = try await SCShareableContent.current
            hasPermission = true
            print("[ScreenCapture] Permission granted")
            return true
        } catch {
            print("[ScreenCapture] Permission not granted: \(error)")
            hasPermission = false
            return false
        }
    }
    
    func start() async {
        guard config.enabled else {
            print("[ScreenCapture] Capture disabled in config")
            return
        }
        
        guard !isRunning else {
            print("[ScreenCapture] Already running")
            return
        }
        
        // Check permission first
        let permissionGranted = await checkPermission()
        guard permissionGranted else {
            print("[ScreenCapture] Cannot start: Permission not granted")
            return
        }
        
        isRunning = true
        print("[ScreenCapture] Starting capture service")
        
        // Do first capture
        await performCapture()
        
        // Set up timer for periodic captures on main thread
        await MainActor.run {
            self.timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(self.config.intervalSeconds), repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self = self, self.isRunning else { return }
                    await self.performCapture()
                }
            }
        }
    }
    
    func stop() async {
        guard isRunning else { return }
        isRunning = false
        
        await MainActor.run {
            self.timer?.invalidate()
            self.timer = nil
        }
        
        print("[ScreenCapture] Stopped")
    }
    
    private func performCapture() async {
        guard isRunning else { return }
        
        if let capture = await capturePrimary() {
            await onCapture?(capture)
        }
    }
    
    func capturePrimary() async -> ScreenCapture? {
        let displayID = CGMainDisplayID()
        
        do {
            let content = try await SCShareableContent.current
            
            guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
                print("[ScreenCapture] Display not found")
                return nil
            }
            
            let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
            let configuration = SCStreamConfiguration()
            configuration.width = min(config.maxWidth, display.width)
            configuration.height = min(config.maxHeight, display.height)
            
            let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
            
            guard let data = image.jpegData(compressionQuality: Double(config.quality) / 100.0) else {
                print("[ScreenCapture] Failed to compress image")
                return nil
            }
            
            print("[ScreenCapture] Captured screen: \(data.count) bytes")
            
            return ScreenCapture(
                displayID: displayID,
                imageData: data,
                timestamp: Date(),
                displayNum: 1
            )
            
        } catch {
            print("[ScreenCapture] Error: \(error)")
            return nil
        }
    }
    
    var isCapturing: Bool {
        isRunning
    }
}

extension CGImage {
    func jpegData(compressionQuality: CGFloat) -> Data? {
        let bitmapRep = NSBitmapImageRep(cgImage: self)
        let properties: [NSBitmapImageRep.PropertyKey: Any] = [
            .compressionFactor: compressionQuality
        ]
        return bitmapRep.representation(using: .jpeg, properties: properties)
    }
}
