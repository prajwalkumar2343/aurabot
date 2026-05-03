import Foundation
import XCTest
@testable import AuraBot

@available(macOS 14.0, *)
final class AuraBotCoreTests: XCTestCase {
    func testPluginHostActivatesWorkspaceTakeoverPolicies() throws {
        let host = PluginHost()
        let descriptor = makeWorkspacePluginDescriptor()

        try host.activateWorkspace(descriptor)

        XCTAssertEqual(host.activeWorkspacePlugin?.pluginID, "com.aurabot.ai-tutor")
        XCTAssertEqual(
            host.activeAppPresentation,
            AppPresentationPolicy(mode: .pluginWorkspace(pluginID: "com.aurabot.ai-tutor", name: "AI Tutor"))
        )
        XCTAssertEqual(host.activeCapturePolicy.priority, [.browserDOM, .browserTranscript, .appMetadata])
        XCTAssertEqual(host.activeWindowPolicy.presentation, .floatingOverlay)
    }

    func testPluginHostReturnsHostDefaultsAfterWorkspaceDeactivation() throws {
        let host = PluginHost()

        try host.activateWorkspace(makeWorkspacePluginDescriptor())
        host.deactivateWorkspace(pluginID: "com.aurabot.ai-tutor")

        XCTAssertNil(host.activeWorkspacePlugin)
        XCTAssertEqual(host.activeAppPresentation, .hostDefault)
        XCTAssertEqual(host.activeCapturePolicy, .hostDefault)
        XCTAssertEqual(host.activeWindowPolicy, .hostDefault)
    }

    func testPluginHostIgnoresDeactivateForDifferentPlugin() throws {
        let host = PluginHost()

        try host.activateWorkspace(makeWorkspacePluginDescriptor())
        host.deactivateWorkspace(pluginID: "com.example.other")

        XCTAssertEqual(host.activeWorkspacePlugin?.pluginID, "com.aurabot.ai-tutor")
    }

    @MainActor
    func testOnboardingGateUsesPersistedCompletionOnly() {
        var incompleteConfig = AppConfig.default
        incompleteConfig.app.onboardingCompleted = false
        XCTAssertTrue(AppService(config: incompleteConfig).needsOnboarding)

        var completedConfig = AppConfig.default
        completedConfig.app.onboardingCompleted = true
        XCTAssertFalse(AppService(config: completedConfig).needsOnboarding)
    }

    func testCapturePolicyDisablesVisualFallbackWhenPluginRequestsStructuredOnlyCapture() {
        let policy = CapturePolicy(
            priority: [.browserDOM, .browserTranscript, .appMetadata],
            fallback: .none,
            redaction: .strict
        )

        XCTAssertTrue(policy.allowsBrowserContext)
        XCTAssertTrue(policy.allowsAppMetadata)
        XCTAssertFalse(policy.allowsVisualFallback)
    }

    @MainActor
    func testAppServiceAppliesWorkspacePluginPresentationAndRollback() async throws {
        let service = AppService()

        try await service.activateWorkspacePlugin(makeWorkspacePluginDescriptor())

        XCTAssertEqual(
            service.appPresentation,
            AppPresentationPolicy(mode: .pluginWorkspace(pluginID: "com.aurabot.ai-tutor", name: "AI Tutor"))
        )
        XCTAssertEqual(service.windowPolicy.presentation, .floatingOverlay)

        await service.deactivateWorkspacePlugin(pluginID: "com.aurabot.ai-tutor")

        XCTAssertEqual(service.appPresentation, .hostDefault)
        XCTAssertEqual(service.windowPolicy, .hostDefault)
    }

    func testMemoryV2SearchFixtureDecodes() throws {
        let response = try decodeMemoryFixture("search-response", as: SearchMemoryResponse.self)

        XCTAssertEqual(response.schemaVersion, MemoryV2JSON.schemaVersion)
        XCTAssertEqual(response.items.first?.source, .brainChunk)
        XCTAssertEqual(response.items.first?.relations.first?.relationType, .decidedIn)
        XCTAssertEqual(response.debug.matchedEntities.first, "ent_project_aurabot")
    }

