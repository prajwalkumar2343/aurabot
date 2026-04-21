import json
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
DOCS = REPO_ROOT / "docs"
CONTRACTS = REPO_ROOT / "services" / "memory-pglite" / "src" / "contracts"
FIXTURES = REPO_ROOT / "services" / "memory-pglite" / "src" / "test-fixtures"

FIXTURE_NAMES = [
    "health-response.json",
    "recent-context-event-response.json",
    "recent-context-list-response.json",
    "current-context-response.json",
    "brain-sync-response.json",
    "graph-query-response.json",
    "search-response.json",
    "promotion-response.json",
    "delete-response.json",
]

MEMORY_SOURCES = {
    "recent_context",
    "recent_summary",
    "brain_page",
    "brain_chunk",
    "graph",
}

RELATION_TYPES = {
    "works_on",
    "uses",
    "visited",
    "opened",
    "edited",
    "mentioned_in",
    "discussed_with",
    "decided_in",
    "evidence_for",
    "related_to",
    "depends_on",
    "blocks",
    "belongs_to",
    "part_of",
    "authored",
    "created",
    "prefers",
}


class MemoryV2ContractTests(unittest.TestCase):
    def test_agent5_contract_artifacts_exist(self):
        self.assertTrue((DOCS / "memory-v2-api.md").is_file())
        self.assertTrue((DOCS / "memory-v2-contracts.md").is_file())
        self.assertTrue((CONTRACTS / "index.ts").is_file())

        for fixture_name in FIXTURE_NAMES:
            self.assertTrue((FIXTURES / fixture_name).is_file(), fixture_name)

    def test_every_fixture_is_versioned(self):
        for fixture_name in FIXTURE_NAMES:
            with self.subTest(fixture=fixture_name):
                fixture = self.load_fixture(fixture_name)
                self.assertEqual(fixture["schema_version"], "memory-v2")

    def test_search_fixture_matches_v2_shape(self):
        fixture = self.load_fixture("search-response.json")

        self.assertIsInstance(fixture["query"], str)
        self.assertIsInstance(fixture["items"], list)
        self.assertIn("matched_entities", fixture["debug"])
        self.assertIn("ranking", fixture["debug"])

        for item in fixture["items"]:
            self.assertIn(item["source"], MEMORY_SOURCES)
            self.assertIsInstance(item["entity_ids"], list)
            self.assertIsInstance(item["relations"], list)
            self.assertIsInstance(item["evidence"], list)
            self.assertIsInstance(item["score"], (int, float))
            self.assertEqual(
                {"vector", "keyword", "graph", "recency"},
                set(item["scores"]),
            )
            self.assertIn("created_at", item)
            self.assertIsInstance(item["metadata"], dict)

            for relation in item["relations"]:
                self.assertIn(relation["relation_type"], RELATION_TYPES)
                self.assert_evidence_list(relation["evidence"])

            self.assert_evidence_list(item["evidence"])

    def test_recent_context_fixtures_match_v2_shape(self):
        event_response = self.load_fixture("recent-context-event-response.json")
        list_response = self.load_fixture("recent-context-list-response.json")

        self.assert_recent_context_event(event_response["event"])
        for event in list_response["items"]:
            self.assert_recent_context_event(event)

    def test_docs_declare_endpoint_fixtures_and_markdown_slug_rules(self):
        api_doc = (DOCS / "memory-v2-api.md").read_text()
        contracts_doc = (DOCS / "memory-v2-contracts.md").read_text()

        for endpoint in [
            "GET /v2/health",
            "POST /v2/recent-context",
            "GET /v2/recent-context",
            "GET /v2/current-context",
            "POST /v2/brain/sync",
            "POST /v2/graph/query",
            "POST /v2/search",
            "POST /v2/memories/promote",
            "DELETE /v2/memories/{source}/{id}",
        ]:
            self.assertIn(endpoint, api_doc)

        self.assertIn("Slug rules", contracts_doc)
        self.assertIn("services/memory-pglite/src/test-fixtures/", contracts_doc)

    def assert_recent_context_event(self, event):
        self.assertIsInstance(event["id"], str)
        self.assertIsInstance(event["user_id"], str)
        self.assertIsInstance(event["source"], str)
        self.assertIsInstance(event["content"], str)
        self.assertIsInstance(event["content_hash"], str)
        self.assertIsInstance(event["occurred_at"], str)
        self.assertIsInstance(event["created_at"], str)

        metadata = event["metadata"]
        self.assertIsInstance(metadata["context"], str)
        self.assertIsInstance(metadata["activities"], list)
        self.assertIsInstance(metadata["key_elements"], list)
        self.assertIsInstance(metadata["user_intent"], str)
        self.assertIsInstance(metadata["display_num"], int)

    def assert_evidence_list(self, evidence_items):
        for evidence in evidence_items:
            self.assertIsInstance(evidence["source"], str)
            self.assertIsInstance(evidence["source_id"], str)

    def load_fixture(self, fixture_name):
        return json.loads((FIXTURES / fixture_name).read_text())


if __name__ == "__main__":
    unittest.main()
