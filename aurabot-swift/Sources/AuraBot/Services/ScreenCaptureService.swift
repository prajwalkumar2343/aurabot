import Foundation
import CoreGraphics
@preconcurrency import ScreenCaptureKit
import AppKit

@available(macOS 14.0, *)
@MainActor
class ScreenCaptureService {
    private let config: CaptureConfig
    private let browserContextService: BrowserContextService
    private var isRunning = false
    private var captureLoopTask: Task<Void, Never>?
    private var hasPermission = false
    private var lastAcceptedFingerprint: UInt64?
    private var lastAcceptedPageSignature: String?
    private var lastAcceptedViewportSignature: String?
    private var lastAcceptedMediaSession: String?
    private var lastAcceptedAt: Date?
    
    var onCapture: ((ScreenCapture) async -> Void)?
    
    init(config: CaptureConfig, browserContextService: BrowserContextService) {
        self.config = config
        self.browserContextService = browserContextService
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

        captureLoopTask = Task { @MainActor [weak self] in
            await self?.runCaptureLoop()
        }
    }
    
    func stop() async {
        guard isRunning else { return }
        isRunning = false
        captureLoopTask?.cancel()
        captureLoopTask = nil
        
        print("[ScreenCapture] Stopped")
    }
    
    private func runCaptureLoop() async {
        await evaluateAndCaptureIfNeeded(force: true)

        while isRunning, !Task.isCancelled {
            let duration = UInt64(max(config.probeIntervalSeconds, 1)) * 1_000_000_000
            try? await Task.sleep(nanoseconds: duration)

            guard isRunning, !Task.isCancelled else { break }
            await evaluateAndCaptureIfNeeded(force: false)
        }
    }

    private func evaluateAndCaptureIfNeeded(force: Bool) async {
        let browserContext = await browserContextService.currentContext()
        guard let preview = await captureImage(
            displayID: CGMainDisplayID(),
            maxWidth: config.previewWidth,
            maxHeight: config.previewHeight
        ) else {
            return
        }

        let fingerprint = preview.differenceHash()
        let decision = shouldCapture(
            fingerprint: fingerprint,
            browserContext: browserContext,
            force: force,
            now: Date()
        )

        guard decision.shouldCapture else { return }
        if let capture = await captureDisplay(
            displayID: CGMainDisplayID(),
            browserContext: browserContext,
            reason: decision.reason
        ) {
            await onCapture?(capture)
        }
    }

    func capturePrimary() async -> ScreenCapture? {
        let capture = await captureDisplay(
            displayID: CGMainDisplayID(),
            browserContext: nil,
            reason: "manual"
        )
        if let capture {
            await onCapture?(capture)
        }
        return capture
    }

    private func captureDisplay(
        displayID: CGDirectDisplayID,
        browserContext: BrowserContext?,
        reason: String?
    ) async -> ScreenCapture? {
        guard let image = await captureImage(
            displayID: displayID,
            maxWidth: config.maxWidth,
            maxHeight: config.maxHeight
        ) else {
            return nil
        }

        guard let data = image.jpegData(compressionQuality: Double(config.quality) / 100.0) else {
            print("[ScreenCapture] Failed to compress image")
            return nil
        }

        print("[ScreenCapture] Captured screen: \(data.count) bytes")

        let capture = ScreenCapture(
            displayID: displayID,
            imageData: data,
            timestamp: Date(),
            displayNum: 1,
            browserContext: browserContext,
            captureReason: reason
        )

        lastAcceptedFingerprint = image.differenceHash()
        lastAcceptedPageSignature = browserContext?.pageSignature
        lastAcceptedViewportSignature = browserContext?.viewportSignature
        lastAcceptedMediaSession = browserContext?.activity == .media ? browserContext?.sessionKey : nil
        lastAcceptedAt = capture.timestamp

        return capture
    }

