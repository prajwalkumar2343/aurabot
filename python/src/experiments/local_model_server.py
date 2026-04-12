#!/usr/bin/env python3
"""
Local Model Server - Downloads and runs models locally without external dependencies.

Models:
- LFM-2-Vision-450M: Vision-language model for image understanding
- Nomic-Embed-Text-v1.5: Text embedding model

This server provides a REST API for:
- Text embeddings (compatible with OpenAI format)
- Vision-language inference (chat with images)

Usage:
    python local_model_server.py
    
Requirements will be auto-installed on first run.
"""

import os
import sys
import json
import time
import io
import base64
import subprocess
from pathlib import Path
from typing import Optional, List, Dict, Any

# ============================================================================
# Configuration
# ============================================================================

MODELS_DIR = Path("./models")
SERVER_HOST = os.getenv("LOCAL_MODEL_HOST", "localhost")
SERVER_PORT = int(os.getenv("LOCAL_MODEL_PORT", "8000"))

# Model configurations
EMBEDDING_MODEL = {
    "name": "nomic-ai/nomic-embed-text-v1.5",
    "local_path": MODELS_DIR / "nomic-embed-text-v1.5",
    "dims": 768,
    "max_length": 2048,
}

VISION_MODEL = {
    "name": "LiquidAI/LFM-2-Vision-450M",
    "local_path": MODELS_DIR / "lfm-2-vision-450m",
    "max_length": 4096,
}

# ============================================================================
# Dependency Management
# ============================================================================

REQUIRED_PACKAGES = [
    "torch>=2.0.0",
    "transformers>=4.40.0",
    "pillow>=10.0.0",
    "numpy>=1.24.0",
    "sentencepiece>=0.2.0",
    "protobuf>=4.0.0",
]

def check_and_install_dependencies():
    """Check and install required dependencies."""
    print("[INFO] Checking dependencies...")
    
    missing = []
    for package in REQUIRED_PACKAGES:
        pkg_name = package.split(">=")[0].split("==")[0]
        try:
            __import__(pkg_name.replace("-", "_"))
        except ImportError:
            missing.append(package)
    
    if missing:
        print(f"[INFO] Installing missing packages: {missing}")
        try:
            subprocess.check_call([
                sys.executable, "-m", "pip", "install", "--quiet"
            ] + missing)
            print("[OK] Dependencies installed successfully")
        except subprocess.CalledProcessError as e:
            print(f"[ERROR] Failed to install dependencies: {e}")
            print("Please run manually: pip install " + " ".join(missing))
            sys.exit(1)
    else:
        print("[OK] All dependencies are available")

# ============================================================================
# Model Management
# ============================================================================

