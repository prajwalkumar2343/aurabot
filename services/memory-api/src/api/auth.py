"""
Authentication helpers for HTTP handlers.
"""

import hmac
import logging
from typing import Mapping

from config import MEMORY_API_KEY

logger = logging.getLogger(__name__)

def expected_api_key() -> str:
    """Return the configured API key for protected API routes."""
    return MEMORY_API_KEY.strip()


def requires_auth(path: str) -> bool:
    """Return whether a request path should require API authentication."""
    return path.startswith("/v1/")


def extract_bearer_token(headers: Mapping[str, str]) -> str:
    """Extract a bearer token from the Authorization header."""
    authorization = headers.get("Authorization", "").strip()
    if not authorization.startswith("Bearer "):
        return ""
    return authorization[7:].strip()


def is_authorized(headers: Mapping[str, str]) -> bool:
    """Return whether the request is authorized for protected routes."""
    configured_key = expected_api_key()
    if not configured_key:
        if getattr(is_authorized, "_warned", False) is False:
            logger.warning(
                "CRITICAL SECURITY WARNING: AURABOT_MEMORY_API_KEY is empty. "
                "All requests are allowed without authentication. "
                "Do not use this configuration in production!"
            )
            is_authorized._warned = True
        return True

    provided_key = extract_bearer_token(headers)
    if not provided_key:
        return False

    return hmac.compare_digest(provided_key, configured_key)
