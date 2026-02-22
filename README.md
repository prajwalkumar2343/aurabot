# Screen Memory Assistant

An AI-powered screen capture and memory system that learns who you are and understands your context using local LLM (Liquid 450M via LM Studio) and Mem0 for memory embeddings.

## Features

- **Periodic Screen Capture**: Configurable interval screenshots with compression
- **Vision AI**: Analyzes screen content using local LLM
- **Memory System**: Stores context and activities using Mem0 embeddings
- **Browser Extension**: Enhance AI prompts on ChatGPT, Claude, Gemini with your memories
- **Cross-Platform**: Optimized for macOS, works on Windows
- **Resource Efficient**: JPEG compression, async processing

## Architecture

```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│   Screen    │────▶│  Compressed  │────▶│    LLM      │
│   Capture   │     │    (JPEG)    │     │   Vision    │
└─────────────┘     └──────────────┘     └──────┬──────┘
                                                │
                                                ▼
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│   Search    │◀────│    Mem0      │◀────│   Context   │
│   Memory    │     │   Vector DB  │     │   Store     │
└─────────────┘     └──────────────┘     └─────────────┘
      │
      │ HTTP API
      ▼
┌──────────────────────────────────────────────────────┐
│                 Browser Extension                     │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐ │
│  │ ChatGPT │  │ Claude  │  │ Gemini  │  │Perplexity│ │
│  └─────────┘  └─────────┘  └─────────┘  └─────────┘ │
└──────────────────────────────────────────────────────┘
```

## Prerequisites

### 1. Go 1.21+
Install from https://go.dev/dl/

### 2. LLM Backend (Choose one)

#### Option A: Local Models (No External Dependencies) ⭐ Recommended
Run models completely locally without LM Studio or external APIs.

**One-Command Setup (Recommended):**
```bash
# Just run this - it handles everything automatically
python start.py
```

This will:
1. Check Hugging Face authentication (prompts if needed)
2. Download required models automatically
3. Verify GPU requirements
4. Start the server

**Manual Setup (if you prefer):**
```bash
# Install dependencies
pip install -r python/requirements.txt

# Run automatic setup (auth + download)
python scripts/auto_setup.py

# Start the server
python start.py --skip-setup
```

**Models included:**
- `LFM-2-Vision-450M` - Vision-language model for chat and image understanding
- `google/embeddinggemma-300m-f8` - Text embeddings for memory/search (GPU required)

See [docs/LOCAL_MODELS.md](docs/LOCAL_MODELS.md) for detailed documentation.

