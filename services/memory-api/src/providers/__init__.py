"""
Shared LLM provider clients.
"""

from .ollama import OllamaClient
from .openai import OpenAICompatibleClient

__all__ = ["OllamaClient", "OpenAICompatibleClient"]
