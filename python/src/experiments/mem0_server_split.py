#!/usr/bin/env python3
"""
Mem0 REST API Server with split LLM setup:
- Cerebras: For chat/LLM responses (fast, high quality)
- LM Studio (LFM2): For memory classification/extraction (local, privacy)
- LM Studio: For embeddings (local)

Environment Variables:
- CEREBRAS_API_KEY: Cerebras API key (https://cloud.cerebras.ai)
- LM_STUDIO_URL: LM Studio server URL (default: http://localhost:1234/v1)
- MEM0_HOST: Server host (default: localhost)
- MEM0_PORT: Server port (default: 8000)
"""

import os
import sys
import json
import uuid
import requests
from datetime import datetime
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import parse_qs, urlparse

try:
    from dotenv import load_dotenv
    load_dotenv()
    print("[INFO] Loaded environment from .env file")
except ImportError:
    pass

# Configuration
HOST = os.getenv("MEM0_HOST", "localhost")
PORT = int(os.getenv("MEM0_PORT", "8000"))
LM_STUDIO_URL = os.getenv("LM_STUDIO_URL", "http://localhost:1234/v1").rstrip('/')
CEREBRAS_API_KEY = os.getenv("CEREBRAS_API_KEY", "")

print("="*70)
print("Mem0 Server: Cerebras (Chat) + LM Studio (Classification + Embeddings)")
print("="*70)
print(f"LM Studio: {LM_STUDIO_URL}")
print(f"Cerebras: {'Connected' if CEREBRAS_API_KEY else 'Not configured'}")
print()

# Check LM Studio
class LMStudioClient:
    def __init__(self, base_url):
        self.base_url = base_url
        self.model = None
        self.embedding_model = None
        
    def connect(self):
        try:
            resp = requests.get(f"{self.base_url}/models", timeout=5)
            if resp.status_code == 200:
                models = resp.json().get('data', [])
                print(f"[OK] LM Studio: {len(models)} model(s)")
                for m in models:
                    print(f"     - {m['id']}")
                    mid = m['id'].lower()
                    if 'lfm' in mid or '350m' in mid:
                        self.model = m['id']
                    elif 'embed' in mid or 'nomic' in mid:
                        self.embedding_model = m['id']
                return True
        except Exception as e:
            print(f"[ERROR] LM Studio: {e}")
        return False
    
    def classify_memory(self, text):
        """Use LFM2 to classify if text is important."""
        url = f"{self.base_url}/chat/completions"
        
        system_prompt = """You classify if text is worth remembering.
USEFUL: User preferences, tasks, decisions, important info
NOT USEFUL: Greetings, loading messages, obvious info

Respond ONLY:
DECISION: USEFUL or DISCARD
REASON: one line"""

        payload = {
            "model": self.model or "local-model",
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": f"Text:\n{text[:1000]}"}
            ],
            "max_tokens": 64,
            "temperature": 0.1,
            "stream": False
        }
        
        try:
            resp = requests.post(url, json=payload, timeout=30)
            content = resp.json()["choices"][0]["message"]["content"]
            is_useful = "USEFUL" in content.upper() and "DISCARD" not in content.upper()
            reason = content.split("REASON:")[1].strip() if "REASON:" in content else ""
            return is_useful, reason
        except:
            return True, "classification_error"
    
    def embed(self, texts):
        if not self.embedding_model:
            return [[0.0] * 768] * len(texts)
        
        url = f"{self.base_url}/embeddings"
        results = []
        for text in texts:
            try:
                resp = requests.post(url, json={
                    "model": self.embedding_model,
                    "input": text
                }, timeout=30)
                results.append(resp.json()["data"][0]["embedding"])
            except:
                results.append([0.0] * 768)
        return results


lmstudio = LMStudioClient(LM_STUDIO_URL)
if not lmstudio.connect():
    print("Please start LM Studio with LFM2-350M loaded")
    sys.exit(1)

print()

# Cerebras client for chat
class CerebrasClient:
    def __init__(self, api_key):
        self.api_key = api_key
        self.base_url = "https://api.cerebras.ai/v1"
    
    def chat(self, messages, max_tokens=512):
        if not self.api_key:
            # Fallback to LM Studio
            url = f"{LM_STUDIO_URL}/chat/completions"
            payload = {
                "model": lmstudio.model or "local-model",
                "messages": messages,
                "max_tokens": max_tokens,
                "temperature": 0.7
            }
        else:
            url = f"{self.base_url}/chat/completions"
            payload = {
                "model": "llama3.1-70b",
                "messages": messages,
                "max_tokens": max_tokens,
                "temperature": 0.7
            }
        
        headers = {"Authorization": f"Bearer {self.api_key}"} if self.api_key else {}
        
        try:
            resp = requests.post(url, json=payload, headers=headers, timeout=60)
            return resp.json()["choices"][0]["message"]["content"]
        except Exception as e:
            print(f"[ERROR] Chat failed: {e}")
            return "Sorry, I couldn't process that."


cerebras = CerebrasClient(CEREBRAS_API_KEY)

# Mem0 setup
try:
    from mem0 import Memory
    HAS_MEM0 = True
except ImportError:
    print("[ERROR] pip install mem0ai")
    sys.exit(1)

print("Configuring Mem0...")

config = {
    "vector_store": {
        "provider": "qdrant",
        "config": {
            "collection_name": "split_memories",
            "embedding_model_dims": 768,
            "path": "./qdrant_storage",
        }
    },
    "embedder": {
        "provider": "openai",
        "config": {
            "model": lmstudio.embedding_model or "local",
            "api_key": "local",
            "openai_base_url": LM_STUDIO_URL,
        }
    },
    "llm": {
        "provider": "openai",
        "config": {
            "model": lmstudio.model or "local",
            "api_key": "local",
            "openai_base_url": LM_STUDIO_URL,
            "temperature": 0.1,
        }
    },
}

