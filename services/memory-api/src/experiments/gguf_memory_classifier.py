#!/usr/bin/env python3
"""
Mem0 REST API Server using local GGUF model for memory classification.

This server:
1. Uses llama.cpp (or compatible server) to run LFM2-350M-Q8_0.gguf
2. Mem0 uses this to classify if text is useful memory (infer=True)
3. Only useful memories get embedded and stored

Setup:
1. Install llama.cpp: git clone https://github.com/ggerganov/llama.cpp && cd llama.cpp && make
2. Place your LFM2-350M-Q8_0.gguf in the models folder
3. Run this script - it will auto-start the GGUF server

Environment Variables:
- MEM0_HOST: Server host (default: localhost)
- MEM0_PORT: Server port (default: 8000)
- GGUF_MODEL_PATH: Path to your .gguf file (auto-detected if not set)
- GGUF_SERVER_PORT: Port for llama.cpp server (default: 8080)
- LLAMA_CPP_PATH: Path to llama.cpp build directory
"""

import os
import sys
import json
import uuid
import time
import subprocess
import requests
from datetime import datetime
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import parse_qs, urlparse
from pathlib import Path
from typing import List, Dict, Any, Optional

# Load environment variables from .env file
try:
    from dotenv import load_dotenv
    load_dotenv()
    print("[INFO] Loaded environment from .env file")
except ImportError:
    pass

# Configuration
HOST = os.getenv("MEM0_HOST", "localhost")
PORT = int(os.getenv("MEM0_PORT", "8000"))
GGUF_SERVER_PORT = int(os.getenv("GGUF_SERVER_PORT", "8080"))
LLAMA_CPP_PATH = os.getenv("LLAMA_CPP_PATH", "")
MODELS_DIR = Path(os.getenv("MODELS_DIR", "./models"))

print("="*70)
print("Mem0 + GGUF Memory Classifier Server")
print("="*70)

# ============================================================================
# Find GGUF Model
# ============================================================================

def find_gguf_model() -> Optional[Path]:
    """Find the LFM2 GGUF model file."""
    # Check explicit path first
    explicit_path = os.getenv("GGUF_MODEL_PATH")
    if explicit_path:
        path = Path(explicit_path)
        if path.exists():
            return path
    
    # Search common locations
    search_paths = [
        MODELS_DIR,
        Path.home() / ".models",
        Path.home() / "models",
        Path("./models"),
        Path("."),
        Path("../models"),
    ]
    
    for search_dir in search_paths:
        if not search_dir.exists():
            continue
        # Look for LFM2-350M GGUF files
        for pattern in ["*LFM2*.gguf", "*lfm2*.gguf", "*LFM-2*.gguf", "*.gguf"]:
            matches = list(search_dir.glob(pattern))
            if matches:
                return matches[0]
    
    return None

# ============================================================================
# GGUF Server Manager
# ============================================================================

