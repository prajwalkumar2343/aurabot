import Foundation
import XCTest
@testable import AuraBot

@available(macOS 14.0, *)
final class AuraBotCoreTests: XCTestCase {
    func testYouTubeWatchURLDerivesStableMediaContext() {
        let derived = BrowserContextService.deriveActivity(
            url: "https://www.youtube.com/watch?v=abc123&t=30",
            title: "Demo video"
        )

        XCTAssertEqual(derived.activity, .media)
        XCTAssertEqual(derived.mediaID, "abc123")
        XCTAssertEqual(derived.pageID, "www.youtube.com/watch")
    }

    func testNormalizedPageIDIgnoresQueryAndFragment() throws {
        let components = try XCTUnwrap(
            URLComponents(string: "https://Example.com/docs/page?utm_source=test#intro")
        )

        XCTAssertEqual(
            BrowserContextService.normalizedPageID(for: components),
            "example.com/docs/page"
        )
    }

    func testBrowserContextSessionKeyPrefersMediaThenPage() {
        let context = BrowserContext(
            source: .extensionData,
            browser: "Chrome",
            bundleIdentifier: "com.google.Chrome",
            url: "https://example.com/watch",
            title: "Video",
            activity: .media,
            pageID: "example.com/watch",
            mediaID: "video-1",
            mediaIsPlaying: true,
            scrollPercent: nil,
            viewportSignature: nil,
            noveltyScore: nil,
            timestamp: Date(timeIntervalSince1970: 0)
        )

        XCTAssertEqual(context.sessionKey, "media:video-1")
        XCTAssertTrue(context.llmSummary.contains("Activity: media playback"))
    }

    func testExtensionConfigDecodesLegacyPayloadWithSecureDefaults() throws {
        let payload = """
        {
          "enabled": true,
          "port": 7345,
          "freshnessSeconds": 15
        }
        """.data(using: .utf8)!

        let config = try JSONDecoder().decode(ExtensionConfig.self, from: payload)

        XCTAssertEqual(config.apiKey, "")
        XCTAssertTrue(config.allowedOrigins.contains("chrome-extension://"))
        XCTAssertTrue(config.allowedOrigins.contains("http://127.0.0.1:"))
    }
}
