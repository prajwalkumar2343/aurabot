#!/usr/bin/env python3
"""
Automatic setup script for Mem0 Local Models.

Handles:
- Hugging Face authentication (browser-based or token input)
- Model verification and auto-download
- Progress tracking and user-friendly output

Usage:
    python auto_setup.py
"""

import os
import sys
import webbrowser
import subprocess
from pathlib import Path
from typing import Optional, Tuple

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent))

# Configuration
MODELS_DIR = Path(os.getenv("MODELS_DIR", "./models"))
HF_TOKEN_PATH = Path.home() / ".cache" / "huggingface" / "token"

# Model configurations (synced with download_models.py)
MODELS = {
    "embedding": {
        "name": "google/embeddinggemma-300m-f8",
        "local_path": MODELS_DIR / "embeddinggemma-300m-f8",
        "description": "Google Embedding Gemma 300M FP8",
        "size": "~300MB",
        "requires_auth": True,
    },
    "vision": {
        "name": "LiquidAI/LFM-2-Vision-450M",
        "local_path": MODELS_DIR / "lfm-2-vision-450m",
        "description": "Liquid AI LFM-2 Vision 450M",
        "size": "~450MB",
        "requires_auth": False,
    }
}


def print_header(text: str):
    """Print a formatted header."""
    print("\n" + "=" * 70)
    print(f"  {text}")
    print("=" * 70 + "\n")


def print_step(step: int, total: int, text: str):
    """Print a step indicator."""
    print(f"[{step}/{total}] {text}")


def check_hf_auth() -> Tuple[bool, Optional[str]]:
    """Check if user is authenticated with Hugging Face."""
    try:
        from huggingface_hub import HfApi
        api = HfApi()
        # Try to get current user - will fail if not logged in
        user = api.whoami()
        return True, user.get("name", user.get("fullname", "Unknown"))
    except Exception:
        return False, None


def hf_browser_login() -> bool:
    """Open browser for Hugging Face login."""
    print("Opening browser for Hugging Face authentication...")
    print("Please login and accept the Gemma model terms.\n")
    
    try:
        # Open the Hugging Face login page
        webbrowser.open("https://huggingface.co/login")
        
        # Also open the model page so they can accept terms
        print("After logging in, please also visit:")
        print("https://huggingface.co/google/embeddinggemma-300m-f8")
        print("And click 'Access repository' to accept the terms.\n")
        
        input("Press Enter once you've completed the login and accepted terms...")
        
        # Check again
        is_auth, user = check_hf_auth()
        if is_auth:
            print(f"✓ Successfully authenticated as: {user}")
            return True
        else:
            print("✗ Authentication failed or not completed.")
            return False
            
    except Exception as e:
        print(f"✗ Error during browser login: {e}")
        return False


def hf_token_login() -> bool:
    """Login using HF token."""
    print("\nYou can get your token from: https://huggingface.co/settings/tokens")
    print("Make sure to create a token with 'read' access.\n")
    
    token = input("Enter your Hugging Face token: ").strip()
    
    if not token:
        print("✗ No token provided.")
        return False
    
    try:
        from huggingface_hub import login
        login(token=token, add_to_git_credential=False)
        
        # Verify
        is_auth, user = check_hf_auth()
        if is_auth:
            print(f"✓ Successfully authenticated as: {user}")
            return True
        else:
            print("✗ Token authentication failed.")
            return False
            
    except Exception as e:
        print(f"✗ Error during token login: {e}")
        return False


def handle_hf_auth() -> bool:
    """Handle Hugging Face authentication flow."""
    print_step(1, 3, "Checking Hugging Face Authentication")
    
    # First check if already authenticated
    is_auth, user = check_hf_auth()
    if is_auth:
        print(f"✓ Already authenticated as: {user}")
        return True
    
    print("✗ Not authenticated with Hugging Face.")
    print("\nThe embedding model (Google Gemma) requires Hugging Face authentication.\n")
    
    print("Choose authentication method:")
    print("  1. Browser login (opens huggingface.co)")
    print("  2. Token login (paste your HF token)")
    print("  3. Skip (you'll need to run `huggingface-cli login` manually)")
    
    choice = input("\nEnter choice (1-3): ").strip()
    
    if choice == "1":
        return hf_browser_login()
    elif choice == "2":
        return hf_token_login()
    else:
        print("Skipping authentication. You'll need to login manually.")
        return False


