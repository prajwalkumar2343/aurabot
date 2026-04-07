"""
CORS utilities for HTTP handlers.
"""

ALLOWED_ORIGINS = [
    "http://localhost:3000",
    "http://localhost:8080",
    "http://localhost:7345",
    "chrome-extension://*",
    "https://chat.openai.com",
    "https://chatgpt.com",
    "https://claude.ai",
    "https://gemini.google.com",
    "https://perplexity.ai",
]


def is_allowed_origin(origin: str) -> bool:
    """Check if the origin is allowed."""
    if not origin:
        return True
    for allowed in ALLOWED_ORIGINS:
        if allowed.endswith("/*"):
            prefix = allowed[:-1]
            if origin.startswith(prefix):
                return True
        elif origin == allowed:
            return True
    return False


def get_cors_headers(origin: str) -> dict:
    """Get CORS headers for the response."""
    if not is_allowed_origin(origin):
        return {}

    return {
        "Access-Control-Allow-Origin": origin if origin else "http://localhost:3000",
        "Access-Control-Allow-Methods": "GET, POST, DELETE, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type, Authorization",
        "Access-Control-Allow-Credentials": "true",
    }
