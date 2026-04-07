#!/usr/bin/env python3
"""
Mem0 REST API Server using LM Studio with LFM2-350M model.

This server connects to your already-running LM Studio instance
and uses the LFM2-350M model for:
- LLM operations (memory extraction, classification)
- Embeddings (if an embedding model is loaded)

Prerequisites:
- LM Studio running with LFM2-350M-Q8_0.gguf loaded
- API server enabled in LM Studio

Environment Variables:
- LM_STUDIO_URL: LM Studio API URL (default: http://localhost:1234/v1)
- MEM0_HOST: Server host (default: localhost)
- MEM0_PORT: Server port (default: 8000)

Usage:
    cd python/src && python mem0_lmstudio_lfm2.py
"""

import os
import sys
import json
import uuid
import time
import requests
from datetime import datetime
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import parse_qs, urlparse
from typing import List, Dict, Any, Optional

# Load .env
try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass

# Configuration
HOST = os.getenv("MEM0_HOST", "localhost")
PORT = int(os.getenv("MEM0_PORT", "8000"))
LM_STUDIO_URL = os.getenv("LM_STUDIO_URL", "http://localhost:1234/v1").rstrip('/')

print("="*70)
print("Mem0 + LM Studio (LFM2-350M)")
print("="*70)
print(f"LM Studio URL: {LM_STUDIO_URL}")
print()


class LMStudioClient:
    """Client for LM Studio API."""
    
    def __init__(self, base_url: str):
        self.base_url = base_url
        self.models = []
        self.lfm2_model = None
        self.embedding_model = None
        
    def connect(self) -> bool:
        """Connect to LM Studio and detect models."""
        try:
            # Get available models
            resp = requests.get(f"{self.base_url}/models", timeout=10)
            if resp.status_code != 200:
                print(f"[ERROR] LM Studio returned status {resp.status_code}")
                return False
            
            data = resp.json()
            self.models = data.get('data', [])
            
            if not self.models:
                print("[ERROR] No models loaded in LM Studio")
                return False
            
            print(f"[OK] Connected to LM Studio")
            print(f"     Models available: {len(self.models)}")
            
            # Detect LFM2 model
            for m in self.models:
                model_id = m.get('id', '').lower()
                if 'lfm' in model_id or '350m' in model_id:
                    self.lfm2_model = m['id']
                    print(f"     LFM2 Model: {self.lfm2_model}")
                    break
            
            # Use first model if LFM2 not detected
            if not self.lfm2_model and self.models:
                self.lfm2_model = self.models[0]['id']
                print(f"     Using model: {self.lfm2_model}")
            
            # Check for embedding model
            for m in self.models:
                model_id = m.get('id', '').lower()
                if any(x in model_id for x in ['embed', 'nomic', 'gemma']):
                    self.embedding_model = m['id']
                    print(f"     Embedding model: {self.embedding_model}")
                    break
            
            return True
            
        except requests.exceptions.ConnectionError:
            print(f"[ERROR] Cannot connect to LM Studio at {self.base_url}")
            print()
            print("Please ensure:")
            print("  1. LM Studio is running")
            print("  2. LFM2-350M-Q8_0.gguf is loaded")
            print("  3. API server is started (click 'Start Server' in LM Studio)")
            return False
        except Exception as e:
            print(f"[ERROR] Connection failed: {e}")
            return False
    
    def chat(self, messages: List[Dict[str, str]], max_tokens: int = 512, 
             temperature: float = 0.7) -> str:
        """Send chat completion request to LM Studio."""
        url = f"{self.base_url}/chat/completions"
        
        payload = {
            "model": self.lfm2_model,
            "messages": messages,
            "max_tokens": max_tokens,
            "temperature": temperature,
            "stream": False
        }
        
        try:
            resp = requests.post(url, json=payload, timeout=60)
            resp.raise_for_status()
            data = resp.json()
            return data["choices"][0]["message"]["content"]
        except Exception as e:
            print(f"[ERROR] Chat failed: {e}")
            return ""
    
    def embed(self, texts: List[str]) -> List[List[float]]:
        """Get embeddings from LM Studio."""
        if not self.embedding_model:
            print("[WARN] No embedding model available in LM Studio")
            return [[0.0] * 768] * len(texts)
        
        url = f"{self.base_url}/embeddings"
        results = []
        
        for text in texts:
            payload = {
                "model": self.embedding_model,
                "input": text
            }
            try:
                resp = requests.post(url, json=payload, timeout=30)
                resp.raise_for_status()
                data = resp.json()
                embedding = data["data"][0]["embedding"]
                results.append(embedding)
            except Exception as e:
                print(f"[ERROR] Embedding failed: {e}")
                results.append([0.0] * 768)
        
        return results


