#!/usr/bin/env python3
"""
Mem0 with LM Studio Classifier
Uses your already-running LM Studio (LFM2-350M-Q8_0.gguf) to classify memories.

Prerequisites:
- LM Studio running with LFM2-350M-Q8_0.gguf loaded
- API server enabled in LM Studio (default port 1234)
- pip install mem0ai qdrant-client transformers torch requests

Usage:
    python mem0_lmstudio_classifier.py
"""

import os
import sys
import json
import time
import requests
from datetime import datetime
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import parse_qs, urlparse
from pathlib import Path
from typing import List, Dict, Any, Tuple

# Load .env if exists
try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass

# Configuration
HOST = os.getenv("MEM0_HOST", "localhost")
PORT = int(os.getenv("MEM0_PORT", "8000"))
LM_STUDIO_URL = os.getenv("LM_STUDIO_URL", "http://localhost:1234/v1")

print("="*70)
print("Mem0 + LM Studio Memory Classifier")
print("="*70)
print(f"LM Studio: {LM_STUDIO_URL}")
print()


class LMStudioClassifier:
    """Uses LM Studio to classify if text is a useful memory."""
    
    def __init__(self, base_url: str):
        self.base_url = base_url.rstrip('/')
        self.chat_url = f"{self.base_url}/chat/completions"
        
    def check_connection(self) -> bool:
        """Verify LM Studio is running."""
        try:
            resp = requests.get(f"{self.base_url}/models", timeout=5)
            if resp.status_code == 200:
                models = resp.json().get('data', [])
                print(f"[OK] LM Studio connected")
                if models:
                    print(f"     Model: {models[0]['id']}")
                return True
        except Exception as e:
            print(f"[ERROR] Cannot connect to LM Studio: {e}")
        return False
    
    def classify(self, text: str) -> Tuple[bool, str]:
        """
        Ask LM Studio if this text is worth remembering.
        Returns: (is_useful, reason)
        """
        system_prompt = """You are a memory classifier. Your job is to decide if the given text contains useful information worth remembering.

USEFUL memories include:
- User preferences, goals, personal details
- Tasks, reminders, deadlines, decisions
- Important context to recall later
- Work projects, commitments
- Key insights or information

NOT useful (respond DISCARD):
- Greetings, small talk, "hello", "thanks"
- Loading messages, "please wait"
- System notifications
- Temporary or obvious info
- Incomplete thoughts

Respond ONLY in this format:
DECISION: USEFUL or DISCARD
REASON: one line explanation"""

        messages = [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": f"Classify this text:\n{text[:1500]}"}
        ]
        
        payload = {
            "model": "local-model",
            "messages": messages,
            "max_tokens": 128,
            "temperature": 0.1,
            "stream": False
        }
        
        try:
            resp = requests.post(self.chat_url, json=payload, timeout=30)
            resp.raise_for_status()
            data = resp.json()
            
            content = data["choices"][0]["message"]["content"]
            
            # Parse decision
            is_useful = "USEFUL" in content.upper() and "DISCARD" not in content.upper()
            
            # Extract reason
            reason = ""
            if "REASON:" in content:
                reason = content.split("REASON:", 1)[1].strip()
            elif "DECISION:" in content:
                reason = content.split("DECISION:", 1)[1].strip()
            
            return is_useful, reason
            
        except Exception as e:
            print(f"[WARN] Classification failed: {e}")
            # Default to storing if classifier fails
            return True, "classifier_error"


# Initialize classifier
classifier = LMStudioClassifier(LM_STUDIO_URL)

if not classifier.check_connection():
    print()
    print("Please check:")
    print("  1. LM Studio is running")
    print("  2. Model is loaded")
    print("  3. API server is started (click 'Start Server' in LM Studio)")
    print()
    sys.exit(1)

print()


# ============================================================================
# Embedding Model (Gemma - for actual embeddings)
# ============================================================================

MODELS_DIR = Path(os.getenv("MODELS_DIR", "./models"))

