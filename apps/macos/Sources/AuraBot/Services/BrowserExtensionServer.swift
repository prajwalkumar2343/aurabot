import Foundation
import Vapor

struct BrowserExtensionUpdateRequest: Content {
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
    var timestamp: Date?

    func asBrowserContext() throws -> BrowserContext {
        try Self.validateLength(browser, field: "browser", max: 80)
        try Self.validateLength(bundleIdentifier, field: "bundleIdentifier", max: 160)
        try Self.validateLength(url, field: "url", max: 4096)
        try Self.validateLength(title, field: "title", max: 512)
        try Self.validateLength(pageID, field: "pageID", max: 512)
        try Self.validateLength(mediaID, field: "mediaID", max: 256)
        try Self.validateLength(viewportSignature, field: "viewportSignature", max: 256)

        if let scrollPercent, !(0...100).contains(scrollPercent) {
            throw Abort(.badRequest, reason: "scrollPercent must be between 0 and 100")
        }
        if let noveltyScore, !(0...1).contains(noveltyScore) {
            throw Abort(.badRequest, reason: "noveltyScore must be between 0 and 1")
        }

        let derived = BrowserContextService.deriveActivity(url: url, title: title)

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
            timestamp: timestamp ?? Date()
        )
    }

    private static func validateLength(_ value: String?, field: String, max: Int) throws {
        guard let value, value.count > max else { return }
        throw Abort(.payloadTooLarge, reason: "\(field) exceeds \(max) characters")
    }
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
        app.routes.defaultMaxBodySize = "16kb"

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
        guard request.url.path == "/browser/context" else {
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