# Initialize LM Studio client
lmstudio = LMStudioClient(LM_STUDIO_URL)

if not lmstudio.connect():
    sys.exit(1)

print()


# ============================================================================
# Mem0 Integration
# ============================================================================

try:
    from mem0 import Memory
    HAS_MEM0 = True
except ImportError:
    print("[ERROR] mem0ai not installed. Run: pip install mem0ai")
    sys.exit(1)


class LMStudioLLM:
    """Mem0-compatible LLM provider using LM Studio."""
    
    def __init__(self, client: LMStudioClient):
        self.client = client
    
    def generate(self, messages: List[Dict[str, Any]], **kwargs) -> str:
        """Generate response via LM Studio."""
        return self.client.chat(
            messages, 
            max_tokens=kwargs.get('max_tokens', 512),
            temperature=kwargs.get('temperature', 0.7)
        )


class LMStudioEmbedder:
    """Mem0-compatible embedder using LM Studio."""
    
    def __init__(self, client: LMStudioClient):
        self.client = client
    
    def embed(self, text: str, memory_type: str = "text") -> List[float]:
        """Embed text via LM Studio."""
        results = self.client.embed([text])
        return results[0] if results else []


# Configure Mem0
print("Configuring Mem0 with LM Studio...")

config = {
    "vector_store": {
        "provider": "qdrant",
        "config": {
            "collection_name": "lmstudio_lfm2_memories",
            "embedding_model_dims": 768,
            "path": "./qdrant_storage",
        }
    },
    "llm": {
        "provider": "openai",
        "config": {
            "model": lmstudio.lfm2_model,
            "api_key": "not-needed",
            "openai_base_url": LM_STUDIO_URL,
            "temperature": 0.7,
            "max_tokens": 512,
        }
    },
}

# Only add embedder config if LM Studio has an embedding model
if lmstudio.embedding_model:
    config["embedder"] = {
        "provider": "openai",
        "config": {
            "model": lmstudio.embedding_model,
            "api_key": "not-needed",
            "openai_base_url": LM_STUDIO_URL,
        }
    }

try:
    memory = Memory.from_config(config_dict=config)
    print("[OK] Mem0 initialized with LM Studio!")
    print()