def check_models() -> Tuple[dict, dict]:
    """Check which models are downloaded and which are missing."""
    downloaded = {}
    missing = {}
    
    for key, model in MODELS.items():
        if model["local_path"].exists():
            downloaded[key] = model
        else:
            missing[key] = model
    
    return downloaded, missing


def download_model(model_key: str, model_info: dict) -> bool:
    """Download a single model with progress."""
    from huggingface_hub import snapshot_download
    
    model_name = model_info["name"]
    local_path = model_info["local_path"]
    
    print(f"\n  Downloading: {model_info['description']}")
    print(f"  Source: {model_name}")
    print(f"  Destination: {local_path}")
    print(f"  Size: {model_info['size']}")
    print()
    
    try:
        MODELS_DIR.mkdir(parents=True, exist_ok=True)
        
        snapshot_download(
            repo_id=model_name,
            local_dir=local_path,
            local_dir_use_symlinks=False,
            resume_download=True
        )
        
        print(f"  ✓ Download complete!")
        return True
        
    except Exception as e:
        print(f"  ✗ Download failed: {e}")
        if "401" in str(e) or "403" in str(e):
            print("  \n  This model requires authentication.")
            print("  Please ensure you're logged in and have accepted the model terms.")
        return False


def handle_model_downloads() -> bool:
    """Handle model verification and downloads."""
    print_step(2, 3, "Checking Models")
    
    downloaded, missing = check_models()
    
    if downloaded:
        print(f"✓ Found {len(downloaded)} downloaded model(s):")
        for key, model in downloaded.items():
            print(f"  • {model['description']}")
    
    if not missing:
        print("\n✓ All models are ready!")
        return True
    
    print(f"\n✗ Missing {len(missing)} model(s):")
    for key, model in missing.items():
        print(f"  • {model['description']} ({model['size']})")
    
    # Check if embedding model is missing but not authenticated
    if "embedding" in missing:
        is_auth, _ = check_hf_auth()
        if not is_auth:
            print("\n⚠ WARNING: Embedding model requires Hugging Face authentication!")
            print("   Please complete Step 1 first.\n")
            return False
    
    print("\nDownload missing models?")
    choice = input("Enter 'y' to download, 'n' to skip: ").strip().lower()
    
    if choice != 'y':
        print("Skipping downloads.")
        return len(downloaded) > 0  # Return True if at least some models exist
    
    # Download missing models
    success = True
    for key, model in missing.items():
        if not download_model(key, model):
            success = False
    
    return success


def check_system_requirements() -> bool:
    """Check GPU and system requirements."""
    print_step(3, 3, "Checking System Requirements")
    
    # Check CUDA
    try:
        import torch
        if torch.cuda.is_available():
            device_name = torch.cuda.get_device_name(0)
            vram = torch.cuda.get_device_properties(0).total_memory / 1e9
            print(f"✓ GPU detected: {device_name}")
            print(f"  VRAM: {vram:.1f} GB")
            return True
        else:
            print("✗ No GPU detected!")
            print("  The embedding model (Gemma) requires CUDA GPU.")
            print("  You can still use the vision model on CPU.")
            return False
    except ImportError:
        print("✗ PyTorch not installed!")
        return False


def main():
    """Main setup flow."""
    print_header("Mem0 Local Models - Automatic Setup")
    
    print("This script will:")
    print("  1. Set up Hugging Face authentication")
    print("  2. Download required AI models")
    print("  3. Verify your system meets requirements")
    print()
    input("Press Enter to continue...")
    
    # Step 1: HF Auth (if embedding model needs it)
    is_auth = handle_hf_auth()
    
    # Step 2: Model downloads
    models_ready = handle_model_downloads()
    
    # Step 3: System check
    has_gpu = check_system_requirements()
    
    # Summary
    print_header("Setup Summary")
    
    if is_auth:
        print("✓ Hugging Face: Authenticated")
    else:
        print("✗ Hugging Face: Not authenticated")
    
    if models_ready:
        print("✓ Models: Ready")
    else:
        print("✗ Models: Missing")
    
    if has_gpu:
        print("✓ GPU: Available")
    else:
        print("⚠ GPU: Not available (embedding model will not work)")
    
    print()
    
    if models_ready and has_gpu:
        print("🎉 Setup complete! You can now run:")
        print("   python mem0_local.py")
        return 0
    elif models_ready and not has_gpu:
        print("⚠ Setup partially complete.")
        print("   Vision model only (no GPU for embeddings)")
        return 0
    else:
        print("❌ Setup incomplete. Please fix the issues above.")
        return 1


if __name__ == "__main__":
    sys.exit(main())
