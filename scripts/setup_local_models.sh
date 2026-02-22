#!/bin/bash
# Setup script for local models on Linux/macOS

set -e

echo "=========================================="
echo "Local Models Setup"
echo "=========================================="
echo

# Check Python
echo "[1/3] Checking Python installation..."
if ! command -v python3 &> /dev/null && ! command -v python &> /dev/null; then
    echo "[ERROR] Python is not installed"
    echo "Please install Python 3.9+"
    exit 1
fi
echo "[OK] Python is available"

# Install dependencies
echo
echo "[2/3] Installing dependencies..."
pip install -q torch transformers pillow numpy sentencepiece protobuf huggingface_hub accelerate
echo "[OK] Dependencies installed"

# Download models
echo
echo "[3/3] Downloading models..."
python3 download_models.py || python download_models.py

echo
echo "=========================================="
echo "Setup complete!"
echo "=========================================="
echo
echo "You can now run the server:"
echo "  python local_model_server.py   (API only)"
echo "  python mem0_local.py           (with Mem0)"
echo
