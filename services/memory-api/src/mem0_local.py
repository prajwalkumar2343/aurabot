#!/usr/bin/env python3
"""
Backward-compatible entry point.

The active server implementation now lives in main.py and uses OpenRouter-backed
models instead of local LFM2/Gemma models.
"""

from main import main


if __name__ == "__main__":
    main()
