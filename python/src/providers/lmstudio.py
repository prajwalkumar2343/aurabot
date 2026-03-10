"""
LM Studio client for LLM and embeddings.
"""

import os
import requests
from typing import List, Dict, Any, Optional


class LMStudioClient:
    """Client for LM Studio API."""

    def __init__(self, base_url: str):
        self.base_url = base_url.rstrip("/")
        self.models = []
        self.lfm2_model = None
        self.embedding_model = None

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

            # Detect LFM2 model
            for m in self.models:
                model_id = m.get("id", "").lower()
                if "lfm" in model_id or "350m" in model_id:
                    self.lfm2_model = m["id"]
                    break

            # Use first model if LFM2 not detected
            if not self.lfm2_model and self.models:
                self.lfm2_model = self.models[0]["id"]

            # Check for embedding model
            for m in self.models:
                model_id = m.get("id", "").lower()
                if any(x in model_id for x in ["embed", "nomic", "gemma"]):
                    self.embedding_model = m["id"]
                    break

            return True

        except requests.exceptions.ConnectionError:
            return False
        except Exception:
            return False

    def chat(
        self,
        messages: List[Dict[str, str]],
        max_tokens: int = 512,
        temperature: float = 0.7,
    ) -> str:
        """Send chat completion request to LM Studio."""
        url = f"{self.base_url}/chat/completions"

        payload = {
            "model": self.lfm2_model or "local-model",
            "messages": messages,
            "max_tokens": max_tokens,
            "temperature": temperature,
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