class GemmaEmbedder:
    """Google Embedding Gemma for vector embeddings."""
    
    def __init__(self):
        self.model = None
        self.tokenizer = None
        self.device = "cpu"
        
        try:
            import torch
            if torch.cuda.is_available():
                self.device = "cuda"
                print(f"[OK] Using CUDA for embeddings")
        except:
            pass
    
    def load(self) -> bool:
        from transformers import AutoTokenizer, AutoModel
        import torch
        
        path = MODELS_DIR / "embeddinggemma-300m-f8"
        if not path.exists():
            print(f"[WARN] Gemma embedder not found at {path}")
            print(f"       Embeddings will not work!")
            return False
        
        print("[INFO] Loading Gemma embedding model...")
        self.tokenizer = AutoTokenizer.from_pretrained(
            path, trust_remote_code=True, local_files_only=True
        )
        self.model = AutoModel.from_pretrained(
            path, trust_remote_code=True, local_files_only=True,
            torch_dtype=torch.float16 if self.device == "cuda" else torch.float32,
            device_map="auto" if self.device == "cuda" else None
        )
        if self.device == "cpu":
            self.model.to(self.device)
        self.model.eval()
        print("[OK] Embedding model ready")
        return True
    
    def embed(self, texts: List[str]) -> List[List[float]]:
        import torch
        
        if self.model is None:
            if not self.load():
                return [[0.0] * 768] * len(texts)
        
        embeddings = []
        with torch.no_grad():
            for i in range(0, len(texts), 4):  # Small batches
                batch = texts[i:i + 4]
                encoded = self.tokenizer(
                    batch, padding=True, truncation=True,
                    return_tensors="pt", max_length=8192
                )
                encoded = {k: v.to(self.device) for k, v in encoded.items()}
                
                output = self.model(**encoded)
                mask = encoded["attention_mask"].unsqueeze(-1).float()
                emb = (output[0] * mask).sum(dim=1) / mask.sum(dim=1).clamp(min=1e-9)
                emb = torch.nn.functional.normalize(emb, p=2, dim=1)
                embeddings.extend(emb.cpu().numpy().tolist())
        
        return embeddings


embedder = GemmaEmbedder()


# ============================================================================
# Mem0 with Pre-Filtering
# ============================================================================

try:
    from mem0 import Memory
    HAS_MEM0 = True
except ImportError:
    print("[ERROR] mem0ai not installed. Run: pip install mem0ai")
    sys.exit(1)


