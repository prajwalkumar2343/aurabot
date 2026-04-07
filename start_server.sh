#!/bin/bash
# Start Mem0 Server with proper setup

cd "$(dirname "$0")/python/src"

echo "================================"
echo "Starting Mem0 Server"
echo "================================"
echo

# Check if .env exists
if [ ! -f .env ]; then
    echo "Creating .env file..."
    cat > .env << 'ENVFILE'
MEM0_HOST=localhost
MEM0_PORT=8000
LM_STUDIO_URL=http://localhost:1234/v1
# Add your key: CEREBRAS_API_KEY=...
ENVFILE
    echo "[OK] Created .env - edit it to add CEREBRAS_API_KEY"
    echo
fi

# Check LM Studio
echo "Checking LM Studio..."
if curl -s http://localhost:1234/v1/models > /dev/null 2>&1; then
    echo "[OK] LM Studio is running"
else
    echo "[ERROR] LM Studio not detected!"
    echo
    echo "Please:"
    echo "  1. Open LM Studio"
    echo "  2. Load LFM2-350M-Q8_0.gguf"
    echo "  3. Start the API server (Developer tab)"
    echo
    exit 1
fi

echo

# Choose server type
echo "Select server type:"
select opt in "Split (Cerebras chat + LM Studio classify)" "Simple (LM Studio only)" "Exit"; do
    case $opt in
        "Split (Cerebras chat + LM Studio classify)")
            echo
            echo "Starting split server..."
            python3 mem0_server_split.py
            break
            ;;
        "Simple (LM Studio only)")
            echo
            echo "Starting simple server..."
            python3 lmstudio_simple.py
            break
            ;;
        "Exit")
            exit 0
            ;;
    esac
done
