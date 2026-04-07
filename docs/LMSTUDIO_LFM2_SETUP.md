# LM Studio + LFM2-350M Setup Guide

Connect your **already-running LM Studio** (with LFM2-350M-Q8_0.gguf) to the Mem0 memory system.

## Prerequisites

1. **LM Studio** installed and running
2. **LFM2-350M-Q8_0.gguf** loaded
3. **API Server** started in LM Studio (⚙️ → "Start Server")

## Quick Start

### 1. Start LM Studio

```
LM Studio
├── Load Model: LFM2-350M-Q8_0.gguf
├── ⚙️ Developer
│   └── ☑️ Start Server (default: http://localhost:1234)
```

### 2. Choose Your Setup

We provide **3 options** depending on your needs:

#### Option A: Simple (Recommended)
```bash
cd aurabot/python/src
python lmstudio_simple.py
```

#### Option B: Full Control
```bash
cd aurabot/python/src
python mem0_lmstudio_lfm2.py
```

#### Option C: With Pre-Filtering (Saves compute)
```bash
cd aurabot/python/src
python mem0_lmstudio_classifier.py
```

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Status check |
| `/v1/memories/` | POST | Add memory |
| `/v1/memories/` | GET | List memories |
| `/v1/memories/search/` | POST | Search |
| `/v1/chat/completions` | POST | Direct LM Studio access |

## Testing

```bash
# Check connection
curl http://localhost:8000/health

# Add memory
curl -X POST http://localhost:8000/v1/memories/ \
  -H "Content-Type: application/json" \
  -d '{"messages": [{"role": "user", "content": "Project due Friday"}]}'

# Search
curl -X POST http://localhost:8000/v1/memories/search/ \
  -d '{"query": "project deadline"}'
```

## Files

```
python/src/
├── lmstudio_simple.py           # Simplest option
├── mem0_lmstudio_lfm2.py        # Full control
├── mem0_lmstudio_classifier.py  # Pre-filtering
└── .env.example                 # Config
```

Run any of these and your Go app will connect to `http://localhost:8000`!
