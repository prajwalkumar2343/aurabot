"""
Memory factory for initializing Mem0 with different providers.
"""

import sys

try:
    from mem0 import Memory

    HAS_MEM0 = True
except ImportError:
    HAS_MEM0 = False
    Memory = None

from config import (
    OPENROUTER_API_KEY,
    OPENROUTER_BASE_URL,
    OPENROUTER_CHAT_MODEL,
    OPENROUTER_EMBEDDING_DIMENSIONS,
    OPENROUTER_EMBEDDING_MODEL,
)


def create_memory_config(
    collection_name: str = "screen_memories_v3",
    embedder_model: str = OPENROUTER_EMBEDDING_MODEL,
    llm_model: str = OPENROUTER_CHAT_MODEL,
    embedder_dims: int = OPENROUTER_EMBEDDING_DIMENSIONS,
) -> dict:
    """
    Create memory configuration dict.

    Args:
        collection_name: Qdrant collection name
        embedder_model: Embedding model name
        llm_model: LLM model name
        embedder_dims: Embedding dimensions
    Returns:
        Memory configuration dict
    """
    return {
        "vector_store": {
            "provider": "qdrant",
            "config": {
                "collection_name": collection_name,
                "embedding_model_dims": embedder_dims,
                "path": "./qdrant_storage",
            },
        },
        "embedder": {
            "provider": "openai",
            "config": {
                "model": embedder_model,
                "api_key": OPENROUTER_API_KEY,
                "openai_base_url": OPENROUTER_BASE_URL,
            },
        },
        "llm": {
            "provider": "openai",
            "config": {
                "model": llm_model,
                "api_key": OPENROUTER_API_KEY,
                "openai_base_url": OPENROUTER_BASE_URL,
                "temperature": 0.7,
                "max_tokens": 4096,
            },
        },
    }


def init_server_memory():
    """Initialize Mem0 for server mode (Cerebras/LM Studio)."""
    if not HAS_MEM0:
        print("ERROR: mem0ai not installed. Run: pip install mem0ai")
        sys.exit(1)

    from core.patching import apply_patches

    apply_patches()

    print()
    print("Configuring Mem0 with OpenRouter...")

    if not OPENROUTER_API_KEY:
        print("[FAIL] OPENROUTER_API_KEY is not configured.")
        print("       Set it in the environment or save it in ~/.aurabot/config.json")
        sys.exit(1)

    config = create_memory_config()

    try:
        memory = Memory.from_config(config_dict=config)
        print("[OK] Mem0 initialized successfully")
        print(f"     LLM: OpenRouter ({OPENROUTER_CHAT_MODEL})")
        print(f"     Embeddings: OpenRouter ({OPENROUTER_EMBEDDING_MODEL})")
        print(f"     Vector Store: Qdrant (./qdrant_storage)")
        return memory
    except Exception as e:
        print(f"[FAIL] Failed to initialize Mem0: {e}")
        sys.exit(1)


def init_local_memory(model_manager, host: str, port: int):
    """Initialize Mem0 with local models."""
    del model_manager, host, port
    memory = init_server_memory()
    return memory, True
