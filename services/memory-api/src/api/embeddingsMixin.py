"""
Embeddings mixin for HTTP handlers.
Provides embeddings endpoint: create embeddings from text.
"""


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
            if not input_texts:
                self.send_json_response({"error": "No input provided"}, 400)
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
        except Exception as e:
            self.send_json_response({"error": str(e)}, 500)
