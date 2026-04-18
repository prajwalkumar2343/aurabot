#!/usr/bin/env python3
"""
Main entry point for the AuraBot memory API server.

Uses OpenRouter-backed models for chat and embeddings.
"""

from http.server import HTTPServer

from config import HOST, PORT
from core.memory_factory import init_server_memory
from api.handlers import MemoryHandler
from models.remote_manager import RemoteModelManager


def main():
    print("=" * 70)
    print("AuraBot Memory Server: OpenRouter (Chat + Embeddings)")
    print("=" * 70)

    model_manager = RemoteModelManager()
    memory = init_server_memory(model_manager)

    MemoryHandler.memory = memory
    MemoryHandler.model_manager = model_manager
    MemoryHandler.HAS_MEMORY = True

    print(f"[OK] Server starting on http://{HOST}:{PORT}")
    print()

    server = HTTPServer((HOST, PORT), MemoryHandler)
    print("-" * 60)
    print("Available endpoints:")
    print(f"  Health:  GET  http://{HOST}:{PORT}/health")
    print(f"  Models:  GET  http://{HOST}:{PORT}/v1/models")
    print(f"  Embed:   POST http://{HOST}:{PORT}/v1/embeddings")
    print(f"  Chat:    POST http://{HOST}:{PORT}/v1/chat/completions")
    print(f"  Add:     POST http://{HOST}:{PORT}/v1/memories/")
    print(f"  Search:  POST http://{HOST}:{PORT}/v1/memories/search/")
    print(f"  Get All: GET  http://{HOST}:{PORT}/v1/memories/")
    print("-" * 60)
    print("Press Ctrl+C to stop")
    print()

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down...")
        server.shutdown()


if __name__ == "__main__":
    main()
