from typing import List, Dict, Any

try:
    from mem0 import Memory
    HAS_MEM0 = True
except ImportError:
    print("[WARN] mem0ai not installed. Running in API-only mode.")
    print("       To use Mem0 features: pip install mem0ai")
    HAS_MEM0 = False
    Memory = None

class LocalEmbedderWrapper:
    """Local embedding provider for Mem0."""
    def __init__(self, model_manager):
        self.model_manager = model_manager
    
    def embed(self, text: str, memory_type: str = "text") -> List[float]:
        result = self.model_manager.embed([text])
        return result[0] if result else []

class LocalLLMWrapper:
    """Local LLM provider for Mem0."""
    def __init__(self, model_manager):
        self.model_manager = model_manager

    def generate(self, messages: List[Dict[str, Any]], **kwargs) -> str:
        return self.model_manager.chat(messages, max_tokens=kwargs.get('max_tokens', 512))

def init_mem0(model_manager, host: str, port: int):
    """Initialize Mem0 with local models."""
    if not HAS_MEM0:
        return None, False

    print()
    print("Configuring Mem0 with local models...")
    
    model_manager.load_embedding_model()
    model_manager.load_llm_model()
    
    config = {
        "vector_store": {
            "provider": "qdrant",
            "config": {
                "collection_name": "screen_memories",
                "embedding_model_dims": 768,
                "path": "./qdrant_storage",
            }
        },
        "embedder": {
            "provider": "openai",
            "config": {
                "model": "nomic-embed-text-v1.5",
                "api_key": "local",
                "openai_base_url": f"http://{host}:{port}/v1",
            }
        },
        "llm": {
            "provider": "openai",
            "config": {
                "model": "lfm-2-vision-450m",
                "api_key": "local",
                "openai_base_url": f"http://{host}:{port}/v1",
                "temperature": 0.7,
                "max_tokens": 512,
            }
        },
    }
    
    try:
        memory = Memory.from_config(config_dict=config)
        print("[OK] Mem0 initialized successfully")
        return memory, True
    except Exception as e:
        print(f"[WARN] Failed to initialize Mem0: {e}")
        print("       Running in API-only mode")
        return None, False
