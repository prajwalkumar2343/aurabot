"""
CORS utilities for HTTP handlers.
"""

import os
from typing import List


DEFAULT_ALLOWED_ORIGINS = [
    "http://localhost:3000",
    "http://localhost:8080",
    "http://localhost:7345",
]


def get_allowed_origins() -> List[str]:
    """Return the configured list of allowed CORS origins."""
    configured = os.getenv("AURABOT_MEMORY_ALLOWED_ORIGINS", "").strip()
    if not configured:
        return DEFAULT_ALLOWED_ORIGINS

    return [origin.strip() for origin in configured.split(",") if origin.strip()]


def is_allowed_origin(origin: str) -> bool:
    """Check if the origin is allowed."""
    if not origin:
        return True
    for allowed in get_allowed_origins():
        if allowed.endswith("*"):
            prefix = allowed[:-1]
            if origin.startswith(prefix):
                return True
        elif origin == allowed:
            return True
    return False


def get_cors_headers(origin: str) -> dict:
    """Get CORS headers for the response."""
    if not origin or not is_allowed_origin(origin):
        return {}

    return {
        "Access-Control-Allow-Origin": origin,
        "Access-Control-Allow-Methods": "GET, POST, DELETE, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type, Authorization",
    }
