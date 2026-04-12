"""
Remote embedder using OpenAI-compatible APIs.
"""

import requests
from typing import List


class RemoteEmbedder:
    """Remote embedding provider using OpenAI-compatible API."""

    def __init__(self, config: dict):
        """
        Initialize with config:
        - base_url: API base URL (e.g., http://localhost:1234/v1)
        - api_key: API key (optional, defaults to "not-needed")
        - model: embedding model name
        """
        self.base_url = config.get("base_url", "")
        self.api_key = config.get("api_key", "not-needed")
        self.model = config.get("model", "local-model")

        if not self.base_url:
            raise ValueError("Remote embedder requires base_url in config")

    def embed(self, texts: List[str]) -> List[List[float]]:
        """Get embeddings from remote API."""
        url = f"{self.base_url}/embeddings"

        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json",
        }

        payload = {
            "model": self.model,
            "input": texts,
        }

        try:
            response = requests.post(url, headers=headers, json=payload, timeout=30)
            response.raise_for_status()
            result = response.json()
            return [item["embedding"] for item in result["data"]]
        except requests.exceptions.ConnectionError:
            raise Exception(
                f"Cannot connect to embedder at {self.base_url}. "
                f"Please ensure the service is running and the URL is correct."
            )
        except Exception as e:
            raise Exception(f"Embedding API error: {e}")

    def is_available(self) -> bool:
        """embedder is availableCheck if the."""
        try:
            # Try a simple embedding to check availability
            self.embed(["test"])
            return True
        except Exception:
            return False
