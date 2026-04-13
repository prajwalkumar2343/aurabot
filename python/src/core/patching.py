import openai
from config import OPENROUTER_BASE_URL, OPENROUTER_EMBEDDING_DIMENSIONS

def apply_patches():
    # Patch Qdrant vector store to handle None vector in update method
    try:
        from mem0.vector_stores.qdrant import Qdrant
        
        _original_qdrant_update = Qdrant.update
        
        def _patched_qdrant_update(self, vector_id, vector=None, payload=None):
            if vector is None:
                self.client.set_payload(
                    collection_name=self.collection_name,
                    payload=payload or {},
                    points=[vector_id],
                )
            else:
                from qdrant_client.models import PointStruct
                point = PointStruct(id=vector_id, vector=vector, payload=payload)
                self.client.upsert(collection_name=self.collection_name, points=[point])
        
        Qdrant.update = _patched_qdrant_update
        print("[INFO] Patched Qdrant vector store to handle None vector in update()")
    except Exception as e:
        print(f"[WARN] Could not patch Qdrant update method: {e}")

    _original_openai_init = openai.OpenAI.__init__

    def _patched_openai_init(self, *args, **kwargs):
        _original_openai_init(self, *args, **kwargs)
        if hasattr(self, 'chat') and hasattr(self.chat, 'completions'):
            orig_create = self.chat.completions.create
            def _patched_create(*args, **kwargs):
                kwargs.pop('store', None)
                if "openrouter.ai" not in OPENROUTER_BASE_URL:
                    kwargs.pop('response_format', None)
                return orig_create(*args, **kwargs)
            self.chat.completions.create = _patched_create
        
        if hasattr(self, 'embeddings') and hasattr(self.embeddings, 'create'):
            orig_embed = self.embeddings.create
            def _patched_embed(*args, **kwargs):
                import time
                max_retries = 3
                input_data = kwargs.get('input', [])
                for attempt in range(max_retries):
                    try:
                        response = orig_embed(*args, **kwargs)
                        if hasattr(response, 'data') and response.data:
                            all_valid = True
                            for i, item in enumerate(response.data):
                                if hasattr(item, 'embedding') and item.embedding and len(item.embedding) > 0:
                                    pass
                                else:
                                    all_valid = False
                            if all_valid:
                                return response
                            else:
                                raise ValueError("One or more embeddings are None/empty")
                        else:
                            raise ValueError("Response has no data")
                    except Exception as e:
                        if attempt < max_retries - 1:
                            time.sleep(0.5 * (attempt + 1))
                        else:
                            from openai.types.create_embedding_response import CreateEmbeddingResponse
                            from openai.types.embedding import Embedding
                            if isinstance(input_data, str):
                                input_data = [input_data]
                            zero_embeddings = []
                            for i, _ in enumerate(input_data):
                                zero_embeddings.append(Embedding(
                                    embedding=[0.0] * OPENROUTER_EMBEDDING_DIMENSIONS,
                                    index=i,
                                    object="embedding"
                                ))
                            return CreateEmbeddingResponse(
                                data=zero_embeddings,
                                model=kwargs.get('model', 'unknown'),
                                object="list",
                                usage={"prompt_tokens": 0, "total_tokens": 0}
                            )
            self.embeddings.create = _patched_embed

    openai.OpenAI.__init__ = _patched_openai_init
    print("[INFO] Patched OpenAI client for AuraBot compatibility")
