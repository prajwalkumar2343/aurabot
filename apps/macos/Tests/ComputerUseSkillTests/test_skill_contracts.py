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


class ComputerUseSkillContractTests(unittest.TestCase):
    def load_skills(self):
        skills = []
        for path in sorted(SKILL_ROOT.glob("*/skill.json")):
            with path.open() as handle:
                skills.append(json.load(handle))
        return skills

    def test_starter_skills_are_present(self):
        skill_ids = {skill["id"] for skill in self.load_skills()}

        self.assertEqual(
            {"finder", "safari", "chrome", "terminal", "generic-native-app"},
            skill_ids,
        )

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
                self.assertIn(action["preferred_worker"], valid_workers)
                self.assertTrue(set(action["fallback_workers"]).issubset(valid_workers))
                self.assertIn(action["requires_focus"], valid_focus)
                self.assertIsInstance(action["parallel_safe"], bool)
                self.assertIsInstance(action["requires_confirmation"], bool)
                self.assertIsInstance(action["destructive"], bool)
                self.assertGreater(len(action["intents"]), 0)

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


if __name__ == "__main__":
    unittest.main()
