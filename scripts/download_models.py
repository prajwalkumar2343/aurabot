#!/usr/bin/env python3
"""
Download models script - Downloads models locally for offline use.

Models:
- google/embeddinggemma-300m-f8: Text embedding model (GPU required)
- LiquidAI/LFM-2-Vision-450M: Vision-language model

Usage:
    python download_models.py [model_name]
    
Arguments:
    model_name    Optional. One of: embedding, vision, or all (default: all)

Note: 
    - Embedding model requires GPU and Hugging Face authentication
    - Run `huggingface-cli login` before downloading embedding model
"""

import os
import sys
import subprocess
from pathlib import Path

# Configuration
MODELS_DIR = Path("./models")

# Model configurations
MODELS = {
    "embedding": {
        "name": "google/embeddinggemma-300m-f8",
        "local_path": MODELS_DIR / "embeddinggemma-300m-f8",
        "description": "Google Embedding Gemma 300M FP8 - 768 dimensional embeddings (GPU required)",
    },
    "vision": {
        "name": "LiquidAI/LFM-2-Vision-450M",
        "local_path": MODELS_DIR / "lfm-2-vision-450m",
        "description": "Liquid AI LFM-2 Vision 450M - Vision-language model",
    }
}

# Required packages
REQUIRED_PACKAGES = [
    "torch>=2.0.0",
    "transformers>=4.40.0",
    "pillow>=10.0.0",
    "numpy>=1.24.0",
    "sentencepiece>=0.2.0",
    "protobuf>=4.0.0",
    "huggingface_hub>=0.20.0",
]


def check_and_install_dependencies():
    """Check and install required dependencies."""
    print("Checking dependencies...")
    
    missing = []
    for package in REQUIRED_PACKAGES:
        pkg_name = package.split(">=")[0].split("==")[0]
        try:
            __import__(pkg_name.replace("-", "_"))
        except ImportError:
            missing.append(package)
    
    if missing:
        print(f"Installing missing packages: {', '.join(missing)}")
        try:
            subprocess.check_call([
                sys.executable, "-m", "pip", "install"
            ] + missing)
            print("[OK] Dependencies installed")
        except subprocess.CalledProcessError as e:
            print(f"[ERROR] Failed to install dependencies: {e}")
            sys.exit(1)
    else:
        print("[OK] All dependencies are available")


def download_model(model_key: str, force: bool = False):
    """Download a specific model."""
    if model_key not in MODELS:
        print(f"[ERROR] Unknown model: {model_key}")
        print(f"Available models: {', '.join(MODELS.keys())}")
        return False
    
    model_info = MODELS[model_key]
    local_path = model_info["local_path"]
    
    print(f"\n{'='*60}")
    print(f"Model: {model_info['name']}")
    print(f"Description: {model_info['description']}")
    print(f"Save location: {local_path.absolute()}")
    print(f"{'='*60}")
    
    if local_path.exists() and not force:
        print(f"[INFO] Model already exists at {local_path}")
        response = input("Re-download? (y/N): ").strip().lower()
        if response != 'y':
            print("[INFO] Skipping download")
            return True
    
    MODELS_DIR.mkdir(parents=True, exist_ok=True)
    
    try:
        from huggingface_hub import snapshot_download
        
        print(f"\n[DOWNLOAD] Starting download...")
        print(f"           This may take several minutes...")
        print()
        
        # Download the model
        snapshot_download(
            repo_id=model_info["name"],
            local_dir=local_path,
            local_dir_use_symlinks=False,
            resume_download=True
        )
        
        print(f"\n[OK] Model downloaded successfully to {local_path}")
        return True
        
    except Exception as e:
        print(f"\n[ERROR] Failed to download model: {e}")
        return False


def get_model_size(model_key: str) -> str:
    """Get the size of a downloaded model."""
    model_info = MODELS[model_key]
    local_path = model_info["local_path"]
    
    if not local_path.exists():
        return "Not downloaded"
    
    try:
        total_size = 0
        for file_path in local_path.rglob('*'):
            if file_path.is_file():
                total_size += file_path.stat().st_size
        
        # Convert to human-readable format
        for unit in ['B', 'KB', 'MB', 'GB']:
            if total_size < 1024:
                return f"{total_size:.1f} {unit}"
            total_size /= 1024
        return f"{total_size:.1f} TB"
    except Exception:
        return "Unknown"


def list_models():
    """List all models and their status."""
    print(f"\n{'='*60}")
    print("Model Status")
    print(f"{'='*60}")
    
    for key, info in MODELS.items():
        status = "Downloaded" if info["local_path"].exists() else "Not downloaded"
        size = get_model_size(key)
        print(f"\n{key}:")
        print(f"  Name: {info['name']}")
        print(f"  Description: {info['description']}")
        print(f"  Status: {status}")
        print(f"  Size: {size}")
        print(f"  Location: {info['local_path'].absolute()}")
    
    print(f"\n{'='*60}")


def main():
    """Main entry point."""
    print("=" * 60)
    print("Model Download Manager")
    print("=" * 60)
    
    # Parse arguments
    model_arg = sys.argv[1] if len(sys.argv) > 1 else "all"
    
    if model_arg == "--list" or model_arg == "-l":
        list_models()
        return
    
    if model_arg == "--help" or model_arg == "-h":
        print(__doc__)
        print("\nUsage:")
        print("  python download_models.py [model_name]")
        print("\nOptions:")
        print("  model_name    One of: embedding, vision, all (default: all)")
        print("  --list, -l    List model status")
        print("  --help, -h    Show this help message")
        return
    
    # Check dependencies
    check_and_install_dependencies()
    
    # Download models
    if model_arg == "all":
        models_to_download = list(MODELS.keys())
    elif model_arg in MODELS:
        models_to_download = [model_arg]
    else:
        print(f"[ERROR] Unknown model: {model_arg}")
        print(f"Available models: {', '.join(MODELS.keys())}, all")
        sys.exit(1)
    
    success_count = 0
    for model_key in models_to_download:
        if download_model(model_key):
            success_count += 1
    
    print(f"\n{'='*60}")
    print(f"Download complete: {success_count}/{len(models_to_download)} models ready")
    print(f"{'='*60}")
    
    if success_count == len(models_to_download):
        print("\n[OK] All models are ready to use!")
        print("\nYou can now run the local model server:")
        print("  python local_model_server.py")
    else:
        print("\n[WARN] Some models failed to download")
        sys.exit(1)


if __name__ == "__main__":
    main()
