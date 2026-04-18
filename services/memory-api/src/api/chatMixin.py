"""
Chat mixin for HTTP handlers.
Provides chat completions endpoint: LLM chat responses.
"""

import time


class ChatMixin:
    """Mixin providing chat completions endpoint handler."""

    model_manager = None

    def chat_completions(self):
        """Handle POST /v1/chat/completions"""
        if not self.model_manager:
            self.send_json_response({"error": "Chat not available"}, 503)
            return

        try:
            data = self.parse_json_body()
            messages = data.get("messages", [])
            max_tokens = data.get("max_tokens", 512)

            if not messages:
                self.send_json_response({"error": "No messages provided"}, 400)
                return

            response_text = self.model_manager.chat(messages, max_tokens=max_tokens)

            response = {
                "id": f"chatcmpl-{int(time.time())}",
                "object": "chat.completion",
                "created": int(time.time()),
                "model": data.get("model", "lfm-2-vision-450m"),
                "choices": [
                    {
                        "index": 0,
                        "message": {"role": "assistant", "content": response_text},
                        "finish_reason": "stop",
                    }
                ],
                "usage": {
                    "prompt_tokens": 0,
                    "completion_tokens": 0,
                    "total_tokens": 0,
                },
            }
            self.send_json_response(response)
        except Exception as e:
            self.send_json_response({"error": str(e)}, 500)
