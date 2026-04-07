#!/usr/bin/env python3
"""
Simpler Mem0 setup that uses external GGUF/Ollama for memory classification.

Prerequisites:
1. Install Ollama or run llama.cpp server with your LFM2-350M-Q8_0.gguf
2. pip install mem0ai

Usage:
    # Option 1: With Ollama
    ollama create lfm2-classifier -f ./Modelfile  # See below
    
    # Option 2: With llama.cpp
    ./llama-server -m LFM2-350M-Q8_0.gguf --port 8080
    
    # Then run this script
    cd python/src && python mem0_with_classifier.py
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
from pathlib import Path
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
CLASSIFIER_URL = os.getenv("CLASSIFIER_URL", "http://localhost:8080/v1/chat/completions")
MODEL_NAME = os.getenv("CLASSIFIER_MODEL", "lfm2-classifier")

print("="*70)
print("Mem0 with GGUF Memory Classifier")
print("="*70)
print(f"Classifier URL: {CLASSIFIER_URL}")
print()


class MemoryClassifier:
    """Uses external GGUF/Ollama server to classify memories."""
    
    def __init__(self, server_url: str, model: str):
        self.server_url = server_url
        self.model = model
        self.system_prompt = """You are a memory filter. Determine if the text contains useful, memorable information.

USEFUL memories include:
- User preferences, goals, important facts
- Tasks, reminders, decisions made
- Context valuable for future reference
- Key insights or information

NOT useful (respond DISCARD):
- Greetings, small talk
- Temporary info, loading messages
- Obvious/generic statements
- Incomplete thoughts

