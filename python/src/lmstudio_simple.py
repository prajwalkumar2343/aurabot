#!/usr/bin/env python3
"""
Simple Mem0 server using LM Studio API endpoint with LFM2-350M.

This is the simplest setup - just connects to your running LM Studio
and uses it for all LLM operations.

Prerequisites:
- LM Studio running with LFM2-350M-Q8_0.gguf loaded
- API server started in LM Studio

Usage:
    python lmstudio_simple.py
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
except ImportError:
    pass

# Config
HOST = os.getenv("MEM0_HOST", "localhost")
PORT = int(os.getenv("MEM0_PORT", "8000"))
LM_STUDIO_URL = os.getenv("LM_STUDIO_URL", "http://localhost:1234/v1").rstrip('/')

print("="*60)
print("Mem0 Server + LM Studio (LFM2-350M)")
print("="*60)

# Check LM Studio
try:
    resp = requests.get(f"{LM_STUDIO_URL}/models", timeout=5)
    models = resp.json().get('data', [])
    print(f"[OK] LM Studio connected: {len(models)} model(s)")
    for m in models[:3]:
        print(f"     - {m['id']}")
except Exception as e:
    print(f"[ERROR] Cannot connect: {e}")
    print("Make sure LM Studio is running with API server started")
    sys.exit(1)

print()

# Import mem0
try:
    from mem0 import Memory
    print("[OK] Mem0 loaded")
except ImportError:
    print("[ERROR] pip install mem0ai")
    sys.exit(1)

# Configure Mem0 to use LM Studio
config = {
    "vector_store": {
        "provider": "qdrant",
        "config": {
            "collection_name": "lfm2_memories",
            "embedding_model_dims": 768,
            "path": "./qdrant_storage",
        }
    },
    "llm": {
        "provider": "openai",
        "config": {
            "model": "local-model",
            "api_key": "not-needed",
            "openai_base_url": LM_STUDIO_URL,
            "temperature": 0.7,
            "max_tokens": 512,
        }
    },
}

try:
    memory = Memory.from_config(config_dict=config)
    print("[OK] Mem0 ready with LFM2-350M")
    print()
except Exception as e:
    print(f"[ERROR] {e}")
    sys.exit(1)


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
            self.json({"status": "ok", "lm_studio": LM_STUDIO_URL})
            return
        
        if p.path == "/v1/memories/":
            try:
                results = memory.get_all(
                    user_id=q.get("user_id", ["default"])[0],
                    limit=int(q.get("limit", ["10"])[0])
                self.json(results if isinstance(results, list) else [])
            except Exception as e:
                self.json({"error": str(e)}, 500)
            return
        
        self.json({"error": "Not found"}, 404)
    
    def do_POST(self):
        p = urlparse(self.path)
        n = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(n).decode()
        data = json.loads(body) if body else {}
        
        # Add memory (LFM2 extracts important facts)
        if p.path == "/v1/memories/":
            try:
                result = memory.add(
                    messages=data.get("messages", []),
                    user_id=data.get("user_id", "default"),
                    infer=True  # LFM2 decides what's important
                )
                self.json(result, 201)
            except Exception as e:
                print(f"Error: {e}")
                self.json({"error": str(e)}, 500)
            return
        
        # Search
        if p.path == "/v1/memories/search/":
            try:
                results = memory.search(
                    query=data.get("query", ""),
                    user_id=data.get("user_id", "default"),
                    limit=data.get("limit", 10)
                )
                self.json({"results": results if isinstance(results, list) else []})
            except Exception as e:
                self.json({"error": str(e)}, 500)
            return
        
        self.json({"error": "Not found"}, 404)
    
    def do_DELETE(self):
        if self.path.startswith("/v1/memories/"):
            self.json({"deleted": True})
            return
        self.json({"error": "Not found"}, 404)


print(f"Server: http://{HOST}:{PORT}")
print("Endpoints:")
print(f"  POST /v1/memories/       - Add memory (LFM2 extracts facts)")
print(f"  POST /v1/memories/search/ - Search memories")
print(f"  GET  /v1/memories/        - List memories")
print(f"  GET  /health              - Health check")
print()
print("Press Ctrl+C to stop")
print()

server = HTTPServer((HOST, PORT), Handler)
try:
    server.serve_forever()
except KeyboardInterrupt:
    print("\nStopped")
    server.shutdown()
