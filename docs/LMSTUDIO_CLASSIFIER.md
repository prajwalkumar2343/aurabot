# Mem0 + LM Studio Classifier

Uses your **already-running LM Studio** (with LFM2-350M-Q8_0.gguf) to classify memories before embedding.

## Prerequisites

1. **LM Studio** running with LFM2-350M-Q8_0.gguf loaded
2. **API Server** started in LM Studio (⚙️ → "Start Server")
3. Python dependencies: `pip install mem0ai qdrant-client transformers torch requests`

## Quick Start

### 1. Start LM Studio (if not already running)

- Open LM Studio
- Load **LFM2-350M-Q8_0.gguf**
- Click **"Start Server"** (default port 1234)

### 2. Run the Mem0 Classifier Server

```bash
cd aurabot/python/src
python mem0_lmstudio_classifier.py
```

That's it! The server will:
- Connect to LM Studio
- Classify each incoming memory
- Only embed & store useful ones

## How It Works

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────┐
│   Screen/Text   │────▶│   LM Studio      │────▶│   Embed?    │
│   (Go app)      │     │  LFM2-350M-Q8_0  │     └──────┬──────┘
└─────────────────┘     └──────────────────┘            │
                                                        │
                              ┌─────────────────────────┼──────┐
                              ▼                         ▼      │
                       ┌────────────┐           ┌────────────┐ │
                       │  DISCARD   │           │   EMBED    │◀─┘
                       │  (drop)    │           │  (Gemma)   │
                       └────────────┘           └─────┬──────┘
                                                      │
                                               ┌──────┴──────┐
                                               │   Qdrant    │
                                               │  Vector DB  │
                                               └─────────────┘
```

## Example Output

```
[CLASSIFY] I need to finish the report by Friday...
[STORE] (1 total) Contains task with deadline

[CLASSIFY] Loading... please wait
[DISCARD] (1 total) System loading message

[CLASSIFY] My favorite color is blue
[STORE] (2 total) User preference information
```

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Status & stats |
| `/v1/memories/` | POST | Add memory (with classification) |
| `/v1/memories/` | GET | List memories |
| `/v1/memories/search/` | POST | Search memories |

## Testing

```bash
# Check status
curl http://localhost:8000/health

# Add useful memory (will be stored)
curl -X POST http://localhost:8000/v1/memories/ \
  -H "Content-Type: application/json" \
  -d '{"messages": [{"role": "user", "content": "Meeting at 3pm with team"}]}'

# Add useless memory (will be discarded)
curl -X POST http://localhost:8000/v1/memories/ \
  -H "Content-Type: application/json" \
  -d '{"messages": [{"role": "user", "content": "Hello, how are you?"}]}'

# Search
curl -X POST http://localhost:8000/v1/memories/search/ \
  -H "Content-Type: application/json" \
  -d '{"query": "meeting", "limit": 5}'
```

## Configuration

Create `.env` file in `aurabot/python/src/`:

```bash
# If LM Studio runs on different port
LM_STUDIO_URL=http://localhost:1234/v1

# If you want different Mem0 port
MEM0_PORT=8000
```

## Connecting Go App

Your Go app automatically connects to `http://localhost:8000`.

```bash
# Terminal 1: Run Mem0 classifier
python python/src/mem0_lmstudio_classifier.py

# Terminal 2: Run Go app
cd go && go run .
```

## What Gets Classified

| **STORED** (USEFUL) | **DISCARDED** (NOT USEFUL) |
|---------------------|---------------------------|
| Tasks, deadlines | Greetings ("hello", "hi") |
| User preferences | Loading messages |
| Work projects | System notifications |
| Important decisions | Small talk |
| Key insights | Obvious statements |

## Troubleshooting

### "Cannot connect to LM Studio"
- Make sure LM Studio is running
- Check that API server is started (should see green dot)
- Verify port matches (default 1234): `LM_STUDIO_URL=http://localhost:1234/v1`

### "All memories discarded"
- The model might be too strict
- Check LM Studio logs to see classification responses
- Edit the system prompt in `mem0_lmstudio_classifier.py` (line 54)

### "No embedding model found"
- Gemma embedder is optional
- If not found, embeddings may not work properly
- Download: `python scripts/download_models.py`

## Files

```
aurabot/python/src/
├── mem0_lmstudio_classifier.py  # ← Main file
└── .env.example                  # Config template
```