    func testMemoryV2RecentContextFixturesDecode() throws {
        let eventResponse = try decodeMemoryFixture(
            "recent-context-event-response",
            as: RecentContextEventResponse.self
        )
        let listResponse = try decodeMemoryFixture(
            "recent-context-list-response",
            as: RecentContextListResponse.self
        )

        XCTAssertEqual(eventResponse.schemaVersion, MemoryV2JSON.schemaVersion)
        XCTAssertEqual(eventResponse.event.source, .browser)
        XCTAssertEqual(eventResponse.event.displayContext, "Browse")
        XCTAssertEqual(listResponse.items.count, 2)
        XCTAssertEqual(listResponse.items.last?.source, .repo)
    }

    func testMemoryV2OperationalFixturesDecode() throws {
        let currentContext = try decodeMemoryFixture(
            "current-context-response",
            as: CurrentContextPacket.self
        )
        let graph = try decodeMemoryFixture("graph-query-response", as: GraphQueryResponse.self)
        let brainSync = try decodeMemoryFixture("brain-sync-response", as: BrainSyncResponse.self)
        let promotion = try decodeMemoryFixture("promotion-response", as: PromotionResponse.self)
        let delete = try decodeMemoryFixture("delete-response", as: DeleteResponse.self)
        let health = try decodeMemoryFixture("health-response", as: HealthResponse.self)

        XCTAssertEqual(currentContext.activeEntities, ["ent_project_aurabot", "ent_concept_memory_v2"])
        XCTAssertEqual(graph.relations.first?.evidence.first?.source, .brainPage)
        XCTAssertEqual(brainSync.syncedPages.first?.slug, "projects/aurabot")
        XCTAssertEqual(promotion.mode, "draft")
        XCTAssertEqual(delete.source, .recentContext)
        XCTAssertEqual(health.status, "ok")
    }

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
            visibleText: nil,
            selectedText: nil,
            readableText: nil,
            visibleTextHash: nil,
            readableTextHash: nil,
            textCaptureMode: nil,
            privateWindow: false,
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

    func testContextCollectorRewritePolicyRequiresOptIn() {
        let config = LLMConfig()

        XCTAssertFalse(config.allowsContextCollectorRewrite(for: "google/gemini-3.1-pro"))
    }

    func testContextCollectorRewritePolicyAcceptsConfiguredModelThresholds() {
        var config = LLMConfig()
        config.contextCollectorRewrite.enabled = true

        XCTAssertTrue(config.allowsContextCollectorRewrite(for: "google/gemini-3.1-pro"))
        XCTAssertTrue(config.allowsContextCollectorRewrite(for: "anthropic/claude-opus-4.5"))
        XCTAssertTrue(config.allowsContextCollectorRewrite(for: "openai/gpt-5.3"))
        XCTAssertTrue(config.allowsContextCollectorRewrite(for: "moonshotai/kimi-2.5"))
    }

    func testContextCollectorRewritePolicyRejectsLowerOrWrongTierModels() {
        var config = LLMConfig()
        config.contextCollectorRewrite.enabled = true

        XCTAssertFalse(config.allowsContextCollectorRewrite(for: "google/gemini-2.5-pro"))
        XCTAssertFalse(config.allowsContextCollectorRewrite(for: "anthropic/claude-sonnet-4.5"))
        XCTAssertFalse(config.allowsContextCollectorRewrite(for: "openai/gpt-5.2"))
        XCTAssertFalse(config.allowsContextCollectorRewrite(for: "moonshotai/kimi-2.1"))
    }