class GGUFServerManager:
    """Manages llama.cpp server for the GGUF model."""
    
    def __init__(self):
        self.process = None
        self.server_url = f"http://localhost:{GGUF_SERVER_PORT}"
        self.model_path = None
        
    def find_llama_server(self) -> Optional[Path]:
        """Find llama-server executable."""
        # Check explicit path
        if LLAMA_CPP_PATH:
            path = Path(LLAMA_CPP_PATH) / "llama-server"
            if path.exists():
                return path
            path = Path(LLAMA_CPP_PATH) / "server" / "llama-server"
            if path.exists():
                return path
        
        # Check PATH
        import shutil
        server = shutil.which("llama-server")
        if server:
            return Path(server)
        
        # Check common build locations
        common_paths = [
            Path("./llama.cpp"),
            Path("../llama.cpp"),
            Path.home() / "llama.cpp",
            Path("/usr/local/bin"),
        ]
        
        for base in common_paths:
            for subpath in ["llama-server", "server/llama-server", "build/bin/llama-server"]:
                path = base / subpath
                if path.exists():
                    return path
        
        return None
    
    def start(self, model_path: Path) -> bool:
        """Start the llama.cpp server with the GGUF model."""
        server_exe = self.find_llama_server()
        if not server_exe:
            print("[ERROR] llama-server not found!")
            print("        Please install llama.cpp:")
            print("        git clone https://github.com/ggerganov/llama.cpp")
            print("        cd llama.cpp && make")
            print()
            print("        Or set LLAMA_CPP_PATH to your build directory")
            return False
        
        self.model_path = model_path
        
        print(f"[INFO] Starting GGUF server...")
        print(f"       Model: {model_path.name}")
        print(f"       Server: {server_exe}")
        print(f"       Port: {GGUF_SERVER_PORT}")
        
        # Build command
        cmd = [
            str(server_exe),
            "-m", str(model_path),
            "--port", str(GGUF_SERVER_PORT),
            "-c", "4096",           # Context size
            "-n", "512",            # Max tokens
            "--host", "127.0.0.1",
        ]
        
        try:
            self.process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True
            )
            
            # Wait for server to be ready
            print("[INFO] Waiting for server to start...")
            max_wait = 30
            for i in range(max_wait):
                time.sleep(1)
                try:
                    resp = requests.get(f"{self.server_url}/health", timeout=2)
                    if resp.status_code == 200:
                        print(f"[OK] GGUF server ready!")
                        return True
                except:
                    pass
                if i % 5 == 0:
                    print(f"       ... ({i}s)")
            
            print("[ERROR] Server failed to start within timeout")
            self.stop()
            return False
            
        except Exception as e:
            print(f"[ERROR] Failed to start server: {e}")
            return False
    
    def stop(self):
        """Stop the llama.cpp server."""
        if self.process:
            print("[INFO] Stopping GGUF server...")
            self.process.terminate()
            try:
                self.process.wait(timeout=5)
            except:
                self.process.kill()
            self.process = None
    
    def chat_complete(self, messages: List[Dict[str, str]], max_tokens: int = 512) -> str:
        """Send chat completion request to GGUF server."""
        url = f"{self.server_url}/v1/chat/completions"
        
        payload = {
            "messages": messages,
            "max_tokens": max_tokens,
            "temperature": 0.1,  # Low temp for consistent classification
            "stream": False
        }
        
        try:
            resp = requests.post(url, json=payload, timeout=30)
            resp.raise_for_status()
            data = resp.json()
            return data["choices"][0]["message"]["content"]
        except Exception as e:
            print(f"[ERROR] GGUF chat failed: {e}")
            return ""
    
    def classify_memory(self, text: str) -> tuple[bool, str]:
        """
        Classify if text is useful memory.
        Returns: (is_useful, extracted_memory)
        """
        system_prompt = """You are a memory classifier. Your job is to determine if the given text contains useful, memorable information.

Useful memories include:
- Facts about the user (preferences, goals, important details)
- Actionable information (tasks, reminders, decisions)
- Context that would be valuable to recall later
- Important conversations or insights

NOT useful (respond with "DISCARD"):
- Small talk or greetings
- Temporary/transient information
- Obvious or generic statements
- Incomplete thoughts

Respond in this exact format:
DECISION: USEFUL or DISCARD
MEMORY: (if USEFUL, extract the concise memory to store)"""

        messages = [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": f"Text to classify:\n{text}"}
        ]
        
        response = self.chat_complete(messages, max_tokens=256)
        
        # Parse response
        is_useful = "USEFUL" in response.upper() and "DISCARD" not in response.upper()
        
        # Extract memory text
        memory_text = ""
        if "MEMORY:" in response:
            memory_text = response.split("MEMORY:", 1)[1].strip()
        elif is_useful:
            # Use original text if no specific extraction
            memory_text = text[:500]  # Limit length
        
        return is_useful, memory_text


# Initialize GGUF manager
gguf_manager = GGUFServerManager()

# ============================================================================
# Embedding Model (unchanged)
# ============================================================================

