# AuraBot - Swift Version

A complete Swift/macOS rewrite of the AuraBot screen memory assistant.

## Features

- ✅ **Screen Capture** - Periodic screenshots using ScreenCaptureKit
- ✅ **Memory Storage** - Memory API integration with vector embeddings
- ✅ **LLM Integration** - OpenAI-compatible API support
- ✅ **Quick Enhance** - Global hotkey (⌘⌥E) to enhance any text
- ✅ **Floating Overlay** - System-wide floating button
- ✅ **SwiftUI Interface** - Native macOS app
- ✅ **HTTP API** - Browser extension support
- ✅ **Computer Use** - Embedded AuraBot computer-use engine for app/window automation

## Requirements

- macOS 13.0+
- Xcode 15.0+
- Swift 5.9+

## Build Instructions

### 1. Clone and Setup

```bash
cd apps/macos
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
│   ├── MemoryService.swift    # Memory API client
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
- **Memory PGlite** - Managed local Memory v2 backend for storage, search, graph extraction, and markdown brain indexing
- **AuraBot Computer Use** - Embedded computer-use engine managed invisibly by AuraBot

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
    "model": "local-model",
    "openRouterChatModel": "openai/gpt-5.3",
    "contextCollectorRewrite": {
      "enabled": false,
      "allowedModels": [
        { "label": "Gemini >= 3.1", "minimumVersion": 3.1, "matchPatterns": ["gemini[-_ ]?(\\d+(?:\\.\\d+)?)"], "requiredTokens": [] },
        { "label": "Claude Opus >= 4.5", "minimumVersion": 4.5, "matchPatterns": ["claude[-_ ]?opus[-_ ]?(\\d+(?:\\.\\d+)?)", "claude[-_ ]?(\\d+(?:\\.\\d+)?)[:/_ -]?opus"], "requiredTokens": ["claude", "opus"] },
        { "label": "GPT >= 5.3", "minimumVersion": 5.3, "matchPatterns": ["gpt[-_ ]?(\\d+(?:\\.\\d+)?)"], "requiredTokens": [] },
        { "label": "Kimi >= 2.5", "minimumVersion": 2.5, "matchPatterns": ["kimi[-_ ]?(\\d+(?:\\.\\d+)?)"], "requiredTokens": [] }
      ]
    }
  },
  "memory": {
    "baseURL": "http://127.0.0.1:8766",
    "apiKey": "memory-v2-token"
  },
  "extension": {
    "apiKey": "browser-extension-token",
    "allowedOrigins": [
      "chrome-extension://",
      "moz-extension://",
      "safari-web-extension://",
      "http://localhost:",
      "http://127.0.0.1:"
    ]
  }
}
```

AuraBot starts the local PGlite memory backend automatically. In packaged builds, `scripts/build-app.sh` bundles the built `services/memory-pglite` service into the app resources so users can launch AuraBot like a normal macOS app.

AuraBot embeds its computer-use engine directly into the macOS binary. Settings keeps the feature under the single “Computer Use” surface for enablement, permissions, diagnostics, and trajectory recording.

### Browser Extension Context API

The app listens on `127.0.0.1:7345` by default for browser context updates:

```http
POST /browser/context
Authorization: Bearer browser-extension-token
Content-Type: application/json
```

Extensions may also send `X-AuraBot-Extension-Key: browser-extension-token` instead of the bearer header. The token must match `extension.apiKey` in `~/.aurabot/config.json`; requests without a matching key are rejected. Origins must also match `extension.allowedOrigins`.

## License

MIT
