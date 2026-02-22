# Split LLM Setup: Cerebras + LM Studio

Uses **Cerebras** for chat, **LM Studio (LFM2)** for memory classification.

## Quick Start

```bash
# 1. Start LM Studio with LFM2-350M loaded
# 2. Configure
cat > .env << 'EOF'
CEREBRAS_API_KEY=your_key_here
LM_STUDIO_URL=http://localhost:1234/v1
EOF

# 3. Run
python mem0_server_split.py
```

## Architecture

- Chat/Responses → Cerebras API (llama3.1-70b)
- Memory Classification → LM Studio (LFM2-350M)
- Embeddings → LM Studio

## Why This Split?

| Task | Model | Reason |
|------|-------|--------|
| Chat | Cerebras 70B | Fast, high-quality |
| Classification | LFM2 350M | Local, private |
| Embeddings | LM Studio | Local, offline |

## Files

- `mem0_server_split.py` - Split setup
- `mem0_server.py` - Original combined
- `.env.example` - Config template with CEREBRAS_API_KEY
