import Foundation

actor ContextRouter {
    private let captureConfig: CaptureConfig
    private let activeAppCollector = ActiveAppCollector()
    private let browserCollector: BrowserContextCollector
    private let gitCollector = GitContextCollector()
    private let terminalCollector = TerminalContextCollector()

    private var lastEventFingerprint: String?
    private var lastEventAt: Date?
    private var lastVisualFallbackAt: Date?

    init(captureConfig: CaptureConfig, browserContextService: BrowserContextService) {
        self.captureConfig = captureConfig
        self.browserCollector = BrowserContextCollector(browserContextService: browserContextService)
    }

    func capturePlan(force: Bool = false) async -> ContextCapturePlan {
        let now = Date()

        guard let activeApp = await activeAppCollector.collect() else {
            return visualFallbackPlan(now: now, force: force, activeApp: nil, reason: "no_active_app")
        }

        if let browserContext = await browserCollector.collect(),
           isBrowser(bundleIdentifier: activeApp.bundleIdentifier ?? browserContext.bundleIdentifier) {
            return planBrowserContext(browserContext, activeApp: activeApp, now: now, force: force)
        }

        if isIDE(bundleIdentifier: activeApp.bundleIdentifier, appName: activeApp.name) {
            let gitContext = await gitCollector.collect()
            return planCodingContext(activeApp: activeApp, gitContext: gitContext, now: now, force: force)
        }

        if isTerminal(bundleIdentifier: activeApp.bundleIdentifier, appName: activeApp.name) {
            return planTerminalContext(activeApp: activeApp, now: now, force: force)
        }

        if isMeeting(bundleIdentifier: activeApp.bundleIdentifier, appName: activeApp.name) {
            return planSimpleStructuredContext(
                mode: .meetingOrCall,
                activeApp: activeApp,
                now: now,
                force: force,
                source: "active_app",
                intent: "Meeting or communication context",
                importance: 0.55,
                ttl: "session"
            )
        }

        if isDocumentApp(bundleIdentifier: activeApp.bundleIdentifier, appName: activeApp.name) {
            return planSimpleStructuredContext(
                mode: .documentWriting,
                activeApp: activeApp,
                now: now,
                force: force,
                source: "active_app",
                intent: "Document writing or reading context",
                importance: 0.58,
                ttl: "session"
            )
        }

        return visualFallbackPlan(now: now, force: force, activeApp: activeApp, reason: "unknown_app_visual_fallback")
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
                browserContext.url
            ]),
            userIntent: browserContext.activity == .media ? "Watching or reviewing media" : "Browsing or researching",
            importance: browserContext.source == .extensionData ? 0.72 : 0.62,
            ttl: "session",
            fingerprint: fingerprint,
            timestamp: now,
            browserContext: browserContext,
            captureReason: "context_router_browser"
        )

        return structuredPlan(event, confidence: browserContext.source == .extensionData ? 0.9 : 0.72, force: force)
    }

    private func planCodingContext(
        activeApp: ActiveAppSnapshot,
        gitContext: GitContext?,
        now: Date,
        force: Bool
    ) -> ContextCapturePlan {
        let fingerprint = "code|\(activeApp.bundleIdentifier ?? activeApp.name)|\(activeApp.windowTitle ?? "")|\(gitContext?.fingerprint ?? "")"
        let dirtyKeyElements = gitContext.map { Array($0.dirtyFiles.prefix(8)) } ?? []
        var summary = "User is working in \(activeApp.displayName)"
        if let gitContext {
            summary += " | \(gitContext.summary)"
        }

        let event = ContextEvent(
            mode: .codingIDE,
            source: "active_app_git",
            summary: summary,
            activities: ["coding", "ide"],
            keyElements: compact([
                activeApp.name,
                activeApp.windowTitle,
                gitContext?.projectName,
                gitContext?.branch
            ]) + dirtyKeyElements,
            userIntent: "Coding workflow context",
            importance: gitContext?.dirtyFiles.isEmpty == false ? 0.78 : 0.66,
            ttl: "session",
            fingerprint: fingerprint,
            timestamp: now,
            browserContext: nil,
            captureReason: "context_router_coding"
        )

        return structuredPlan(event, confidence: gitContext == nil ? 0.72 : 0.88, force: force)
    }

    private func planTerminalContext(
        activeApp: ActiveAppSnapshot,
        now: Date,
        force: Bool
    ) -> ContextCapturePlan {
        let terminalContext = terminalCollector.collect(from: activeApp)
        let fingerprint = "terminal|\(terminalContext.fingerprint)"
        let event = ContextEvent(
            mode: .terminalDebugging,
            source: "active_app_terminal",
            summary: terminalContext.summary,
            activities: ["terminal", "debugging"],
            keyElements: compact([activeApp.name, activeApp.windowTitle]),
            userIntent: "Terminal or debugging workflow",
            importance: 0.62,
            ttl: "session",
            fingerprint: fingerprint,
            timestamp: now,
            browserContext: nil,
            captureReason: "context_router_terminal"
        )

        return structuredPlan(event, confidence: 0.78, force: force)
    }

    private func planSimpleStructuredContext(
        mode: ContextMode,
        activeApp: ActiveAppSnapshot,
        now: Date,
        force: Bool,
        source: String,
        intent: String,
        importance: Double,
        ttl: String
    ) -> ContextCapturePlan {
        let fingerprint = "\(mode.rawValue)|\(activeApp.bundleIdentifier ?? activeApp.name)|\(activeApp.windowTitle ?? "")"
        let event = ContextEvent(
            mode: mode,
            source: source,
            summary: "User is in \(activeApp.displayName)",
            activities: [mode.rawValue],
            keyElements: compact([activeApp.name, activeApp.windowTitle]),
            userIntent: intent,
            importance: importance,
            ttl: ttl,
            fingerprint: fingerprint,
            timestamp: now,
            browserContext: nil,
            captureReason: "context_router_\(mode.rawValue)"
        )

        return structuredPlan(event, confidence: 0.68, force: force)
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
        reason: String
    ) -> ContextCapturePlan {
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
        return ContextCapturePlan(
            mode: .genericVisual,
            confidence: activeApp == nil ? 0.2 : 0.45,
            screenshotDirective: .fallback,
            event: nil,
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

    private func isBrowser(bundleIdentifier: String?) -> Bool {
        guard let bundleIdentifier else { return false }
        return [
            "com.google.Chrome",
            "com.microsoft.edgemac",
            "com.brave.Browser",
            "company.thebrowser.Browser",
            "com.apple.Safari",
            "org.mozilla.firefox"
        ].contains(bundleIdentifier)
    }

    private func isIDE(bundleIdentifier: String?, appName: String) -> Bool {
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

    private func isMeeting(bundleIdentifier: String?, appName: String) -> Bool {
        if let bundleIdentifier,
           [
            "us.zoom.xos",
            "com.microsoft.teams2",
            "com.tinyspeck.slackmacgap",
            "com.apple.FaceTime"
           ].contains(bundleIdentifier) {
            return true
        }

        let lowercased = appName.lowercased()
        return ["zoom", "teams", "slack", "facetime", "meet"].contains {
            lowercased.contains($0)
        }
    }

    private func isDocumentApp(bundleIdentifier: String?, appName: String) -> Bool {
        if let bundleIdentifier,
           [
            "com.apple.Notes",
            "com.apple.TextEdit",
            "com.apple.iWork.Pages",
            "com.microsoft.Word",
            "com.microsoft.Excel",
            "com.microsoft.Powerpoint",
            "notion.id"
           ].contains(bundleIdentifier) {
            return true
        }

        let lowercased = appName.lowercased()
        return ["notes", "textedit", "pages", "word", "notion", "obsidian"].contains {
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
