import Foundation
import Vapor

struct BrowserExtensionUpdateRequest: Content {
    static let currentSchemaVersion = 1
    static let maxVisibleTextLength = 8 * 1024
    static let maxSelectedTextLength = 2 * 1024
    static let maxReadableTextLength = 64 * 1024

    var schemaVersion: Int?
    var captureID: String?
    var browser: String
    var bundleIdentifier: String?
    var url: String?
    var title: String?
    var activity: BrowserActivityKind?
    var pageID: String?
    var mediaID: String?
    var mediaIsPlaying: Bool?
    var scrollPercent: Double?
    var viewportSignature: String?
    var noveltyScore: Double?
    var visibleText: String?
    var selectedText: String?
    var readableText: String?
    var visibleTextHash: String?
    var readableTextHash: String?
    var textCaptureMode: String?
    var privateWindow: Bool?
    var timestamp: Date?

    func asBrowserContext() throws -> BrowserContext {
        let normalizedSchemaVersion = schemaVersion ?? Self.currentSchemaVersion
        guard normalizedSchemaVersion == Self.currentSchemaVersion else {
            throw Abort(.badRequest, reason: "Unsupported browser context schemaVersion")
        }

        try Self.validateLength(captureID, field: "captureID", max: 128)
        try Self.validateLength(browser, field: "browser", max: 80)
        try Self.validateLength(bundleIdentifier, field: "bundleIdentifier", max: 160)
        try Self.validateLength(url, field: "url", max: 4096)
        try Self.validateLength(title, field: "title", max: 512)
        try Self.validateLength(pageID, field: "pageID", max: 512)
        try Self.validateLength(mediaID, field: "mediaID", max: 256)
        try Self.validateLength(viewportSignature, field: "viewportSignature", max: 256)
        try Self.validateLength(visibleText, field: "visibleText", max: Self.maxVisibleTextLength)
        try Self.validateLength(selectedText, field: "selectedText", max: Self.maxSelectedTextLength)
        try Self.validateLength(readableText, field: "readableText", max: Self.maxReadableTextLength)
        try Self.validateLength(visibleTextHash, field: "visibleTextHash", max: 128)
        try Self.validateLength(readableTextHash, field: "readableTextHash", max: 128)
        try Self.validateLength(textCaptureMode, field: "textCaptureMode", max: 80)

        if let scrollPercent, !(0...100).contains(scrollPercent) {
            throw Abort(.badRequest, reason: "scrollPercent must be between 0 and 100")
        }
        if let noveltyScore, !(0...1).contains(noveltyScore) {
            throw Abort(.badRequest, reason: "noveltyScore must be between 0 and 1")
        }

        let derived = BrowserContextService.deriveActivity(url: url, title: title)
        let isPrivateWindow = privateWindow ?? false
        let normalizedTextCaptureMode = textCaptureMode?.lowercased() ?? ""
        let shouldDropText =
            isPrivateWindow ||
            normalizedTextCaptureMode.contains("metadata_only") ||
            normalizedTextCaptureMode.contains("sensitive")

        return BrowserContext(
            source: .extensionData,
            browser: browser,
            bundleIdentifier: bundleIdentifier,
            url: url,
            title: title,
            activity: activity ?? derived.activity,
            pageID: pageID ?? derived.pageID,
            mediaID: mediaID ?? derived.mediaID,
            mediaIsPlaying: mediaIsPlaying ?? ((activity ?? derived.activity) == .media),
            scrollPercent: scrollPercent,
            viewportSignature: viewportSignature,
            noveltyScore: noveltyScore,
            visibleText: shouldDropText ? nil : visibleText,
            selectedText: shouldDropText ? nil : selectedText,
            readableText: shouldDropText ? nil : readableText,
            visibleTextHash: visibleTextHash,
            readableTextHash: readableTextHash,
            textCaptureMode: isPrivateWindow ? "private_window_metadata_only" : textCaptureMode,
            privateWindow: isPrivateWindow,
            schemaVersion: normalizedSchemaVersion,
            captureID: captureID,
            timestamp: timestamp ?? Date()
        )
    }

    private static func validateLength(_ value: String?, field: String, max: Int) throws {
        guard let value, value.count > max else { return }
        throw Abort(.payloadTooLarge, reason: "\(field) exceeds \(max) characters")
    }
}

