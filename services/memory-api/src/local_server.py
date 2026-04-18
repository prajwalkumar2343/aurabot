#!/usr/bin/env python3
"""
Local server entry point for fully offline operation.

Uses local models (no external dependencies):
- Embedding model: nomic-embed-text-v1.5
- LLM model: lfm-2-vision-450m
"""

import sys
from http.server import HTTPServer

from config import HOST, PORT, MODELS_DIR
from models.local_manager import LocalModelManager
from core.memory_factory import init_local_memory
from api.handlers import MemoryHandler


def main():
    """Main entry point for local server."""

    embedding_path = MODELS_DIR / "embeddinggemma-300m-f8"
    llm_path = MODELS_DIR / "lfm-2-vision-450m"

    if not embedding_path.exists() or not llm_path.exists():
        print("[ERROR] Models not found!")
        print()
        print("Please download the models first:")
        print("  python download_models.py")
        print()
        sys.exit(1)

    print("=" * 70)
    print("AuraBot Memory API Server (Local Models)")
    print("=" * 70)
    print()

    model_manager = LocalModelManager()
    memory, has_memory = init_local_memory(model_manager, HOST, PORT)

    MemoryHandler.model_manager = model_manager
    MemoryHandler.memory = memory
    MemoryHandler.HAS_MEMORY = has_memory

    print("-" * 70)
    print("Available endpoints:")
    print(f"  Health:      GET  http://{HOST}:{PORT}/health")
    print(f"  Models:      GET  http://{HOST}:{PORT}/v1/models")
    print(f"  Embeddings:  POST http://{HOST}:{PORT}/v1/embeddings")
    print(f"  Chat:        POST http://{HOST}:{PORT}/v1/chat/completions")
    if has_memory:
        print(f"  Memories:    GET  http://{HOST}:{PORT}/v1/memories/")
        print(f"  Add Memory:  POST http://{HOST}:{PORT}/v1/memories/")
        print(f"  Search:      POST http://{HOST}:{PORT}/v1/memories/search/")
    print("-" * 70)
    print()
    print("Press Ctrl+C to stop")
    print()

    server = HTTPServer((HOST, PORT), MemoryHandler)

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n[INFO] Shutting down...")
        server.shutdown()


if __name__ == "__main__":
    main()
