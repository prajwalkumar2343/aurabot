# AuraBot - Swift Version

A complete Swift/macOS rewrite of the AuraBot screen memory assistant.

## Features

- ✅ **Screen Capture** - Periodic screenshots using ScreenCaptureKit
- ✅ **Memory Storage** - Mem0 integration for vector embeddings
- ✅ **LLM Integration** - OpenAI-compatible API support
- ✅ **Quick Enhance** - Global hotkey (⌘⌥E) to enhance any text
- ✅ **Floating Overlay** - System-wide floating button
- ✅ **SwiftUI Interface** - Native macOS app
- ✅ **HTTP API** - Browser extension support

## Requirements

- macOS 13.0+
- Xcode 15.0+
- Swift 5.9+

## Build Instructions

### 1. Clone and Setup

```bash
cd aurabot-swift
```

### 2. Build with Swift Package Manager

```bash
swift build
```

### 3. Run the App

```bash
swift run AuraBot
```

### 4. Create App Bundle (Optional)

```bash
swift build -c release
# Then package as .app
```

## Architecture

```
Sources/AuraBot/
├── Core/
│   └── AppDelegate.swift      # App lifecycle & global hotkeys
├── Models/
│   ├── Config.swift           # Configuration models
│   ├── Memory.swift           # Memory data models
│   └── ScreenCapture.swift    # Capture models
├── Services/
│   ├── AppService.swift       # Main service orchestrator
│   ├── LLMService.swift       # LLM API client
│   ├── MemoryService.swift    # Mem0 API client
│   ├── ScreenCaptureService.swift  # ScreenCaptureKit wrapper
│   ├── EnhancerService.swift  # Prompt enhancement logic
│   └── APIServer.swift        # HTTP API for extension
├── UI/
│   ├── AuraBotApp.swift       # SwiftUI App entry
│   ├── MainView.swift         # Main window layout
│   ├── DashboardView.swift    # Dashboard view
│   ├── MemoriesView.swift     # Memory browser
│   ├── ChatView.swift         # Chat interface
│   ├── SettingsView.swift     # Settings panel
│   ├── OverlayWindow.swift    # Floating button window
│   └── QuickEnhancePanel.swift # Quick enhance popup
└── Utils/
```

## Usage

### Quick Enhance

1. Select text in any app
2. Press **⌘⌥E** (Cmd+Opt+E)
3. Click the floating purple button
4. Your text is enhanced with memories

### Screen Capture

1. Enable capture in settings
2. Screenshots are taken every 30s (configurable)
3. AI analyzes and stores context
4. Search memories anytime

### Chat with Memories

1. Open Chat tab
2. Ask questions about your activities
3. AI uses stored memories for context

## Dependencies

- **Vapor** - HTTP server for browser extension API
- **KeyboardShortcuts** - Global hotkey handling
- **ScreenCaptureKit** - Native screen capture (built-in)

## Configuration

Config is stored at `~/.aurabot/config.json`:

```json
{
  "capture": {
    "intervalSeconds": 30,
    "quality": 60,
    "enabled": true
  },
  "llm": {
    "baseURL": "http://localhost:1234/v1",
    "model": "local-model"
  },
  "memory": {
    "baseURL": "http://localhost:8000"
  }
}
```

## License

MIT
