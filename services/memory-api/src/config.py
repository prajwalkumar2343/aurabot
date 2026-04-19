import os
import json
from pathlib import Path
import logging

logger = logging.getLogger(__name__)

try:
    from dotenv import find_dotenv, load_dotenv

    dotenv_path = find_dotenv(usecwd=True)
    if dotenv_path:
        load_dotenv(dotenv_path)
        logger.debug("Loaded environment variables from .env file")
except ImportError:
    pass


APP_CONFIG_PATH = Path.home() / ".aurabot" / "config.json"


def _load_app_config() -> dict:
    """Load the shared AuraBot app config if it exists."""
    if not APP_CONFIG_PATH.exists():
        return {}

    try:
        return json.loads(APP_CONFIG_PATH.read_text())
    except Exception:
        return {}


APP_CONFIG = _load_app_config()


def _config_value(env_key: str, default, config_path: str = ""):
    """Resolve a config value from env first, then shared app config."""
    value = os.getenv(env_key)
    if value not in (None, ""):
        return value

    if config_path:
        current = APP_CONFIG
        for key in config_path.split("."):
            if not isinstance(current, dict):
                return default
            current = current.get(key)
        if current not in (None, ""):
            return current

    return default


HOST = os.getenv("AURABOT_MEMORY_HOST", "localhost")
PORT = int(os.getenv("AURABOT_MEMORY_PORT", "8000"))
MODELS_DIR = Path(os.getenv("MODELS_DIR", "./models"))
DATABASE_URL = _config_value("DATABASE_URL", "", "memory.databaseURL")
OPENROUTER_API_KEY = _config_value("OPENROUTER_API_KEY", "", "llm.openRouterAPIKey")
OPENROUTER_BASE_URL = _config_value(
    "OPENROUTER_BASE_URL", "https://openrouter.ai/api/v1", "llm.baseURL"
)
OPENROUTER_VISION_MODEL = _config_value(
    "OPENROUTER_VISION_MODEL", "google/gemini-flash-1.5", "llm.model"
)
OPENROUTER_CHAT_MODEL = _config_value(
    "OPENROUTER_CHAT_MODEL",
    "anthropic/claude-3.5-sonnet",
    "llm.openRouterChatModel",
)
OPENROUTER_EMBEDDING_MODEL = _config_value(
    "OPENROUTER_EMBEDDING_MODEL", "openai/text-embedding-3-small"
)
OPENROUTER_EMBEDDING_DIMENSIONS = int(
    _config_value("OPENROUTER_EMBEDDING_DIMENSIONS", "1536")
)
MEMORY_API_KEY = _config_value("AURABOT_MEMORY_API_KEY", "", "memory.apiKey")
OPENAI_TIMEOUT = int(os.getenv("OPENAI_TIMEOUT", "60"))
