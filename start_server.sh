#!/bin/bash
# Start Mem0 Server with OpenRouter-backed models

cd "$(dirname "$0")/python/src"

echo "================================"
echo "Starting Mem0 Server"
echo "================================"
echo

# Check if .env exists
if [ ! -f .env ]; then
    echo "Creating .env file..."
    cat > .env << 'ENVFILE'
# OpenRouter API Key (required for memory embeddings and chat)
# Get your key from: https://openrouter.ai/settings/keys
OPENROUTER_API_KEY=

# OpenRouter Configuration
OPENROUTER_BASE_URL=https://openrouter.ai/api/v1
OPENROUTER_VISION_MODEL=google/gemini-flash-1.5
OPENROUTER_CHAT_MODEL=anthropic/claude-3.5-sonnet
OPENROUTER_EMBEDDING_MODEL=openai/text-embedding-3-small

# Mem0 Server Configuration
MEM0_HOST=localhost
MEM0_PORT=8000
ENVFILE
    echo "[OK] Created .env - edit it to add OPENROUTER_API_KEY"
    echo
fi

echo "Checking configuration..."
echo

# Start the main Mem0 server
echo "Starting Mem0 server..."
python3 main.py
