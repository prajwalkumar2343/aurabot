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
    
    var onCapture: ((ScreenCapture) async -> Void)?
    
    init(config: CaptureConfig) {
        self.config = config
    }
    
    func start() {
        guard config.enabled else { return }
        isRunning = true
        
        Task {
            _ = await capturePrimary()
            
            self.timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(config.intervalSeconds), repeats: true) { [weak self] _ in
                Task { [weak self] in
                    _ = await self?.capturePrimary()
                }
            }
        }
    }
    
    func stop() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }
    
    func capturePrimary() async -> ScreenCapture? {
        let displayID = CGMainDisplayID()
        return await captureDisplay(displayID: displayID)
    }
    
    nonisolated
    func captureDisplay(displayID: CGDirectDisplayID) async -> ScreenCapture? {
        do {
            let content = try await SCShareableContent.current
            
            guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
                return nil
            }
            
            let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
            let configuration = SCStreamConfiguration()
            configuration.width = min(self.config.maxWidth, display.width)
            configuration.height = min(self.config.maxHeight, display.height)
            
            let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
            
            guard let data = image.jpegData(compressionQuality: Double(self.config.quality) / 100.0) else {
                return nil
            }
            
            let capture = ScreenCapture(
                displayID: displayID,
                imageData: data,
                timestamp: Date(),
                displayNum: 1
            )
            
            return capture
            
        } catch {
            print("Screen capture error: \(error)")
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