class ModelManager:
    """Manages downloading and loading of local models."""
    
    def __init__(self):
        self.embedding_model = None
        self.embedding_tokenizer = None
        self.vision_model = None
        self.vision_processor = None
        self.vision_tokenizer = None
        self.device = "cpu"
        
        # Try to use CUDA if available
        try:
            import torch
            if torch.cuda.is_available():
                self.device = "cuda"
                print(f"[OK] CUDA is available, using GPU acceleration")
            else:
                print(f"[INFO] CUDA not available, using CPU")
        except ImportError:
            pass
    
    def download_embedding_model(self, force: bool = False):
        """Download the Nomic embedding model."""
        from transformers import AutoTokenizer, AutoModel
        
        local_path = EMBEDDING_MODEL["local_path"]
        
        if local_path.exists() and not force:
            print(f"[INFO] Embedding model already exists at {local_path}")
            return
        
        print(f"[INFO] Downloading {EMBEDDING_MODEL['name']}...")
        print(f"       This may take a few minutes depending on your connection...")
        
        MODELS_DIR.mkdir(parents=True, exist_ok=True)
        
        try:
            # Download tokenizer and model
            tokenizer = AutoTokenizer.from_pretrained(EMBEDDING_MODEL["name"], trust_remote_code=True)
            model = AutoModel.from_pretrained(EMBEDDING_MODEL["name"], trust_remote_code=True)
            
            # Save locally
            tokenizer.save_pretrained(local_path)
            model.save_pretrained(local_path)
            
            print(f"[OK] Embedding model downloaded to {local_path}")
        except Exception as e:
            print(f"[ERROR] Failed to download embedding model: {e}")
            raise
    
    def load_embedding_model(self):
        """Load the embedding model into memory."""
        from transformers import AutoTokenizer, AutoModel
        import torch
        
        local_path = EMBEDDING_MODEL["local_path"]
        
        if not local_path.exists():
            self.download_embedding_model()
        
        print(f"[INFO] Loading embedding model from {local_path}...")
        
        try:
            self.embedding_tokenizer = AutoTokenizer.from_pretrained(
                local_path, 
                trust_remote_code=True,
                local_files_only=True
            )
            self.embedding_model = AutoModel.from_pretrained(
                local_path, 
                trust_remote_code=True,
                local_files_only=True
            )
            self.embedding_model.to(self.device)
            self.embedding_model.eval()
            
            print(f"[OK] Embedding model loaded successfully")
        except Exception as e:
            print(f"[ERROR] Failed to load embedding model: {e}")
            # Try downloading again
            print("[INFO] Attempting to re-download...")
            self.download_embedding_model(force=True)
            self.embedding_tokenizer = AutoTokenizer.from_pretrained(
                local_path, trust_remote_code=True, local_files_only=True
            )
            self.embedding_model = AutoModel.from_pretrained(
                local_path, trust_remote_code=True, local_files_only=True
            )
            self.embedding_model.to(self.device)
            self.embedding_model.eval()
    
    def download_vision_model(self, force: bool = False):
        """Download the LFM vision model."""
        from transformers import AutoProcessor, AutoModelForVision2Seq
        
        local_path = VISION_MODEL["local_path"]
        
        if local_path.exists() and not force:
            print(f"[INFO] Vision model already exists at {local_path}")
            return
        
        print(f"[INFO] Downloading {VISION_MODEL['name']}...")
        print(f"       This may take several minutes depending on your connection...")
        
        MODELS_DIR.mkdir(parents=True, exist_ok=True)
        
        try:
            # Download processor and model
            processor = AutoProcessor.from_pretrained(VISION_MODEL["name"], trust_remote_code=True)
            model = AutoModelForVision2Seq.from_pretrained(
                VISION_MODEL["name"], 
                trust_remote_code=True,
                torch_dtype="auto"
            )
            
            # Save locally
            processor.save_pretrained(local_path)
            model.save_pretrained(local_path)
            
            print(f"[OK] Vision model downloaded to {local_path}")
        except Exception as e:
            print(f"[ERROR] Failed to download vision model: {e}")
            print("[INFO] Note: LFM models require the latest transformers library")
            raise
    
    def load_vision_model(self):
        """Load the vision model into memory."""
        from transformers import AutoProcessor, AutoModelForVision2Seq
        import torch
        
        local_path = VISION_MODEL["local_path"]
        
        if not local_path.exists():
            self.download_vision_model()
        
        print(f"[INFO] Loading vision model from {local_path}...")
        
        try:
            self.vision_processor = AutoProcessor.from_pretrained(
                local_path,
                trust_remote_code=True,
                local_files_only=True
            )
            self.vision_model = AutoModelForVision2Seq.from_pretrained(
                local_path,
                trust_remote_code=True,
                local_files_only=True,
                torch_dtype="auto"
            )
            self.vision_model.to(self.device)
            self.vision_model.eval()
            
            print(f"[OK] Vision model loaded successfully")
        except Exception as e:
            print(f"[ERROR] Failed to load vision model: {e}")
            print("[INFO] Attempting to re-download...")
            self.download_vision_model(force=True)
            self.vision_processor = AutoProcessor.from_pretrained(
                local_path, trust_remote_code=True, local_files_only=True
            )
            self.vision_model = AutoModelForVision2Seq.from_pretrained(
                local_path, trust_remote_code=True, local_files_only=True
            )
            self.vision_model.to(self.device)
            self.vision_model.eval()
    
    def generate_embeddings(self, texts: List[str]) -> List[List[float]]:
        """Generate embeddings for given texts."""
        import torch
        
        if self.embedding_model is None:
            self.load_embedding_model()
        
        # Nomic specific: add task prefix for document/query
        # For now, treat all as documents
        texts = [f"search_document: {t}" for t in texts]
        
        embeddings = []
        batch_size = 8  # Process in batches to avoid OOM
        
        with torch.no_grad():
            for i in range(0, len(texts), batch_size):
                batch = texts[i:i + batch_size]
                
                # Tokenize
                encoded = self.embedding_tokenizer(
                    batch,
                    padding=True,
                    truncation=True,
                    return_tensors="pt",
                    max_length=EMBEDDING_MODEL["max_length"]
                )
                encoded = {k: v.to(self.device) for k, v in encoded.items()}
                
                # Generate embeddings
                model_output = self.embedding_model(**encoded)
                
                # Mean pooling
                attention_mask = encoded["attention_mask"]
                token_embeddings = model_output[0]
                input_mask_expanded = attention_mask.unsqueeze(-1).float()
                sum_embeddings = (token_embeddings * input_mask_expanded).sum(dim=1)
                embeddings_batch = sum_embeddings / input_mask_expanded.sum(dim=1).clamp(min=1e-9)
                
                # Normalize
                embeddings_batch = torch.nn.functional.normalize(embeddings_batch, p=2, dim=1)
                
                embeddings.extend(embeddings_batch.cpu().numpy().tolist())
        
        return embeddings
    
    def vision_chat(self, messages: List[Dict[str, Any]]) -> str:
        """Chat with the vision model."""
        import torch
        from PIL import Image
        
        if self.vision_model is None:
            self.load_vision_model()
        
        # Extract images and text from messages
        images = []
        text_parts = []
        
        for msg in messages:
            content = msg.get("content", "")
            if isinstance(content, list):
                for item in content:
                    if item.get("type") == "image_url":
                        image_url = item.get("image_url", {}).get("url", "")
                        if image_url.startswith("data:image"):
                            # Base64 encoded image
                            image_data = image_url.split(",")[1]
                            image_bytes = base64.b64decode(image_data)
                            image = Image.open(io.BytesIO(image_bytes)).convert("RGB")
                            images.append(image)
                    elif item.get("type") == "text":
                        text_parts.append(item.get("text", ""))
            else:
                text_parts.append(content)
        
        text = " ".join(text_parts)
        
        # Process inputs
        if images:
            inputs = self.vision_processor(
                text=text,
                images=images[0] if len(images) == 1 else images,
                return_tensors="pt"
            )
        else:
            inputs = self.vision_processor(
                text=text,
                return_tensors="pt"
            )
        
        inputs = {k: v.to(self.device) for k, v in inputs.items()}
        
        # Generate response
        with torch.no_grad():
            outputs = self.vision_model.generate(
                **inputs,
                max_new_tokens=512,
                do_sample=True,
                temperature=0.7,
                top_p=0.9,
            )
        
        response = self.vision_processor.decode(outputs[0], skip_special_tokens=True)
        return response


