"""
Local embedder using sentence-transformers.
"""

from pathlib import Path
from typing import List

from config import MODELS_DIR


class LocalEmbedder:
    """Local embedding provider using sentence-transformers."""

    def __init__(self, config: dict = None):
        self.config = config or {}
        self.model = None
        self.device = "cpu"
        self._load_model()

    def _load_model(self):
        """Load the local embedding model."""
        # Try to import torch for CUDA detection
        try:
            import torch

            if torch.cuda.is_available():
                self.device = "cuda"
        except ImportError:
            pass

        model_path = MODELS_DIR / "embeddinggemma-300m"

        if not model_path.exists():
            print(f"[WARN] Embedding model not found at {model_path}")
            print("[INFO] Will use remote embedding provider instead")
            return

        try:
            from sentence_transformers import SentenceTransformer

            print(f"[INFO] Loading embedding model from {model_path}")
            self.model = SentenceTransformer(str(model_path), device=self.device)
            print("[OK] Embedding model loaded")
        except Exception as e:
            print(f"[WARN] Failed to load embedding model: {e}")
            self.model = None

    def embed(self, texts: List[str]) -> List[List[float]]:
        """Get embeddings for texts."""
        if self.model is None:
            raise ValueError(
                "Local embedding model not available. "
                "Please download the model or switch to a remote embedding provider."
            )

        embeddings = self.model.encode(texts, convert_to_numpy=True)
        return embeddings.tolist()

    def is_available(self) -> bool:
        """Check if the embedder is available."""
        return self.model is not None
