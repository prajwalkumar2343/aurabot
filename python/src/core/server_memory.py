import sys
from config import CEREBRAS_API_KEY, LM_STUDIO_URL

def init_server_memory():
    try:
        from mem0 import Memory
    except ImportError:
        print("ERROR: mem0ai not installed. Run: pip install mem0ai")
        sys.exit(1)

    print()
    print("Configuring Mem0...")

    if not CEREBRAS_API_KEY:
        print("[WARN] CEREBRAS_API_KEY not set. Falling back to LM Studio for LLM.")
        print("       Get your API key from: https://cloud.cerebras.ai")
        print()

    config = {
        "vector_store": {
            "provider": "qdrant",
            "config": {
                "collection_name": "screen_memories_v3",
                "embedding_model_dims": 768,
                "path": "./qdrant_storage",
            }
        },
        "embedder": {
            "provider": "openai",
            "config": {
                "model": "text-embedding-embeddinggemma-300m",
                "api_key": "not-needed",
                "openai_base_url": LM_STUDIO_URL,
            }
        },
        "llm": {
            "provider": "openai",
            "config": {
                "model": "llama3.1-70b",
                "api_key": CEREBRAS_API_KEY if CEREBRAS_API_KEY else "not-needed",
                "openai_base_url": "https://api.cerebras.ai/v1" if CEREBRAS_API_KEY else LM_STUDIO_URL,
                "temperature": 0.7,
                "max_tokens": 4096,
            }
        },
    }

    try:
        memory = Memory.from_config(config_dict=config)
        print("[OK] Mem0 initialized successfully")
        print(f"     LLM: {'Cerebras (llama3.1-70b)' if CEREBRAS_API_KEY else 'LM Studio (local)'}")
        print(f"     Embeddings: LM Studio (text-embedding-embeddinggemma-300m)")
        print(f"     Vector Store: Qdrant (./qdrant_storage)")
        return memory
    except Exception as e:
        print(f"[FAIL] Failed to initialize Mem0: {e}")
        sys.exit(1)