# ============================================================================
# HTTP Server
# ============================================================================

from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import parse_qs, urlparse
from datetime import datetime


class ModelServerHandler(BaseHTTPRequestHandler):
    """HTTP request handler for the local model server."""
    
    model_manager: Optional[ModelManager] = None
    
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
            self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
            self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization")
            self.send_header("Access-Control-Allow-Credentials", "true")
        self.end_headers()
        self.wfile.write(json.dumps(data).encode())
    
    def do_OPTIONS(self):
        origin = self._get_origin()
        self.send_response(200)
        if self._is_allowed_origin(origin):
            self.send_header("Access-Control-Allow-Origin", origin if origin else "http://localhost:3000")
            self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
            self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization")
            self.send_header("Access-Control-Allow-Credentials", "true")
        self.end_headers()
    
    def do_GET(self):
        parsed = urlparse(self.path)
        path = parsed.path
        
        # Health check
        if path == "/health" or path == "/v1/models":
            self.send_json_response({
                "status": "ok",
                "timestamp": datetime.now().isoformat(),
                "models": [
                    {
                        "id": "nomic-embed-text-v1.5",
                        "object": "model",
                        "owned_by": "local",
                        "type": "embeddings"
                    },
                    {
                        "id": "lfm-2-vision-450m",
                        "object": "model",
                        "owned_by": "local",
                        "type": "chat"
                    }
                ]
            })
            return
        
        self.send_json_response({"error": "Not found"}, 404)
    
    def do_POST(self):
        parsed = urlparse(self.path)
        path = parsed.path
        
        content_length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(content_length).decode()
        data = json.loads(body) if body else {}
        
        # OpenAI-compatible embeddings endpoint
        if path == "/v1/embeddings":
            try:
                input_texts = data.get("input", [])
                if isinstance(input_texts, str):
                    input_texts = [input_texts]
                
                if not input_texts:
                    self.send_json_response({"error": "No input provided"}, 400)
                    return
                
                # Generate embeddings
                embeddings = self.model_manager.generate_embeddings(input_texts)
                
                # Format response (OpenAI compatible)
                response = {
                    "object": "list",
                    "data": [
                        {
                            "object": "embedding",
                            "embedding": emb,
                            "index": i
                        }
                        for i, emb in enumerate(embeddings)
                    ],
                    "model": data.get("model", "nomic-embed-text-v1.5"),
                    "usage": {
                        "prompt_tokens": sum(len(t.split()) for t in input_texts),
                        "total_tokens": sum(len(t.split()) for t in input_texts)
                    }
                }
                
                self.send_json_response(response)
            except Exception as e:
                print(f"[ERROR] Embedding generation failed: {e}")
                import traceback
                traceback.print_exc()
                self.send_json_response({"error": str(e)}, 500)
            return
        
        # OpenAI-compatible chat completions endpoint
        if path == "/v1/chat/completions":
            try:
                messages = data.get("messages", [])
                
                if not messages:
                    self.send_json_response({"error": "No messages provided"}, 400)
                    return
                
                # Generate response
                response_text = self.model_manager.vision_chat(messages)
                
                # Format response (OpenAI compatible)
                response = {
                    "id": f"chatcmpl-{int(time.time())}",
                    "object": "chat.completion",
                    "created": int(time.time()),
                    "model": data.get("model", "lfm-2-vision-450m"),
                    "choices": [
                        {
                            "index": 0,
                            "message": {
                                "role": "assistant",
                                "content": response_text
                            },
                            "finish_reason": "stop"
                        }
                    ],
                    "usage": {
                        "prompt_tokens": 0,
                        "completion_tokens": 0,
                        "total_tokens": 0
                    }
                }
                
                self.send_json_response(response)
            except Exception as e:
                print(f"[ERROR] Chat completion failed: {e}")
                import traceback
                traceback.print_exc()
                self.send_json_response({"error": str(e)}, 500)
            return
        
        self.send_json_response({"error": "Not found"}, 404)


