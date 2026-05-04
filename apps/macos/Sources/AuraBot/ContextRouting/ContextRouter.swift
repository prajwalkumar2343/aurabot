import Foundation

actor ContextRouter {
    private let captureConfig: CaptureConfig
    private let activeAppCollector = ActiveAppCollector()
    private let browserCollector: BrowserContextCollector
    private let gitCollector = GitContextCollector()
    private var capturePolicy: CapturePolicy

    private var lastEventFingerprint: String?
    private var lastEventAt: Date?
    private var lastVisualFallbackAt: Date?

    init(
        captureConfig: CaptureConfig,
        browserContextService: BrowserContextService,
        capturePolicy: CapturePolicy = .hostDefault
    ) {
        self.captureConfig = captureConfig
        self.browserCollector = BrowserContextCollector(browserContextService: browserContextService)
        self.capturePolicy = capturePolicy
    }

    func updateCapturePolicy(_ capturePolicy: CapturePolicy) {
        self.capturePolicy = capturePolicy
    }

    func capturePlan(force: Bool = false) async -> ContextCapturePlan {
        let now = Date()
        let policy = capturePolicy

        guard let activeApp = await activeAppCollector.collect() else {
            return visualFallbackPlan(
                now: now,
                force: force,
                activeApp: nil,
                reason: "no_active_app",
                policy: policy
            )
        }

        if policy.allowsBrowserContext,
           let browserContext = await browserCollector.collect(),
           isChromiumBrowser(bundleIdentifier: activeApp.bundleIdentifier ?? browserContext.bundleIdentifier) {
            return planBrowserContext(browserContext, activeApp: activeApp, now: now, force: force)
        }

        if policy.allowsAppMetadata,
           isCodeApp(bundleIdentifier: activeApp.bundleIdentifier, appName: activeApp.name) {
            let gitContext = await gitCollector.collect()
            return planCodingContext(activeApp: activeApp, gitContext: gitContext, now: now, force: force)
        }

        return visualFallbackPlan(
            now: now,
            force: force,
            activeApp: activeApp,
            reason: "screen_context_fallback",
            policy: policy
        )
    }

    private func planBrowserContext(
        _ browserContext: BrowserContext,
        activeApp: ActiveAppSnapshot,
        now: Date,
        force: Bool
    ) -> ContextCapturePlan {
        let fingerprint = "browser|\(browserContext.sessionKey)|\(browserContext.viewportSignature ?? "")|\(browserContext.activity.rawValue)"
        let summary = browserContext.llmSummary
        let event = ContextEvent(
            mode: .browserResearch,
            source: browserContext.source == .extensionData ? "browser_extension" : "browser_automation",
            summary: summary,
            activities: ["browser", browserContext.activity.rawValue],
            keyElements: compact([
                activeApp.name,
                browserContext.title,
                browserContext.url,
                browserContext.sourceQuality.rawValue
            ]),
            userIntent: browserContext.activity == .media ? "Watching or reviewing media" : "Browsing or researching",
            importance: browserImportance(for: browserContext),
            ttl: "session",
            fingerprint: fingerprint,
            timestamp: now,
            browserContext: browserContext,
            captureReason: "context_router_browser"
        )

        return structuredPlan(event, confidence: browserConfidence(for: browserContext), force: force)
    }

    private func browserImportance(for context: BrowserContext) -> Double {
        switch context.sourceQuality {
        case .extensionFull:
            return 0.76
        case .extensionMetadataOnly:
            return 0.66
        case .extensionPrivate:
            return 0.52
        case .automationFallback:
            return 0.58
        }
    }

    private func browserConfidence(for context: BrowserContext) -> Double {
        switch context.sourceQuality {
        case .extensionFull:
            return 0.92
        case .extensionMetadataOnly:
            return 0.82
        case .extensionPrivate:
            return 0.74
        case .automationFallback:
            return 0.62
        }
    }

    private func planCodingContext(
        activeApp: ActiveAppSnapshot,
        gitContext: GitContext?,
        now: Date,
        force: Bool
    ) -> ContextCapturePlan {
        let projectName = gitContext?.projectName
        let fingerprint = "code|\(activeApp.bundleIdentifier ?? activeApp.name)|\(activeApp.windowTitle ?? "")|\(projectName ?? "")"
        var summary = "User is working in \(activeApp.displayName)"
        if let projectName, !projectName.isEmpty {
            summary += " | Project: \(projectName)"
        }

        let event = ContextEvent(
            mode: .codingIDE,
            source: "active_app_project",
            summary: summary,
            activities: ["coding", "project_work"],
            keyElements: compact([
                activeApp.name,
                activeApp.windowTitle,
                projectName
            ]),
            userIntent: "Project work context",
            importance: 0.64,
            ttl: "session",
            fingerprint: fingerprint,
            timestamp: now,
            browserContext: nil,
            captureReason: "context_router_coding"
        )

        return structuredPlan(event, confidence: projectName == nil ? 0.68 : 0.8, force: force)
    }

    private func structuredPlan(_ event: ContextEvent, confidence: Double, force: Bool) -> ContextCapturePlan {
        if !force, isDuplicate(event.fingerprint, now: event.timestamp) {
            return ContextCapturePlan(
                mode: .idleOrDuplicate,
                confidence: confidence,
                screenshotDirective: .skip,
                event: nil,
                browserContext: event.browserContext,
                reason: "duplicate_structured_context"
            )
        }

        lastEventFingerprint = event.fingerprint
        lastEventAt = event.timestamp

        return ContextCapturePlan(
            mode: event.mode,
            confidence: confidence,
            screenshotDirective: .skip,
            event: event,
            browserContext: event.browserContext,
            reason: event.captureReason
        )
    }

    private func visualFallbackPlan(
        now: Date,
        force: Bool,
        activeApp: ActiveAppSnapshot?,
        reason: String,
        policy: CapturePolicy
    ) -> ContextCapturePlan {
        guard policy.allowsVisualFallback else {
            return ContextCapturePlan(
                mode: .idleOrDuplicate,
                confidence: 0.2,
                screenshotDirective: .skip,
                event: nil,
                browserContext: nil,
                reason: "capture_policy_no_visual_fallback"
            )
        }

        let minGap = TimeInterval(max(captureConfig.minCaptureGapSeconds, 1))
        if !force,
           let lastVisualFallbackAt,
           now.timeIntervalSince(lastVisualFallbackAt) < minGap {
            return ContextCapturePlan(
                mode: .idleOrDuplicate,
                confidence: 0.35,
                screenshotDirective: .skip,
                event: nil,
                browserContext: nil,
                reason: "visual_fallback_cooldown"
            )
        }

        lastVisualFallbackAt = now
        let event = activeApp.map { activeApp in
            ContextEvent(
                mode: .genericVisual,
                source: "active_app_metadata",
                summary: "User is using \(activeApp.displayName)",
                activities: ["desktop", "active_app"],
                keyElements: compact([
                    activeApp.name,
                    activeApp.windowTitle,
                    activeApp.bundleIdentifier
                ]),
                userIntent: "Desktop activity context",
                importance: 0.42,
                ttl: "session",
                fingerprint: "desktop|\(activeApp.bundleIdentifier ?? activeApp.name)|\(activeApp.windowTitle ?? "")",
                timestamp: now,
                browserContext: nil,
                captureReason: reason
            )
        }

        return ContextCapturePlan(
            mode: .genericVisual,
            confidence: activeApp == nil ? 0.2 : 0.45,
            screenshotDirective: .fallback,
            event: event,
            browserContext: nil,
            reason: reason
        )
    }

    private func isDuplicate(_ fingerprint: String, now: Date) -> Bool {
        guard fingerprint == lastEventFingerprint else {
            return false
        }

        guard let lastEventAt else {
            return true
        }

        return now.timeIntervalSince(lastEventAt) < TimeInterval(max(captureConfig.minCaptureGapSeconds, 1))
    }

    private func isChromiumBrowser(bundleIdentifier: String?) -> Bool {
        guard let bundleIdentifier else { return false }
        return [
            "com.google.Chrome",
            "com.microsoft.edgemac",
            "com.brave.Browser",
            "company.thebrowser.Browser"
        ].contains(bundleIdentifier)
    }

    private func isCodeApp(bundleIdentifier: String?, appName: String) -> Bool {
        if isTerminal(bundleIdentifier: bundleIdentifier, appName: appName) {
            return true
        }

        if let bundleIdentifier {
            if bundleIdentifier.hasPrefix("com.jetbrains.") {
                return true
            }

            if [
                "com.apple.dt.Xcode",
                "com.microsoft.VSCode",
                "com.todesktop.230313mzl4w4u92",
                "dev.zed.Zed",
                "com.sublimetext.4",
                "com.github.atom",
                "com.exafunction.windsurf"
            ].contains(bundleIdentifier) {
                return true
            }
        }

        let lowercased = appName.lowercased()
        return ["xcode", "visual studio code", "cursor", "zed", "sublime", "intellij", "pycharm", "webstorm", "windsurf"].contains {
            lowercased.contains($0)
        }
    }

    private func isTerminal(bundleIdentifier: String?, appName: String) -> Bool {
        if let bundleIdentifier,
           [
            "com.apple.Terminal",
            "com.googlecode.iterm2",
            "dev.warp.Warp",
            "net.kovidgoyal.kitty",
            "org.alacritty"
           ].contains(bundleIdentifier) {
            return true
        }

        let lowercased = appName.lowercased()
        return ["terminal", "iterm", "warp", "kitty", "alacritty"].contains {
            lowercased.contains($0)
        }
    }

    private func compact(_ values: [String?]) -> [String] {
        values.compactMap {
            let value = $0?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return value.isEmpty ? nil : value
        }
    }
}