class FilteringMemoryStore:
    """
    Mem0 wrapper that classifies with LM Studio BEFORE embedding.
    Only useful memories get embedded and stored.
    """
    
    def __init__(self, base_memory: Memory):
        self.memory = base_memory
        self.stats = {"stored": 0, "discarded": 0}
    
    def add(self, messages, user_id="default_user", agent_id=None, metadata=None, **kwargs):
        """Add memory with LM Studio classification filter."""
        # Extract text
        if isinstance(messages, list):
            text = " ".join([m.get("content", "") for m in messages if isinstance(m, dict)])
        else:
            text = str(messages)
        
        # Skip empty
        if not text.strip():
            return {"id": "empty", "filtered": True}
        
        print(f"\n[CLASSIFY] {text[:100]}...")
        
        # Classify with LM Studio
        is_useful, reason = classifier.classify(text)
        
        if not is_useful:
            self.stats["discarded"] += 1
            print(f"[DISCARD] ({self.stats['discarded']} total) {reason}")
            return {
                "id": f"discarded_{int(time.time())}",
                "filtered": True,
                "reason": reason
            }
        
        # Useful - proceed to embed and store
        self.stats["stored"] += 1
        print(f"[STORE] ({self.stats['stored']} total) {reason}")
        
        # Add classification metadata
        enriched_metadata = {
            **(metadata or {}),
            "classified": True,
            "classifier": "lmstudio_lfm2",
            "classification_reason": reason
        }
        
        # Store in Mem0 (skip infer since we classified)
        return self.memory.add(
            messages=messages,
            user_id=user_id,
            agent_id=agent_id,
            metadata=enriched_metadata,
            infer=False  # We already did classification
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
print("Configuring Mem0...")

# Load embedding model
has_embedder = embedder.load()

config = {
    "vector_store": {
        "provider": "qdrant",
        "config": {
            "collection_name": "lmstudio_filtered_memories",
            "embedding_model_dims": 768,
            "path": "./qdrant_storage",
        }
    },
    "embedder": {
        "provider": "openai",
        "config": {
            "model": "embedding-gemma",
            "api_key": "local",
            "openai_base_url": f"http://{HOST}:{PORT}/v1",
        }
    } if has_embedder else {
        "provider": "openai",  # Will use our endpoint
        "config": {
            "model": "local",
            "api_key": "local",
            "openai_base_url": f"http://{HOST}:{PORT}/v1",
        }
    },
    "llm": {
        "provider": "openai",
        "config": {
            "model": "local-model",
            "api_key": "not-needed",
            "openai_base_url": LM_STUDIO_URL,
            "temperature": 0.1,
            "max_tokens": 128,
        }
    },
}

try:
    base_memory = Memory.from_config(config_dict=config)
    memory = FilteringMemoryStore(base_memory)
    print("[OK] Mem0 initialized with LM Studio classifier!")
    print()
    print("Flow: Text → LM Studio (classify) → [USEFUL] → Embed → Store")
    print("                         ↓[DISCARD]  (no embedding created)")
    print()
except Exception as e:
    print(f"[ERROR] Failed to initialize Mem0: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)


# ============================================================================
# HTTP Server (API for Go app)
# ============================================================================

class Handler(BaseHTTPRequestHandler):
    
    # Allowed origins for CORS - configure based on your deployment
    ALLOWED_ORIGINS = [
        "http://localhost:3000",
        "http://localhost:8080",
        "http://localhost:7345",
        "chrome-extension://*",
    ]
    
    def log_message(self, format, *args):
        print(f"[{datetime.now().strftime('%H:%M:%S')}] {format % args}")
    
    def _get_origin(self):
        """Get the Origin header from the request."""
        return self.headers.get('Origin', '')
    
    def _is_allowed_origin(self, origin):
        """Check if the origin is in the allowed list."""
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
                "lm_studio": LM_STUDIO_URL,
                "classifier": "lmstudio_lfm2",
                "stats": memory.get_stats() if memory else {},
            })
            return
        
        # List memories
        if path == "/v1/memories/":
            try:
                user_id = query.get("user_id", ["default_user"])[0]
                limit = int(query.get("limit", ["10"])[0])
                results = memory.get_all(user_id=user_id, limit=limit)
                self.send_json(results if isinstance(results, list) else [])
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
        
        # Embeddings endpoint (for Mem0)
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
                print(f"[ERROR] Embeddings: {e}")
                self.send_json({"error": str(e)}, 500)
            return
        
        # Add memory WITH LM STUDIO CLASSIFICATION
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
                        "status": "stored",
                        "stats": memory.get_stats()
                    }, 201)
                    
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
                limit = data.get("limit", 10)
                
                results = memory.search(query=query, user_id=user_id, limit=limit)
                self.send_json({"results": results if isinstance(results, list) else []})
            except Exception as e:
                print(f"[ERROR] Search: {e}")
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
    print("Server running:")
    print(f"  Health:  GET  http://{HOST}:{PORT}/health")
    print(f"  Add:     POST http://{HOST}:{PORT}/v1/memories/")
    print(f"  Search:  POST http://{HOST}:{PORT}/v1/memories/search/")
    print(f"  Get All: GET  http://{HOST}:{PORT}/v1/memories/")
    print("-" * 70)
    print()
    print("Your Go app should connect to: http://localhost:8000")
    print()
    print("Press Ctrl+C to stop")
    print()
    
    server = HTTPServer((HOST, PORT), Handler)
    
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n\n[INFO] Shutting down...")
        server.shutdown()
        print(f"Final stats: {memory.get_stats()}")


if __name__ == "__main__":
    main()
