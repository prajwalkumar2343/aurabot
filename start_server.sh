#!/bin/bash
# Start AuraBot memory server with OpenRouter-backed models

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT_DIR"

echo "================================"
echo "Starting AuraBot Memory Server"
echo "================================"
echo

# Check if .env exists
if [ ! -f .env ]; then
    echo "Creating .env file..."
    cp .env.example .env
    echo "[OK] Created .env - edit it to add OPENROUTER_API_KEY"
    echo
fi

echo "Checking configuration..."
echo

# Start the main memory server
echo "Starting memory server..."
python3 services/memory-api/src/main.py
