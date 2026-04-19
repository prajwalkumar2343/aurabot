"""
Chat mixin for HTTP handlers.
Provides chat completions endpoint: LLM chat responses.
"""

import time

from api.base_handler import RequestBodyError
from config import MAX_CHAT_MESSAGES, MAX_CHAT_TOKENS, MAX_TEXT_CHARS


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
            max_tokens = self._bounded_max_tokens(data.get("max_tokens", 512))

            if not isinstance(messages, list) or not messages:
                self.send_json_response({"error": "No messages provided"}, 400)
                return
            if len(messages) > MAX_CHAT_MESSAGES:
                self.send_json_response({"error": "Too many messages"}, 400)
                return
            if not self._messages_within_limit(messages):
                self.send_json_response({"error": "Message content too large"}, 413)
                return

            response_text = self.model_manager.chat(messages, max_tokens=max_tokens)

            prompt_text = " ".join([m.get("content", "") for m in messages if m.get("content")])
            prompt_tokens = max(1, len(prompt_text) // 4)
            completion_tokens = max(1, len(response_text) // 4)

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
                    "prompt_tokens": prompt_tokens,
                    "completion_tokens": completion_tokens,
                    "total_tokens": prompt_tokens + completion_tokens,
                },
            }
            self.send_json_response(response)
        except RequestBodyError as e:
            self.send_json_response({"error": str(e)}, e.status)
        except Exception as e:
            self.send_json_response({"error": str(e)}, 500)

    def _bounded_max_tokens(self, value) -> int:
        try:
            max_tokens = int(value)
        except (TypeError, ValueError):
            max_tokens = 512
        return min(MAX_CHAT_TOKENS, max(1, max_tokens))

    def _messages_within_limit(self, messages: list) -> bool:
        total_chars = 0
        for message in messages:
            if not isinstance(message, dict):
                return False
            content = message.get("content", "")
            total_chars += len(str(content))
            if total_chars > MAX_TEXT_CHARS:
                return False
        return True
