import sys
from config import CEREBRAS_API_KEY, LM_STUDIO_URL


def _probe_lm_studio() -> dict:
    """Probe LM Studio for loaded models and embedding dimensions."""
    import requests

    info = {"available": False, "chat_model": None, "embedding_model": None, "embedding_dims": 768}
    try:
        resp = requests.get(f"{LM_STUDIO_URL}/models", timeout=5)
        if resp.status_code != 200:
            return info

        data = resp.json()
        models = data.get("data", [])
        if not models:
            return info

        info["available"] = True

        # Pick chat model: prefer non-embedding
        non_emb = [
            m for m in models
            if not any(k in m.get("id", "").lower() for k in ("embed", "nomic", "gte", "bge"))
        ]
        info["chat_model"] = (non_emb[0] if non_emb else models[0]).get("id")

        # Pick embedding model
        for m in models:
            mid = m.get("id", "").lower()
            if any(k in mid for k in ("embed", "nomic", "gte", "bge", "gemma")):
                info["embedding_model"] = m["id"]
                break
        if not info["embedding_model"]:
            info["embedding_model"] = models[0]["id"]

        # Detect embedding dimensions
        try:
            emb_resp = requests.post(
                f"{LM_STUDIO_URL}/embeddings",
                json={"model": info["embedding_model"], "input": "test"},
                timeout=10,
            )
            if emb_resp.status_code == 200:
                emb = emb_resp.json().get("data", [{}])[0].get("embedding", [])
                if emb:
                    info["embedding_dims"] = len(emb)
        except Exception:
            pass

    except Exception:
        pass

    return info


def init_server_memory():
    try:
        from mem0 import Memory
    except ImportError:
        print("ERROR: mem0ai not installed. Run: pip install mem0ai")
        sys.exit(1)

    print()
    print("Configuring Mem0...")

    lm_info = _probe_lm_studio()

    if not CEREBRAS_API_KEY:
        print("[WARN] CEREBRAS_API_KEY not set. Falling back to LM Studio for LLM.")
        print("       Get your API key from: https://cloud.cerebras.ai")
        print()

        if not lm_info["available"]:
            print(f"[FAIL] Cannot connect to LM Studio at {LM_STUDIO_URL}")
            print("       Please start LM Studio and load a model.")
            sys.exit(1)

    chat_model = "llama3.1-70b"
    chat_base_url = "https://api.cerebras.ai/v1"
    chat_api_key = CEREBRAS_API_KEY

    if not CEREBRAS_API_KEY and lm_info["available"]:
        chat_model = lm_info["chat_model"] or "local-model"
        chat_base_url = LM_STUDIO_URL
        chat_api_key = "not-needed"

    embed_model = lm_info["embedding_model"] or "text-embedding-embeddinggemma-300m"
    embed_base_url = LM_STUDIO_URL if lm_info["available"] else chat_base_url
    embed_api_key = "not-needed" if lm_info["available"] else CEREBRAS_API_KEY
    embed_dims = lm_info["embedding_dims"] if lm_info["available"] else 768

    config = {
        "vector_store": {
            "provider": "qdrant",
            "config": {
                "collection_name": "screen_memories_v3",
                "embedding_model_dims": embed_dims,
                "path": "./qdrant_storage",
            }
        },
        "embedder": {
            "provider": "openai",
            "config": {
                "model": embed_model,
                "api_key": embed_api_key,
                "openai_base_url": embed_base_url,
            }
        },
        "llm": {
            "provider": "openai",
            "config": {
                "model": chat_model,
                "api_key": chat_api_key,
                "openai_base_url": chat_base_url,
                "temperature": 0.7,
                "max_tokens": 4096,
            }
        },
    }

    try:
        memory = Memory.from_config(config_dict=config)
        print("[OK] Mem0 initialized successfully")
        if CEREBRAS_API_KEY:
            print(f"     LLM: Cerebras (llama3.1-70b)")
        else:
            print(f"     LLM: LM Studio ({chat_model})")
        print(f"     Embeddings: {'LM Studio' if lm_info['available'] else 'OpenRouter'} ({embed_model}, dims={embed_dims})")
        print(f"     Vector Store: Qdrant (./qdrant_storage)")
        return memory
    except Exception as e:
        print(f"[FAIL] Failed to initialize Mem0: {e}")
        sys.exit(1)
