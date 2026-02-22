import Foundation
import CoreGraphics
import ScreenCaptureKit
import AppKit

@available(macOS 12.3, *)
actor ScreenCaptureService {
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
            await capturePrimary()
            
            timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(config.intervalSeconds), repeats: true) { _ in
                Task {
                    await self.capturePrimary()
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
        guard let displayID = CGMainDisplayID() else { return nil }
        return await captureDisplay(displayID: displayID)
    }
    
    func captureDisplay(displayID: CGDirectDisplayID) async -> ScreenCapture? {
        do {
            let content = try await SCShareableContent.current
            
            guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
                return nil
            }
            
            let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
            let configuration = SCStreamConfiguration()
            configuration.width = min(config.maxWidth, display.width)
            configuration.height = min(config.maxHeight, display.height)
            
            let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
            
            guard let data = image.jpegData(compressionQuality: Double(config.quality) / 100.0) else {
                return nil
            }
            
            let capture = ScreenCapture(
                displayID: displayID,
                imageData: data,
                timestamp: Date(),
                displayNum: 1
            )
            
            await onCapture?(capture)
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
