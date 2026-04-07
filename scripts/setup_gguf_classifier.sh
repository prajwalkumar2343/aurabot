#!/bin/bash
# Setup script for GGUF Memory Classifier
# This helps you configure LFM2-350M-Q8_0.gguf for memory classification

set -e

echo "================================"
echo "GGUF Memory Classifier Setup"
echo "================================"
echo

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Find GGUF model
find_gguf_model() {
    local paths=(
        "$HOME/.models/LFM2-350M-Q8_0.gguf"
        "$HOME/models/LFM2-350M-Q8_0.gguf"
        "./models/LFM2-350M-Q8_0.gguf"
        "../models/LFM2-350M-Q8_0.gguf"
        "./LFM2-350M-Q8_0.gguf"
        "$1"
    )
    
    for path in "${paths[@]}"; do
        if [ -f "$path" ]; then
            echo "$path"
            return 0
        fi
    done
    
    # Try to find any GGUF
    found=$(find "$HOME" -name "*.gguf" -type f 2>/dev/null | head -1)
    if [ -n "$found" ]; then
        echo "$found"
        return 0
    fi
    
    return 1
}

# Check if model path provided
MODEL_PATH="${1:-}"

if [ -z "$MODEL_PATH" ]; then
    echo "Looking for LFM2-350M-Q8_0.gguf..."
    MODEL_PATH=$(find_gguf_model) || {
        echo -e "${RED}ERROR: GGUF model not found!${NC}"
        echo
        echo "Please provide the path to your LFM2-350M-Q8_0.gguf:"
        echo "  $0 /path/to/LFM2-350M-Q8_0.gguf"
        echo
        exit 1
    }
fi

if [ ! -f "$MODEL_PATH" ]; then
    echo -e "${RED}ERROR: Model not found at: $MODEL_PATH${NC}"
    exit 1
fi

echo -e "${GREEN}Found model: $MODEL_PATH${NC}"
echo

# Check which server option to use
echo "How do you want to serve the model?"
echo
select option in "Ollama (recommended)" "llama.cpp" "Already running"; do
    case $option in
        "Ollama (recommended)")
            SERVER_TYPE="ollama"
            break
            ;;
        "llama.cpp")
            SERVER_TYPE="llamacpp"
            break
            ;;
        "Already running")
            SERVER_TYPE="existing"
            break
            ;;
    esac
done

echo

# Setup based on choice
case $SERVER_TYPE in
    ollama)
        echo "Setting up with Ollama..."
        
        # Check if Ollama is installed
        if ! command -v ollama &> /dev/null; then
            echo -e "${YELLOW}Ollama not found. Installing...${NC}"
            
            if [[ "$OSTYPE" == "darwin"* ]]; then
                # macOS
                if command -v brew &> /dev/null; then
                    brew install ollama
                else
                    curl -fsSL https://ollama.com/install.sh | sh
                fi
            elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
                # Linux
                curl -fsSL https://ollama.com/install.sh | sh
            else
                echo -e "${RED}Please install Ollama manually from https://ollama.com${NC}"
                exit 1
            fi
        fi
        
        # Create models directory if needed
        mkdir -p models
        
        # Copy model if not already there
        if [ "$MODEL_PATH" != "./models/$(basename "$MODEL_PATH")" ]; then
            echo "Copying model to ./models/..."
            cp "$MODEL_PATH" ./models/
            MODEL_PATH="./models/$(basename "$MODEL_PATH")"
        fi
        
        # Create Modelfile
        cat > Modelfile << 'EOF'
FROM ./models/LFM2-350M-Q8_0.gguf

PARAMETER temperature 0.1
PARAMETER top_p 0.5
PARAMETER num_predict 256

SYSTEM """You are a memory classification system.

USEFUL memories include:
- User preferences, goals, tasks, decisions
- Important context to recall later
- Work projects, deadlines, commitments

NOT useful (DISCARD):
- Greetings, small talk
- Loading messages, notifications
- Obvious or temporary info

Respond ONLY:
DECISION: USEFUL or DISCARD
REASON: brief explanation"""
EOF
        
        echo "Creating Ollama model 'lfm2-classifier'..."
        ollama create lfm2-classifier -f Modelfile
        
        # Start Ollama
        echo "Starting Ollama server..."
        ollama serve &
        OLLAMA_PID=$!
        sleep 3
        
        # Run the model to keep it loaded
        echo "Loading model into memory..."
        ollama run lfm2-classifier "test" &
        
        echo -e "${GREEN}Ollama setup complete!${NC}"
        echo
        echo "Ollama is running on http://localhost:11434"
        echo "Model name: lfm2-classifier"
        echo
        ;;
        
    llamacpp)
        echo "Setting up with llama.cpp..."
        
        # Check for llama-server
        if ! command -v llama-server &> /dev/null; then
            echo -e "${YELLOW}llama-server not found. Please build llama.cpp first:${NC}"
            echo
            echo "  git clone https://github.com/ggerganov/llama.cpp"
            echo "  cd llama.cpp"
            echo "  make"
            echo
            echo "Then re-run this script with the path to llama-server:"
            echo "  LLAMA_CPP_PATH=./llama.cpp $0 $MODEL_PATH"
            exit 1
        fi
        
        echo "Starting llama.cpp server..."
        echo "  Model: $MODEL_PATH"
        echo "  Port: 8080"
        echo
        
        llama-server \
            -m "$MODEL_PATH" \
            --port 8080 \
            -c 4096 \
            -n 256 \
            --host 127.0.0.1 &
        
        LLAMA_PID=$!
        
        echo "Waiting for server to start..."
        sleep 5
        
        if curl -s http://localhost:8080/health > /dev/null; then
            echo -e "${GREEN}llama.cpp server running on http://localhost:8080${NC}"
        else
            echo -e "${YELLOW}Server may still be loading. Check with: curl http://localhost:8080/health${NC}"
        fi
        echo
        ;;
        
    existing)
        echo "Using existing server..."
        read -p "Enter your GGUF server URL (e.g., http://localhost:8080/v1/chat/completions): " SERVER_URL
        ;;
esac

# Create .env file
echo "Creating .env configuration..."

cat > .env << EOF
# Mem0 Configuration
MEM0_HOST=localhost
MEM0_PORT=8000

# Classifier Configuration
CLASSIFIER_URL=${SERVER_URL:-http://localhost:11434/v1/chat/completions}
CLASSIFIER_MODEL=lfm2-classifier

# Model Paths
MODELS_DIR=./models
GGUF_MODEL_PATH=$MODEL_PATH
EOF

echo -e "${GREEN}.env file created!${NC}"
echo

# Install Python dependencies
echo "Installing Python dependencies..."
pip install -q mem0ai qdrant-client transformers torch numpy requests python-dotenv

echo -e "${GREEN}Setup complete!${NC}"
echo
echo "Next steps:"
echo "  1. Start the classifier server (if not already running):"
if [ "$SERVER_TYPE" == "ollama" ]; then
    echo "     ollama run lfm2-classifier"
fi
echo
echo "  2. Run the Mem0 server with classification:"
echo "     cd python/src"
echo "     python mem0_with_classifier.py"
echo
echo "  3. The Go app will automatically connect to http://localhost:8000"
echo