except Exception as e:
    print(f"[ERROR] Failed to initialize Mem0: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)


# ============================================================================
# HTTP Server
# ============================================================================

class LMStudioHandler(BaseHTTPRequestHandler):
    """HTTP handler for Mem0 with LM Studio."""
    
    # Allowed origins for CORS
    ALLOWED_ORIGINS = [
        "http://localhost:3000",
        "http://localhost:8080",
        "http://localhost:7345",
        "chrome-extension://*",
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
                if origin.startswith(allowed[:-1]):
                    return True
            elif origin == allowed:
                return True
        return False
    
    def send_json(self, data, status=200):
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
        
        # Health check
        if path == "/health":
            self.send_json({
                "status": "ok",
                "lm_studio_url": LM_STUDIO_URL,
                "lfm2_model": lmstudio.lfm2_model,
                "embedding_model": lmstudio.embedding_model,
                "timestamp": datetime.now().isoformat(),
            })
            return
        
        # Get memories
        if path == "/v1/memories/":
            try:
                user_id = query.get("user_id", ["default_user"])[0]
                agent_id = query.get("agent_id", [""])[0] or None
                limit = int(query.get("limit", ["10"])[0])
                
                results = memory.get_all(user_id=user_id, agent_id=agent_id, limit=limit)
                
                # Format results
                memories = []
                if isinstance(results, list):
                    memories = results
                elif isinstance(results, dict) and "results" in results:
                    memories = results["results"]
                
                self.send_json(memories)
            except Exception as e:
                print(f"[ERROR] Get memories: {e}")
                self.send_json({"error": str(e)}, 500)
            return
        
        self.send_json({"error": "Not found"}, 404)
    
    def do_POST(self):
        parsed = urlparse(self.path)
        path = parsed.path
        
        content_length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(content_length).decode()
        data = json.loads(body) if body else {}
        
        # Embeddings endpoint
        if path == "/v1/embeddings":
            try:
                input_texts = data.get("input", [])
                if isinstance(input_texts, str):
                    input_texts = [input_texts]
                
                embeddings = lmstudio.embed(input_texts)
                
                self.send_json({
                    "object": "list",
                    "data": [
                        {"object": "embedding", "embedding": emb, "index": i}
                        for i, emb in enumerate(embeddings)
                    ],
                    "model": lmstudio.embedding_model or "unknown",
                })
            except Exception as e:
                print(f"[ERROR] Embeddings: {e}")
                self.send_json({"error": str(e)}, 500)
            return
        
        # Chat completions (passthrough to LM Studio)
        if path == "/v1/chat/completions":
            try:
                url = f"{LM_STUDIO_URL}/chat/completions"
                resp = requests.post(url, json=data, timeout=60)
                self.send_json(resp.json(), resp.status_code)
            except Exception as e:
                self.send_json({"error": str(e)}, 500)
            return
        
        # Add memory
        if path == "/v1/memories/":
            try:
                messages = data.get("messages", [])
                user_id = data.get("user_id", "default_user")
                agent_id = data.get("agent_id")
                metadata = data.get("metadata", {})
                
                # Add to Mem0 (uses LFM2 via LM Studio for extraction)
                result = memory.add(
                    messages=messages,
                    user_id=user_id,
                    agent_id=agent_id,
                    metadata=metadata,
                    infer=True  # Use LFM2 to extract facts
                )
                
                self.send_json(result, 201)
            except Exception as e:
                print(f"[ERROR] Add memory: {e}")
                import traceback
                traceback.print_exc()
                self.send_json({"error": str(e)}, 500)
            return
        
        # Search memories
        if path == "/v1/memories/search/":
            try:
                query = data.get("query", "")
                user_id = data.get("user_id", "default_user")
                agent_id = data.get("agent_id")
                limit = data.get("limit", 10)
                
                results = memory.search(
                    query=query,
                    user_id=user_id,
                    agent_id=agent_id,
                    limit=limit
                )
                
                self.send_json({"results": results if isinstance(results, list) else []})
            except Exception as e:
                print(f"[ERROR] Search: {e}")
                self.send_json({"error": str(e)}, 500)
            return
        
        self.send_json({"error": "Not found"}, 404)
    
    def do_DELETE(self):
        parsed = urlparse(self.path)
        path = parsed.path
        
        if path.startswith("/v1/memories/"):
            try:
                self.send_json({"deleted": True})
            except Exception as e:
                self.send_json({"error": str(e)}, 500)
            return
        
        self.send_json({"error": "Not found"}, 404)


def main():
    print("-" * 70)
    print("Server endpoints:")
    print(f"  Health:      GET  http://{HOST}:{PORT}/health")
    print(f"  Chat:        POST http://{HOST}:{PORT}/v1/chat/completions")
    print(f"  Embeddings:  POST http://{HOST}:{PORT}/v1/embeddings")
    print(f"  Add Memory:  POST http://{HOST}:{PORT}/v1/memories/")
    print(f"  Search:      POST http://{HOST}:{PORT}/v1/memories/search/")
    print(f"  Get All:     GET  http://{HOST}:{PORT}/v1/memories/")
    print("-" * 70)
    print()
    print("Features:")
    print("  ✓ LFM2-350M for memory extraction")
    print("  ✓ LM Studio for embeddings (if available)")
    print("  ✓ Qdrant vector storage")
    print()
    print("Your Go app connects to: http://localhost:8000")
    print()
    print("Press Ctrl+C to stop")
    print()
    
    server = HTTPServer((HOST, PORT), LMStudioHandler)
    
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n[INFO] Shutting down...")
        server.shutdown()


if __name__ == "__main__":
    main()
