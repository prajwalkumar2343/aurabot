import os
from pathlib import Path

try:
    from dotenv import load_dotenv
    load_dotenv()
    print("[INFO] Loaded environment from .env file")
except ImportError:
    pass

HOST = os.getenv("MEM0_HOST", "localhost")
PORT = int(os.getenv("MEM0_PORT", "8000"))
MODELS_DIR = Path(os.getenv("MODELS_DIR", "./models"))
LM_STUDIO_URL = os.getenv("LM_STUDIO_URL", "http://localhost:1234")
CEREBRAS_API_KEY = os.getenv("CEREBRAS_API_KEY", "")
GGUF_SERVER_PORT = int(os.getenv("GGUF_SERVER_PORT", "8080"))
LLAMA_CPP_PATH = os.getenv("LLAMA_CPP_PATH", "")
