import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))

import api.auth as auth
from api.auth import is_authorized
from api.handlers import MemoryHandler
from api.memoryMixin import MemoryMixin


class FakeMemoryStore:
    def __init__(
        self,
        get_all_result=None,
        add_result=None,
        search_result=None,
        delete_result=None,
        delete_requires_id_fallback=False,
    ):
        self.get_all_result = get_all_result if get_all_result is not None else []
        self.add_result = add_result if add_result is not None else {"id": "generated-id"}
        self.search_result = search_result if search_result is not None else []
        self.delete_result = delete_result if delete_result is not None else {"deleted": True}
        self.delete_requires_id_fallback = delete_requires_id_fallback
        self.calls = []

    def get_all(self, **kwargs):
        self.calls.append(("get_all", kwargs))
        return self.get_all_result

    def add(self, **kwargs):
        self.calls.append(("add", kwargs))
        return self.add_result

    def search(self, **kwargs):
        self.calls.append(("search", kwargs))
        return self.search_result

    def delete(self, **kwargs):
        self.calls.append(("delete", kwargs))
        if self.delete_requires_id_fallback and "memory_id" in kwargs:
            raise TypeError("unexpected keyword argument 'memory_id'")
        return self.delete_result


class DummyMemoryHandler(MemoryMixin):
    def __init__(self, memory, body=None):
        self.memory = memory
        self.HAS_MEMORY = True
        self._body = body or {}
        self.response = None
        self.status = None

    def parse_json_body(self):
        return self._body

    def send_json_response(self, data, status=200):
        self.response = data
        self.status = status


class MemoryMixinTests(unittest.TestCase):
    def test_get_memories_formats_results_payload(self):
        memory = FakeMemoryStore(
            get_all_result={
                "results": [
                    {
                        "id": "mem-1",
                        "memory": "Reviewed the onboarding flow",
                        "metadata": {"context": "Work"},
                        "created_at": "2026-04-14T12:00:00.000000",
                    }
                ]
            }
        )
        handler = DummyMemoryHandler(memory)

        handler.get_memories(user_id="user-1", agent_id="agent-a", limit=5)

        self.assertEqual(handler.status, 200)
        self.assertEqual(
            handler.response,
            [
                {
                    "id": "mem-1",
                    "content": "Reviewed the onboarding flow",
                    "user_id": "user-1",
                    "metadata": {"context": "Work"},
                    "created_at": "2026-04-14T12:00:00.000000",
                }
            ],
        )
        self.assertEqual(
            memory.calls[0],
            ("get_all", {"user_id": "user-1", "agent_id": "agent-a", "limit": 5}),
        )

    def test_add_memory_passes_messages_and_returns_created_payload(self):
        memory = FakeMemoryStore(add_result={"id": "mem-2"})
        body = {
            "messages": [
                {"role": "user", "content": "Need to finish the release notes"},
                {"role": "assistant", "content": "I can help draft them"},
            ]
        }
        handler = DummyMemoryHandler(memory, body=body)

        handler.add_memory(
            user_id="user-2",
            agent_id="agent-b",
            metadata={"context": "Work"},
            infer=False,
        )

        self.assertEqual(handler.status, 201)
        self.assertEqual(handler.response["id"], "mem-2")
        self.assertEqual(
            handler.response["content"],
            "Need to finish the release notes I can help draft them",
        )
        self.assertEqual(handler.response["user_id"], "user-2")
        self.assertEqual(handler.response["metadata"], {"context": "Work"})
        self.assertEqual(
            memory.calls[0],
            (
                "add",
                {
                    "messages": body["messages"],
                    "user_id": "user-2",
                    "agent_id": "agent-b",
                    "metadata": {"context": "Work"},
                    "infer": False,
                },
            ),
        )

    def test_search_memories_wraps_nested_memory_payload(self):
        memory = FakeMemoryStore(
            search_result=[
                {
                    "id": "mem-3",
                    "memory": "Discussed launch metrics in the weekly meeting",
                    "metadata": {"context": "Meeting"},
                    "created_at": "2026-04-14T13:00:00.000000",
                    "score": 0.92,
                    "distance": 0.08,
                }
            ]
        )
        handler = DummyMemoryHandler(memory, body={"query": "launch metrics"})

        handler.search_memories(user_id="user-3", agent_id="agent-c", limit=3)

        self.assertEqual(handler.status, 200)
        self.assertEqual(
            handler.response,
            {
                "results": [
                    {
                        "memory": {
                            "id": "mem-3",
                            "content": "Discussed launch metrics in the weekly meeting",
                            "user_id": "user-3",
                            "metadata": {"context": "Meeting"},
                            "created_at": "2026-04-14T13:00:00.000000",
                        },
                        "score": 0.92,
                        "distance": 0.08,
                    }
                ]
            },
        )
        self.assertEqual(
            memory.calls[0],
            (
                "search",
                {
                    "query": "launch metrics",
                    "user_id": "user-3",
                    "agent_id": "agent-c",
                    "limit": 3,
                },
            ),
        )

    def test_delete_memory_falls_back_to_id_keyword(self):
        memory = FakeMemoryStore(
            delete_result={"deleted": True},
            delete_requires_id_fallback=True,
        )
        handler = DummyMemoryHandler(memory)

        handler.delete_memory("mem-legacy")

        self.assertEqual(handler.status, 200)
        self.assertEqual(handler.response, {"deleted": True})
        self.assertEqual(
            memory.calls,
            [
                ("delete", {"memory_id": "mem-legacy"}),
                ("delete", {"id": "mem-legacy"}),
            ],
        )


