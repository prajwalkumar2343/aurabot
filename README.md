# AuraBot - AI Memory Assistant for macOS

AuraBot is an intelligent screen capture and memory system that learns your context and activities over time. It uses vision AI to understand your screen content and stores meaningful memories using a vector database, enabling you to query your digital history and get AI-assisted responses with personal context.

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Architecture](#architecture)
- [Quick Start](#quick-start)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Configuration](#configuration)
- [Usage](#usage)
- [API Reference](#api-reference)
- [Skills System](#skills-system)
- [Project Structure](#project-structure)
- [Development](#development)
- [Distribution](#distribution)
- [Troubleshooting](#troubleshooting)
- [FAQ](#faq)

---

## Overview

AuraBot solves the problem of fragmented digital memory by continuously capturing your screen activity and building a searchable memory store. Unlike simple screenshot tools, AuraBot:

1. **Analyzes** screen content using vision-capable LLMs
2. **Stores** meaningful context in a vector database
3. **Retrieves** relevant memories when you need them
4. **Responds** with AI assistance that understands your history

### Use Cases

- **Activity Tracking**: Automatically track what you worked on throughout the day
- **Context Search**: Find screenshots or activities from specific times
- **AI Memory**: Ask "What was I working on yesterday?" and get meaningful answers
- **Quick Enhance**: Apply your personal context to any text (Cmd+Opt+E)
- **Productivity Insights**: Understand your work patterns over time

---

## Features

### Core Features

| Feature | Description |
|---------|-------------|
| **Periodic Screen Capture** | Configurable interval screenshots with JPEG/WebP compression |
| **Vision AI Analysis** | LLM-powered understanding of screen content |
| **Vector Memory Storage** | Mem0-powered semantic memory with Qdrant backend |
| **Memory Search** | Natural language search across your activity history |
| **Quick Enhance** | Global hotkey (Cmd+Opt+E) to enhance text with context |
| **Native macOS App** | Built with Swift and SwiftUI for optimal performance |
| **Menu Bar Integration** | Discreet menu bar presence with status indicator |

### Technical Features

| Feature | Description |
|---------|-------------|
| **Local Model Support** | Run without external APIs (optional) |
| **GGUF Classifier** | Filter useless memories before storage |
| **Actor-Based Concurrency** | Thread-safe Swift services |
| **Resource Optimization** | JPEG compression, async processing |
| **CORS Support** | Works with browser extensions |
| **Skills System** | Modular prompt engineering workflows |

---

## Architecture

### System Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              AuraBot                                     │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌─────────────────────┐         ┌──────────────────────────────────┐   │
│  │   macOS App        │         │   Python Backend                  │   │
│  │   (Swift/SwiftUI)  │         │   (Mem0 REST API Server)         │   │
│  │                    │         │                                  │   │
│  │  ┌───────────────┐ │         │  ┌────────────────────────────┐  │   │
│  │  │ ScreenCapture │ │         │  │ Mem0 Memory Server        │  │   │
│  │  │ Service       │──────────▶│  │ - Embeddings API          │  │   │
│  │  └───────────────┘ │ JPEG    │  │ - Chat Completions API    │  │   │
│  │          │         │         │  │ - Memory CRUD API         │  │   │
│  │          ▼         │         │  └────────────┬─────────────┘  │   │
│  │  ┌───────────────┐ │         │               │                 │   │
│  │  │ LLM Service   │ │         │               ▼                 │   │
│  │  │ (OpenRouter) │ │◀────────│  ┌────────────────────────────┐  │   │
│  │  └───────────────┘ │ Vision  │  │ Local Model Manager        │  │   │
│  │          │         │         │  │ - LFM-2-Vision-450M       │  │   │
│  │          ▼         │         │  │ - EmbeddingGemma-300M     │  │   │
│  │  ┌───────────────┐ │         │  └────────────────────────────┘  │   │
│  │  │ Memory       │ │         │                                  │   │
│  │  │ Service      │──────────▶│  ┌────────────────────────────┐  │   │
│  │  └───────────────┘ │ REST    │  │ Qdrant Vector DB          │  │   │
│  │                   │         │  │ (Local Storage)           │  │   │
│  └─────────────────────┘         │  └────────────────────────────┘  │   │
│                                  └──────────────────────────────────┘   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### Data Flow

```
┌────────────────┐     ┌──────────────┐     ┌────────────────┐
│  Screen        │────▶│  JPEG        │────▶│  Vision LLM    │
│  Capture       │     │  Compress    │     │  (Analysis)    │
│  (30s default) │     │  (Quality %) │     │                │
└────────────────┘     └──────────────┘     └───────┬────────┘
                                                    │
                                                    ▼
┌────────────────┐     ┌──────────────┐     ┌────────────────┐
│  Memory        │◀────│  Qdrant      │◀────│  Embedding     │
│  Search        │     │  Vector DB   │     │  (Gemma)       │
└───────┬────────┘     └──────────────┘     └────────────────┘
        │
        ▼
┌────────────────┐     ┌──────────────┐     ┌────────────────┐
│  User Query    │────▶│  Context     │────▶│  Chat LLM      │
│                │     │  Injection  │     │  (Response)    │
└────────────────┘     └──────────────┘     └────────────────┘
```

### Component Responsibilities

#### macOS App (`aurabot-swift/`)

| Component | Responsibility |
|-----------|----------------|
| `ScreenCaptureService` | Periodic screen capture using ScreenCaptureKit |
| `LLMService` | OpenRouter API communication for vision and chat |
| `MemoryService` | REST API calls to Mem0 server |
| `AppService` | Orchestrates all services, manages state |

#### Python Backend (`python/`)

| Component | Responsibility |
|-----------|----------------|
| `mem0_local.py` | Main server entry point |
| `core/local_memory.py` | Mem0 initialization with local models |
| `models/local_manager.py` | Local model loading and inference |
| `api/local_handlers.py` | HTTP request handling |
| `embedders/local.py` | Local embedding provider |

---

## Quick Start

### Option 1: One-Command Setup (Recommended)

```bash
# Clone the repository
git clone https://github.com/prajwalkumar2343/aurabot.git
cd aurabot

# Run the one-command launcher
python start.py
```

This automatically:
1. Checks Hugging Face authentication (prompts if needed)
2. Downloads required AI models
3. Starts the Mem0 server on port 8000

### Option 2: Pre-built App

1. Download `AuraBot-1.0.0.zip` from GitHub Releases
2. Unzip and move to Applications: `mv AuraBot.app /Applications/`
3. First launch: Right-click → Open → Click "Open"
4. Grant Screen Recording permission when prompted
5. Start the Python backend: `python start.py`

---

## Prerequisites

### System Requirements

| Requirement | Minimum | Recommended |
|-------------|---------|-------------|
| macOS Version | 14.0+ (Sonoma) | Latest |
| RAM | 8 GB | 16 GB |
| Storage | 2 GB free | 5 GB free |
| GPU | Optional | NVIDIA CUDA (for local models) |

### Required Accounts

| Account | Purpose | Signup |
|---------|---------|--------|
| OpenRouter API Key | Vision and chat LLM access | https://openrouter.ai/settings/keys |
| Hugging Face (optional) | Download Gemma embedding model | https://huggingface.co/ |

### Permissions Required

| Permission | Purpose | How to Grant |
|------------|---------|--------------|
| Screen Recording | Capture screenshots | System Settings → Privacy & Security → Screen Recording |
| Accessibility (optional) | Detect selected text for Quick Enhance | System Settings → Privacy & Security → Accessibility |

---

## Installation

### Step 1: Clone Repository

```bash
git clone https://github.com/prajwalkumar2343/aurabot.git
cd aurabot
```

### Step 2: Get OpenRouter API Key

1. Visit https://openrouter.ai/settings/keys
2. Create a new API key
3. Copy the key (you'll add it to `.env`)

### Step 3: Configure Environment

```bash
# Copy the example environment file
cp .env.example .env

# Edit with your API key
nano .env
```

Add your OpenRouter API key:
```bash
OPENROUTER_API_KEY=sk-or-v1-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

### Step 4: Install Python Dependencies

```bash
# Using make
make deps-py

# Or directly
pip install -r python/requirements.txt
```

### Step 5: Run Setup Script

```bash
# This downloads AI models automatically
python scripts/auto_setup.py
```

The setup script will:
1. Check/configure Hugging Face authentication
2. Download `google/embeddinggemma-300m-f8` (embedding model)
3. Download `LiquidAI/LFM-2-Vision-450M` (vision model)
4. Verify system requirements (CUDA for local inference)

### Step 6: Start Services

```bash
# Terminal 1: Start Mem0 server
python start.py

# Terminal 2: Run macOS app (if building from source)
cd aurabot-swift && swift run AuraBot
```

---

## Configuration

### Environment Variables (`.env`)

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `OPENROUTER_API_KEY` | Yes | - | OpenRouter API key for LLM access |
| `OPENROUTER_BASE_URL` | No | `https://openrouter.ai/api/v1` | OpenRouter endpoint |
| `OPENROUTER_VISION_MODEL` | No | `google/gemini-flash-1.5` | Vision model identifier |
| `OPENROUTER_CHAT_MODEL` | No | `anthropic/claude-3.5-sonnet` | Chat model identifier |
| `OPENROUTER_EMBEDDING_MODEL` | No | `openai/text-embedding-3-small` | Embedding model identifier |
| `MEM0_HOST` | No | `localhost` | Mem0 server host |
| `MEM0_PORT` | No | `8000` | Mem0 server port |
| `MODELS_DIR` | No | `./models` | Local model storage path |
| `LM_STUDIO_URL` | No | `http://localhost:1234` | LM Studio server URL |
| `CEREBRAS_API_KEY` | No | - | Cerebras API key (alternative) |

### YAML Configuration (`config/config.yaml`)

For advanced users, detailed YAML configuration is available:

```yaml
# Screen capture configuration
capture:
  interval_seconds: 30          # Capture interval (seconds)
  quality: 60                   # JPEG quality (1-100)
  format: webp                  # Image format: webp or jpeg
  max_width: 1280               # Max screenshot width
  max_height: 720               # Max screenshot height
  enabled: true                 # Start capturing on launch

# LLM Configuration
llm:
  provider: "openrouter"        # openai, anthropic, cerebras, ollama, lm-studio
  base_url: "https://openrouter.ai/api/v1"
  api_key: ""                   # Loaded from OPENROUTER_API_KEY
  model: "anthropic/claude-3.5-sonnet"
  max_tokens: 512
  temperature: 0.7

# Vision Configuration
vision:
  provider: "openrouter"
  base_url: "https://openrouter.ai/api/v1"
  model: "google/gemini-flash-1.5"

# Embeddings Configuration
embeddings:
  provider: "openrouter"
  model: "openai/text-embedding-3-small"
  dimensions: 1536

# Mem0 Configuration
memory:
  api_key: ""                   # Leave empty for local
  base_url: "http://localhost:8000"
  user_id: "default_user"
  collection_name: "screen_memories"

# App Behavior
app:
  verbose: false               # Enable debug logging
  process_on_capture: true      # Analyze each capture
  memory_window: 10             # Context memories to include
```

### Swift App Configuration

The macOS app loads configuration from `~/.aurabot/config.json`:

```json
{
  "capture": {
    "intervalSeconds": 30,
    "quality": 60,
    "maxWidth": 1280,
    "maxHeight": 720,
    "enabled": true
  },
  "llm": {
    "baseURL": "https://openrouter.ai/api/v1",
    "model": "google/gemini-flash-1.5",
    "maxTokens": 512,
    "temperature": 0.7,
    "timeoutSeconds": 30
  },
  "memory": {
    "baseURL": "http://localhost:8000",
    "userID": "default_user",
    "collectionName": "screen_memories_v3"
  },
  "app": {
    "verbose": false,
    "processOnCapture": true,
    "memoryWindow": 10
  }
}
```

---

## Usage

### Starting the Backend

```bash
# Standard start (runs setup if needed)
python start.py

# Skip setup and start directly
python start.py --skip-setup

# Run setup only
python start.py --setup-only
```

The backend server provides these endpoints:

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Health check |
| `/v1/models` | GET | List available models |
| `/v1/embeddings` | POST | Create text embeddings |
| `/v1/chat/completions` | POST | Chat completion |
| `/v1/memories/` | GET | Get all memories |
| `/v1/memories/` | POST | Add new memory |
| `/v1/memories/search/` | POST | Search memories |
| `/v1/memories/{id}` | DELETE | Delete memory |

### Running the macOS App

```bash
# Build and run
cd aurabot-swift
swift build
swift run AuraBot

# Or build app bundle
./scripts/build-app.sh
```

### Quick Enhance Feature

Press **Cmd+Opt+E** to enhance any selected text with your memory context. The system will:

1. Search your memory for relevant context
2. Inject context into the LLM prompt
3. Return an enhanced version of your text

### Menu Bar Features

| Menu Item | Action |
|-----------|--------|
| Start/Stop Capture | Toggle screen capture |
| Recent Memories | View recent activity |
| Search Memory | Natural language search |
| Settings | Configure app behavior |
| Quit | Exit application |

---

## API Reference

### Health Check

```bash
curl http://localhost:8000/health
```

Response:
```json
{
  "status": "ok",
  "timestamp": "2024-01-15T10:30:00",
  "llm_provider": "local (lfm-2-vision-450m)",
  "embedder_provider": "local (nomic-embed-text-v1.5)",
  "vector_store": "qdrant"
}
```

### List Models

```bash
curl http://localhost:8000/v1/models
```

Response:
```json
{
  "object": "list",
  "data": [
    {"id": "nomic-embed-text-v1.5", "object": "model", "owned_by": "local"},
    {"id": "lfm-2-vision-450m", "object": "model", "owned_by": "local"}
  ]
}
```

### Create Embeddings

```bash
curl -X POST http://localhost:8000/v1/embeddings \
  -H "Content-Type: application/json" \
  -d '{
    "input": ["Hello, world!", "How are you?"],
    "model": "nomic-embed-text-v1.5"
  }'
```

Response:
```json
{
  "object": "list",
  "data": [
    {"object": "embedding", "embedding": [0.123, ...], "index": 0},
    {"object": "embedding", "embedding": [0.456, ...], "index": 1}
  ],
  "model": "nomic-embed-text-v1.5",
  "usage": {"prompt_tokens": 2, "total_tokens": 2}
}
```

### Chat Completions

```bash
curl -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "lfm-2-vision-450m",
    "messages": [
      {"role": "system", "content": "You are a helpful assistant."},
      {"role": "user", "content": "Hello!"}
    ],
    "max_tokens": 512
  }'
```

### Add Memory

```bash
curl -X POST http://localhost:8000/v1/memories/ \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [
      {"role": "user", "content": "I need to finish the project by Friday"}
    ],
    "user_id": "default_user",
    "metadata": {
      "context": "work",
      "activities": ["coding", "meeting"],
      "timestamp": "2024-01-15T10:30:00Z"
    }
  }'
```

Response:
```json
{
  "id": "mem_abc123",
  "content": "I need to finish the project by Friday",
  "user_id": "default_user",
  "metadata": {"context": "work", "activities": ["coding"]},
  "created_at": "2024-01-15T10:30:00"
}
```

### Search Memories

```bash
curl -X POST http://localhost:8000/v1/memories/search/ \
  -H "Content-Type: application/json" \
  -d '{
    "query": "project deadline",
    "user_id": "default_user",
    "limit": 5
  }'
```

Response:
```json
{
  "results": [
    {
      "id": "mem_abc123",
      "memory": "I need to finish the project by Friday",
      "score": 0.95,
      "distance": 0.05,
      "metadata": {"context": "work"}
    }
  ]
}
```

### Get All Memories

```bash
curl "http://localhost:8000/v1/memories/?user_id=default_user&limit=10"
```

---

## Skills System

AuraBot includes a modular skills system for specialized workflows. Skills are located in the `skills/` directory.

### Available Skills

| Skill | Purpose | When to Use |
|-------|---------|-------------|
| `skill-routing` | Route requests to specialized skills | First skill to check |
| `product-manager` | Product development workflow | Product ideas, MVP planning |
| `investigate` | Systematic debugging | Bugs, errors, crashes |
| `ship` | Deployment workflow | Ship features, create PRs |
| `review` | Code review | Validate code quality |
| `document-release` | Documentation workflow | Update docs after shipping |
| `design-review` | Visual design review | UI/UX audits |
| `design-consultation` | Design system guidance | Brand, design systems |

### Skill Routing

The `skill-routing` skill automatically routes requests:

| Request Type | Routes To |
|--------------|-----------|
| Product ideas, brainstorming | `product-manager` |
| Bugs, errors, "why broken" | `investigate` |
| Ship, deploy, push, create PR | `ship` |
| Code review, check diff | `review` |
| Update docs after shipping | `document-release` |
| Visual audit, design polish | `design-review` |
| Design systems, brand | `design-consultation` |
| Save progress, checkpoint | `checkpoint` |
| Code quality, health check | `health` |

### Using Skills

Skills are invoked by the AI system based on request content. The skill-routing system automatically detects the appropriate skill to use.

---

## Project Structure

```
aurabot/
├── README.md                      # This file
├── Makefile                      # Build automation
├── .env.example                  # Environment template
├── .gitignore                    # Git ignore patterns
├── LICENSE                       # MIT License
│
├── config/
│   └── config.yaml.example       # YAML configuration template
│
├── docs/
│   └── GGUF_CLASSIFIER.md        # GGUF classifier documentation
│
├── scripts/
│   ├── auto_setup.py            # One-command setup script
│   └── download_models.py       # Model download utility
│
├── python/                       # Python Backend
│   ├── requirements.txt         # Python dependencies
│   ├── src/
│   │   ├── mem0_local.py        # Main server entry
│   │   ├── config.py            # Configuration loader
│   │   ├── core/
│   │   │   └── local_memory.py  # Mem0 initialization
│   │   ├── models/
│   │   │   └── local_manager.py # Local model inference
│   │   ├── api/
│   │   │   ├── local_handlers.py # HTTP request handlers
│   │   │   ├── memoryMixin.py    # Memory endpoints
│   │   │   ├── embeddingsMixin.py # Embeddings endpoints
│   │   │   └── chatMixin.py      # Chat endpoints
│   │   ├── embedders/
│   │   │   └── local.py          # Local embedder
│   │   └── providers/            # LLM provider abstractions
│   └── tests/                    # Python tests
│
├── swift-mem0/                   # Swift Mem0 Client Package
│   ├── Package.swift            # Swift Package Manager config
│   └── Sources/Mem0/
│       └── Mem0.swift           # Swift client implementation
│
├── aurabot-swift/                # macOS Native App
│   ├── Package.swift            # Swift Package dependencies
│   ├── Makefile                 # Swift build config
│   ├── scripts/
│   │   └── build-app.sh         # App bundle builder
│   ├── DISTRIBUTION.md          # Distribution guide
│   ├── INSTALL.txt              # Installation instructions
│   └── Sources/AuraBot/
│       ├── main.swift            # App entry point
│       ├── AuraBotApp.swift     # SwiftUI App
│       ├── Core/
│       │   └── AppDelegate.swift # App lifecycle
│       ├── Models/
│       │   ├── Config.swift      # Configuration models
│       │   ├── Memory.swift      # Memory data models
│       │   └── ScreenCapture.swift # Screen capture models
│       ├── Services/
│       │   ├── AppService.swift        # Main orchestrator
│       │   ├── LLMService.swift        # LLM API client
│       │   ├── MemoryService.swift     # Memory API client
│       │   └── ScreenCaptureService.swift # Screen capture
│       ├── UI/
│       │   ├── Components/      # Reusable UI components
│       │   ├── Screens/         # Main screen views
│       │   └── Design/          # Theme and animations
│       └── Utils/               # Utility functions
│
└── skills/                      # Skills System
    ├── skill-routing/
    │   └── SKILL.md            # Routing skill
    ├── product-manager/
    │   └── SKILL.md            # Product development skill
    ├── investigate/
    │   └── SKILL.md            # Debugging skill
    ├── ship/
    │   └── SKILL.md            # Deployment skill
    ├── review/
    │   └── SKILL.md            # Code review skill
    ├── document-release/
    │   └── SKILL.md            # Documentation skill
    ├── design-review/
    │   └── SKILL.md            # Design review skill
    └── design-consultation/
        └── SKILL.md            # Design consultation skill
```

---

## Development

### Building the macOS App

```bash
# Using Make
make build-app

# Manual build
cd aurabot-swift
swift build -c release

# Run development version
swift run AuraBot
```

### Running Tests

```bash
# All tests
make test

# Python tests
make test-py

# With coverage
make test-coverage
```

### Cleaning Build Artifacts

```bash
# Clean all
make clean

# Clean Swift only
make clean-swift
```

### Installing Dependencies

```bash
# All dependencies
make deps-all

# Python only
make deps-py

# Swift only
make deps
```

### Environment Setup for Development

1. Copy environment template:
   ```bash
   cp .env.example .env
   ```

2. Configure your API keys in `.env`

3. Install Python dependencies:
   ```bash
   pip install -r python/requirements.txt
   ```

4. Run auto-setup for models:
   ```bash
   python scripts/auto_setup.py
   ```

### Local Model Configuration

To use local models instead of OpenRouter:

1. Set up Ollama or LM Studio
2. Export the server URL:
   ```bash
   export LM_STUDIO_URL="http://localhost:1234"
   ```
3. Models will be used from the configured local server

### GGUF Memory Classifier

For storage optimization, use the GGUF classifier to filter memories:

See [docs/GGUF_CLASSIFIER.md](docs/GGUF_CLASSIFIER.md) for detailed setup.

---

## Distribution

### Building for Distribution

```bash
cd aurabot-swift
./scripts/build-app.sh
```

This creates:
- `AuraBot.app/` - Application bundle
- `AuraBot-1.0.0.zip` - Distributable archive

### Installing Pre-built App

1. Download `AuraBot-1.0.0.zip`
2. Unzip (double-click)
3. Move to Applications: `mv AuraBot.app /Applications/`
4. First launch: Right-click → Open → Click "Open" (macOS security)

### Terminal Fix for Gatekeeper

```bash
xattr -cr /Applications/AuraBot.app
open /Applications/AuraBot.app
```

---

## Troubleshooting

### "No active displays found"

**Cause**: Screen recording permission not granted

**Solution**:
1. Go to System Settings → Privacy & Security → Screen Recording
2. Enable AuraBot
3. Restart the application

### "OpenRouter API error"

**Cause**: Invalid or missing API key

**Solution**:
1. Verify `OPENROUTER_API_KEY` in `.env`
2. Check OpenRouter account has credits at https://openrouter.ai/credits
3. Ensure API key is valid at https://openrouter.ai/settings/keys

### "Mem0 not available"

**Cause**: Backend server not running

**Solution**:
1. Start Mem0 server: `python start.py`
2. Check port 8000 is free: `lsof -i :8000`
3. Verify server is running: `curl http://localhost:8000/health`

### "GPU required for embedding model"

**Cause**: CUDA GPU not available

**Solution**:
1. Install PyTorch with CUDA: `pip install torch --index-url https://download.pytorch.org/whl/cu118`
2. Or use CPU-only mode with OpenRouter embeddings

### "Hugging Face authentication failed"

**Cause**: Not logged into Hugging Face or terms not accepted

**Solution**:
1. Visit https://huggingface.co/settings/tokens
2. Create a read token
3. Run `huggingface-cli login`
4. Accept Gemma terms at https://huggingface.co/google/embeddinggemma-300m-f8

### Memory classifier not working

**Cause**: GGUF server not running or misconfigured

**Solution**:
1. Start Ollama: `ollama serve`
2. Verify classifier model: `curl http://localhost:11434/api/tags`
3. Check `CLASSIFIER_URL` environment variable

### Slow performance

**Cause**: CPU inference or network latency

**Solutions**:
1. Enable CUDA for local models
2. Increase capture interval in settings
3. Lower JPEG quality
4. Use local LLM instead of OpenRouter

---

## FAQ

### Q: How does AuraBot protect privacy?

A: All processing can happen locally:
- Screenshots stay on your machine
- Local models (LFM-2-Vision, Gemma) don't send data externally
- OpenRouter is optional for cloud LLM access
- Mem0 with Qdrant stores data locally

### Q: Can I use AuraBot without internet?

A: Yes! Enable "Local Mode":
1. Start Ollama or LM Studio locally
2. Configure `LM_STUDIO_URL` in `.env`
3. All inference runs locally

### Q: How much storage does it use?

A: Depends on capture frequency:
- 1 screenshot per minute: ~50MB/day
- 1 screenshot per 30 seconds: ~100MB/day
- Mem0 vector storage: ~10KB per memory

### Q: Can I use different LLM providers?

A: Yes! Supported providers:
- OpenRouter (default)
- Cerebras
- LM Studio
- Ollama
- OpenAI (compatible APIs)

### Q: How do I export my memories?

A: Use the API:
```bash
curl "http://localhost:8000/v1/memories/?user_id=default_user&limit=1000" > memories.json
```

### Q: Can multiple users share the same installation?

A: Yes! Use different `user_id` values:
```bash
# User A
MEMORY_USER_ID=user_a

# User B
MEMORY_USER_ID=user_b
```

### Q: Does AuraBot work with multiple monitors?

A: Currently captures the primary display. Multi-monitor support is planned.

---

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Contributing

Contributions welcome! Please read the existing code style and submit PRs with tests.

## Support

- Issues: https://github.com/prajwalkumar2343/aurabot/issues
- Discussions: https://github.com/prajwalkumar2343/aurabot/discussions
