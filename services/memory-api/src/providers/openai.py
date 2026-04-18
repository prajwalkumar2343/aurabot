"""
OpenAI-compatible client for LLM and embeddings.
Works with OpenAI, Cerebras, Groq, and other OpenAI-compatible APIs.
"""

import os
import requests
from typing import List, Dict, Any, Optional


class OpenAICompatibleClient:
    """Client for OpenAI-compatible APIs."""

    def __init__(self, base_url: str, api_key: str = None, default_model: str = None):
        self.base_url = base_url.rstrip("/")
        self.api_key = api_key or os.getenv("OPENAI_API_KEY", "")
        self.default_model = default_model

    def chat(
        self,
        messages: List[Dict[str, str]],
        max_tokens: int = 512,
        temperature: float = 0.7,
        model: str = None,
    ) -> str:
        """Send chat completion request."""
        url = f"{self.base_url}/chat/completions"

        headers = {"Content-Type": "application/json"}
        if self.api_key:
            headers["Authorization"] = f"Bearer {self.api_key}"

        payload = {
            "model": model or self.default_model or "gpt-4",
            "messages": messages,
            "max_tokens": max_tokens,
            "temperature": temperature,
        }

        try:
            response = requests.post(url, headers=headers, json=payload, timeout=120)
            response.raise_for_status()
            result = response.json()
            return result["choices"][0]["message"]["content"]
        except requests.exceptions.HTTPError as e:
            raise Exception(f"Chat completion HTTP error: {e.response.text}")
        except Exception as e:
            raise Exception(f"Chat completion failed: {e}")

    def embed(self, texts: List[str], model: str = None) -> List[List[float]]:
        """Get embeddings."""
        url = f"{self.base_url}/embeddings"

        headers = {"Content-Type": "application/json"}
        if self.api_key:
            headers["Authorization"] = f"Bearer {self.api_key}"

        payload = {
            "model": model or self.default_model or "text-embedding-ada-002",
            "input": texts,
        }

        try:
            response = requests.post(url, headers=headers, json=payload, timeout=30)
            response.raise_for_status()
            result = response.json()
            return [item["embedding"] for item in result["data"]]
        except requests.exceptions.HTTPError as e:
            raise Exception(f"Embedding HTTP error: {e.response.text}")
        except Exception as e:
            raise Exception(f"Embedding failed: {e}")


def get_openai_client(
    provider: str = None, base_url: str = None, api_key: str = None, model: str = None
) -> OpenAICompatibleClient:
    """Create an OpenAI-compatible client based on provider."""

    provider_configs = {
        "openai": {
            "base_url": "https://api.openai.com/v1",
            "default_model": "gpt-4o",
        },
        "cerebras": {
            "base_url": "https://api.cerebras.ai/v1",
            "default_model": "llama-3.3-70b",
        },
        "groq": {
            "base_url": "https://api.groq.com/openai/v1",
            "default_model": "llama-3.3-70b-versatile",
        },
        "gemini": {
            "base_url": "https://generativelanguage.googleapis.com/v1beta",
            "default_model": "gemini-2.0-flash",
        },
    }

    if provider and provider in provider_configs:
        config = provider_configs[provider]
        base_url = base_url or config["base_url"]
        model = model or config.get("default_model")

    if not base_url:
        raise ValueError("base_url is required for OpenAI-compatible client")

    return OpenAICompatibleClient(base_url, api_key, model)
