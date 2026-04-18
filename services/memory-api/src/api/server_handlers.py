import json
import uuid
from datetime import datetime
from http.server import BaseHTTPRequestHandler
from urllib.parse import parse_qs, urlparse

from api.auth import is_authorized, requires_auth
from api.cors import get_cors_headers
from config import CEREBRAS_API_KEY, LM_STUDIO_URL


def _probe_lm_studio_health() -> dict:
    """Lightweight probe of LM Studio for health endpoint."""
    import requests
    info = {"available": False, "chat_model": None, "embedding_model": None, "embedding_dims": 768}
    try:
        resp = requests.get(f"{LM_STUDIO_URL}/models", timeout=3)
        if resp.status_code != 200:
            return info
        models = resp.json().get("data", [])
        if not models:
            return info
        info["available"] = True
        non_emb = [m for m in models if not any(k in m.get("id", "").lower() for k in ("embed", "nomic", "gte", "bge"))]
        info["chat_model"] = (non_emb[0] if non_emb else models[0]).get("id")
        for m in models:
            mid = m.get("id", "").lower()
            if any(k in mid for k in ("embed", "nomic", "gte", "bge", "gemma")):
                info["embedding_model"] = m["id"]
                break
        if not info["embedding_model"]:
            info["embedding_model"] = models[0]["id"]
    except Exception:
        pass
    return info


