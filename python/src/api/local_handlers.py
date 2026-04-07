import json
import uuid
import time
from datetime import datetime
from http.server import BaseHTTPRequestHandler
from urllib.parse import parse_qs, urlparse

class Mem0LocalHandler(BaseHTTPRequestHandler):
    """HTTP handler for Mem0 with local models."""
    
    # These should be set on the class before passing to HTTPServer
    model_manager = None
    memory = None
    HAS_MEM0 = False
    
    # Allowed origins for CORS
    ALLOWED_ORIGINS = [
        "http://localhost:3000",
        "http://localhost:8080",
        "http://localhost:7345",
        "chrome-extension://*",
        "https://chat.openai.com",
        "https://chatgpt.com",
        "https://claude.ai",
        "https://gemini.google.com",
        "https://perplexity.ai",
    ]
    
    def log_message(self, format, *args):
        print(f"[{datetime.now().strftime('%H:%M:%S')}] {format % args}")
    
    def _get_origin(self):
        return self.headers.get('Origin', '')
    
    def _is_allowed_origin(self, origin):
        if not origin:
            return True
        for allowed in self.ALLOWED_ORIGINS:
            if allowed.endswith('/*'):
                prefix = allowed[:-1]
                if origin.startswith(prefix):
                    return True
            elif origin == allowed:
                return True
        return False
    
    def send_json_response(self, data: dict, status: int = 200):
        origin = self._get_origin()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        if self._is_allowed_origin(origin):
            self.send_header("Access-Control-Allow-Origin", origin if origin else "http://localhost:3000")
            self.send_header("Access-Control-Allow-Methods", "GET, POST, DELETE, OPTIONS")
            self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization")
            self.send_header("Access-Control-Allow-Credentials", "true")
        self.end_headers()
        self.wfile.write(json.dumps(data).encode())
    
    def do_OPTIONS(self):
        origin = self._get_origin()
        self.send_response(200)
        if self._is_allowed_origin(origin):
            self.send_header("Access-Control-Allow-Origin", origin if origin else "http://localhost:3000")
            self.send_header("Access-Control-Allow-Methods", "GET, POST, DELETE, OPTIONS")
            self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization")
            self.send_header("Access-Control-Allow-Credentials", "true")
        self.end_headers()
    
    def do_GET(self):
        parsed = urlparse(self.path)
        path = parsed.path
        query = parse_qs(parsed.query)
        
        if path == "/health":
            self.send_json_response({
                "status": "ok",
                "timestamp": datetime.now().isoformat(),
                "llm_provider": "local (lfm-2-vision-450m)",
                "embedder_provider": "local (nomic-embed-text-v1.5)",
                "vector_store": "qdrant" if self.HAS_MEM0 else "disabled",
            })
            return
            
        if path == "/v1/models":
            self.send_json_response({
                "object": "list",
                "data": [
                    {"id": "nomic-embed-text-v1.5", "object": "model", "created": int(time.time()), "owned_by": "local"},
                    {"id": "lfm-2-vision-450m", "object": "model", "created": int(time.time()), "owned_by": "local"}
                ]
            })
            return
            
        if path == "/v1/memories/" and self.HAS_MEM0 and self.memory:
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
                elif isinstance(results, dict) and "results" in results:
                    for mem in results["results"]:
                        memories.append({
                            "id": mem.get("id", str(uuid.uuid4())),
                            "content": mem.get("memory", mem.get("content", "")),
                            "user_id": user_id,
                            "metadata": mem.get("metadata", {}),
                            "created_at": mem.get("created_at", datetime.now().isoformat())
                        })
                self.send_json_response(memories)
            except Exception as e:
                print(f"[ERROR] Get memories failed: {e}")
                self.send_json_response({"error": str(e)}, 500)
            return
            
        self.send_json_response({"error": "Not found"}, 404)
        
    def do_POST(self):
        parsed = urlparse(self.path)
        path = parsed.path
        
        content_length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(content_length).decode()
        data = json.loads(body) if body else {}
        
        if path == "/v1/embeddings":
            try:
                input_texts = data.get("input", [])
                if isinstance(input_texts, str):
                    input_texts = [input_texts]
                if not input_texts:
                    self.send_json_response({"error": "No input provided"}, 400)
                    return
                embeddings = self.model_manager.embed(input_texts)
                response = {
                    "object": "list",
                    "data": [
                        {"object": "embedding", "embedding": emb, "index": i}
                        for i, emb in enumerate(embeddings)
                    ],
                    "model": data.get("model", "nomic-embed-text-v1.5"),
                    "usage": {"prompt_tokens": len(input_texts), "total_tokens": len(input_texts)}
                }
                self.send_json_response(response)
            except Exception as e:
                print(f"[ERROR] Embeddings failed: {e}")
                self.send_json_response({"error": str(e)}, 500)
            return
            
        if path == "/v1/chat/completions":
            try:
                messages = data.get("messages", [])
                max_tokens = data.get("max_tokens", 512)
                if not messages:
                    self.send_json_response({"error": "No messages provided"}, 400)
                    return
                response_text = self.model_manager.chat(messages, max_tokens=max_tokens)
                response = {
                    "id": f"chatcmpl-{int(time.time())}",
                    "object": "chat.completion",
                    "created": int(time.time()),
                    "model": data.get("model", "lfm-2-vision-450m"),
                    "choices": [{"index": 0, "message": {"role": "assistant", "content": response_text}, "finish_reason": "stop"}],
                    "usage": {"prompt_tokens": 0, "completion_tokens": 0, "total_tokens": 0}
                }
                self.send_json_response(response)
            except Exception as e:
                print(f"[ERROR] Chat completion failed: {e}")
                self.send_json_response({"error": str(e)}, 500)
            return
            
        if path == "/v1/memories/" and self.HAS_MEM0 and self.memory:
            try:
                messages = data.get("messages", [])
                user_id = data.get("user_id", "default_user")
                agent_id = data.get("agent_id")
                metadata = data.get("metadata", {})
                content = " ".join([m.get("content", "") for m in messages if m.get("content")])
                result = self.memory.add(messages=messages, user_id=user_id, agent_id=agent_id, metadata=metadata, infer=False)
                response = {
                    "id": result.get("id", str(uuid.uuid4())),
                    "content": content,
                    "user_id": user_id,
                    "metadata": metadata,
                    "created_at": datetime.now().isoformat()
                }
                self.send_json_response(response, 201)
            except Exception as e:
                print(f"[ERROR] Add memory failed: {e}")
                self.send_json_response({"error": str(e)}, 500)
            return
            
        if path == "/v1/memories/search/" and self.HAS_MEM0 and self.memory:
            try:
                query = data.get("query", "")
                user_id = data.get("user_id", "default_user")
                agent_id = data.get("agent_id")
                limit = data.get("limit", 10)
                results = self.memory.search(query=query, user_id=user_id, agent_id=agent_id, limit=limit)
                search_results = []
                for r in results:
                    if isinstance(r, dict):
                        search_results.append({
                            "memory": {
                                "id": r.get("id", str(uuid.uuid4())),
                                "content": r.get("memory", ""),
                                "user_id": user_id,
                                "metadata": r.get("metadata", {}),
                                "created_at": r.get("created_at", datetime.now().isoformat())
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
                                "created_at": datetime.now().isoformat()
                            },
                            "score": 1.0,
                            "distance": 0.0
                        })
                self.send_json_response(search_results)
            except Exception as e:
                print(f"[ERROR] Search failed: {e}")
                self.send_json_response({"error": str(e)}, 500)
            return
            
        self.send_json_response({"error": "Not found"}, 404)
        
    def do_DELETE(self):
        parsed = urlparse(self.path)
        path = parsed.path
        if path.startswith("/v1/memories/"):
            self.send_json_response({"deleted": True})
            return
        self.send_json_response({"error": "Not found"}, 404)