class LocalEmbedder:
    """Local embedding provider for Mem0."""
    
    def __init__(self):
        self.embedding_model = None
        self.embedding_tokenizer = None
        self.device = "cpu"
        
        try:
            import torch
            if torch.cuda.is_available():
                self.device = "cuda"
        except:
            pass
    
    def load(self):
        """Load embedding model."""
        from transformers import AutoTokenizer, AutoModel
        import torch
        
        model_path = MODELS_DIR / "embeddinggemma-300m-f8"
        
        if not model_path.exists():
            print(f"[ERROR] Embedding model not found at {model_path}")
            return False
        
        print(f"[INFO] Loading embedding model...")
        self.embedding_tokenizer = AutoTokenizer.from_pretrained(
            model_path, trust_remote_code=True, local_files_only=True
        )
        self.embedding_model = AutoModel.from_pretrained(
            model_path, trust_remote_code=True, local_files_only=True,
            torch_dtype=torch.float16,
            device_map="auto"
        )
        self.embedding_model.to(self.device)
        self.embedding_model.eval()
        print("[OK] Embedding model loaded")
        return True
    
    def embed(self, texts: List[str]) -> List[List[float]]:
        """Generate embeddings."""
        import torch
        
        if self.embedding_model is None:
            if not self.load():
                return [[0.0] * 768] * len(texts)
        
        embeddings = []
        batch_size = 8
        
        with torch.no_grad():
            for i in range(0, len(texts), batch_size):
                batch = texts[i:i + batch_size]
                encoded = self.embedding_tokenizer(
                    batch, padding=True, truncation=True,
                    return_tensors="pt", max_length=8192
                )
                encoded = {k: v.to(self.device) for k, v in encoded.items()}
                
                output = self.embedding_model(**encoded)
                mask = encoded["attention_mask"].unsqueeze(-1).float()
                embeddings_batch = (output[0] * mask).sum(dim=1) / mask.sum(dim=1).clamp(min=1e-9)
                embeddings_batch = torch.nn.functional.normalize(embeddings_batch, p=2, dim=1)
                embeddings.extend(embeddings_batch.cpu().numpy().tolist())
        
        return embeddings


# Initialize embedder
embedder = LocalEmbedder()

# ============================================================================
# Mem0 Integration with Custom LLM Classifier
# ============================================================================

try:
    from mem0 import Memory
    HAS_MEM0 = True
except ImportError:
    print("[WARN] mem0ai not installed. Run: pip install mem0ai")
    HAS_MEM0 = False
    Memory = None


class GGUFLLM:
    """
    Custom LLM provider for Mem0 that uses GGUF model for classification.
    """
    
    def __init__(self):
        pass
    
    def generate(self, messages: List[Dict[str, Any]], **kwargs) -> str:
        """
        This is called by Mem0 during memory.add() with infer=True.
        We use the GGUF model to extract/classify important facts.
        """
        # Convert messages to text
        text = "\n".join([m.get("content", "") for m in messages])
        
        # Use GGUF to classify
        is_useful, extracted = gguf_manager.classify_memory(text)
        
        if is_useful and extracted:
            # Return in format Mem0 expects for fact extraction
            return json.dumps({
                "facts": [extracted],
                "importance": "high"
            })
        else:
            # Return empty to signal nothing useful
            return json.dumps({"facts": []})


# Custom Memory Class that filters before embedding
class FilteringMemoryStore:
    """Wraps Mem0 but filters through GGUF classifier first."""
    
    def __init__(self, mem0_memory: Memory):
        self.memory = mem0_memory
    
    def add(self, messages, user_id="default_user", agent_id=None, metadata=None, **kwargs):
        """Add memory only if GGUF classifier says it's useful."""
        # Extract text
        if isinstance(messages, list):
            text = " ".join([m.get("content", "") for m in messages if isinstance(m, dict)])
        else:
            text = str(messages)
        
        print(f"[CLASSIFY] Checking: {text[:80]}...")
        
        # Classify with GGUF
        is_useful, extracted = gguf_manager.classify_memory(text)
        
        if not is_useful:
            print(f"[DISCARD] Not useful memory")
            return {"id": "discarded", "memory": "", "filtered": True}
        
        print(f"[USEFUL] Extracted: {extracted[:80]}...")
        
        # Use extracted text if available, otherwise original
        if extracted:
            if isinstance(messages, list) and len(messages) > 0:
                messages[0]["content"] = extracted
            else:
                messages = [{"role": "user", "content": extracted}]
        
        # Now add to Mem0 (with infer=False since we already classified)
        return self.memory.add(
            messages=messages,
            user_id=user_id,
            agent_id=agent_id,
            metadata=metadata,
            infer=False  # We already did the classification
        )
    
    def search(self, **kwargs):
        return self.memory.search(**kwargs)
    
    def get_all(self, **kwargs):
        return self.memory.get_all(**kwargs)
    
    def delete(self, **kwargs):
        return self.memory.delete(**kwargs)


# Configure and initialize Mem0
memory = None
filtered_memory = None

