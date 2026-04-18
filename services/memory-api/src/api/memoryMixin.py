"""
Memory mixin for HTTP handlers.
Provides common memory endpoints: get_all, add, search, delete.
"""

import uuid
from datetime import datetime


class MemoryMixin:
    """Mixin providing memory endpoint handlers."""

    memory = None
    HAS_MEMORY = False

    def get_memories(self, user_id: str, agent_id: str = None, limit: int = 10):
        """Handle GET /v1/memories/"""
        if not self.HAS_MEMORY or not self.memory:
            self.send_json_response({"error": "Memory not available"}, 503)
            return

        try:
            results = self.memory.get_all(
                user_id=user_id, agent_id=agent_id, limit=limit
            )
            memories = self._format_memories_list(results, user_id)
            self.send_json_response(memories)
        except Exception as e:
            self.send_json_response({"error": str(e)}, 500)

    def add_memory(
        self,
        user_id: str,
        agent_id: str = None,
        metadata: dict = None,
        infer: bool = True,
    ):
        """Handle POST /v1/memories/"""
        if not self.HAS_MEMORY or not self.memory:
            self.send_json_response({"error": "Memory not available"}, 503)
            return

        try:
            messages = self.parse_json_body().get("messages", [])
            content = " ".join(
                [m.get("content", "") for m in messages if m.get("content")]
            )

            result = self.memory.add(
                messages=messages,
                user_id=user_id,
                agent_id=agent_id,
                metadata=metadata or {},
                infer=infer,
            )

            response = {
                "id": result.get("id", str(uuid.uuid4())),
                "content": content,
                "user_id": user_id,
                "metadata": metadata or {},
                "created_at": datetime.now().isoformat(),
            }
            self.send_json_response(response, 201)
        except Exception as e:
            self.send_json_response({"error": str(e)}, 500)

    def search_memories(self, user_id: str, agent_id: str = None, limit: int = 10):
        """Handle POST /v1/memories/search/"""
        if not self.HAS_MEMORY or not self.memory:
            self.send_json_response({"error": "Memory not available"}, 503)
            return

        try:
            data = self.parse_json_body()
            query = data.get("query", "")

            result = self.memory.search(
                query=query, user_id=user_id, agent_id=agent_id, limit=limit
            )

            results = result.get("results", []) if isinstance(result, dict) else result
            search_results = self._format_search_results(results, user_id)
            self.send_json_response({"results": search_results})
        except Exception as e:
            self.send_json_response({"error": str(e)}, 500)

    def delete_memory(self, memory_id: str):
        """Handle DELETE /v1/memories/{id}"""
        if not self.HAS_MEMORY or not self.memory:
            self.send_json_response({"error": "Memory not available"}, 503)
            return

        try:
            deleted = False
            try:
                result = self.memory.delete(memory_id=memory_id)
            except TypeError:
                result = self.memory.delete(id=memory_id)

            if isinstance(result, dict):
                deleted = bool(result.get("deleted", True))
            elif isinstance(result, bool):
                deleted = result
            else:
                deleted = True

            self.send_json_response({"deleted": deleted})
        except Exception as e:
            self.send_json_response({"error": str(e)}, 500)

    def _format_memories_list(self, results, user_id: str) -> list:
        """Format memory results into API response format."""
        memories = []
        if isinstance(results, list):
            for mem in results:
                if isinstance(mem, dict):
                    memories.append(
                        {
                            "id": mem.get("id", str(uuid.uuid4())),
                            "content": mem.get("memory", ""),
                            "user_id": user_id,
                            "metadata": mem.get("metadata", {}),
                            "created_at": mem.get(
                                "created_at", datetime.now().isoformat()
                            ),
                        }
                    )
                elif isinstance(mem, str):
                    memories.append(
                        {
                            "id": str(uuid.uuid4()),
                            "content": mem,
                            "user_id": user_id,
                            "metadata": {},
                            "created_at": datetime.now().isoformat(),
                        }
                    )
        elif isinstance(results, dict):
            if "results" in results:
                for mem in results["results"]:
                    if isinstance(mem, dict):
                        memories.append(
                            {
                                "id": mem.get("id", str(uuid.uuid4())),
                                "content": mem.get("memory", mem.get("content", "")),
                                "user_id": user_id,
                                "metadata": mem.get("metadata", {}),
                                "created_at": mem.get(
                                    "created_at", datetime.now().isoformat()
                                ),
                            }
                        )
            elif "memory" in results or "id" in results:
                memories.append(
                    {
                        "id": results.get("id", str(uuid.uuid4())),
                        "content": results.get("memory", results.get("content", "")),
                        "user_id": user_id,
                        "metadata": results.get("metadata", {}),
                        "created_at": results.get(
                            "created_at", datetime.now().isoformat()
                        ),
                    }
                )
        return memories

    def _format_search_results(self, results, user_id: str) -> list:
        """Format search results into API response format."""
        search_results = []
        for r in results:
            if isinstance(r, dict):
                memory_payload = {
                    "id": r.get("id", str(uuid.uuid4())),
                    "content": r.get("memory", r.get("content", "")),
                    "user_id": user_id,
                    "metadata": r.get("metadata", {}),
                    "created_at": r.get("created_at", datetime.now().isoformat()),
                }
                search_results.append(
                    {
                        "memory": memory_payload,
                        "score": r.get("score", 0.0),
                        "distance": r.get("distance", 0.0),
                    }
                )
            elif isinstance(r, str):
                search_results.append(
                    {
                        "memory": {
                            "id": str(uuid.uuid4()),
                            "content": r,
                            "user_id": user_id,
                            "metadata": {},
                            "created_at": datetime.now().isoformat(),
                        },
                        "score": 1.0,
                        "distance": 0.0,
                    }
                )
        return search_results
