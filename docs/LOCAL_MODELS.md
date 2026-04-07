# Local Models Setup

This guide explains how to run **LFM-2-Vision-450M** and **google/embeddinggemma-300m-f8** locally without any external API dependencies.

## Overview

| Model | Type | Size | Purpose | GPU Required |
|-------|------|------|---------|-------------|
| `LiquidAI/LFM-2-Vision-450M` | Vision-Language | ~450M | Chat, vision understanding, Q&A | Optional |
| `google/embeddinggemma-300m-f8` | Embedding | ~300M | Text embeddings for search/memory | **Yes** |

## Quick Start

### 1. Install Dependencies

```bash
pip install -r python/requirements.txt
```

Or let the scripts auto-install on first run.

### 2. Authenticate with Hugging Face

The Gemma embedding model requires Hugging Face authentication:

```bash
# Install huggingface-cli if not already installed
pip install huggingface_hub

# Login (requires Hugging Face account and accepting Gemma terms)
huggingface-cli login
```

**Note:** You must accept the Gemma license terms on the Hugging Face model page before downloading.

### 3. Download Models (One-time)

Download both models:
```bash
python scripts/download_models.py
```

Or download individually:
```bash
python scripts/download_models.py embedding   # Gemma embed model only
python scripts/download_models.py vision      # LFM vision model only
```

Check download status:
```bash
python scripts/download_models.py --list
```

Models are saved to `./models/` directory:
- `./models/embeddinggemma-300m-f8/` - Embedding model
- `./models/lfm-2-vision-450m/` - Vision-language model

### 4. Run the Server

**Option A: Standalone Model Server** (Simple, API-only)
```bash
cd python/src && python local_model_server.py
```

**Option B: Mem0 + Local Models** (Full memory system)
```bash
cd python/src && python mem0_local.py
```

## API Endpoints

Once the server is running, the following endpoints are available:

### Health Check
```bash
curl http://localhost:8000/health
```

### List Models
```bash
curl http://localhost:8000/v1/models
```

### Generate Embeddings
```bash
curl -X POST http://localhost:8000/v1/embeddings \
  -H "Content-Type: application/json" \
  -d '{
    "input": "Hello, world!",
    "model": "embeddinggemma-300m-f8"
  }'
```

### Chat Completions
```bash
curl -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "lfm-2-vision-450m",
    "messages": [
      {"role": "user", "content": "What is machine learning?"}
    ]
  }'
```

### Memory Operations (Mem0 server only)

**Add memory:**
```bash
curl -X POST http://localhost:8000/v1/memories/ \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [{"role": "user", "content": "I love programming in Python"}],
    "user_id": "user123"
  }'
```

**Search memories:**
```bash
curl -X POST http://localhost:8000/v1/memories/search/ \
  -H "Content-Type: application/json" \
  -d '{
    "query": "programming languages",
    "user_id": "user123"
  }'
```

**Get all memories:**
```bash
curl "http://localhost:8000/v1/memories/?user_id=user123"
```

## Configuration

Environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `MEM0_HOST` | `localhost` | Server bind address |
| `MEM0_PORT` | `8000` | Server port |
| `MODELS_DIR` | `./models` | Directory for downloaded models |

Example:
```bash
set MEM0_PORT=8080
python mem0_local.py
```

## Scripts Reference

### `download_models.py`
Downloads models from Hugging Face Hub.

```bash
python scripts/download_models.py [model_name]

# Options:
python scripts/download_models.py all        # Download all models (default)
python scripts/download_models.py embedding  # Download Gemma embed model
python scripts/download_models.py vision     # Download LFM vision model
python scripts/download_models.py --list     # Show download status
python scripts/download_models.py --help     # Show help
```

### `local_model_server.py`
Standalone server providing OpenAI-compatible API for local models.
- Auto-downloads models on first run
- Provides embeddings and chat endpoints
- **Note:** Embedding model requires GPU

### `mem0_local.py`
Full Mem0 memory server with local models.
- Requires `mem0ai` package
- Provides memory storage, search, and retrieval
- Uses Qdrant for vector storage
- **Note:** Embedding model requires GPU

## Hardware Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| RAM | 8 GB | 16 GB |
| Disk | 3 GB free | 5 GB free |
| GPU | **Required** for embeddings | CUDA-compatible GPU (8GB+ VRAM) |
| Hugging Face | Account + Auth | Account + Auth |

**Note:** 
- Vision model can run on CPU or GPU
- **Embedding model (Gemma) requires GPU** - will not start without CUDA
- Gemma model requires Hugging Face authentication

## Troubleshooting

### ImportError: No module named 'transformers'
```bash
pip install transformers torch pillow numpy
```

### Model download fails
1. Check internet connection
2. Ensure you have enough disk space (~3GB)
3. Verify Hugging Face authentication: `huggingface-cli whoami`
4. Accept Gemma license at https://huggingface.co/google/embeddinggemma-300m-f8
5. Try manual download:
   ```bash
   python -c "from huggingface_hub import snapshot_download; snapshot_download('google/embeddinggemma-300m-f8', local_dir='./models/embeddinggemma-300m-f8')"
   ```

### Out of memory
- Close other applications
- Use CPU instead of GPU by setting: `CUDA_VISIBLE_DEVICES=""`
- Reduce batch size in the code

### Slow inference
- Ensure CUDA is available: `python -c "import torch; print(torch.cuda.is_available())"`
- Use GPU for faster inference
- Models are optimized for inference but still require significant compute

## Model Information

### LFM-2-Vision-450M
- **Provider**: Liquid AI
- **Architecture**: Vision-Language Model
- **Parameters**: 450M
- **Context**: 4096 tokens
- **Use cases**: Image understanding, visual Q&A, chat with images

### Google Embedding Gemma 300M FP8
- **Provider**: Google
- **Type**: Text Embedding Model
- **Dimensions**: 768
- **Max Length**: 8192 tokens
- **Quantization**: FP8 (8-bit floating point)
- **GPU Required**: Yes
- **Use cases**: Semantic search, text similarity, clustering
- **License**: Gemma Terms of Use (requires HF authentication)

## Integration with Existing Code

The local server is OpenAI-compatible, so you can use it with existing clients:

```python
from openai import OpenAI

client = OpenAI(
    base_url="http://localhost:8000/v1",
    api_key="local"  # Not used but required
)

# Embeddings
response = client.embeddings.create(
    model="embeddinggemma-300m-f8",
    input="Hello, world!"
)

# Chat
response = client.chat.completions.create(
    model="lfm-2-vision-450m",
    messages=[{"role": "user", "content": "Hello!"}]
)
```

## License

These scripts are provided as-is. Please check the model licenses on Hugging Face:
- [LFM-2-Vision-450M](https://huggingface.co/LiquidAI/LFM-2-Vision-450M)
- [google/embeddinggemma-300m-f8](https://huggingface.co/google/embeddinggemma-300m-f8) (requires authentication)
