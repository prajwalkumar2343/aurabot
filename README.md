# AuraBot - AI Memory Assistant for macOS

AuraBot is an intelligent screen capture and memory system that learns your context and activities over time. It uses vision AI to understand your screen content and stores meaningful memories using a vector database, enabling you to query your digital history and get AI-assisted responses with personal context.

## How It Works

```
Screen Capture (every 30s) → Vision AI Analysis → Vector Storage → Memory Search → AI Responses
```

1. **Capture**: AuraBot periodically screenshots your screen
2. **Analyze**: Vision AI understands what's on screen
3. **Store**: Memories are embedded and stored in a vector database
4. **Retrieve**: Search your activity history with natural language
5. **Respond**: Get AI-powered answers with your personal context

### Architecture

- **macOS App**: `apps/macos` handles screen capture and user interaction
- **Python Backend**: `services/memory-api` provides the memory API with Postgres/pgvector storage
- **LLM Integration**: OpenRouter for vision and chat capabilities

### Repository Layout

```text
apps/macos/             # SwiftUI macOS app
services/memory-api/    # Python memory API service
tools/                  # Development and demo utilities
config/                 # Example configuration
docs/                   # Project documentation
```

## Prerequisites

- macOS 14.0+ (Sonoma)
- OpenRouter API key ([get one here](https://openrouter.ai/settings/keys))
- Postgres database with pgvector available
- Screen Recording permission (prompted on first launch)

## Getting Started

### 1. Clone and Setup

```bash
git clone https://github.com/prajwalkumar2343/aurabot.git
cd aurabot
```

### 2. Configure Environment

```bash
cp .env.example .env
# Add OPENROUTER_API_KEY and DATABASE_URL to .env
```

### 3. Install Dependencies

```bash
pip install -r services/memory-api/requirements.txt
```

### 4. Start the Backend

```bash
python start.py
```

This starts the memory API server on port 8000.

### 5. Run the App

```bash
cd apps/macos && swift run AuraBot
```

Or download a pre-built release from GitHub Releases and run `python start.py` separately.

## Usage

- **Menu Bar**: Access capture controls, recent memories, and search
- **Cmd+Opt+E**: Enhance selected text with your memory context
- **Search**: Query your activity history with natural language

## Configuration

Key environment variables (see `.env.example`):

| Variable | Description |
|----------|-------------|
| `OPENROUTER_API_KEY` | Your OpenRouter API key (required) |
| `DATABASE_URL` | Postgres connection string for the memory store |
| `AURABOT_MEMORY_API_KEY` | Bearer token required for protected memory API routes |
| `AURABOT_MEMORY_PORT` | Backend server port (default: 8000) |

Capture settings and matching API keys can be adjusted in `~/.aurabot/config.json` after first launch.

## License

MIT License - see [LICENSE](LICENSE) file for details.