#### Option B: LM Studio
- Download: https://lmstudio.ai/
- Load your Liquid 450M model (or any vision-capable model)
- Start the local server (default: http://localhost:1234)

### 3. Mem0 Server

Mem0 requires a REST API server. Choose one:

**With Local Models:**
```bash
python start.py
```

**With LM Studio (if using Option B above):**
```bash
pip install mem0ai requests
cd python/src && python mem0_server.py
```

Mem0 server will start on http://localhost:8000

## Installation

```bash
# Clone the repository
git clone <repo-url>
cd screen-memory-assistant

# Install Mem0 (Python required)
pip install mem0ai

# Download Go dependencies
cd go && go mod download

# Build
make build-go

# Or build for specific platform
make build-macos
make build-windows
```

## Configuration

Copy `config/config.yaml.example` to `config/config.yaml` and edit, or set environment variables:

```yaml
# Screen capture
capture:
  interval_seconds: 30    # How often to capture
  quality: 85             # JPEG quality (1-100)
  enabled: true

# LM Studio
llm:
  base_url: "http://localhost:1234/v1"
  model: "local-model"
  max_tokens: 512
  temperature: 0.7

# Mem0
memory:
  base_url: "http://localhost:8000"
  user_id: "default_user"
  collection_name: "screen_memories"
```

### Environment Variables
- `LM_STUDIO_URL`: Override LM Studio endpoint
- `MEM0_URL`: Override Mem0 endpoint
- `MEM0_API_KEY`: API key for Mem0 (if using cloud)

## Usage

### Desktop App (Recommended)

Build and run the native desktop application:

```bash
# Install Wails CLI (one-time)
go install github.com/wailsapp/wails/v2/cmd/wails@latest

# Run in development mode
make dev-app

# Build for Windows (.exe)
make build-app-windows

# Build for macOS (.app)
make build-app-macos
```

The desktop app provides:
- 📊 **Dashboard** - Visual overview of your memories and system status
- 💾 **Memories Browser** - Search and browse captured memories
- 💬 **Chat Interface** - Talk to your memory assistant
- 🔌 **Extension API** - HTTP server for browser extension (port 7345)
- ⚙️ **Settings UI** - Configure without editing config files

### Browser Extension

Enhance your AI prompts on ChatGPT, Claude, Gemini, and Perplexity with your saved memories.

**1. Install the Extension:**
```bash
# Chrome/Edge
1. Open chrome://extensions/
2. Enable "Developer mode"
3. Click "Load unpacked"
4. Select the `extension/chrome` folder
```

**2. How to Use:**
1. Start the AuraBot desktop app (extension API runs automatically on port 7345)
2. Visit ChatGPT, Claude, Gemini, or Perplexity
3. Type your prompt
4. Click the "Enhance" button next to the input field
5. Your prompt will be enriched with relevant memories from your history

**Supported Platforms:**
- ✅ ChatGPT (chat.openai.com, chatgpt.com)
- ✅ Claude (claude.ai)
- ✅ Gemini (gemini.google.com)
- ✅ Perplexity (perplexity.ai)

See [extension/README.md](extension/README.md) for detailed setup and troubleshooting.

### Start the Service (CLI Mode)

```bash
# Run Mem0 server with local models (auto-setup included)
python start.py

# Run Go service (requires mem0 server running)
cd go && go run .

# Or use make
make run-go

# With verbose logging
make dev-go
```

### How It Works

1. **Captures screen** every N seconds (configurable)
2. **Compresses** to JPEG (85% quality by default)
3. **Sends to LLM** for vision analysis
4. **Stores in Mem0** with metadata (context, activities, intent)
5. **Builds context** over time to understand you better

### Chat with Context

The service maintains a memory of your activities. You can query it:

```go
response, err := svc.Chat(ctx, "What was I working on earlier?")
```

## Testing

```bash
# Run all tests
make test

# With coverage
make test-coverage
```

## Resource Optimization

- **JPEG compression**: Reduces payload size significantly
- **Async processing**: Non-blocking capture and analysis
- **Configurable intervals**: Balance between insight and resource usage

## Project Structure

```
aurabot/
├── README.md                    # Project overview
├── Makefile                     # Build automation
├── .env.example                 # Environment template
├── config/
│   └── config.yaml.example      # Configuration template
├── docs/
│   └── LOCAL_MODELS.md          # Local models documentation
├── extension/                   # Browser extension
│   ├── README.md                # Extension documentation
│   └── chrome/                  # Chrome/Edge extension
│       ├── manifest.json
│       ├── content.js           # Injects enhance button
│       ├── styles.css
│       ├── popup.html
│       ├── popup.js
│       └── icons/
├── scripts/                     # Setup & utility scripts
│   ├── download_models.py
│   ├── setup_local_models.sh
│   └── setup_local_models.bat
├── python/                      # Python source code
│   ├── requirements.txt
│   ├── src/                     # Python modules
│   │   ├── __init__.py
│   │   ├── mem0_local.py        # Mem0 with local models
│   │   ├── mem0_server.py       # Mem0 server
│   │   └── local_model_server.py # Local model server
│   └── tests/                   # Python tests
└── go/                          # Go source code
    ├── go.mod
    ├── go.sum
    ├── main.go                  # Entry point (CLI service)
    ├── cmd/
    │   ├── chat/                # Chat CLI tool
    │   │   └── main.go
    │   └── app/                 # Desktop app (Wails)
    │       ├── main.go
    │       ├── app.go
    │       ├── app_test.go
    │       └── frontend/
    │           └── dist/
    │               ├── index.html
    │               ├── style.css
    │               └── app.js
    └── internal/
        ├── config/              # Configuration management
        ├── capture/             # Screen capture
        ├── llm/                 # LLM client
        ├── memory/              # Mem0 integration
        ├── service/             # Orchestrator
        ├── enhancer/            # Prompt enhancement
        └── server/              # Extension HTTP API server
```

## Platform Notes

### macOS
- Optimized for macOS
- Requires screen recording permission
- Go to System Preferences > Security & Privacy > Screen Recording

### Windows
- Requires Windows 10/11
- May need graphics drivers for screenshot library

## Troubleshooting

### "No active displays found"
- Check display permissions
- Restart the application

### "LLM not available"
- Verify LM Studio is running
- Check the URL in config
- Ensure a model is loaded

### "Mem0 not available"
- Start Mem0 server: `mem0 server`
- Check the URL in config
- Verify port 8000 is free

## License

MIT
