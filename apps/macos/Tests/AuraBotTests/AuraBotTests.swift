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

        let appleEventsWorker = try XCTUnwrap(registry.worker(for: .appleEvents))
        let fileAPIWorker = try XCTUnwrap(registry.worker(for: .fileAPI))

        XCTAssertTrue(appleEventsWorker is AppleEventsComputerUseWorker)
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

        let result = await worker.execute(
            ComputerUseWorkerRequest(
                plan: plan,
                command: "move files",
                parameters: [
                    "confirmed": "true",
                    "dry_run": "true",
                    "source_paths": "/tmp/example-a\n/tmp/example-b",
                    "destination_path": "/tmp"
                ]
            )
        )

        XCTAssertEqual(result.status, .success)
        XCTAssertEqual(result.metadata["dry_run"], "true")
        XCTAssertEqual(result.metadata["source_count"], "2")
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
}