try:
    base_memory = Memory.from_config(config_dict=config)
    print("[OK] Mem0 ready")
    print()
except Exception as e:
    print(f"[ERROR] {e}")
    sys.exit(1)


# Wrap memory with classification
class SmartMemoryStore:
    def __init__(self, memory):
        self.memory = memory
        self.stats = {"stored": 0, "discarded": 0}
    
    def add(self, messages, user_id="default", **kwargs):
        # Extract text
        if isinstance(messages, list):
            text = " ".join([m.get("content", "") for m in messages])
        else:
            text = str(messages)
        
        print(f"[CLASSIFY] {text[:80]}...")
        
        # LM Studio (LFM2) decides if important
        is_useful, reason = lmstudio.classify_memory(text)
        
        if not is_useful:
            self.stats["discarded"] += 1
            print(f"[DISCARD] ({self.stats['discarded']}) {reason}")
            return {"id": "discarded", "filtered": True}
        
        self.stats["stored"] += 1
        print(f"[STORE] ({self.stats['stored']}) {reason}")
        
        return self.memory.add(
            messages=messages,
            user_id=user_id,
            infer=False,  # Already classified
            **kwargs
        )
    
    def search(self, **kwargs):
        return self.memory.search(**kwargs)
    
    def get_all(self, **kwargs):
        return self.memory.get_all(**kwargs)


memory = SmartMemoryStore(base_memory)

# HTTP Server
class Handler(BaseHTTPRequestHandler):
    # Allowed origins for CORS
    ALLOWED_ORIGINS = [
        "http://localhost:3000",
        "http://localhost:8080",
        "http://localhost:7345",
        "chrome-extension://*",
    ]
    
    def log_message(self, fmt, *args):
        print(f"[{datetime.now().strftime('%H:%M:%S')}] {fmt % args}")
    
    def _get_origin(self):
        return self.headers.get('Origin', '')
    
    def _is_allowed_origin(self, origin):
        if not origin:
            return True
        for allowed in self.ALLOWED_ORIGINS:
            if allowed.endswith('/*'):
                if origin.startswith(allowed[:-1]):
                    return True
            elif origin == allowed:
                return True
        return False
    
    def json(self, data, status=200):
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
        p = urlparse(self.path)
        q = parse_qs(p.query)
        
        if p.path == "/health":
            self.json({
                "status": "ok",
                "lm_studio": LM_STUDIO_URL,
                "cerebras": bool(CEREBRAS_API_KEY),
                "stats": memory.stats
            })
            return
        
        if p.path == "/v1/memories/":
            try:
                r = memory.get_all(user_id=q.get("user_id", ["default"])[0])
                self.json(r if isinstance(r, list) else [])
            except Exception as e:
                self.json({"error": str(e)}, 500)
            return
        
        self.json({"error": "Not found"}, 404)
    
    def do_POST(self):
        p = urlparse(self.path)
        n = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(n).decode()
        data = json.loads(body) if body else {}
        
        # Chat - uses CEREBRAS
        if p.path == "/v1/chat/completions":
            try:
                messages = data.get("messages", [])
                max_tokens = data.get("max_tokens", 512)
                
                # Use Cerebras for chat
                response = cerebras.chat(messages, max_tokens)
                
                self.json({
                    "id": f"chat-{int(datetime.now().timestamp())}",
                    "object": "chat.completion",
                    "choices": [{
                        "index": 0,
                        "message": {"role": "assistant", "content": response},
                        "finish_reason": "stop"
                    }]
                })
            except Exception as e:
                self.json({"error": str(e)}, 500)
            return
        
        # Embeddings
        if p.path == "/v1/embeddings":
            try:
                texts = data.get("input", [])
                if isinstance(texts, str):
                    texts = [texts]
                embeddings = lmstudio.embed(texts)
                self.json({
                    "object": "list",
                    "data": [{"embedding": e, "index": i} for i, e in enumerate(embeddings)]
                })
            except Exception as e:
                self.json({"error": str(e)}, 500)
            return
        
        # Add memory - LM Studio classifies
        if p.path == "/v1/memories/":
            try:
                result = memory.add(
                    messages=data.get("messages", []),
                    user_id=data.get("user_id", "default")
                )
                if result.get("filtered"):
                    self.json({"status": "discarded", "stats": memory.stats})
                else:
                    self.json({**result, "status": "stored", "stats": memory.stats}, 201)
            except Exception as e:
                self.json({"error": str(e)}, 500)
            return
        
        # Search
        if p.path == "/v1/memories/search/":
            try:
                r = memory.search(
                    query=data.get("query", ""),
                    user_id=data.get("user_id", "default"),
                    limit=data.get("limit", 10)
                )
                self.json({"results": r if isinstance(r, list) else []})
            except Exception as e:
                self.json({"error": str(e)}, 500)
            return
        
        self.json({"error": "Not found"}, 404)


print("-" * 70)
print(f"Server: http://{HOST}:{PORT}")
print()
print("Setup:")
print("  • Chat/Responses: Cerebras (llama3.1-70b)")
print("  • Memory Classification: LM Studio (LFM2-350M)")
print("  • Embeddings: LM Studio")
print()
print("Endpoints:")
print(f"  POST /v1/chat/completions  -> Cerebras")
print(f"  POST /v1/memories/         -> LM Studio (classify) + Embed")
print(f"  POST /v1/memories/search/  -> Qdrant search")
print("-" * 70)
print()

server = HTTPServer((HOST, PORT), Handler)
try:
    server.serve_forever()
except KeyboardInterrupt:
    print("\nStopped")
    server.shutdown()
