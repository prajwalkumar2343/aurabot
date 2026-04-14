"""
LM Studio client for LLM and embeddings.
Compatible with any model loaded in LM Studio.
"""

import os
import requests
from typing import List, Dict, Any, Optional


class LMStudioClient:
    """Client for LM Studio OpenAI-compatible API."""

    def __init__(self, base_url: str):
        self.base_url = base_url.rstrip("/")
        self.models: List[Dict[str, Any]] = []
        self.chat_model: Optional[str] = None
        self.embedding_model: Optional[str] = None
        self.embedding_dims: int = 768

    def connect(self) -> bool:
        """Connect to LM Studio and detect models."""
        try:
            resp = requests.get(f"{self.base_url}/models", timeout=10)
            if resp.status_code != 200:
                return False

            data = resp.json()
            self.models = data.get("data", [])

            if not self.models:
                return False

            # Auto-detect chat model: prefer non-embedding models, fallback to first
            non_embedding_models = [
                m for m in self.models
                if not any(k in m.get("id", "").lower() for k in ("embed", "nomic", "gte", "bge"))
            ]
            self.chat_model = (non_embedding_models[0] if non_embedding_models else self.models[0]).get("id")

            # Auto-detect embedding model: look for known embedding keywords
            for m in self.models:
                model_id = m.get("id", "").lower()
                if any(k in model_id for k in ("embed", "nomic", "gte", "bge", "gemma")):
                    self.embedding_model = m["id"]
                    break

            # If no dedicated embedding model, use first model (many LM Studio versions support embeddings on any model)
            if not self.embedding_model and self.models:
                self.embedding_model = self.models[0]["id"]

            # Detect embedding dimensions dynamically
            self._detect_embedding_dims()

            return True

        except requests.exceptions.ConnectionError:
            return False
        except Exception:
            return False

    def _detect_embedding_dims(self) -> None:
        """Probe embedding dimensions by making a test embedding request."""
        if not self.embedding_model:
            return
        try:
            resp = requests.post(
                f"{self.base_url}/embeddings",
                json={"model": self.embedding_model, "input": "test"},
                timeout=15,
            )
            if resp.status_code == 200:
                data = resp.json()
                emb = data.get("data", [{}])[0].get("embedding", [])
                if emb:
                    self.embedding_dims = len(emb)
        except Exception:
            pass

    def get_info(self) -> Dict[str, Any]:
        """Return current connection info."""
        return {
            "base_url": self.base_url,
            "chat_model": self.chat_model,
            "embedding_model": self.embedding_model,
            "embedding_dims": self.embedding_dims,
            "available_models": [m.get("id") for m in self.models],
        }

    def chat(
        self,
        messages: List[Dict[str, str]],
        max_tokens: int = 512,
        temperature: float = 0.7,
        stream: bool = False,
    ) -> str:
        """Send chat completion request to LM Studio."""
        url = f"{self.base_url}/chat/completions"

        payload = {
            "model": self.chat_model or "local-model",
            "messages": messages,
            "max_tokens": max_tokens,
            "temperature": temperature,
            "stream": stream,
        }

        try:
            response = requests.post(url, json=payload, timeout=120)
            response.raise_for_status()
            result = response.json()
            return result["choices"][0]["message"]["content"]
        except Exception as e:
            raise Exception(f"Chat completion failed: {e}")

    def embed(self, texts: List[str]) -> List[List[float]]:
        """Get embeddings from LM Studio."""
        if not self.embedding_model:
            raise Exception("No embedding model available in LM Studio")

        url = f"{self.base_url}/embeddings"
        embeddings = []

        for text in texts:
            payload = {"model": self.embedding_model, "input": text}
            try:
                response = requests.post(url, json=payload, timeout=30)
                response.raise_for_status()
                result = response.json()
                embeddings.append(result["data"][0]["embedding"])
            except Exception as e:
                raise Exception(f"Embedding failed: {e}")

        return embeddings


def get_lmstudio_client(base_url: str = None) -> LMStudioClient:
    """Create and connect an LM Studio client."""
    if base_url is None:
        base_url = os.getenv("LM_STUDIO_URL", "http://localhost:1234/v1")

    client = LMStudioClient(base_url)
    if not client.connect():
        raise Exception(f"Cannot connect to LM Studio at {base_url}")

    return client
