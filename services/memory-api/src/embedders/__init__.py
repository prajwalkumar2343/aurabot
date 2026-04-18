"""
Shared embedder classes.
"""

from .local import LocalEmbedder
from .remote import RemoteEmbedder

__all__ = ["LocalEmbedder", "RemoteEmbedder"]


def get_embedder(provider: str, config: dict):
    """Factory function to get the appropriate embedder."""
    if provider == "local":
        return LocalEmbedder(config)
    else:
        return RemoteEmbedder(config)
