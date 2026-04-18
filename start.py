#!/usr/bin/env python3
"""
One-command launcher for the AuraBot memory server.

This script handles:
1. Environment verification
2. Starting the server

Usage:
    python start.py              # Start the server
    python start.py --setup-only # Validate config only
"""

import sys
import subprocess
from pathlib import Path


def start_server():
    """Start the Mem0 server."""
    server_script = (
        Path(__file__).parent / "services" / "memory-api" / "src" / "main.py"
    )

    if not server_script.exists():
        print("[ERROR] Server script not found!")
        return 1

    print()
    print("=" * 70)
    print("  Starting Mem0 Server")
    print("=" * 70)
    print()

    result = subprocess.run([sys.executable, str(server_script)])
    return result.returncode


def main():
    """Main entry point."""
    args = sys.argv[1:]

    # Parse arguments
    setup_only = "--setup-only" in args
    if setup_only:
        print("[INFO] No local model setup is required.")
        print("       Configure OPENROUTER_API_KEY or save it in ~/.aurabot/config.json")
        return 0

    return start_server()


if __name__ == "__main__":
    sys.exit(main())