class Mem0Handler(BaseHTTPRequestHandler):
    memory = None

    def log_message(self, format, *args):
        print(f"[{datetime.now().strftime('%H:%M:%S')}] {format % args}")
    
    def _get_origin(self):
        return self.headers.get('Origin', '')

    def _authorize(self, path: str) -> bool:
        if not requires_auth(path) or is_authorized(self.headers):
            return True
        self.send_json_response({"error": "Unauthorized"}, 401)
        return False
    
    def send_json_response(self, data, status=200):
        cors_headers = get_cors_headers(self._get_origin())
        try:
            self.send_response(status)
            self.send_header("Content-Type", "application/json")
            for key, value in cors_headers.items():
                self.send_header(key, value)
            self.end_headers()
            self.wfile.write(json.dumps(data).encode())
        except (ConnectionAbortedError, BrokenPipeError):
            print(f"[WARN] Client disconnected before response could be sent")

    def do_OPTIONS(self):
        cors_headers = get_cors_headers(self._get_origin())
        self.send_response(200)
        for key, value in cors_headers.items():
            self.send_header(key, value)
        self.end_headers()

    def do_GET(self):
        parsed = urlparse(self.path)
        path = parsed.path
        query = parse_qs(parsed.query)

        if not self._authorize(path):
            return

        if path == "/health":
            lm_health = _probe_lm_studio_health()
            self.send_json_response({
                "status": "ok",
                "timestamp": datetime.now().isoformat(),
                "llm_provider": "cerebras" if CEREBRAS_API_KEY else "lm_studio",
                "llm_model": "llama3.1-70b" if CEREBRAS_API_KEY else (lm_health.get("chat_model") or "local"),
                "embedder_provider": "lm_studio" if lm_health["available"] else "unknown",
                "embedder_model": lm_health.get("embedding_model") or "unknown",
                "vector_store": "qdrant",
                "lm_studio_url": LM_STUDIO_URL,
                "lm_studio_connected": lm_health["available"],
            })
            return

        if path == "/v1/memories/":
            user_id = query.get("user_id", ["default_user"])[0]
            agent_id = query.get("agent_id", [""])[0] or None
            limit = int(query.get("limit", ["10"])[0])

            try:
                results = self.memory.get_all(user_id=user_id, agent_id=agent_id, limit=limit)
                memories = []
                if isinstance(results, list):
                    for mem in results:
                        if isinstance(mem, dict):
                            memories.append({
                                "id": mem.get("id", str(uuid.uuid4())),
                                "content": mem.get("memory", ""),
                                "user_id": user_id,
                                "metadata": mem.get("metadata", {}),
                                "created_at": mem.get("created_at", datetime.now().isoformat())
                            })
                        elif isinstance(mem, str):
                            memories.append({
                                "id": str(uuid.uuid4()),
                                "content": mem,
                                "user_id": user_id,
                                "metadata": {},
                                "created_at": datetime.now().isoformat()
                            })
                elif isinstance(results, dict):
                    if "results" in results:
                        for mem in results["results"]:
                            if isinstance(mem, dict):
                                memories.append({
                                    "id": mem.get("id", str(uuid.uuid4())),
                                    "content": mem.get("memory", mem.get("content", "")),
                                    "user_id": user_id,
                                    "metadata": mem.get("metadata", {}),
                                    "created_at": mem.get("created_at", datetime.now().isoformat())
                                })
                    elif "memory" in results or "id" in results:
                        memories.append({
                            "id": results.get("id", str(uuid.uuid4())),
                            "content": results.get("memory", results.get("content", "")),
                            "user_id": user_id,
                            "metadata": results.get("metadata", {}),
                            "created_at": results.get("created_at", datetime.now().isoformat())
                        })
                self.send_json_response(memories)
            except Exception as e:
                print(f"Error getting memories: {e}")
                self.send_json_response({"error": str(e)}, 500)
            return

        self.send_json_response({"error": "Not found"}, 404)

    def do_POST(self):
        parsed = urlparse(self.path)
        path = parsed.path

        if not self._authorize(path):
            return

        content_length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(content_length).decode()
        data = json.loads(body) if body else {}

        if path == "/v1/memories/":
            try:
                messages = data.get("messages", [])
                user_id = data.get("user_id", "default_user")
                agent_id = data.get("agent_id")
                metadata = data.get("metadata", {})

                content = " ".join([m.get("content", "") for m in messages if m.get("content")])

                result = self.memory.add(
                    messages=messages,
                    user_id=user_id,
                    agent_id=agent_id,
                    metadata=metadata,
                    infer=bool(CEREBRAS_API_KEY)
                )

                response = {
                    "id": result.get("id", str(uuid.uuid4())),
                    "content": content,
                    "user_id": user_id,
                    "metadata": metadata,
                    "created_at": datetime.now().isoformat()
                }
                self.send_json_response(response, 201)
            except Exception as e:
                print(f"Error adding memory: {e}")
                self.send_json_response({"error": str(e)}, 500)
            return

        if path == "/v1/memories/search/":
            try:
                query = data.get("query", "")
                user_id = data.get("user_id", "default_user")
                agent_id = data.get("agent_id")
                limit = data.get("limit", 10)

                result = self.memory.search(
                    query=query,
                    user_id=user_id,
                    agent_id=agent_id,
                    limit=limit
                )

                results = result.get("results", []) if isinstance(result, dict) else result

                search_results = []
                for r in results:
                    if isinstance(r, dict):
                        search_results.append({
                            "memory": {
                                "id": r.get("id", str(uuid.uuid4())),
                                "content": r.get("memory", r.get("content", "")),
                                "user_id": user_id,
                                "metadata": r.get("metadata", {}),
                                "created_at": r.get("created_at", datetime.now().isoformat()),
                            },
                            "score": r.get("score", 0.0),
                            "distance": r.get("distance", 0.0)
                        })
                    elif isinstance(r, str):
                        search_results.append({
                            "memory": {
                                "id": str(uuid.uuid4()),
                                "content": r,
                                "user_id": user_id,
                                "metadata": {},
                                "created_at": datetime.now().isoformat(),
                            },
                            "score": 1.0,
                            "distance": 0.0
                        })

                self.send_json_response({"results": search_results})
            except Exception as e:
                print(f"Error searching memories: {e}")
                self.send_json_response({"error": str(e)}, 500)
            return

        self.send_json_response({"error": "Not found"}, 404)

    def do_DELETE(self):
        parsed = urlparse(self.path)
        path = parsed.path

        if not self._authorize(path):
            return

        if path.startswith("/v1/memories/"):
            try:
                memory_id = path.rstrip("/").split("/")[-1]
                try:
                    result = self.memory.delete(memory_id=memory_id)
                except TypeError:
                    result = self.memory.delete(id=memory_id)

                deleted = result if isinstance(result, bool) else True
                if isinstance(result, dict):
                    deleted = bool(result.get("deleted", True))

                self.send_json_response({"deleted": deleted})
            except Exception as e:
                print(f"Error deleting memory: {e}")
                self.send_json_response({"error": str(e)}, 500)
            return

        self.send_json_response({"error": "Not found"}, 404)
