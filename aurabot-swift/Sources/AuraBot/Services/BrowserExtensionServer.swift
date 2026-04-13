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

    func asBrowserContext() -> BrowserContext {
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
}

final class BrowserExtensionServer {
    private let port: Int
    private let browserContextService: BrowserContextService
    private var app: Application?
    private let queue = DispatchQueue(label: "AuraBot.BrowserExtensionServer")

    init(port: Int, browserContextService: BrowserContextService) {
        self.port = port
        self.browserContextService = browserContextService
    }

    func start() {
        guard app == nil else { return }

        let app = Application(.production)
        app.http.server.configuration.hostname = "127.0.0.1"
        app.http.server.configuration.port = port

        let corsConfiguration = CORSMiddleware.Configuration(
            allowedOrigin: .all,
            allowedMethods: [.GET, .POST, .OPTIONS],
            allowedHeaders: [.accept, .authorization, .contentType, .origin, .xRequestedWith]
        )
        app.middleware.use(CORSMiddleware(configuration: corsConfiguration))

        app.get("health") { _ in
            ["status": "ok"]
        }

        app.post("browser", "context") { [browserContextService] req async throws -> HTTPStatus in
            let payload = try req.content.decode(BrowserExtensionUpdateRequest.self)
            await browserContextService.updateExtensionContext(payload.asBrowserContext())
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