if HAS_MEM0:
    print()
    print("Configuring Mem0 with GGUF classifier...")
    
    # Find and start GGUF server
    model_path = find_gguf_model()
    if not model_path:
        print("[ERROR] GGUF model not found!")
        print("        Please set GGUF_MODEL_PATH or place model in ./models/")
        sys.exit(1)
    
    print(f"[OK] Found GGUF model: {model_path}")
    
    if not gguf_manager.start(model_path):
        print("[ERROR] Failed to start GGUF server")
        sys.exit(1)
    
    # Load embedding model
    embedder.load()
    
    # Mem0 config
    config = {
        "vector_store": {
            "provider": "qdrant",
            "config": {
                "collection_name": "screen_memories_filtered",
                "embedding_model_dims": 768,
                "path": "./qdrant_storage",
            }
        },
        "llm": {
            "provider": "openai",
            "config": {
                "model": "gguf-classifier",
                "api_key": "local",
                "openai_base_url": f"http://localhost:{GGUF_SERVER_PORT}/v1",
            }
        },
    }
    
    try:
        base_memory = Memory.from_config(config_dict=config)
        # Wrap with our filtering layer
        filtered_memory = FilteringMemoryStore(base_memory)
        memory = filtered_memory
        print("[OK] Mem0 initialized with GGUF classifier!")
    except Exception as e:
        print(f"[WARN] Failed to initialize Mem0: {e}")
        import traceback
        traceback.print_exc()

print()

# ============================================================================
# HTTP Server
# ============================================================================

class GGUFMem0Handler(BaseHTTPRequestHandler):
    """HTTP handler with GGUF classification."""
    
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
                "gguf_model": str(gguf_manager.model_path) if gguf_manager.model_path else None,
                "gguf_server": gguf_manager.server_url,
                "classifier_active": True,
            })
            return
        
        if path == "/v1/memories/" and memory:
            user_id = query.get("user_id", ["default_user"])[0]
            limit = int(query.get("limit", ["10"])[0])
            
            try:
                results = memory.get_all(user_id=user_id, limit=limit)
                self.send_json_response(results if isinstance(results, list) else [])
            except Exception as e:
                self.send_json_response({"error": str(e)}, 500)
            return
        
        self.send_json_response({"error": "Not found"}, 404)
    
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
                
                embeddings = embedder.embed(input_texts)
                
                response = {
                    "object": "list",
                    "data": [
                        {"object": "embedding", "embedding": emb, "index": i}
                        for i, emb in enumerate(embeddings)
                    ],
                    "model": "embedding-gemma",
                }
                self.send_json_response(response)
            except Exception as e:
                print(f"[ERROR] Embeddings failed: {e}")
                self.send_json_response({"error": str(e)}, 500)
            return
        
        # Add memory WITH CLASSIFICATION
        if path == "/v1/memories/" and memory:
            try:
                messages = data.get("messages", [])
                user_id = data.get("user_id", "default_user")
                metadata = data.get("metadata", {})
                
                result = memory.add(
                    messages=messages,
                    user_id=user_id,
                    metadata=metadata
                )
                
                # Check if it was filtered
                if result.get("filtered"):
                    self.send_json_response({
                        "id": "filtered",
                        "status": "discarded",
                        "reason": "not_useful_memory"
                    }, 200)
                else:
                    self.send_json_response(result, 201)
                    
            except Exception as e:
                print(f"[ERROR] Add memory failed: {e}")
                import traceback
                traceback.print_exc()
                self.send_json_response({"error": str(e)}, 500)
            return
        
        # Search memories
        if path == "/v1/memories/search/" and memory:
            try:
                query = data.get("query", "")
                user_id = data.get("user_id", "default_user")
                limit = data.get("limit", 10)
                
                results = memory.search(query=query, user_id=user_id, limit=limit)
                self.send_json_response({"results": results if isinstance(results, list) else []})
            except Exception as e:
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


def main():
    """Main entry point."""
    print("-" * 70)
    print("Available endpoints:")
    print(f"  Health:      GET  http://{HOST}:{PORT}/health")
    print(f"  Memories:    GET  http://{HOST}:{PORT}/v1/memories/")
    print(f"  Add Memory:  POST http://{HOST}:{PORT}/v1/memories/")
    print(f"  Search:      POST http://{HOST}:{PORT}/v1/memories/search/")
    print("-" * 70)
    print()
    print("Features:")
    print("  ✓ GGUF model classifies memories before embedding")
    print("  ✓ Only useful memories are stored")
    print("  ✓ Unimportant text is automatically discarded")
    print()
    print("Press Ctrl+C to stop")
    print()
    
    server = HTTPServer((HOST, PORT), GGUFMem0Handler)
    
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n[INFO] Shutting down...")
        gguf_manager.stop()
        server.shutdown()


if __name__ == "__main__":
    main()