class HandlerRouteTests(unittest.TestCase):
    def test_get_route_clamps_memory_limit(self):
        handler = MemoryHandler.__new__(MemoryHandler)
        handler.path = "/v1/memories/?user_id=user-1&limit=100000"
        calls = []

        handler.require_authorization = lambda path=None: True
        handler.get_memories = lambda user_id, agent_id, limit: calls.append(
            (user_id, agent_id, limit)
        )
        handler.send_json_response = lambda data, status=200: None

        MemoryHandler.do_GET(handler)

        self.assertEqual(calls, [("user-1", None, 100)])

    def test_add_memory_route_rejects_missing_user_id(self):
        handler = MemoryHandler.__new__(MemoryHandler)
        handler.path = "/v1/memories/"
        handler.require_authorization = lambda path=None: True
        handler.parse_json_body = lambda: {
            "messages": [{"role": "user", "content": "hello"}]
        }
        handler.response = None
        handler.status = None
        handler.add_memory = lambda *args, **kwargs: self.fail("add_memory should not run")
        handler.send_json_response = lambda data, status=200: setattr(
            handler, "response", data
        ) or setattr(handler, "status", status)

        MemoryHandler.do_POST(handler)

        self.assertEqual(handler.status, 400)
        self.assertEqual(
            handler.response["error"],
            "Missing 'messages' or 'user_id' in request body",
        )

    def test_search_route_rejects_oversized_query(self):
        handler = MemoryHandler.__new__(MemoryHandler)
        handler.path = "/v1/memories/search/"
        handler.require_authorization = lambda path=None: True
        handler.parse_json_body = lambda: {"user_id": "user-1", "query": "x" * 4001}
        handler.response = None
        handler.status = None
        handler.search_memories = lambda *args, **kwargs: self.fail(
            "search_memories should not run"
        )
        handler.send_json_response = lambda data, status=200: setattr(
            handler, "response", data
        ) or setattr(handler, "status", status)

        MemoryHandler.do_POST(handler)

        self.assertEqual(handler.status, 413)
        self.assertEqual(
            handler.response["error"],
            "Query string exceeds max length of 4000 characters",
        )

    def test_delete_route_strips_trailing_slash_before_dispatch(self):
        handler = MemoryHandler.__new__(MemoryHandler)
        handler.path = "/v1/memories/mem-9/"
        deleted_ids = []

        handler.require_authorization = lambda path=None: True
        handler.delete_memory = deleted_ids.append
        handler.send_json_response = lambda data, status=200: None

        MemoryHandler.do_DELETE(handler)

        self.assertEqual(deleted_ids, ["mem-9"])


class AuthTests(unittest.TestCase):
    def test_missing_api_key_denies_by_default(self):
        original_key = auth.MEMORY_API_KEY
        original_allow = auth.ALLOW_UNAUTHENTICATED_MEMORY_API
        try:
            auth.MEMORY_API_KEY = ""
            auth.ALLOW_UNAUTHENTICATED_MEMORY_API = False

            self.assertFalse(is_authorized({}))
        finally:
            auth.MEMORY_API_KEY = original_key
            auth.ALLOW_UNAUTHENTICATED_MEMORY_API = original_allow

    def test_valid_bearer_token_authorizes(self):
        original_key = auth.MEMORY_API_KEY
        try:
            auth.MEMORY_API_KEY = "secret"

            self.assertTrue(is_authorized({"Authorization": "Bearer secret"}))
            self.assertFalse(is_authorized({"Authorization": "Bearer wrong"}))
        finally:
            auth.MEMORY_API_KEY = original_key


if __name__ == "__main__":
    unittest.main()
