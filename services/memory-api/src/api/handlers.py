"""
Unified HTTP handler using mixins.
Provides all endpoints: health, models, embeddings, chat, memories.
"""

from urllib.parse import urlparse
import time

from api.base_handler import BaseHandler, RequestBodyError
from api.memoryMixin import MemoryMixin
from api.embeddingsMixin import EmbeddingsMixin
from api.chatMixin import ChatMixin
from config import (
    MAX_RESPONSE_LIMIT,
    OPENROUTER_BASE_URL,
    OPENROUTER_CHAT_MODEL,
    OPENROUTER_EMBEDDING_MODEL,
)


class MemoryHandler(BaseHandler, MemoryMixin, EmbeddingsMixin, ChatMixin):
    """Unified HTTP handler for the AuraBot memory API server."""

    memory = None
    model_manager = None
    HAS_MEMORY = False

    def do_GET(self):
        parsed = urlparse(self.path)
        path = parsed.path
        query = self.parse_query()

        if not self.require_authorization(path):
            return

        if path == "/health":
            self.handle_health()
            return

        if path == "/v1/models":
            self.handle_models()
            return

        if path == "/v1/memories/":
            user_id = query.get("user_id", ["default_user"])[0]
            agent_id = query.get("agent_id", [""])[0] or None
            limit = self._bounded_limit(query.get("limit", ["10"])[0])
            self.get_memories(user_id, agent_id, limit)
            return

        self.send_json_response({"error": "Not found"}, 404)

    def do_POST(self):
        parsed = urlparse(self.path)
        path = parsed.path

        if not self.require_authorization(path):
            return

        if path == "/v1/embeddings":
            self.create_embeddings()
            return

        if path == "/v1/chat/completions":
            data = self._parse_or_respond()
            if data is None:
                return
            messages = data.get("messages") if isinstance(data, dict) else None
            if not isinstance(messages, list) or not messages:
                self.send_json_response({"error": "Missing 'messages' in request body"}, 400)
                return
            for msg in messages:
                if not isinstance(msg, dict):
                    self.send_json_response({"error": "Each message must be an object"}, 400)
                    return
                if len(str(msg.get("content", ""))) > 32000:
                    self.send_json_response({"error": "Message content exceeds max length of 32000 characters"}, 413)
                    return
            self.chat_completions()
            return

        if path == "/v1/memories/":
            data = self._parse_or_respond()
            if data is None:
                return
            messages = data.get("messages") if isinstance(data, dict) else None
            if not isinstance(data, dict) or not isinstance(messages, list) or not messages or "user_id" not in data:
                self.send_json_response({"error": "Missing 'messages' or 'user_id' in request body"}, 400)
                return
            for msg in messages:
                if not isinstance(msg, dict):
                    self.send_json_response({"error": "Each message must be an object"}, 400)
                    return
                if len(str(msg.get("content", ""))) > 32000:
                    self.send_json_response({"error": "Message content exceeds max length of 32000 characters"}, 413)
                    return
            user_id = data.get("user_id", "default_user")
            agent_id = data.get("agent_id")
            metadata = data.get("metadata", {})
            # Screen captures are already summarized by the app before storage.
            infer = False
            self.add_memory(user_id, agent_id, metadata, infer)
            return

        if path == "/v1/memories/search/":
            data = self._parse_or_respond()
            if data is None:
                return
            if not isinstance(data, dict) or "query" not in data or "user_id" not in data:
                self.send_json_response({"error": "Missing 'query' or 'user_id' in request body"}, 400)
                return
            if len(str(data["query"])) > 4000:
                self.send_json_response({"error": "Query string exceeds max length of 4000 characters"}, 413)
                return
            user_id = data.get("user_id", "default_user")
            agent_id = data.get("agent_id")
            limit = self._bounded_limit(data.get("limit", 10))
            self.search_memories(user_id, agent_id, limit)
            return

        self.send_json_response({"error": "Not found"}, 404)

    def do_DELETE(self):
        parsed = urlparse(self.path)
        path = parsed.path

        if not self.require_authorization(path):
            return

        if path.startswith("/v1/memories/"):
            memory_id = path.rstrip("/").split("/")[-1]
            if memory_id in ("memories", "v1", ""):
                self.send_json_response({"error": "Missing memory ID in path"}, 400)
                return
            self.delete_memory(memory_id)
            return

        self.send_json_response({"error": "Not found"}, 404)

    def handle_health(self):
        """Handle GET /health"""
        memory_info = self.memory.info() if self.memory and hasattr(self.memory, "info") else None
        self.send_json_response(
            {
                "status": "ok",
                "timestamp": time.time(),
                "llm_provider": "openrouter",
                "llm_model": OPENROUTER_CHAT_MODEL,
                "embedder_provider": "openrouter",
                "embedder_model": OPENROUTER_EMBEDDING_MODEL,
                "memory_backend": memory_info.backend if memory_info else "unavailable",
                "vector_store": memory_info.vector_store if memory_info else "unavailable",
                "openrouter_url": OPENROUTER_BASE_URL,
            }
        )

    def handle_models(self):
        """Handle GET /v1/models"""
        self.send_json_response(
            {
                "object": "list",
                "data": [
                    {
                        "id": OPENROUTER_EMBEDDING_MODEL,
                        "object": "model",
                        "created": int(time.time()),
                        "owned_by": "openrouter",
                    },
                    {
                        "id": OPENROUTER_CHAT_MODEL,
                        "object": "model",
                        "created": int(time.time()),
                        "owned_by": "openrouter",
                    },
                ],
            }
        )

    def _bounded_limit(self, value, default: int = 10) -> int:
        try:
            limit = int(value)
        except (TypeError, ValueError):
            limit = default
        return min(MAX_RESPONSE_LIMIT, max(1, limit))

    def _parse_or_respond(self):
        try:
            return self.parse_json_body()
        except RequestBodyError as exc:
            self.send_json_response({"error": str(exc)}, exc.status)
            return None