Respond ONLY with:
DECISION: USEFUL or DISCARD
REASON: brief explanation"""

    def check_server(self) -> bool:
        """Verify classifier server is running."""
        try:
            # Try Ollama-style check
            resp = requests.get(self.server_url.replace("/v1/chat/completions", "/api/tags"), timeout=5)
            if resp.status_code == 200:
                print(f"[OK] Ollama server detected")
                return True
        except:
            pass
        
        try:
            # Try OpenAI-compatible check
            resp = requests.get(self.server_url.replace("/v1/chat/completions", "/health"), timeout=5)
            if resp.status_code == 200:
                print(f"[OK] llama.cpp server detected")
                return True
        except:
            pass
        
        return False
    
    def classify(self, text: str) -> tuple[bool, str]:
        """
        Classify if text is useful memory.
        Returns: (is_useful, reason)
        """
        messages = [
            {"role": "system", "content": self.system_prompt},
            {"role": "user", "content": f"Text:\n{text[:2000]}"}  # Limit input
        ]
        
        payload = {
            "model": self.model,
            "messages": messages,
            "max_tokens": 256,
            "temperature": 0.1,
            "stream": False
        }
        
        try:
            resp = requests.post(self.server_url, json=payload, timeout=30)
            resp.raise_for_status()
            data = resp.json()
            
            content = data.get("choices", [{}])[0].get("message", {}).get("content", "")
            
            is_useful = "USEFUL" in content.upper() and "DISCARD" not in content.upper()
            
            # Extract reason
            reason = ""
            if "REASON:" in content:
                reason = content.split("REASON:", 1)[1].strip()
            
            return is_useful, reason
            
        except Exception as e:
            print(f"[WARN] Classification failed: {e}")
            # Default to storing if classifier fails
            return True, "classification_error"


# Initialize classifier
classifier = MemoryClassifier(CLASSIFIER_URL, MODEL_NAME)

if not classifier.check_server():
    print("[ERROR] Classifier server not responding!")
    print(f"        Checked: {CLASSIFIER_URL}")
    print()
    print("Please start your GGUF server:")
    print()
    print("Option 1 - Ollama:")
    print("  1. Create a Modelfile:")
    print("     FROM ./LFM2-350M-Q8_0.gguf")
    print("     PARAMETER temperature 0.1")
    print("")
    print("  2. ollama create lfm2-classifier -f Modelfile")
    print("  3. ollama run lfm2-classifier")
    print()
    print("Option 2 - llama.cpp:")
    print("  ./llama-server -m LFM2-350M-Q8_0.gguf --port 8080")
    print()
    sys.exit(1)

print("[OK] Classifier connected")


# ============================================================================
# Embedding Model (same as before)
# ============================================================================

MODELS_DIR = Path(os.getenv("MODELS_DIR", "./models"))

class LocalEmbedder:
    def __init__(self):
        self.model = None
        self.tokenizer = None
        self.device = "cpu"
        
        try:
            import torch
            if torch.cuda.is_available():
                self.device = "cuda"
        except:
            pass
    
    def load(self):
        from transformers import AutoTokenizer, AutoModel
        import torch
        
        path = MODELS_DIR / "embeddinggemma-300m-f8"
        if not path.exists():
            print(f"[ERROR] Embedding model not found: {path}")
            return False
        
        print("[INFO] Loading embedding model...")
        self.tokenizer = AutoTokenizer.from_pretrained(path, trust_remote_code=True, local_files_only=True)
        self.model = AutoModel.from_pretrained(
            path, trust_remote_code=True, local_files_only=True,
            torch_dtype=torch.float16, device_map="auto"
        )
        self.model.to(self.device)
        self.model.eval()
        print("[OK] Embedding model loaded")
        return True
    
    def embed(self, texts: List[str]) -> List[List[float]]:
        import torch
        
        if self.model is None:
            if not self.load():
                return [[0.0] * 768] * len(texts)
        
        embeddings = []
        with torch.no_grad():
            for i in range(0, len(texts), 8):
                batch = texts[i:i + 8]
                encoded = self.tokenizer(batch, padding=True, truncation=True,
                                         return_tensors="pt", max_length=8192)
                encoded = {k: v.to(self.device) for k, v in encoded.items()}
                
                output = self.model(**encoded)
                mask = encoded["attention_mask"].unsqueeze(-1).float()
                emb = (output[0] * mask).sum(dim=1) / mask.sum(dim=1).clamp(min=1e-9)
                emb = torch.nn.functional.normalize(emb, p=2, dim=1)
                embeddings.extend(emb.cpu().numpy().tolist())
        
        return embeddings


embedder = LocalEmbedder()


# ============================================================================
# Mem0 Setup with Filtering
# ============================================================================

try:
    from mem0 import Memory
    HAS_MEM0 = True
except ImportError:
    print("[ERROR] mem0ai not installed. Run: pip install mem0ai")
    HAS_MEM0 = False
    sys.exit(1)


class ClassifyingMemoryStore:
    """
    Mem0 wrapper that filters memories through GGUF classifier.
    Only useful memories get embedded and stored.
    """
    
    def __init__(self, base_memory: Memory):
        self.memory = base_memory
        self.stats = {"stored": 0, "discarded": 0}
    
    def add(self, messages, user_id="default_user", agent_id=None, metadata=None, **kwargs):
        """Add memory with classification filter."""
        # Extract text from messages
        if isinstance(messages, list):
            text = " ".join([m.get("content", "") for m in messages if isinstance(m, dict)])
        else:
            text = str(messages)
        
        print(f"\n[INPUT] {text[:100]}...")
        
        # Classify
        is_useful, reason = classifier.classify(text)
        
        if not is_useful:
            self.stats["discarded"] += 1
            print(f"[DISCARD] ({self.stats['discarded']} total) - {reason}")
            return {
                "id": f"discarded_{uuid.uuid4().hex[:8]}",
                "filtered": True,
                "reason": reason
            }
        
        # It's useful - proceed with embedding
        self.stats["stored"] += 1
        print(f"[STORE] ({self.stats['stored']} total) - {reason}")
        
        # Add to Mem0 (skip infer since we classified)
        return self.memory.add(
            messages=messages,
            user_id=user_id,
            agent_id=agent_id,
            metadata={**(metadata or {}), "classified": True, "classifier_reason": reason},
            infer=False
        )
    
    def search(self, **kwargs):
        return self.memory.search(**kwargs)
    
    def get_all(self, **kwargs):
        return self.memory.get_all(**kwargs)
    
    def delete(self, **kwargs):
        return self.memory.delete(**kwargs)
    
    def get_stats(self):
        return self.stats.copy()


# Configure Mem0
print()
print("Configuring Mem0...")

embedder.load()

config = {
    "vector_store": {
        "provider": "qdrant",
        "config": {
            "collection_name": "filtered_memories",
            "embedding_model_dims": 768,
            "path": "./qdrant_storage",
        }
    },
    "llm": {
        "provider": "openai",
        "config": {
            "model": MODEL_NAME,
            "api_key": "not-needed",
            "openai_base_url": CLASSIFIER_URL.replace("/chat/completions", ""),
        }
    },
}

try:
    base_memory = Memory.from_config(config_dict=config)
    memory = ClassifyingMemoryStore(base_memory)
    print("[OK] Mem0 initialized with GGUF classifier!")
    print()
    print("How it works:")
    print("  1. Incoming text → GGUF classifier (LFM2-350M)")
    print("  2. Classifier decides: USEFUL or DISCARD")
    print("  3. Only USEFUL memories get embedded & stored")
    print()
except Exception as e:
    print(f"[ERROR] Failed to initialize Mem0: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)


# ============================================================================
# HTTP Server (OpenAI-compatible for Go app)
# ============================================================================

class Handler(BaseHTTPRequestHandler):
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
        
        if path == "/health":
            self.send_json({
                "status": "ok",
                "classifier_url": CLASSIFIER_URL,
                "model": MODEL_NAME,
                "stats": memory.get_stats() if memory else {},
            })
            return
        
        if path == "/v1/memories/":
            try:
                user_id = query.get("user_id", ["default_user"])[0]
                limit = int(query.get("limit", ["10"])[0])
                results = memory.get_all(user_id=user_id, limit=limit)
                self.send_json(results if isinstance(results, list) else [])
            except Exception as e:
                self.send_json({"error": str(e)}, 500)
            return
        
        self.send_json({"error": "Not found"}, 404)
    
    def do_POST(self):
        parsed = urlparse(self.path)
        path = parsed.path
        
        content_length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(content_length).decode()
        data = json.loads(body) if body else {}
        
        # Embeddings
        if path == "/v1/embeddings":
            try:
                texts = data.get("input", [])
                if isinstance(texts, str):
                    texts = [texts]
                
                embeddings = embedder.embed(texts)
                
                self.send_json({
                    "object": "list",
                    "data": [
                        {"object": "embedding", "embedding": emb, "index": i}
                        for i, emb in enumerate(embeddings)
                    ],
                    "model": "embedding-gemma",
                })
            except Exception as e:
                self.send_json({"error": str(e)}, 500)
            return
        
        # Add memory WITH CLASSIFICATION
        if path == "/v1/memories/":
            try:
                messages = data.get("messages", [])
                user_id = data.get("user_id", "default_user")
                agent_id = data.get("agent_id")
                metadata = data.get("metadata", {})
                
                result = memory.add(
                    messages=messages,
                    user_id=user_id,
                    agent_id=agent_id,
                    metadata=metadata
                )
                
                if result.get("filtered"):
                    self.send_json({
                        "id": result["id"],
                        "status": "discarded",
                        "reason": result.get("reason"),
                        "stats": memory.get_stats()
                    }, 200)
                else:
                    self.send_json({
                        **result,
                        "stats": memory.get_stats()
                    }, 201)
                    
            except Exception as e:
                print(f"[ERROR] Add memory failed: {e}")
                import traceback
                traceback.print_exc()
                self.send_json({"error": str(e)}, 500)
            return
        
        # Search
        if path == "/v1/memories/search/":
            try:
                query = data.get("query", "")
                user_id = data.get("user_id", "default_user")
                limit = data.get("limit", 10)
                
                results = memory.search(query=query, user_id=user_id, limit=limit)
                self.send_json({"results": results if isinstance(results, list) else []})
            except Exception as e:
                self.send_json({"error": str(e)}, 500)
            return
        
        self.send_json({"error": "Not found"}, 404)
    
    def do_DELETE(self):
        parsed = urlparse(self.path)
        if parsed.path.startswith("/v1/memories/"):
            self.send_json({"deleted": True})
            return
        self.send_json({"error": "Not found"}, 404)


def main():
    print("-" * 70)
    print("Server endpoints:")
    print(f"  Health:  GET  http://{HOST}:{PORT}/health")
    print(f"  Add:     POST http://{HOST}:{PORT}/v1/memories/")
    print(f"  Search:  POST http://{HOST}:{PORT}/v1/memories/search/")
    print(f"  Get All: GET  http://{HOST}:{PORT}/v1/memories/")
    print("-" * 70)
    print()
    print("Press Ctrl+C to stop")
    print()
    
    server = HTTPServer((HOST, PORT), Handler)
    
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down...")
        server.shutdown()


if __name__ == "__main__":
    main()