    func testBrowserExtensionPayloadCapturesTextHashesWithoutPersistingPrivateWindowText() throws {
        let payload = BrowserExtensionUpdateRequest(
            schemaVersion: 1,
            captureID: "capture-1",
            browser: "Google Chrome",
            bundleIdentifier: "com.google.Chrome",
            url: "https://example.com/article",
            title: "Example Article",
            activity: .browsing,
            pageID: nil,
            mediaID: nil,
            mediaIsPlaying: nil,
            scrollPercent: 42,
            viewportSignature: "viewport-1",
            noveltyScore: 0.6,
            visibleText: "Visible article text",
            selectedText: "Selected sentence",
            readableText: "Full readable page text",
            visibleTextHash: "visible-hash",
            readableTextHash: "readable-hash",
            textCaptureMode: "full_readable_text",
            privateWindow: true,
            timestamp: Date(timeIntervalSince1970: 0)
        )

        let context = try payload.asBrowserContext()

        XCTAssertEqual(context.textCaptureMode, "private_window_metadata_only")
        XCTAssertTrue(context.privateWindow)
        XCTAssertEqual(context.schemaVersion, 1)
        XCTAssertEqual(context.captureID, "capture-1")
        XCTAssertEqual(context.sourceQuality, .extensionPrivate)
        XCTAssertNil(context.visibleText)
        XCTAssertNil(context.readableText)
        XCTAssertEqual(context.visibleTextHash, "visible-hash")
        XCTAssertEqual(context.readableTextHash, "readable-hash")
    }

    func testBrowserExtensionPayloadRejectsUnsupportedSchemaVersion() throws {
        let payload = BrowserExtensionUpdateRequest(
            schemaVersion: 999,
            captureID: "capture-unsupported",
            browser: "Google Chrome",
            bundleIdentifier: "com.google.Chrome",
            url: "https://example.com/article",
            title: "Example Article",
            activity: .browsing,
            pageID: nil,
            mediaID: nil,
            mediaIsPlaying: nil,
            scrollPercent: nil,
            viewportSignature: nil,
            noveltyScore: nil,
            visibleText: nil,
            selectedText: nil,
            readableText: nil,
            visibleTextHash: nil,
            readableTextHash: nil,
            textCaptureMode: nil,
            privateWindow: false,
            timestamp: Date(timeIntervalSince1970: 0)
        )

        XCTAssertThrowsError(try payload.asBrowserContext())
    }

    func testBrowserContextServiceReportsFreshExtensionStatus() async throws {
        var config = ExtensionConfig()
        config.freshnessSeconds = 30
        let service = BrowserContextService(config: config)
        let context = makeBrowserContext(
            source: .extensionData,
            browser: "Google Chrome",
            bundleIdentifier: "com.google.Chrome",
            url: "https://example.com/docs",
            title: "Example Docs",
            timestamp: Date()
        )

        await service.updateExtensionContext(context)
        let status = await service.currentContextStatus()

        XCTAssertTrue(status.hasFreshExtensionContext)
        XCTAssertNil(status.staleExtensionContext)
        XCTAssertNil(status.reason)
        XCTAssertEqual(status.context?.sourceQuality, .extensionFull)
    }

    func testBrowserContextServicePreservesStaleExtensionDiagnostics() async throws {
        var config = ExtensionConfig()
        config.freshnessSeconds = 1
        let service = BrowserContextService(config: config)
        let context = makeBrowserContext(
            source: .extensionData,
            browser: "Google Chrome",
            bundleIdentifier: "com.google.Chrome",
            url: "https://example.com/docs",
            title: "Example Docs",
            timestamp: Date(timeIntervalSince1970: 0)
        )

        await service.updateExtensionContext(context)
        let status = await service.currentContextStatus()

        XCTAssertEqual(status.staleExtensionContext?.captureID, "capture-fixture")
        XCTAssertEqual(status.reason, .extensionStale)
    }

    func testComputerUseConfigDecodesMissingPayloadWithAuraDefaults() throws {
        let payload = """
        {
          "capture": {},
          "llm": {},
          "memory": {},
          "app": {},
          "extension": {}
        }
        """.data(using: .utf8)!

        let config = try JSONDecoder().decode(AppConfig.self, from: payload)

        XCTAssertFalse(config.computerUse.enabled)
        XCTAssertTrue(config.computerUse.autoStart)
        XCTAssertTrue(config.computerUse.allowUpdateChecks)
        XCTAssertFalse(config.computerUse.recordTrajectories)
        XCTAssertEqual(config.computerUse.captureMode, "som")
    }