# ============================================================================
# Main
# ============================================================================

def main():
    """Main entry point."""
    print("=" * 70)
    print("Local Model Server")
    print("=" * 70)
    print()
    
    # Check and install dependencies
    check_and_install_dependencies()
    print()
    
    # Initialize model manager
    manager = ModelManager()
    ModelServerHandler.model_manager = manager
    
    # Download models if needed
    print("[INFO] Checking models...")
    print()
    
    try:
        manager.download_embedding_model()
        manager.download_vision_model()
    except KeyboardInterrupt:
        print("\n[INFO] Download interrupted by user")
        sys.exit(0)
    except Exception as e:
        print(f"[ERROR] Failed to download models: {e}")
        sys.exit(1)
    
    print()
    
    # Pre-load models
    print("[INFO] Pre-loading models into memory...")
    print("       (This may take a moment...)")
    try:
        manager.load_embedding_model()
        manager.load_vision_model()
    except Exception as e:
        print(f"[ERROR] Failed to load models: {e}")
        sys.exit(1)
    
    print()
    print("=" * 70)
    print(f"Server ready at http://{SERVER_HOST}:{SERVER_PORT}")
    print("=" * 70)
    print()
    print("Available endpoints:")
    print(f"  Health:      GET  http://{SERVER_HOST}:{SERVER_PORT}/health")
    print(f"  Models:      GET  http://{SERVER_HOST}:{SERVER_PORT}/v1/models")
    print(f"  Embeddings:  POST http://{SERVER_HOST}:{SERVER_PORT}/v1/embeddings")
    print(f"  Chat:        POST http://{SERVER_HOST}:{SERVER_PORT}/v1/chat/completions")
    print()
    print("Press Ctrl+C to stop")
    print("-" * 70)
    print()
    
    # Start server
    server = HTTPServer((SERVER_HOST, SERVER_PORT), ModelServerHandler)
    
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n[INFO] Shutting down...")
        server.shutdown()


if __name__ == "__main__":
    main()
