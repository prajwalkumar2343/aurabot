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

    func testBundledComputerUseSkillsLoad() throws {
        let skills = try AppSkillLoader().loadBundledSkills()
        let skillIDs = Set(skills.map(\.id))

        XCTAssertTrue(skillIDs.contains("finder"))
        XCTAssertTrue(skillIDs.contains("safari"))
        XCTAssertTrue(skillIDs.contains("chrome"))
        XCTAssertTrue(skillIDs.contains("terminal"))
        XCTAssertTrue(skillIDs.contains("generic-native-app"))
    }

    func testFinderMoveToolSelectionBuildsFileAPIPlanWithConfirmation() throws {
        let router = try ComputerUseCapabilityRouter.bundled()

        let plan = try XCTUnwrap(
            router.plan(
                for: ComputerUseToolSelection(
                    skillID: "finder",
                    actionName: "move_files",
                    confidence: 0.91,
                    reasons: ["test_tool_selection"]
                )
            )
        )

        XCTAssertEqual(plan.skillID, "finder")
        XCTAssertEqual(plan.actionName, "move_files")
        XCTAssertEqual(plan.worker, .fileAPI)
        XCTAssertTrue(plan.parallelSafe)
        XCTAssertFalse(plan.requiresForegroundLock)
        XCTAssertTrue(plan.requiresConfirmation)
        XCTAssertFalse(plan.destructive)
    }

    func testChromeToolSelectionPrefersBrowserExtension() throws {
        let router = try ComputerUseCapabilityRouter.bundled()

        let plan = try XCTUnwrap(
            router.plan(
                for: ComputerUseToolSelection(
                    skillID: "chrome",
                    actionName: "extract_page_context",
                    confidence: 0.88,
                    reasons: ["test_tool_selection"]
                )
            )
        )

        XCTAssertEqual(plan.skillID, "chrome")
        XCTAssertEqual(plan.actionName, "extract_page_context")
        XCTAssertEqual(plan.worker, .browserExtension)
        XCTAssertTrue(plan.parallelSafe)
        XCTAssertFalse(plan.requiresConfirmation)
    }

    func testSafariCurrentPageToolSelectionPrefersAppleEvents() throws {
        let router = try ComputerUseCapabilityRouter.bundled()

        let plan = try XCTUnwrap(
            router.plan(
                for: ComputerUseToolSelection(
                    skillID: "safari",
                    actionName: "get_current_page",
                    confidence: 0.86,
                    reasons: ["test_tool_selection"]
                )
            )
        )

        XCTAssertEqual(plan.skillID, "safari")
        XCTAssertEqual(plan.actionName, "get_current_page")
        XCTAssertEqual(plan.worker, .appleEvents)
        XCTAssertTrue(plan.parallelSafe)
        XCTAssertFalse(plan.requiresConfirmation)
    }

    func testBrowserExtensionWorkerExtractsMockedChromeContext() async throws {
        let router = try ComputerUseCapabilityRouter.bundled()
        let plan = try XCTUnwrap(
            router.plan(
                for: ComputerUseToolSelection(
                    skillID: "chrome",
                    actionName: "extract_page_context",
                    confidence: 0.88,
                    reasons: ["test_tool_selection"]
                )
            )
        )
        let worker = BrowserExtensionComputerUseWorker(
            contextProvider: StaticBrowserContextProvider(
                context: makeBrowserContext(
                    source: .extensionData,
                    browser: "Google Chrome",
                    bundleIdentifier: "com.google.Chrome",
                    url: "https://example.com/docs",
                    title: "Example Docs"
                )
            )
        )

        let result = await worker.execute(
            ComputerUseWorkerRequest(plan: plan, command: "summarize this page")
        )

        XCTAssertEqual(result.status, .success)
        XCTAssertEqual(result.worker, .browserExtension)
        XCTAssertEqual(result.metadata["source"], "extension")
        XCTAssertEqual(result.metadata["browser"], "Google Chrome")
        XCTAssertEqual(result.metadata["url"], "https://example.com/docs")
        XCTAssertEqual(result.metadata["title"], "Example Docs")
        XCTAssertEqual(result.metadata["page_id"], "example.com/docs")
        XCTAssertEqual(result.metadata["schema_version"], "1")
        XCTAssertEqual(result.metadata["capture_id"], "capture-fixture")
        XCTAssertEqual(result.metadata["source_quality"], "extension_full")
    }

    func testBrowserExtensionWorkerFallsBackWhenExtensionContextIsUnavailable() async throws {
        let router = try ComputerUseCapabilityRouter.bundled()
        let plan = try XCTUnwrap(
            router.plan(
                for: ComputerUseToolSelection(
                    skillID: "chrome",
                    actionName: "extract_page_context",
                    confidence: 0.88,
                    reasons: ["test_tool_selection"]
                )
            )
        )
        let worker = BrowserExtensionComputerUseWorker(
            contextProvider: StaticBrowserContextProvider(
                context: makeBrowserContext(
                    source: .automation,
                    browser: "Google Chrome",
                    bundleIdentifier: "com.google.Chrome",
                    url: "https://example.com/docs",
                    title: "Example Docs"
                )
            )
        )

        let result = await worker.execute(
            ComputerUseWorkerRequest(plan: plan, command: "summarize this page")
        )

        XCTAssertEqual(result.status, .unavailable)
        XCTAssertEqual(result.metadata["reason"], "browser_extension_context_unavailable")
        XCTAssertEqual(result.metadata["fallback_workers"], "browser_devtools,apple_events,accessibility")
    }

    func testSafariAppleEventsWorkerParsesMockedCurrentPage() async throws {
        let router = try ComputerUseCapabilityRouter.bundled()
        let plan = try XCTUnwrap(
            router.plan(
                for: ComputerUseToolSelection(
                    skillID: "safari",
                    actionName: "get_current_page",
                    confidence: 0.86,
                    reasons: ["test_tool_selection"]
                )
            )
        )
        let worker = AppleEventsComputerUseWorker(
            runner: StaticAppleScriptRunner(
                result: AppleScriptRunResult(
                    terminationStatus: 0,
                    output: "https://apple.com/safari\nSafari Browser",
                    errorOutput: ""
                )
            )
        )

        let result = await worker.execute(
            ComputerUseWorkerRequest(plan: plan, command: "what page is open")
        )

        XCTAssertEqual(result.status, .success)
        XCTAssertEqual(result.worker, .appleEvents)
        XCTAssertEqual(result.metadata["url"], "https://apple.com/safari")
        XCTAssertEqual(result.metadata["title"], "Safari Browser")
        XCTAssertEqual(result.metadata["page_id"], "apple.com/safari")
    }

    func testUnknownAppRoutesToGenericAccessibilityInspection() throws {
        let router = try ComputerUseCapabilityRouter.bundled()

        let plan = try XCTUnwrap(
            router.fallbackPlan(
                for: ComputerUseCommandContext(
                    command: "figure out what controls are available",
                    activeAppName: "UnknownApp",
                    bundleIdentifier: "com.example.Unknown"
                )
            )
        )

        XCTAssertEqual(plan.skillID, "generic-native-app")
        XCTAssertEqual(plan.actionName, "inspect_ui")
        XCTAssertEqual(plan.worker, .accessibility)
        XCTAssertTrue(plan.parallelSafe)
        XCTAssertFalse(plan.requiresConfirmation)
    }

    func testAccessibilityNormalizerCompactsAndLimitsStaticTree() {
        let snapshot = AccessibilityRawElementSnapshot(
            role: nil,
            title: "   Main   Window   ",
            actions: ["AXRaise", "AXPress"],
            children: [
                AccessibilityRawElementSnapshot(
                    role: "AXButton",
                    title: "  Continue\nButton  ",
                    value: "ignored",
                    actions: ["AXPress"]
                ),
                AccessibilityRawElementSnapshot(
                    role: "AXStaticText",
                    value: "A long label that should be truncated"
                )
            ]
        )
        let normalizer = AccessibilitySnapshotNormalizer(
            maxDepth: 1,
            maxChildrenPerElement: 1,
            maxTextLength: 18
        )

        let normalized = normalizer.normalize(snapshot)

        XCTAssertEqual(normalized.role, "AXUnknown")
        XCTAssertEqual(normalized.name, "Main Window")
        XCTAssertEqual(normalized.actions, ["AXPress", "AXRaise"])
        XCTAssertEqual(normalized.children.count, 1)
        XCTAssertEqual(normalized.children.first?.path, "0.0")
        XCTAssertEqual(normalized.children.first?.name, "Continue Button")
        XCTAssertEqual(normalized.children.first?.value, "ignored")
    }

    func testAccessibilityWorkerRequiresPermissionBeforeInspection() async throws {
        let router = try ComputerUseCapabilityRouter.bundled()
        let plan = try XCTUnwrap(
            router.plan(
                for: ComputerUseToolSelection(
                    skillID: "generic-native-app",
                    actionName: "inspect_ui",
                    confidence: 0.75,
                    reasons: ["test_tool_selection"]
                )
            )
        )
        let worker = AccessibilityComputerUseWorker(
            permissionChecker: StaticAccessibilityPermissionChecker(trusted: false),
            treeReader: StaticAccessibilityTreeReader(snapshot: makeAccessibilitySnapshot())
        )

        let result = await worker.execute(
            ComputerUseWorkerRequest(plan: plan, command: "inspect this app")
        )

        XCTAssertEqual(result.status, .unavailable)
        XCTAssertEqual(result.metadata["reason"], "accessibility_permission_missing")
        XCTAssertEqual(result.metadata["fallback_workers"], "screen_observation")
    }

    func testAccessibilityWorkerReturnsNormalizedReadOnlySnapshot() async throws {
        let router = try ComputerUseCapabilityRouter.bundled()
        let plan = try XCTUnwrap(
            router.plan(
                for: ComputerUseToolSelection(
                    skillID: "generic-native-app",
                    actionName: "inspect_ui",
                    confidence: 0.75,
                    reasons: ["test_tool_selection"]
                )
            )
        )
        let worker = AccessibilityComputerUseWorker(
            permissionChecker: StaticAccessibilityPermissionChecker(trusted: true),
            treeReader: StaticAccessibilityTreeReader(snapshot: makeAccessibilitySnapshot())
        )

        let result = await worker.execute(
            ComputerUseWorkerRequest(plan: plan, command: "inspect this app")
        )

        XCTAssertEqual(result.status, .success)
        XCTAssertEqual(result.worker, .accessibility)
        XCTAssertEqual(result.metadata["root_role"], "AXWindow")
        XCTAssertEqual(result.metadata["element_count"], "2")
        XCTAssertTrue(result.metadata["summary"]?.contains("AXButton") == true)
        XCTAssertTrue(result.metadata["snapshot_json"]?.contains("Submit") == true)
    }

    func testDestructiveFinderCommandAlwaysRequiresConfirmation() throws {
        let router = try ComputerUseCapabilityRouter.bundled()

        let plan = try XCTUnwrap(
            router.plan(
                for: ComputerUseToolSelection(
                    skillID: "finder",
                    actionName: "delete_files",
                    confidence: 0.95,
                    reasons: ["test_tool_selection"]
                )
            )
        )

        XCTAssertEqual(plan.skillID, "finder")
        XCTAssertEqual(plan.actionName, "delete_files")
        XCTAssertTrue(plan.destructive)
        XCTAssertTrue(plan.requiresConfirmation)
        XCTAssertFalse(plan.parallelSafe)
    }

    func testConfirmationPolicyDetectsDestructiveCommandLanguage() throws {
        let plan = ComputerUseExecutionPlan(
            skillID: "terminal",
            appName: "Terminal",
            actionName: "run_command",
            worker: .nativeCommand,
            fallbackWorkers: [],
            parallelSafe: true,
            requiresFocus: .never,
            requiresForegroundLock: false,
            requiresConfirmation: false,
            destructive: false,
            permissions: [],
            confidence: 0.8,
            matchReasons: ["test"]
        )
        let request = ComputerUseWorkerRequest(
            plan: plan,
            command: "remove the generated folder"
        )

        XCTAssertTrue(ComputerUseConfirmationPolicy().requiresConfirmation(request))
        XCTAssertTrue(ComputerUseConfirmationPolicy().shouldBlock(request))
    }

    func testExecutionCoordinatorBlocksUnsafeActionAndAuditsDecision() async throws {
        let router = try ComputerUseCapabilityRouter.bundled()
        let plan = try XCTUnwrap(
            router.plan(
                for: ComputerUseToolSelection(
                    skillID: "finder",
                    actionName: "delete_files",
                    confidence: 0.95,
                    reasons: ["test_tool_selection"]
                )
            )
        )
        let auditLog = InMemoryComputerUseAuditLog()
        let coordinator = ComputerUseExecutionCoordinator(
            registry: .dryRunDefault(),
            auditLog: auditLog,
            now: { Date(timeIntervalSince1970: 10) }
        )

        let result = await coordinator.execute(
            ComputerUseWorkerRequest(plan: plan, command: "delete these files")
        )
        let records = await auditLog.allRecords()

        XCTAssertEqual(result.status, .requiresConfirmation)
        XCTAssertEqual(result.metadata["reason"], "confirmation_required")
        XCTAssertEqual(records.map(\.phase), [.requested, .blocked])
        XCTAssertEqual(records.last?.status, .requiresConfirmation)
        XCTAssertEqual(records.last?.destructive, true)
    }

    func testExecutionCoordinatorAuditsSuccessfulWorkerExecution() async throws {
        let router = try ComputerUseCapabilityRouter.bundled()
        let plan = try XCTUnwrap(
            router.plan(
                for: ComputerUseToolSelection(
                    skillID: "chrome",
                    actionName: "extract_page_context",
                    confidence: 0.88,
                    reasons: ["test_tool_selection"]
                )
            )
        )
        let auditLog = InMemoryComputerUseAuditLog()
        let coordinator = ComputerUseExecutionCoordinator(
            registry: .dryRunDefault(),
            auditLog: auditLog,
            now: { Date(timeIntervalSince1970: 20) }
        )

        let result = await coordinator.execute(
            ComputerUseWorkerRequest(plan: plan, command: "summarize this page")
        )
        let records = await auditLog.allRecords()

        XCTAssertEqual(result.status, .skipped)
        XCTAssertEqual(records.map(\.phase), [.requested, .started, .completed])
        XCTAssertEqual(records.last?.status, .skipped)
        XCTAssertEqual(records.last?.requiresForegroundLock, false)
    }

    func testForegroundInteractionLockSerializesRequiredOperations() async {
        let foregroundLock = ComputerUseForegroundInteractionLock()
        let recorder = ForegroundLockRecorder()

        let first = Task {
            await foregroundLock.withLock(required: true) {
                await recorder.append("first-start")
                try? await Task.sleep(nanoseconds: 50_000_000)
                await recorder.append("first-end")
            }
        }
        try? await Task.sleep(nanoseconds: 5_000_000)

        let second = Task {
            await foregroundLock.withLock(required: true) {
                await recorder.append("second-start")
                await recorder.append("second-end")
            }
        }

        _ = await (first.value, second.value)
        let events = await recorder.events()

        XCTAssertEqual(
            events,
            ["first-start", "first-end", "second-start", "second-end"]
        )
    }

    func testDryRunWorkerRegistryResolvesRoutedWorker() async throws {
        let router = try ComputerUseCapabilityRouter.bundled()
        let plan = try XCTUnwrap(
            router.plan(
                for: ComputerUseToolSelection(
                    skillID: "chrome",
                    actionName: "extract_page_context",
                    confidence: 0.88,
                    reasons: ["test_tool_selection"]
                )
            )
        )
        let registry = ComputerUseWorkerRegistry.dryRunDefault()
        let worker = try XCTUnwrap(registry.worker(for: plan))

        let result = await worker.execute(
            ComputerUseWorkerRequest(plan: plan, command: "summarize this page")
        )

        XCTAssertEqual(result.worker, .browserExtension)
        XCTAssertEqual(result.status, .skipped)
        XCTAssertFalse(result.requiresConfirmation)
        XCTAssertEqual(result.metadata["skill_id"], "chrome")
    }

    func testLocalWorkerRegistryUsesRealWorkersForSafeLocalPaths() throws {
        let registry = ComputerUseWorkerRegistry.localDefault()

        let accessibilityWorker = try XCTUnwrap(registry.worker(for: .accessibility))
        let appleEventsWorker = try XCTUnwrap(registry.worker(for: .appleEvents))
        let browserExtensionWorker = try XCTUnwrap(registry.worker(for: .browserExtension))
        let fileAPIWorker = try XCTUnwrap(registry.worker(for: .fileAPI))

        XCTAssertTrue(accessibilityWorker is AccessibilityComputerUseWorker)
        XCTAssertTrue(appleEventsWorker is AppleEventsComputerUseWorker)
        XCTAssertTrue(browserExtensionWorker is BrowserExtensionComputerUseWorker)
        XCTAssertTrue(fileAPIWorker is FileAPIComputerUseWorker)
    }

    func testFileAPIMoveFilesRequiresConfirmationBeforeDryRun() async throws {
        let router = try ComputerUseCapabilityRouter.bundled()
        let plan = try XCTUnwrap(
            router.plan(
                for: ComputerUseToolSelection(
                    skillID: "finder",
                    actionName: "move_files",
                    confidence: 0.9,
                    reasons: ["test_tool_selection"]
                )
            )
        )
        let worker = FileAPIComputerUseWorker()

        let result = await worker.execute(
            ComputerUseWorkerRequest(
                plan: plan,
                command: "move files",
                parameters: [
                    "source_paths": "/tmp/example-a\n/tmp/example-b",
                    "destination_path": "/tmp"
                ]
            )
        )

        XCTAssertEqual(result.status, .requiresConfirmation)
        XCTAssertTrue(result.requiresConfirmation)
    }

    func testFileAPIMoveFilesDryRunDoesNotMutateFilesystem() async throws {
        let router = try ComputerUseCapabilityRouter.bundled()
        let plan = try XCTUnwrap(
            router.plan(
                for: ComputerUseToolSelection(
                    skillID: "finder",
                    actionName: "move_files",
                    confidence: 0.9,
                    reasons: ["test_tool_selection"]
                )
            )
        )
        let worker = FileAPIComputerUseWorker()
        let fixture = try makeTemporaryMoveFixture(fileName: "dry-run-note.txt")
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        let plannedDestination = fixture.destinationDirectory
            .appendingPathComponent(fixture.sourceFile.lastPathComponent)

        let result = await worker.execute(
            ComputerUseWorkerRequest(
                plan: plan,
                command: "move files",
                parameters: [
                    "confirmed": "true",
                    "dry_run": "true",
                    "source_path": fixture.sourceFile.path,
                    "destination_path": fixture.destinationDirectory.path
                ]
            )
        )

        XCTAssertEqual(result.status, .success)
        XCTAssertEqual(result.metadata["dry_run"], "true")
        XCTAssertEqual(result.metadata["source_count"], "1")
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.sourceFile.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: plannedDestination.path))
    }

    func testFileAPIMoveFilesMovesTemporaryFileWhenConfirmed() async throws {
        let router = try ComputerUseCapabilityRouter.bundled()
        let plan = try XCTUnwrap(
            router.plan(
                for: ComputerUseToolSelection(
                    skillID: "finder",
                    actionName: "move_files",
                    confidence: 0.9,
                    reasons: ["test_tool_selection"]
                )
            )
        )
        let worker = FileAPIComputerUseWorker()
        let fixture = try makeTemporaryMoveFixture(fileName: "confirmed-note.txt")
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        let movedFile = fixture.destinationDirectory
            .appendingPathComponent(fixture.sourceFile.lastPathComponent)
        let encodedSourcePaths = try XCTUnwrap(
            String(data: JSONEncoder().encode([fixture.sourceFile.path]), encoding: .utf8)
        )

        let result = await worker.execute(
            ComputerUseWorkerRequest(
                plan: plan,
                command: "move files",
                parameters: [
                    "confirmed": "true",
                    "dry_run": "false",
                    "source_paths_json": encodedSourcePaths,
                    "destination_path": fixture.destinationDirectory.path
                ]
            )
        )

        XCTAssertEqual(result.status, .success)
        XCTAssertEqual(result.metadata["dry_run"], "false")
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.sourceFile.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: movedFile.path))
        XCTAssertEqual(try String(contentsOf: movedFile, encoding: .utf8), "fixture")
    }

    func testToolSchemaBuilderRoundTripsToolSelection() throws {
        let skills = try AppSkillLoader().loadBundledSkills()
        let builder = ComputerUseToolSchemaBuilder()
        let tools = builder.buildTools(from: skills)

        XCTAssertTrue(tools.contains(where: { $0.name == "finder__move_files" }))
        XCTAssertTrue(tools.contains(where: { $0.name == "chrome__extract_page_context" }))

        let selection = try XCTUnwrap(
            builder.selection(
                from: "finder__move_files",
                arguments: [
                    "reason": "User asked to move Finder selection",
                    "confidence": 0.93
                ]
            )
        )

        XCTAssertEqual(selection.skillID, "finder")
        XCTAssertEqual(selection.actionName, "move_files")
        XCTAssertEqual(selection.confidence, 0.93)
        XCTAssertTrue(selection.reasons.contains("openrouter_tool_call"))
    }

    private func makeTemporaryMoveFixture(
        fileName: String
    ) throws -> (root: URL, sourceFile: URL, destinationDirectory: URL) {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("aurabot-computeruse-\(UUID().uuidString)", isDirectory: true)
        let sourceDirectory = root.appendingPathComponent("source", isDirectory: true)
        let destinationDirectory = root.appendingPathComponent("destination", isDirectory: true)
        let sourceFile = sourceDirectory.appendingPathComponent(fileName)

        try fileManager.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
        try "fixture".write(to: sourceFile, atomically: true, encoding: .utf8)

        return (root, sourceFile, destinationDirectory)
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

    private func makeAccessibilitySnapshot() -> AccessibilityRawElementSnapshot {
        AccessibilityRawElementSnapshot(
            role: "AXWindow",
            title: "Settings",
            identifier: "settings-window",
            actions: ["AXRaise"],
            frame: AccessibilityElementFrame(x: 0, y: 0, width: 640, height: 480),
            children: [
                AccessibilityRawElementSnapshot(
                    role: "AXButton",
                    title: "Submit",
                    identifier: "submit-button",
                    actions: ["AXPress"],
                    frame: AccessibilityElementFrame(x: 20, y: 20, width: 120, height: 40)
                )
            ]
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

private actor ForegroundLockRecorder {
    private var recordedEvents: [String] = []

    func append(_ event: String) {
        recordedEvents.append(event)
    }

    func events() -> [String] {
        recordedEvents
    }
}
