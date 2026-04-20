import json
import unittest
from pathlib import Path


SKILL_ROOT = (
    Path(__file__).resolve().parents[2]
    / "Sources"
    / "AuraBot"
    / "Resources"
    / "ComputerUseSkills"
    / "apps"
)
COMPUTER_USE_ROOT = Path(__file__).resolve().parents[2] / "Sources" / "AuraBot" / "ComputerUse"


class ComputerUseSkillContractTests(unittest.TestCase):
    def load_skills(self):
        skills = []
        for path in sorted(SKILL_ROOT.glob("*/skill.json")):
            with path.open() as handle:
                skill = json.load(handle)
                skill["_path"] = str(path)
                skills.append(skill)
        return skills

    def test_skill_files_exist_and_are_valid_json(self):
        paths = sorted(SKILL_ROOT.glob("*/skill.json"))

        self.assertGreaterEqual(len(paths), 5)
        for path in paths:
            with path.open() as handle:
                json.load(handle)

    def test_starter_skills_are_present(self):
        skill_ids = {skill["id"] for skill in self.load_skills()}

        self.assertEqual(
            {"finder", "safari", "chrome", "terminal", "generic-native-app"},
            skill_ids,
        )

    def test_manifest_identity_matches_directory(self):
        for skill in self.load_skills():
            path = Path(skill["_path"])

            self.assertEqual(path.parent.name, skill["id"])
            self.assertRegex(skill["id"], r"^[a-z0-9][a-z0-9-]*$")
            self.assertGreater(len(skill["app_name"].strip()), 0)
            self.assertGreater(len(skill["category"].strip()), 0)
            self.assertIsInstance(skill["aliases"], list)
            self.assertIsInstance(skill["bundle_ids"], list)
            self.assertIsInstance(skill["domains"], list)

    def test_every_action_declares_safety_and_worker_metadata(self):
        valid_focus = {"never", "app_dependent", "always"}
        valid_workers = {
            "native_command",
            "browser_extension",
            "browser_devtools",
            "apple_events",
            "shortcuts",
            "accessibility",
            "screen_observation",
            "foreground_input",
            "file_api",
        }

        for skill in self.load_skills():
            self.assertTrue(skill["id"])
            self.assertTrue(skill["app_name"])
            self.assertIsInstance(skill["priority"], int)
            self.assertGreater(len(skill["actions"]), 0)

            for action in skill["actions"]:
                self.assertRegex(action["name"], r"^[a-z][a-z0-9_]*$")
                self.assertGreater(len(action["description"].strip()), 0)
                self.assertIn(action["preferred_worker"], valid_workers)
                self.assertTrue(set(action["fallback_workers"]).issubset(valid_workers))
                self.assertIn(action["requires_focus"], valid_focus)
                self.assertIsInstance(action["parallel_safe"], bool)
                self.assertIsInstance(action["requires_confirmation"], bool)
                self.assertIsInstance(action["destructive"], bool)
                self.assertGreater(len(action["intents"]), 0)
                self.assertEqual(len(action["intents"]), len(set(action["intents"])))
                self.assertIsInstance(action["permissions"], list)

                for intent in action["intents"]:
                    self.assertEqual(intent, intent.strip())
                    self.assertGreaterEqual(len(intent), 3)
                    self.assertLessEqual(len(intent), 80)

                for worker in action["fallback_workers"]:
                    self.assertNotEqual(worker, action["preferred_worker"])

    def test_destructive_actions_require_confirmation(self):
        for skill in self.load_skills():
            for action in skill["actions"]:
                if action["destructive"]:
                    self.assertTrue(
                        action["requires_confirmation"],
                        f"{skill['id']}.{action['name']} must require confirmation",
                    )

    def test_expected_worker_preferences_are_encoded(self):
        skills = {skill["id"]: skill for skill in self.load_skills()}

        finder_actions = {action["name"]: action for action in skills["finder"]["actions"]}
        chrome_actions = {action["name"]: action for action in skills["chrome"]["actions"]}
        generic_actions = {
            action["name"]: action
            for action in skills["generic-native-app"]["actions"]
        }

        self.assertEqual(finder_actions["move_files"]["preferred_worker"], "file_api")
        self.assertTrue(finder_actions["move_files"]["requires_confirmation"])
        self.assertEqual(
            chrome_actions["extract_page_context"]["preferred_worker"],
            "browser_extension",
        )
        self.assertEqual(
            generic_actions["inspect_ui"]["preferred_worker"],
            "accessibility",
        )

    def test_openrouter_tool_names_are_unique_and_valid(self):
        tool_names = []
        for skill in self.load_skills():
            for action in skill["actions"]:
                tool_names.append(f"{skill['id']}__{action['name']}".replace("-", "_"))

        self.assertEqual(len(tool_names), len(set(tool_names)))
        for name in tool_names:
            self.assertRegex(name, r"^[A-Za-z0-9_]+$")
            self.assertLessEqual(len(name), 64)

    def test_real_worker_slice_exists_for_safe_local_paths(self):
        expected_files = [
            COMPUTER_USE_ROOT / "Accessibility" / "AccessibilityElementSnapshot.swift",
            COMPUTER_USE_ROOT / "Accessibility" / "AccessibilityPermission.swift",
            COMPUTER_USE_ROOT / "Accessibility" / "AccessibilitySnapshotNormalizer.swift",
            COMPUTER_USE_ROOT / "Accessibility" / "AccessibilityTreeReader.swift",
            COMPUTER_USE_ROOT / "Core" / "ComputerUseExecutionCoordinator.swift",
            COMPUTER_USE_ROOT / "Safety" / "ComputerUseAuditLog.swift",
            COMPUTER_USE_ROOT / "Safety" / "ConfirmationPolicy.swift",
            COMPUTER_USE_ROOT / "Safety" / "ForegroundInteractionLock.swift",
            COMPUTER_USE_ROOT / "Workers" / "AccessibilityComputerUseWorker.swift",
            COMPUTER_USE_ROOT / "Workers" / "AppleEventsComputerUseWorker.swift",
            COMPUTER_USE_ROOT / "Workers" / "BrowserExtensionComputerUseWorker.swift",
            COMPUTER_USE_ROOT / "Workers" / "FileAPIComputerUseWorker.swift",
        ]

        for path in expected_files:
            self.assertTrue(path.exists(), f"Missing worker file: {path}")

        registry_source = (COMPUTER_USE_ROOT / "Workers" / "ComputerUseWorker.swift").read_text()
        self.assertIn("static func localDefault(", registry_source)
        self.assertIn("accessibilityPermissionChecker", registry_source)
        self.assertIn("accessibilityTreeReader", registry_source)
        self.assertIn("AccessibilityComputerUseWorker(", registry_source)
        self.assertIn("browserContextProvider", registry_source)
        self.assertIn("AppleEventsComputerUseWorker()", registry_source)
        self.assertIn("BrowserExtensionComputerUseWorker(", registry_source)
        self.assertIn("FileAPIComputerUseWorker()", registry_source)

    def test_safety_slice_blocks_audits_and_serializes_unsafe_work(self):
        coordinator_source = (
            COMPUTER_USE_ROOT
            / "Core"
            / "ComputerUseExecutionCoordinator.swift"
        ).read_text()
        confirmation_source = (
            COMPUTER_USE_ROOT
            / "Safety"
            / "ConfirmationPolicy.swift"
        ).read_text()
        lock_source = (
            COMPUTER_USE_ROOT
            / "Safety"
            / "ForegroundInteractionLock.swift"
        ).read_text()
        audit_source = (
            COMPUTER_USE_ROOT
            / "Safety"
            / "ComputerUseAuditLog.swift"
        ).read_text()
        test_source = (
            Path(__file__).resolve().parents[1]
            / "AuraBotTests"
            / "AuraBotTests.swift"
        ).read_text()

        self.assertIn("ComputerUseDestructiveActionDetector", confirmation_source)
        self.assertIn("destructiveCommandTokens", confirmation_source)
        self.assertIn("confirmationPolicy.shouldBlock", coordinator_source)
        self.assertIn(".blocked", coordinator_source)
        self.assertIn("foregroundLock.withLock", coordinator_source)
        self.assertIn("protocol ComputerUseAuditLogging", audit_source)
        self.assertIn("struct ComputerUseAuditRecord", audit_source)
        self.assertIn("CheckedContinuation", lock_source)
        self.assertIn("testExecutionCoordinatorBlocksUnsafeActionAndAuditsDecision", test_source)
        self.assertIn("testForegroundInteractionLockSerializesRequiredOperations", test_source)

    def test_accessibility_slice_is_read_only_and_mockable(self):
        worker_source = (
            COMPUTER_USE_ROOT
            / "Workers"
            / "AccessibilityComputerUseWorker.swift"
        ).read_text()
        reader_source = (
            COMPUTER_USE_ROOT
            / "Accessibility"
            / "AccessibilityTreeReader.swift"
        ).read_text()
        normalizer_source = (
            COMPUTER_USE_ROOT
            / "Accessibility"
            / "AccessibilitySnapshotNormalizer.swift"
        ).read_text()
        test_source = (
            Path(__file__).resolve().parents[1]
            / "AuraBotTests"
            / "AuraBotTests.swift"
        ).read_text()

        self.assertIn("protocol AccessibilityPermissionChecking", (COMPUTER_USE_ROOT / "Accessibility" / "AccessibilityPermission.swift").read_text())
        self.assertIn("protocol AccessibilityTreeReading", reader_source)
        self.assertIn("StaticAccessibilityTreeReader", reader_source)
        self.assertIn("AXUIElementCopyAttributeValue", reader_source)
        self.assertIn("AccessibilitySnapshotNormalizer", normalizer_source)
        self.assertIn('case ("generic-native-app", "inspect_ui")', worker_source)
        self.assertIn("permissionChecker.isTrusted", worker_source)
        self.assertIn("snapshot_json", worker_source)
        self.assertNotIn("AXUIElementPerformAction", worker_source)
        self.assertNotIn("AXUIElementSetAttributeValue", worker_source)
        self.assertIn("testAccessibilityNormalizerCompactsAndLimitsStaticTree", test_source)
        self.assertIn("testAccessibilityWorkerReturnsNormalizedReadOnlySnapshot", test_source)

    def test_browser_worker_slice_uses_extension_context_and_fallbacks(self):
        source = (
            COMPUTER_USE_ROOT
            / "Workers"
            / "BrowserExtensionComputerUseWorker.swift"
        ).read_text()

        self.assertIn("protocol BrowserContextProviding", source)
        self.assertIn("context.source == .extensionData", source)
        self.assertIn("browser_extension_context_unavailable", source)
        self.assertIn("fallback_workers", source)
        self.assertIn("com.google.Chrome", source)

    def test_safari_current_page_has_mockable_apple_events_metadata(self):
        source = (COMPUTER_USE_ROOT / "Workers" / "AppleEventsComputerUseWorker.swift").read_text()
        test_source = (
            Path(__file__).resolve().parents[1]
            / "AuraBotTests"
            / "AuraBotTests.swift"
        ).read_text()

        self.assertIn("protocol AppleScriptRunning", source)
        self.assertIn("StaticAppleScriptRunner", source)
        self.assertIn('metadata["url"]', source)
        self.assertIn('metadata["title"]', source)
        self.assertIn('metadata["page_id"]', source)
        self.assertIn("testSafariAppleEventsWorkerParsesMockedCurrentPage", test_source)

    def test_file_worker_blocks_delete_until_confirmation_ui_exists(self):
        source = (COMPUTER_USE_ROOT / "Workers" / "FileAPIComputerUseWorker.swift").read_text()

        self.assertIn("Delete is intentionally blocked", source)
        self.assertNotIn("removeItem", source)

    def test_finder_move_has_temp_file_operation_coverage(self):
        source = (
            Path(__file__).resolve().parents[1]
            / "AuraBotTests"
            / "AuraBotTests.swift"
        ).read_text()

        self.assertIn("testFileAPIMoveFilesDryRunDoesNotMutateFilesystem", source)
        self.assertIn("testFileAPIMoveFilesMovesTemporaryFileWhenConfirmed", source)
        self.assertIn("makeTemporaryMoveFixture", source)
        self.assertIn('"dry_run": "false"', source)
        self.assertIn("XCTAssertFalse(FileManager.default.fileExists", source)

    def test_bundle_ids_and_domains_do_not_overlap_between_specific_skills(self):
        seen_bundle_ids = {}
        seen_domains = {}

        for skill in self.load_skills():
            if skill["id"] == "generic-native-app":
                continue

            for bundle_id in skill["bundle_ids"]:
                self.assertNotIn(bundle_id, seen_bundle_ids)
                seen_bundle_ids[bundle_id] = skill["id"]

            for domain in skill["domains"]:
                self.assertNotIn(domain, seen_domains)
                seen_domains[domain] = skill["id"]


if __name__ == "__main__":
    unittest.main()