struct BrowserExtensionStatusResponse: Content {
    let status: String
    let source: String?
    let sourceQuality: String?
    let reason: String?
    let browser: String?
    let url: String?
    let title: String?
    let captureID: String?
    let schemaVersion: Int?
    let ageSeconds: Double?
    let staleCaptureID: String?
}

final class BrowserExtensionServer {
    private let config: ExtensionConfig
    private let browserContextService: BrowserContextService
    private var app: Application?
    private let queue = DispatchQueue(label: "AuraBot.BrowserExtensionServer")

    init(config: ExtensionConfig, browserContextService: BrowserContextService) {
        self.config = config
        self.browserContextService = browserContextService
    }

    func start() {
        guard app == nil else { return }

        let app = Application(.production)
        app.http.server.configuration.hostname = "127.0.0.1"
        app.http.server.configuration.port = config.port
        app.routes.defaultMaxBodySize = "128kb"

        app.middleware.use(BrowserExtensionSecurityMiddleware(config: config))

        let corsConfiguration = CORSMiddleware.Configuration(
            allowedOrigin: .originBased,
            allowedMethods: [.GET, .POST, .OPTIONS],
            allowedHeaders: [.accept, .authorization, .contentType, .origin, .xRequestedWith]
        )
        app.middleware.use(CORSMiddleware(configuration: corsConfiguration))

        app.get("health") { _ in
            ["status": "ok"]
        }

        app.get("browser", "context", "status") { [browserContextService] _ async -> BrowserExtensionStatusResponse in
            let status = await browserContextService.currentContextStatus()
            let context = status.context
            let ageSeconds = context.map { Date().timeIntervalSince($0.timestamp) }

            return BrowserExtensionStatusResponse(
                status: status.hasFreshExtensionContext ? "fresh_extension" : context == nil ? "unavailable" : "fallback",
                source: context?.source.rawValue,
                sourceQuality: context?.sourceQuality.rawValue,
                reason: status.reason?.rawValue,
                browser: context?.browser,
                url: context?.url,
                title: context?.title,
                captureID: context?.captureID,
                schemaVersion: context?.schemaVersion,
                ageSeconds: ageSeconds,
                staleCaptureID: status.staleExtensionContext?.captureID
            )
        }

        app.post("browser", "context") { [browserContextService] req async throws -> HTTPStatus in
            let payload = try req.content.decode(BrowserExtensionUpdateRequest.self)
            await browserContextService.updateExtensionContext(try payload.asBrowserContext())
            return .accepted
        }

        self.app = app

        queue.async {
            do {
                try app.run()
            } catch {
                print("Browser extension server error: \(error)")
            }
        }
    }

    func stop() {
        app?.shutdown()
        app = nil
    }
}

private struct BrowserExtensionSecurityMiddleware: Middleware {
    let config: ExtensionConfig

    func respond(to request: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
        guard request.url.path == "/browser/context" || request.url.path == "/browser/context/status" else {
            return next.respond(to: request)
        }

        guard isAllowedOrigin(request.headers[.origin].first) else {
            return request.eventLoop.makeFailedFuture(Abort(.forbidden, reason: "Origin is not allowed"))
        }

        if request.method == .OPTIONS {
            return next.respond(to: request)
        }

        guard isAuthorized(request.headers) else {
            return request.eventLoop.makeFailedFuture(Abort(.unauthorized, reason: "Missing browser extension API key"))
        }

        return next.respond(to: request)
    }

    private func isAllowedOrigin(_ origin: String?) -> Bool {
        guard let origin, !origin.isEmpty else {
            return true
        }

        return config.allowedOrigins.contains { allowed in
            if allowed.hasSuffix("*") {
                return origin.hasPrefix(String(allowed.dropLast()))
            }
            if allowed.hasSuffix(":") || allowed.hasSuffix("://") {
                return origin.hasPrefix(allowed)
            }
            return origin == allowed
        }
    }

    private func isAuthorized(_ headers: HTTPHeaders) -> Bool {
        let expectedKey = config.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !expectedKey.isEmpty else {
            return false
        }

        let bearerPrefix = "Bearer "
        let bearerToken = headers[.authorization].first.flatMap { header -> String? in
            guard header.hasPrefix(bearerPrefix) else { return nil }
            return String(header.dropFirst(bearerPrefix.count))
        }

        let providedKey = bearerToken ?? headers.first(name: "X-AuraBot-Extension-Key")
        return providedKey == expectedKey
    }
}
