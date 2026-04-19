"""
Embeddings mixin for HTTP handlers.
Provides embeddings endpoint: create embeddings from text.
"""

from api.base_handler import RequestBodyError
from config import MAX_EMBEDDING_INPUTS, MAX_TEXT_CHARS


class EmbeddingsMixin:
    """Mixin providing embeddings endpoint handler."""

    model_manager = None

    def create_embeddings(self):
        """Handle POST /v1/embeddings"""
        if not self.model_manager:
            self.send_json_response({"error": "Embeddings not available"}, 503)
            return

        try:
            data = self.parse_json_body()
            input_texts = data.get("input", [])

            if isinstance(input_texts, str):
                input_texts = [input_texts]
            if not isinstance(input_texts, list) or not input_texts:
                self.send_json_response({"error": "No input provided"}, 400)
                return
            if len(input_texts) > MAX_EMBEDDING_INPUTS:
                self.send_json_response({"error": "Too many embedding inputs"}, 400)
                return
            if sum(len(str(text)) for text in input_texts) > MAX_TEXT_CHARS:
                self.send_json_response({"error": "Embedding input too large"}, 413)
                return

            embeddings = self.model_manager.embed(input_texts)

            response = {
                "object": "list",
                "data": [
                    {"object": "embedding", "embedding": emb, "index": i}
                    for i, emb in enumerate(embeddings)
                ],
                "model": data.get("model", "nomic-embed-text-v1.5"),
                "usage": {
                    "prompt_tokens": len(input_texts),
                    "total_tokens": len(input_texts),
                },
            }
            self.send_json_response(response)
        except RequestBodyError as e:
            self.send_json_response({"error": str(e)}, e.status)
        except Exception as e:
            self.send_json_response({"error": str(e)}, 500)
