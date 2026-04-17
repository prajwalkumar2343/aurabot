"""
Unified HTTP handler using mixins.
Provides all endpoints: health, models, embeddings, chat, memories.
"""

from urllib.parse import urlparse
import time

from api.base_handler import BaseHandler
from api.memoryMixin import MemoryMixin
from api.embeddingsMixin import EmbeddingsMixin
from api.chatMixin import ChatMixin
from config import (
    OPENROUTER_BASE_URL,
    OPENROUTER_CHAT_MODEL,
    OPENROUTER_EMBEDDING_MODEL,
)


class Mem0Handler(BaseHandler, MemoryMixin, EmbeddingsMixin, ChatMixin):
    """Unified HTTP handler for Mem0 API server."""

    memory = None
    model_manager = None
    HAS_MEM0 = False

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
            limit = int(query.get("limit", ["10"])[0])
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
            self.chat_completions()
            return

        if path == "/v1/memories/":
            data = self.parse_json_body()
            user_id = data.get("user_id", "default_user")
            agent_id = data.get("agent_id")
            metadata = data.get("metadata", {})
            # Screen captures are already summarized by the app before storage.
            infer = False
            self.add_memory(user_id, agent_id, metadata, infer)
            return

        if path == "/v1/memories/search/":
            data = self.parse_json_body()
            user_id = data.get("user_id", "default_user")
            agent_id = data.get("agent_id")
            limit = data.get("limit", 10)
            self.search_memories(user_id, agent_id, limit)
            return

        self.send_json_response({"error": "Not found"}, 404)

    def do_DELETE(self):
        parsed = urlparse(self.path)
        path = parsed.path

        if not self.require_authorization(path):
            return

        if path.startswith("/v1/memories/"):
            self.delete_memory(path.rstrip("/").split("/")[-1])
            return

        self.send_json_response({"error": "Not found"}, 404)

    def handle_health(self):
        """Handle GET /health"""
        self.send_json_response(
            {
                "status": "ok",
                "timestamp": time.time(),
                "llm_provider": "openrouter",
                "llm_model": OPENROUTER_CHAT_MODEL,
                "embedder_provider": "openrouter",
                "embedder_model": OPENROUTER_EMBEDDING_MODEL,
                "vector_store": "qdrant",
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
