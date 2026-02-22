# Cerebras + LM Studio Setup

This setup uses **Cerebras API** for LLM (memory extraction) and **LM Studio** for local embeddings.

## Why Cerebras?

- **Fast inference**: Purpose-built AI accelerators
- **Lower latency**: Than many cloud providers
- **OpenAI-compatible**: Easy integration
- **Llama 3.1 70B**: High-quality fact extraction

## Prerequisites

1. **Cerebras API key**: Get from https://cloud.cerebras.ai
2. **LM Studio**: Running with embedding model

## Quick Start

### 1. Get Cerebras API Key

1. Sign up at https://cloud.cerebras.ai
2. Go to API Keys section
3. Copy your key

### 2. Configure Environment

```bash
cd aurabot/python/src

# Create .env file
cat > .env << 'EOF'
CEREBRAS_API_KEY=your_key_here
LM_STUDIO_URL=http://localhost:1234/v1
EOF
```

### 3. Start LM Studio

```
LM Studio
├── Load Model: nomic-embed-text-v1.5 (or any embedding model)
├── ⚙️ Developer
│   └── ☑️ Start Server
```

### 4. Run Mem0 Server

```bash
python mem0_server.py
```

## How It Works

```
┌─────────────┐      ┌──────────────┐      ┌─────────────┐
│   Go App    │─────▶│  Mem0 Server │─────▶│  Cerebras   │
│  (capture)  │      │  (port 8000) │      │   Cloud     │
└─────────────┘      └──────┬───────┘      │ llama3.1-70b│
                            │              └──────┬──────┘
                            │                     │
                            ▼                     │
                     ┌──────────────┐            │
                     │  LM Studio   │◀───────────┘
                     │  (embeddings)│  (fallback if no key)
                     └──────┬───────┘
                            ▼
                     ┌──────────────┐
                     │    Qdrant    │
                     │  Vector DB   │
                     └──────────────┘
```

## Configuration

| Variable | Description | Required |
|----------|-------------|----------|
| `CEREBRAS_API_KEY` | Your Cerebras API key | Yes (for Cerebras) |
| `LM_STUDIO_URL` | LM Studio API URL | Yes |
| `MEM0_HOST` | Server bind host | No (default: localhost) |
| `MEM0_PORT` | Server port | No (default: 8000) |

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Status (shows Cerebras or LM Studio) |
| `/v1/memories/` | POST | Add memory |
| `/v1/memories/` | GET | List memories |
| `/v1/memories/search/` | POST | Search |

## Testing

```bash
# Check health - should show "cerebras" as llm_provider
curl http://localhost:8000/health

# Add memory - Cerebras extracts facts
curl -X POST http://localhost:8000/v1/memories/ \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [{"role": "user", "content": "I have a meeting with John tomorrow at 2pm about the Q4 budget"}],
    "user_id": "user123"
  }'

# Search
curl -X POST http://localhost:8000/v1/memories/search/ \
  -d '{"query": "meeting with John", "user_id": "user123"}'
```

## Fallback Mode

If `CEREBRAS_API_KEY` is not set, the server automatically falls back to LM Studio for LLM operations.

## Troubleshooting

### "CEREBRAS_API_KEY not set"
```bash
export CEREBRAS_API_KEY="your_key_here"
```

### "Authentication failed"
- Check your API key at https://cloud.cerebras.ai

### "Rate limit exceeded"
- Wait between requests
- Check your plan limits

## Files

```
python/src/
├── mem0_server.py      # Main server (Cerebras + LM Studio)
└── .env.example        # Configuration template
```