    func testCuaDriverVendorManifestTargetsBundledAuraComputerUseEngine() throws {
        let manifest = try CuaDriverInstallationManager().loadManifest()
        let artifact = try XCTUnwrap(manifest.artifacts.first)

        XCTAssertEqual(manifest.name, "AuraBot Computer Use")
        XCTAssertEqual(manifest.version, "0.1.2")
        XCTAssertEqual(manifest.bundleIdentifier, "com.trycua.driver")
        XCTAssertEqual(manifest.license, "MIT")
        XCTAssertEqual(artifact.architecture, "arm64")
        XCTAssertEqual(
            artifact.sha256,
            "bbe83a79f15d3da11b5de94cda414b70727b621b2d5319e6e2fa1a1137157654"
        )
    }

    func testCuaDriverBundleIsVendoredAndVerifiable() throws {
        let manager = CuaDriverInstallationManager()
        let appURL = try manager.bundledAppURL()

        XCTAssertTrue(try manager.validateBundle(at: appURL))
        XCTAssertEqual(manager.bundleVersion(for: appURL), "0.1.2")
        XCTAssertTrue(
            FileManager.default.isExecutableFile(
                atPath: appURL.appendingPathComponent("Contents/MacOS/cua-driver").path
            )
        )
    }

    func testOldComputerUseImplementationIsRemoved() {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: repoRoot
                    .appendingPathComponent("apps/macos/Sources/AuraBot/ComputerUse")
                    .path
            )
        )
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: repoRoot
                    .appendingPathComponent("apps/macos/Sources/AuraBot/Resources/ComputerUseSkills")
                    .path
            )
        )
    }

    private func makeBrowserContext(
        source: BrowserContextSource,
        browser: String,
        bundleIdentifier: String,
        url: String,
        title: String,
        timestamp: Date = Date(timeIntervalSince1970: 0)
    ) -> BrowserContext {
        let derived = BrowserContextService.deriveActivity(url: url, title: title)

        return BrowserContext(
            source: source,
            browser: browser,
            bundleIdentifier: bundleIdentifier,
            url: url,
            title: title,
            activity: derived.activity,
            pageID: derived.pageID,
            mediaID: derived.mediaID,
            mediaIsPlaying: derived.activity == .media,
            scrollPercent: 42,
            viewportSignature: "viewport-1",
            noveltyScore: 0.2,
            visibleText: "Visible documentation text",
            selectedText: nil,
            readableText: nil,
            visibleTextHash: "visible-hash",
            readableTextHash: nil,
            textCaptureMode: "visible_viewport",
            privateWindow: false,
            captureID: "capture-fixture",
            timestamp: timestamp
        )
    }

}

@available(macOS 14.0, *)
private func makeWorkspacePluginDescriptor() -> WorkspacePluginDescriptor {
    WorkspacePluginDescriptor(
        pluginID: "com.aurabot.ai-tutor",
        name: "AI Tutor",
        takeover: PluginTakeoverPolicy(
            ui: .replace,
            agent: .replace,
            context: .replace,
            capture: .replace,
            memory: .augment,
            retrieval: .replace,
            window: .replace,
            commands: .replace,
            settings: .augment
        ),
        appBehavior: AppBehaviorPolicy(
            navigation: .pluginWorkspace,
            commands: .pluginWorkspace,
            fallback: .hostDefault
        ),
        capturePolicy: CapturePolicy(
            priority: [.browserDOM, .browserTranscript, .appMetadata],
            fallback: .none,
            redaction: .strict
        ),
        windowPolicy: WindowPolicy(
            presentation: .floatingOverlay,
            level: .alwaysOnTop,
            hideWhen: [.screenSharing, .sensitiveApp],
            excludePluginUIFromCapture: true
        )
    )
}

@available(macOS 14.0, *)
private func decodeMemoryFixture<T: Decodable>(_ name: String, as type: T.Type) throws -> T {
    let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let url = repoRoot
        .appendingPathComponent("services/memory-pglite/src/test-fixtures")
        .appendingPathComponent("\(name).json")
    let data = try Data(contentsOf: url)
    return try MemoryV2JSON.makeDecoder().decode(type, from: data)
}