    private func captureImage(displayID: CGDirectDisplayID, maxWidth: Int, maxHeight: Int) async -> CGImage? {
        do {
            let content = try await SCShareableContent.current
            
            guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
                print("[ScreenCapture] Display not found")
                return nil
            }
            
            let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
            let configuration = SCStreamConfiguration()
            configuration.width = min(maxWidth, display.width)
            configuration.height = min(maxHeight, display.height)
            
            return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
            
        } catch {
            print("[ScreenCapture] Error: \(error)")
            return nil
        }
    }

    private func shouldCapture(
        fingerprint: UInt64,
        browserContext: BrowserContext?,
        force: Bool,
        now: Date
    ) -> CaptureDecision {
        if force {
            return CaptureDecision(shouldCapture: true, reason: "initial_capture")
        }

        let timeSinceLastCapture = now.timeIntervalSince(lastAcceptedAt ?? .distantPast)
        let visualDelta = lastAcceptedFingerprint.map {
            ScreenCaptureService.hammingDistance($0, fingerprint)
        } ?? config.meaningfulChangeThreshold
        let visualChanged = visualDelta >= config.meaningfulChangeThreshold

        if timeSinceLastCapture >= TimeInterval(config.idleCaptureSeconds) {
            return CaptureDecision(shouldCapture: true, reason: "idle_checkpoint")
        }

        if let browserContext {
            if browserContext.activity == .media, browserContext.sessionKey == lastAcceptedMediaSession {
                return CaptureDecision(shouldCapture: false, reason: nil)
            }

            if browserContext.activity == .media, browserContext.sessionKey != lastAcceptedMediaSession {
                return CaptureDecision(shouldCapture: true, reason: "new_media_session")
            }

            if browserContext.source == .extensionData, browserContext.activity == .scrolling {
                let scrollCooldown = max(config.minCaptureGapSeconds, config.scrollCaptureCooldownSeconds)
                guard timeSinceLastCapture >= TimeInterval(scrollCooldown) else {
                    return CaptureDecision(shouldCapture: false, reason: nil)
                }

                if let noveltyScore = browserContext.noveltyScore, noveltyScore >= 0.35 {
                    return CaptureDecision(shouldCapture: true, reason: "scroll_novelty")
                }

                if let viewportSignature = browserContext.viewportSignature,
                   viewportSignature != lastAcceptedViewportSignature {
                    return CaptureDecision(shouldCapture: true, reason: "scroll_viewport_change")
                }
            }

            if browserContext.pageSignature != lastAcceptedPageSignature,
               timeSinceLastCapture >= TimeInterval(config.minCaptureGapSeconds) {
                return CaptureDecision(shouldCapture: true, reason: "page_changed")
            }
        }

        guard timeSinceLastCapture >= TimeInterval(config.minCaptureGapSeconds) else {
            return CaptureDecision(shouldCapture: false, reason: nil)
        }

        if visualChanged {
            return CaptureDecision(shouldCapture: true, reason: "visual_change")
        }

        return CaptureDecision(shouldCapture: false, reason: nil)
    }

    private static func hammingDistance(_ lhs: UInt64, _ rhs: UInt64) -> Int {
        Int((lhs ^ rhs).nonzeroBitCount)
    }
    
    var isCapturing: Bool {
        isRunning
    }
}

private struct CaptureDecision {
    let shouldCapture: Bool
    let reason: String?
}

extension CGImage {
    func jpegData(compressionQuality: CGFloat) -> Data? {
        let bitmapRep = NSBitmapImageRep(cgImage: self)
        let properties: [NSBitmapImageRep.PropertyKey: Any] = [
            .compressionFactor: compressionQuality
        ]
        return bitmapRep.representation(using: .jpeg, properties: properties)
    }

    func differenceHash() -> UInt64 {
        let width = 9
        let height = 8
        let colorSpace = CGColorSpaceCreateDeviceGray()
        var pixels = [UInt8](repeating: 0, count: width * height)

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return 0
        }

        context.interpolationQuality = .low
        context.draw(self, in: CGRect(x: 0, y: 0, width: width, height: height))

        var hash: UInt64 = 0
        var bitIndex = 0

        for row in 0..<height {
            for column in 0..<(width - 1) {
                let left = pixels[row * width + column]
                let right = pixels[row * width + column + 1]
                if left > right {
                    hash |= UInt64(1) << UInt64(bitIndex)
                }
                bitIndex += 1
            }
        }

        return hash
    }
}
