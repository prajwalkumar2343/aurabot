"""
Remote model manager for OpenRouter-backed chat and embeddings.
"""

from config import (
    OPENROUTER_API_KEY,
    OPENROUTER_BASE_URL,
    OPENROUTER_CHAT_MODEL,
    OPENROUTER_EMBEDDING_MODEL,
)
from providers.openai import get_openai_client


def _normalize_openai_base_url(base_url: str) -> str:
    """Normalize an OpenAI-compatible base URL to include /v1."""
    normalized = base_url.rstrip("/")
    if normalized.endswith("/v1"):
        return normalized
    return f"{normalized}/v1"


class RemoteModelManager:
    """Adapter exposing chat and embed methods for the unified HTTP handler."""

    def __init__(self):
        openrouter_base_url = _normalize_openai_base_url(OPENROUTER_BASE_URL)
        self.embedding_client = get_openai_client(
            base_url=openrouter_base_url,
            api_key=OPENROUTER_API_KEY,
            model=OPENROUTER_EMBEDDING_MODEL,
        )
        self.chat_client = get_openai_client(
            base_url=openrouter_base_url,
            api_key=OPENROUTER_API_KEY,
            model=OPENROUTER_CHAT_MODEL,
        )

    def chat(self, messages, max_tokens: int = 512) -> str:
        """Send a chat request via the configured remote provider."""
        return self.chat_client.chat(messages, max_tokens=max_tokens)

    def embed(self, texts):
        """Send an embeddings request via OpenRouter."""
        return self.embedding_client.embed(texts)
