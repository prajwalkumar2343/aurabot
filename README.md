# AuraBot - AI Memory Assistant for macOS

An AI-powered screen capture and memory system that learns who you are and understands your context using OpenRouter API and Mem0 for memory embeddings.

## Features

- **Periodic Screen Capture**: Configurable interval screenshots with compression
- **Vision AI**: Analyzes screen content using vision-capable LLMs
- **Memory System**: Stores context and activities using Mem0 embeddings
- **Quick Enhance**: Enhance any text with your memory context (⌘⌥E)
- **Native macOS App**: Built with Swift and SwiftUI
- **Resource Efficient**: JPEG compression, async processing

## Architecture

```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│   Screen    │────▶│  Compressed  │────▶│   Vision    │
│   Capture   │     │    (JPEG)    │     │     LLM     │
└─────────────┘     └──────────────┘     └──────┬──────┘
                                                 │
                                                 ▼
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│   Search    │◀────│    Mem0      │◀────│   Context   │
│   Memory    │     │   Vector DB  │     │   Store     │
└─────────────┘     └──────────────┘     └─────────────┘
```

## Requirements

- macOS 14.0+
- Xcode 15.0+ (for building)
- Swift 5.9+
- OpenRouter API Key

## Prerequisites

### 1. OpenRouter API Key
Get your API key from https://openrouter.ai/settings/keys

### 2. Mem0 Server

**One-Command Setup:**
```bash
python start.py
```

This will:
1. Check Hugging Face authentication (prompts if needed)
2. Download required models automatically
3. Start the Mem0 server

**Manual Setup:**
```bash
# Install dependencies
pip install -r python/requirements.txt

# Run automatic setup
python scripts/auto_setup.py

# Start the server
python start.py --skip-setup
```

## Installation

### Download Pre-built App

Download the latest release from GitHub Releases:
```bash
# Download AuraBot-1.0.0.zip from releases
# Unzip and drag to Applications
```

### Build from Source

```bash
# Clone the repository
git clone <repo-url>
cd aurabot

# Build with Swift Package Manager
cd aurabot-swift
swift build -c release

# Or use the build script
./scripts/build-app.sh
```

## Configuration

Copy `.env.example` to `.env` and add your OpenRouter API key:

```bash
# Required: OpenRouter API Key
OPENROUTER_API_KEY=your_api_key_here

# Optional: Model configuration
OPENROUTER_VISION_MODEL=google/gemini-flash-1.5
OPENROUTER_CHAT_MODEL=anthropic/claude-3.5-sonnet
OPENROUTER_EMBEDDING_MODEL=openai/text-embedding-3-small

# Mem0 Server
MEM0_HOST=localhost
MEM0_PORT=8000
```

Or use `config/config.yaml.example` as a reference for YAML configuration.

### Environment Variables
- `OPENROUTER_API_KEY`: Your OpenRouter API key (required)
- `OPENROUTER_BASE_URL`: Override OpenRouter endpoint
- `MEM0_HOST`: Mem0 server host (default: localhost)
- `MEM0_PORT`: Mem0 server port (default: 8000)

## Usage

### macOS App (Recommended)

Native Swift application with ScreenCaptureKit:

```bash
cd aurabot-swift

# Build with Swift Package Manager
swift build

# Run the app
swift run AuraBot
```

Features:
- **Screen Capture** - Periodic screenshots using ScreenCaptureKit
- **Quick Enhance** - Global hotkey (⌘⌥E) to enhance any text
- **Floating Overlay** - System-wide floating button
- **Native UI** - SwiftUI interface

### How It Works

1. **Captures screen** every N seconds (configurable)
2. **Compresses** to JPEG (configurable quality)
3. **Sends to Vision LLM** for analysis
4. **Stores in Mem0** with metadata (context, activities, intent)
5. **Builds context** over time to understand you better

### Chat with Context

The service maintains a memory of your activities. You can query it:

```swift
response = try await service.chat(message: "What was I working on earlier?")
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
├── docs/                        # Setup guides
├── scripts/                     # Setup & utility scripts
│   ├── auto_setup.py
│   └── download_models.py
├── python/                      # Python source code
│   ├── requirements.txt
│   └── src/
│       ├── mem0_local.py        # Mem0 with local models
│       ├── mem0_server.py       # Mem0 server
│       ├── local_server.py      # Local model server
│       ├── core/                # Core services
│       ├── api/                 # API handlers
│       ├── providers/           # LLM providers
│       └── embedders/           # Embedding services
├── go/                          # Go source code
│   ├── go.mod
│   ├── main.go                  # Entry point (CLI service)
│   └── internal/
│       ├── config/              # Configuration management
│       ├── capture/             # Screen capture
│       ├── llm/                 # LLM client
│       ├── memory/              # Mem0 integration
│       ├── service/             # Orchestrator
│       ├── enhancer/            # Prompt enhancement
│       ├── overlay/             # Overlay window
│       └── server/              # HTTP API server
└── aurabot-swift/              # Native macOS app (Swift)
    ├── Package.swift
    ├── scripts/
    │   └── build-app.sh         # Build script
    ├── DISTRIBUTION.md          # Distribution guide
    └── Sources/AuraBot/
        ├── Core/               # App lifecycle
        ├── Models/             # Data models
        ├── Services/           # Business logic
        ├── UI/                # SwiftUI views
        └── Utils/             # Utilities
```

## Platform Notes

### macOS
- **Required**: macOS 14.0+
- Requires screen recording permission
- Go to System Settings > Privacy & Security > Screen Recording

## Troubleshooting

### "No active displays found"
- Check display/screen recording permissions
- Restart the application

### "OpenRouter API error"
- Verify OPENROUTER_API_KEY is set correctly
- Check your OpenRouter account has available credits
- Ensure the API key is valid at https://openrouter.ai/settings/keys

### "Mem0 not available"
- Start Mem0 server: `python start.py`
- Check the URL in config
- Verify port 8000 is free

## License

MIT
