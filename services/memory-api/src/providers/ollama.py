"""
Ollama client for LLM and embeddings.
"""

import os
import requests
from typing import List, Dict, Any


class OllamaClient:
    """Client for Ollama API."""

    def __init__(self, base_url: str):
        self.base_url = base_url.rstrip("/")
        self.model = None
        self.embedding_model = None

    def connect(self, model: str = None, embedding_model: str = None) -> bool:
        """Connect to Ollama and verify models."""
        try:
            # Check if Ollama is running
            resp = requests.get(f"{self.base_url}/api/tags", timeout=10)
            if resp.status_code != 200:
                return False

            data = resp.json()
            models = data.get("models", [])

            if not models:
                return False

            # Use specified model or first available
            if model:
                self.model = model
            elif models:
                self.model = models[0].get("name", "llama2")

            self.embedding_model = embedding_model or "nomic-embed-text"

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
        """Send chat completion request to Ollama."""
        url = f"{self.base_url}/api/generate"

        # Convert messages to prompt
        prompt = "\n".join([f"{m['role']}: {m['content']}" for m in messages])

        payload = {
            "model": self.model or "llama2",
            "prompt": prompt,
            "stream": False,
            "options": {
                "num_predict": max_tokens,
                "temperature": temperature,
            },
        }

        try:
            response = requests.post(url, json=payload, timeout=120)
            response.raise_for_status()
            result = response.json()
            return result.get("response", "").strip()
        except Exception as e:
            raise Exception(f"Ollama chat failed: {e}")

    def embed(self, texts: List[str]) -> List[List[float]]:
        """Get embeddings from Ollama."""
        url = f"{self.base_url}/api/embeddings"

        embeddings = []
        for text in texts:
            payload = {
                "model": self.embedding_model or "nomic-embed-text",
                "prompt": text,
            }
            try:
                response = requests.post(url, json=payload, timeout=30)
                response.raise_for_status()
                result = response.json()
                embeddings.append(result.get("embedding", []))
            except Exception as e:
                raise Exception(f"Ollama embedding failed: {e}")

        return embeddings


def get_ollama_client(
    base_url: str = None, model: str = None, embedding_model: str = None
) -> OllamaClient:
    """Create and connect an Ollama client."""
    if base_url is None:
        base_url = os.getenv("OLLAMA_URL", "http://localhost:11434")

    client = OllamaClient(base_url)
    if not client.connect(model=model, embedding_model=embedding_model):
        raise Exception(f"Cannot connect to Ollama at {base_url}")

    return client
