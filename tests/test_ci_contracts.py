import re
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
CI_WORKFLOW = REPO_ROOT / ".github" / "workflows" / "ci.yml"


class GitHubActionsContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.workflow = CI_WORKFLOW.read_text()

    def test_ci_runs_for_pull_requests_manual_dispatch_and_all_pushes(self):
        self.assertIn("pull_request:", self.workflow)
        self.assertIn("workflow_dispatch:", self.workflow)

        push_block = re.search(
            r"(?ms)^  push:\n(?P<body>.*?)(?:\n\npermissions:|\npermissions:)",
            self.workflow,
        )
        self.assertIsNotNone(push_block)
        self.assertNotIn("branches:", push_block.group("body"))

    def test_workflow_uses_read_only_default_token_permissions(self):
        self.assertRegex(self.workflow, r"(?m)^permissions:\n  contents: read$")

    def test_repository_contract_job_runs_before_language_specific_jobs(self):
        self.assertIn("repository-contracts:", self.workflow)
        self.assertIn("Run repository contract tests", self.workflow)
        self.assertIn("python -m unittest discover tests", self.workflow)

    def test_secret_scan_runs_gitleaks_against_full_history(self):
        self.assertIn("secret-scan:", self.workflow)
        self.assertIn("name: Secret Scan", self.workflow)
        self.assertIn("uses: gitleaks/gitleaks-action@v2", self.workflow)
        self.assertIn("fetch-depth: 0", self.workflow)
        self.assertIn("GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}", self.workflow)

    def test_python_ci_runs_memory_api_and_skill_contract_suites(self):
        self.assertIn(
            "python -m unittest discover services/memory-api/tests",
            self.workflow,
        )
        self.assertIn(
            "python -m unittest discover apps/macos/Tests/ComputerUseSkillTests",
            self.workflow,
        )
        self.assertIn(
            "python -m compileall -q services/memory-api/src tools start.py",
            self.workflow,
        )

    def test_swift_ci_builds_and_tests_macos_package(self):
        self.assertIn("working-directory: apps/macos", self.workflow)
        self.assertEqual(self.workflow.count("run: swift build"), 1)
        self.assertEqual(self.workflow.count("run: swift test"), 1)

    def test_actions_are_pinned_to_major_versions(self):
        uses_lines = re.findall(r"uses: ([^\s]+)", self.workflow)
        allowed_patterns = [
            r"^actions/[A-Za-z0-9_-]+@v[0-9]+$",
            r"^gitleaks/gitleaks-action@v[0-9]+$",
        ]

        self.assertGreaterEqual(len(uses_lines), 4)
        for action in uses_lines:
            self.assertTrue(
                any(re.match(pattern, action) for pattern in allowed_patterns),
                f"{action} must be pinned to an allowed major version",
            )

    def test_workflow_does_not_install_unreviewed_remote_scripts(self):
        forbidden_patterns = [
            "curl ",
            "wget ",
            "| sh",
            "| bash",
        ]

        for pattern in forbidden_patterns:
            self.assertNotIn(pattern, self.workflow)


if __name__ == "__main__":
    unittest.main()
