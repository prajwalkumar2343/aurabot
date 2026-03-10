#!/usr/bin/env python3
"""
Mem0 REST API Server with dual LLM setup:
- Cerebras API: For chat/LLM responses (fast, high-quality)
- LM Studio (LFM2): For memory classification (local, privacy)
- LM Studio: For embeddings (local)
"""

import sys
from http.server import HTTPServer

from config import HOST, PORT
from core.patching import apply_patches
from core.server_memory import init_server_memory
from api.server_handlers import Mem0Handler

def main():
    print("="*70)
    print("Mem0 Server: Cerebras (Chat) + LM Studio (Classification + Embeddings)")
    print("="*70)

    # Apply required monkey patches
    apply_patches()

    # Initialize memory
    memory = init_server_memory()
    
    # Configure handler
    Mem0Handler.memory = memory

    print(f"[OK] Server starting on http://{HOST}:{PORT}")
    print()

    server = HTTPServer((HOST, PORT), Mem0Handler)
    print("-" * 60)
    print("Available endpoints:")
    print(f"  Health:  GET  http://{HOST}:{PORT}/health")
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
