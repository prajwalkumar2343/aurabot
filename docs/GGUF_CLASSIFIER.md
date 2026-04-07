# GGUF Memory Classifier for Mem0

This setup uses your **LFM2-350M-Q8_0.gguf** model to classify whether information is useful before creating embeddings. This saves storage and reduces noise in your memory system.

## How It Works

```
Screen/Text Input
        ↓
┌─────────────────────┐
│ LFM2-350M-Q8_0.gguf │ ← "Is this useful to remember?"
│   (Classifier)      │
└─────────────────────┘
        ↓
   ┌────────┴────────┐
DISCARD            USEFUL
   ↓                  ↓
  (drop)      ┌──────────────┐
              │  Embedding   │
              │   (Gemma)    │
              └──────────────┘
                     ↓
              ┌──────────────┐
              │    Qdrant    │
              │  Vector DB   │
              └──────────────┘
```

## What Counts as "Useful"

| USEFUL (Store) | NOT USEFUL (Discard) |
|----------------|---------------------|
| User preferences, goals | Greetings, small talk |
| Tasks, reminders, decisions | Loading messages |
| Work projects, deadlines | System notifications |
| Important context | Obvious/generic statements |
| Key insights from conversations | Incomplete thoughts |

## Quick Start

### Option 1: Ollama (Easiest)

```bash
# 1. Install Ollama if needed
curl -fsSL https://ollama.com/install.sh | sh

# 2. Go to the python src directory
cd aurabot/python/src

# 3. Create the model
cat > Modelfile << 'EOF'
FROM /path/to/your/LFM2-350M-Q8_0.gguf
PARAMETER temperature 0.1
PARAMETER num_predict 256
SYSTEM """You are a memory classifier. Decide if text is useful to remember.
USEFUL: user goals, tasks, decisions, important context
NOT USEFUL: greetings, loading messages, obvious info
Respond: DECISION: USEFUL or DISCARD
REASON: brief explanation"""
EOF

ollama create lfm2-classifier -f Modelfile

# 4. Start Ollama
ollama serve

# 5. In another terminal, run the Mem0 classifier server
export CLASSIFIER_URL="http://localhost:11434/v1/chat/completions"
export CLASSIFIER_MODEL="lfm2-classifier"
python mem0_with_classifier.py
```

### Option 2: llama.cpp

```bash
# 1. Build llama.cpp
git clone https://github.com/ggerganov/llama.cpp
cd llama.cpp
make

# 2. Start the server with your model
./llama-server \
  -m /path/to/LFM2-350M-Q8_0.gguf \
  --port 8080 \
  -c 4096 \
  -n 256

# 3. In another terminal, run Mem0 server
export CLASSIFIER_URL="http://localhost:8080/v1/chat/completions"
export CLASSIFIER_MODEL="LFM2-350M-Q8_0"
python mem0_with_classifier.py
```

### Option 3: Automatic Setup

```bash
cd aurabot
./scripts/setup_gguf_classifier.sh /path/to/LFM2-350M-Q8_0.gguf
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `CLASSIFIER_URL` | URL of your GGUF server | `http://localhost:8080/v1/chat/completions` |
| `CLASSIFIER_MODEL` | Model name | `lfm2-classifier` |
| `MEM0_HOST` | Mem0 server host | `localhost` |
| `MEM0_PORT` | Mem0 server port | `8000` |

## Testing

```bash
# 1. Check health
curl http://localhost:8000/health

# 2. Add a useful memory (should be stored)
curl -X POST http://localhost:8000/v1/memories/ \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [{"role": "user", "content": "I need to finish the project by Friday"}],
    "user_id": "user123"
  }'

# 3. Add useless memory (should be discarded)
curl -X POST http://localhost:8000/v1/memories/ \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [{"role": "user", "content": "Loading... please wait"}],
    "user_id": "user123"
  }'

# 4. Check stored memories
curl "http://localhost:8000/v1/memories/?user_id=user123"

# 5. Search memories
curl -X POST http://localhost:8000/v1/memories/search/ \
  -H "Content-Type: application/json" \
  -d '{
    "query": "project deadline",
    "user_id": "user123"
  }'
```

## Connecting Go App

Your Go app connects automatically to `http://localhost:8000`. The classifier filters memories before they're stored.

```bash
# Make sure Mem0 classifier server is running first
python python/src/mem0_with_classifier.py

# Then run Go app
cd go && go run .
```

## How Classification Prompt Works

The LFM2-350M model receives this prompt for each memory:

```
System: You are a memory classification system...

User: Text to classify:
I need to finish the project by Friday

Assistant: DECISION: USEFUL
REASON: Contains task and deadline information
```

If the model returns `DISCARD`, the memory is dropped and **no embedding is created**.

## Monitoring

Check the server output to see classification stats:

```
[STORE] (5 total) - Task with deadline
[DISCARD] (3 total) - Loading message
[STORE] (6 total) - User preference
```

Visit `http://localhost:8000/health` for JSON stats:
```json
{
  "stats": {
    "stored": 42,
    "discarded": 18
  }
}
```

## Troubleshooting

### "Classifier server not responding"
- Make sure Ollama or llama.cpp server is running
- Check `CLASSIFIER_URL` matches your server port
- Try: `curl http://localhost:8080/health`

### "All memories being discarded"
- The classification threshold might be too strict
- Edit the system prompt in the code to be more lenient
- Lower the temperature parameter

### "All memories being stored"
- Check that the model is actually running
- Verify the model name matches (`ollama list` or check llama.cpp output)
- Look at server logs for classification responses

## File Structure

```
aurabot/python/src/
├── mem0_with_classifier.py    # ← Main server (use this)
├── gguf_memory_classifier.py   # Alternative (auto-starts GGUF)
├── Modelfile                   # Ollama model definition
└── ...
```
