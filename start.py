#!/usr/bin/env python3
"""
One-command launcher for Mem0 Local Server.

This script handles:
1. Automatic setup (HF auth + model downloads)
2. Environment verification
3. Starting the server

Usage:
    python start.py              # Full auto-setup + start server
    python start.py --setup-only # Run setup only, don't start server
    python start.py --skip-setup # Skip setup, start server directly
"""

import os
import sys
import subprocess
from pathlib import Path


def run_setup():
    """Run the automatic setup script."""
    setup_script = Path(__file__).parent / "scripts" / "auto_setup.py"
    
    if not setup_script.exists():
        print("[ERROR] Setup script not found!")
        return False
    
    print("=" * 70)
    print("  Mem0 - Automatic Setup")
    print("=" * 70)
    print()
    
    result = subprocess.run([sys.executable, str(setup_script)])
    return result.returncode == 0


def start_server():
    """Start the Mem0 server."""
    server_script = Path(__file__).parent / "python" / "src" / "mem0_local.py"
    
    if not server_script.exists():
        print("[ERROR] Server script not found!")
        return 1
    
    print()
    print("=" * 70)
    print("  Starting Mem0 Server")
    print("=" * 70)
    print()
    
    # Change to the server directory and run
    os.chdir(server_script.parent)
    result = subprocess.run([sys.executable, str(server_script)])
    return result.returncode


def main():
    """Main entry point."""
    args = sys.argv[1:]
    
    # Parse arguments
    setup_only = "--setup-only" in args
    skip_setup = "--skip-setup" in args
    
    if setup_only and skip_setup:
        print("[ERROR] Cannot use both --setup-only and --skip-setup")
        return 1
    
    # Run setup unless skipped
    if not skip_setup:
        if not run_setup():
            print("\n[ERROR] Setup failed. Please fix the issues above.")
            print("You can skip setup with: python start.py --skip-setup")
            return 1
        
        if setup_only:
            print("\n✓ Setup complete! You can now start the server with:")
            print("   python start.py")
            return 0
    
    # Start the server
    return start_server()


if __name__ == "__main__":
    sys.exit(main())
