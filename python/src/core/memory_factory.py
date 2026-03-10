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

from config import CEREBRAS_API_KEY, LM_STUDIO_URL


def create_memory_config(
    collection_name: str = "screen_memories_v3",
    embedder_model: str = "text-embedding-embeddinggemma-300m",
    llm_model: str = "llama3.1-70b",
    embedder_dims: int = 768,
    llm_provider: str = "openai",
) -> dict:
    """
    Create memory configuration dict.

    Args:
        collection_name: Qdrant collection name
        embedder_model: Embedding model name
        llm_model: LLM model name
        embedder_dims: Embedding dimensions
        llm_provider: LLM provider type

    Returns:
        Memory configuration dict
    """
    if llm_provider == "cerebras":
        llm_base_url = "https://api.cerebras.ai/v1"
        llm_api_key = CEREBRAS_API_KEY
    else:
        llm_base_url = LM_STUDIO_URL
        llm_api_key = "not-needed" if not CEREBRAS_API_KEY else CEREBRAS_API_KEY

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
                "api_key": "not-needed",
                "openai_base_url": LM_STUDIO_URL,
            },
        },
        "llm": {
            "provider": "openai",
            "config": {
                "model": llm_model,
                "api_key": llm_api_key,
                "openai_base_url": llm_base_url,
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
    print("Configuring Mem0...")

    if not CEREBRAS_API_KEY:
        print("[WARN] CEREBRAS_API_KEY not set. Falling back to LM Studio for LLM.")
        print("       Get your API key from: https://cloud.cerebras.ai")
        print()

    config = create_memory_config()

    try:
        memory = Memory.from_config(config_dict=config)
        print("[OK] Mem0 initialized successfully")
        print(
            f"     LLM: {'Cerebras (llama3.1-70b)' if CEREBRAS_API_KEY else 'LM Studio (local)'}"
        )
        print(f"     Embeddings: LM Studio (text-embedding-embeddinggemma-300m)")
        print(f"     Vector Store: Qdrant (./qdrant_storage)")
        return memory
    except Exception as e:
        print(f"[FAIL] Failed to initialize Mem0: {e}")
        sys.exit(1)


def init_local_memory(model_manager, host: str, port: int):
    """Initialize Mem0 with local models."""
    if not HAS_MEM0:
        return None, False

    print()
    print("Configuring Mem0 with local models...")

    model_manager.load_embedding_model()
    model_manager.load_llm_model()

    config = create_memory_config(
        collection_name="screen_memories",
        embedder_model="nomic-embed-text-v1.5",
        llm_model="lfm-2-vision-450m",
        llm_provider="local",
    )
    config["embedder"]["config"]["openai_base_url"] = f"http://{host}:{port}/v1"
    config["llm"]["config"]["openai_base_url"] = f"http://{host}:{port}/v1"

    try:
        memory = Memory.from_config(config_dict=config)
        print("[OK] Mem0 initialized successfully")
        return memory, True
    except Exception as e:
        print(f"[WARN] Failed to initialize Mem0: {e}")
        print("       Running in API-only mode")
        return None, False
