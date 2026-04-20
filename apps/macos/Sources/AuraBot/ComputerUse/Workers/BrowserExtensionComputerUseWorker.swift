import Foundation

protocol BrowserContextProviding: Sendable {
    func currentContext() async -> BrowserContext?
}

extension BrowserContextService: BrowserContextProviding {}

struct EmptyBrowserContextProvider: BrowserContextProviding {
    func currentContext() async -> BrowserContext? {
        nil
    }
}

struct StaticBrowserContextProvider: BrowserContextProviding {
    let context: BrowserContext?

    func currentContext() async -> BrowserContext? {
        context
    }
}

struct BrowserExtensionComputerUseWorker: ComputerUseWorker {
    let kind: ComputerUseWorkerKind = .browserExtension

    private let contextProvider: any BrowserContextProviding

    init(contextProvider: any BrowserContextProviding = EmptyBrowserContextProvider()) {
        self.contextProvider = contextProvider
    }

    func execute(_ request: ComputerUseWorkerRequest) async -> ComputerUseWorkerResult {
        switch (request.plan.skillID, request.plan.actionName) {
        case ("chrome", "extract_page_context"):
            return await extractPageContext(request)
        default:
            return unavailable(request, reason: "unsupported_browser_extension_action")
        }
    }

    private func extractPageContext(_ request: ComputerUseWorkerRequest) async -> ComputerUseWorkerResult {
        guard let context = await contextProvider.currentContext() else {
            return unavailable(request, reason: "browser_context_unavailable")
        }

        guard context.source == .extensionData else {
            return unavailable(request, reason: "browser_extension_context_unavailable")
        }

        guard matchesChromiumSkill(context) else {
            return unavailable(request, reason: "browser_context_mismatch")
        }

        var metadata = baseMetadata(for: request)
        metadata["source"] = context.source.rawValue
        metadata["browser"] = context.browser
        metadata["session_key"] = context.sessionKey
        metadata["page_signature"] = context.pageSignature
        metadata["activity"] = context.activity.rawValue
        metadata["summary"] = context.llmSummary

        if let bundleIdentifier = context.bundleIdentifier {
            metadata["bundle_id"] = bundleIdentifier
        }
        if let url = context.url {
            metadata["url"] = url
        }
        if let title = context.title {
            metadata["title"] = title
        }
        if let pageID = context.pageID {
            metadata["page_id"] = pageID
        }
        if let mediaID = context.mediaID {
            metadata["media_id"] = mediaID
        }
        if let scrollPercent = context.scrollPercent {
            metadata["scroll_percent"] = String(scrollPercent)
        }
        if let viewportSignature = context.viewportSignature {
            metadata["viewport_signature"] = viewportSignature
        }

        return ComputerUseWorkerResult(
            status: .success,
            worker: kind,
            summary: "Extracted browser extension page context.",
            requiresConfirmation: false,
            metadata: metadata
        )
    }

    private func matchesChromiumSkill(_ context: BrowserContext) -> Bool {
        if let bundleIdentifier = context.bundleIdentifier,
           Self.chromiumBundleIdentifiers.contains(bundleIdentifier) {
            return true
        }

        let normalizedBrowser = context.browser.lowercased()
        return Self.chromiumBrowserNames.contains { normalizedBrowser.contains($0) }
    }

    private func unavailable(_ request: ComputerUseWorkerRequest, reason: String) -> ComputerUseWorkerResult {
        var metadata = baseMetadata(for: request)
        metadata["reason"] = reason
        metadata["fallback_workers"] = request.plan.fallbackWorkers.map(\.rawValue).joined(separator: ",")

        return ComputerUseWorkerResult(
            status: .unavailable,
            worker: kind,
            summary: "Browser extension context is unavailable for \(request.plan.appName).\(request.plan.actionName).",
            requiresConfirmation: false,
            metadata: metadata
        )
    }

    private func baseMetadata(for request: ComputerUseWorkerRequest) -> [String: String] {
        [
            "skill_id": request.plan.skillID,
            "action": request.plan.actionName,
            "worker": kind.rawValue
        ]
    }

    private static let chromiumBundleIdentifiers: Set<String> = [
        "com.google.Chrome",
        "com.microsoft.edgemac",
        "com.brave.Browser",
        "company.thebrowser.Browser"
    ]

    private static let chromiumBrowserNames: Set<String> = [
        "chrome",
        "chromium",
        "edge",
        "brave",
        "arc"
    ]
}
