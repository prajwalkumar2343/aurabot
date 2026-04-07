# Mem0 Desktop App

A native desktop application for the Mem0 Screen Memory Assistant, built with [Wails](https://wails.io/).

## Features

- 🖥️ **Dashboard** - Overview of system status and recent memories
- 💾 **Memories** - Browse and search your captured screen memories
- 💬 **Chat** - Interact with your memories using natural language
- ⚙️ **Settings** - Configure capture interval, quality, and more

## Screenshots

```
┌─────────────────────────────────────────────────────────────┐
│  🧠 Mem0                                                    │
│  ─────────────────────────────────────────────────────────  │
│  📊 Dashboard  │  Dashboard                                 │
│  💾 Memories   │  Overview of your screen memory system     │
│  💬 Chat       │                                            │
│  ⚙️ Settings   │  ┌─────────┐ ┌─────────┐ ┌─────────┐      │
│                │  │Memories │ │ Capture │ │  Last   │      │
│  ───────────── │  │Stored   │ │Interval │ │Activity │      │
│                │  │   42    │ │   30s   │ │Coding...│      │
│  ● Capture     │  └─────────┘ └─────────┘ └─────────┘      │
│  ● LLM         │                                            │
│  ● Mem0        │  Recent Memories                           │
│                │  ┌─────────────────────────────────────┐   │
│                │  │ User was working on code editor...  │   │
│                │  │ 5 minutes ago • Coding session      │   │
│                │  └─────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## Prerequisites

1. **Go 1.22+** - https://go.dev/dl/
2. **Wails CLI** - Install with:
   ```bash
   go install github.com/wailsapp/wails/v2/cmd/wails@latest
   ```

## Development

From the project root (`mem0/` directory):

```bash
# Navigate to the app
cd go/cmd/app

# Run in development mode with hot reload
wails dev
```

Or from the project root using Make:

```bash
# Run the desktop app in dev mode
make dev-app
```

## Building

### Windows (.exe)

```bash
# Build for Windows (from mem0/go/cmd/app)
cd mem0/go/cmd/app
wails build -platform windows/amd64

# Output: mem0/go/cmd/app/build/bin/mem0.exe
```

Or using Make from the project root:

```bash
cd mem0
make build-app-windows
```

### macOS (.app/.dmg)

```bash
# Build for macOS (from mem0/go/cmd/app)
cd mem0/go/cmd/app

# For Apple Silicon (M1/M2/M3)
wails build -platform darwin/arm64

# For Intel Macs
wails build -platform darwin/amd64

# Universal binary (both architectures)
wails build -platform darwin/universal

# Output: mem0/go/cmd/app/build/bin/Mem0.app
```

Or using Make:

```bash
cd mem0
make build-app-macos
```

### Linux (AppImage)

```bash
# Build for Linux (from mem0/go/cmd/app)
cd mem0/go/cmd/app
wails build -platform linux/amd64

# Output: mem0/go/cmd/app/build/bin/mem0
```

## Project Structure

```
mem0/go/cmd/app/
├── main.go              # Entry point
├── app.go               # App logic and Wails bindings
├── app_test.go          # Tests
├── wails.json           # Wails configuration (auto-generated)
├── frontend/
│   └── dist/            # Static frontend files
│       ├── index.html   # Main HTML
│       ├── style.css    # Styles
│       └── app.js       # JavaScript app
└── build/               # Build output
    └── bin/
        ├── mem0.exe     # Windows executable
        └── Mem0.app/    # macOS app bundle
```

## Configuration

The app uses the same configuration as the core mem0 service:

- **Config file:** `config/config.yaml` (relative to where you run the app)
- **Environment variables:** Supported (see main README)

## API Bindings

The following Go functions are exposed to the frontend via Wails:

| Function | Description | Returns |
|----------|-------------|---------|
| `GetStatus()` | Get current service status | `map[string]interface{}` |
| `Chat(message)` | Send a chat message | `string, error` |
| `GetConfig()` | Get current configuration | `map[string]interface{}` |
| `UpdateConfig(settings)` | Update configuration | `error` |
| `GetMemories(limit)` | Get recent memories | `[]map[string]interface{}` |
| `ToggleCapture(enabled)` | Enable/disable screen capture | `bool` |

## Testing

```bash
# From mem0/go/cmd/app
go test -v .

# Or from project root
cd mem0
go test ./go/cmd/app/...
```

## Troubleshooting

### Build fails with "embed: pattern frontend/dist: no matching files"
Make sure the `frontend/dist` directory exists and contains the HTML/CSS/JS files.

### Frontend not updating in dev mode
Run `wails dev` for hot-reload during development.

### "wails: command not found"
Install Wails CLI:
```bash
go install github.com/wailsapp/wails/v2/cmd/wails@latest
```

### Windows Defender flags the .exe
This is normal for unsigned executables. You may need to add an exception.

### macOS "App is damaged and can't be opened"
Run this to remove the quarantine attribute:
```bash
xattr -cr /path/to/Mem0.app
```

## License

MIT
