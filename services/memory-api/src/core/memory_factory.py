import sys

from config import (
    DATABASE_URL,
    OPENROUTER_API_KEY,
    OPENROUTER_EMBEDDING_DIMENSIONS,
)
from core.postgres_memory import PostgresMemoryStore


def init_server_memory(
    model_manager,
    embedding_dimensions: int = OPENROUTER_EMBEDDING_DIMENSIONS,
    require_openrouter_key: bool = True,
):
    """Initialize the Postgres-backed memory store."""
    print()
    print("Configuring memory store...")

    if require_openrouter_key and not OPENROUTER_API_KEY:
        print("[FAIL] OPENROUTER_API_KEY is not configured.")
        print("       Set it in the environment or save it in ~/.aurabot/config.json")
        sys.exit(1)

    try:
        memory = PostgresMemoryStore(
            database_url=DATABASE_URL,
            embedding_dimensions=embedding_dimensions,
            embedder=model_manager.embed,
        )
        info = memory.info()
        print("[OK] Memory store initialized successfully")
        print(f"     Backend: {info.backend}")
        print(f"     Vector Store: {info.vector_store}")
        print(f"     Database: {info.database_url}")
        return memory
    except Exception as e:
        print(f"[FAIL] Failed to initialize memory store: {e}")
        sys.exit(1)


def init_local_memory(model_manager, host: str, port: int):
    """Initialize the memory store with local embeddings."""
    del host, port
    return init_server_memory(
        model_manager,
        embedding_dimensions=768,
        require_openrouter_key=False,
    ), True
