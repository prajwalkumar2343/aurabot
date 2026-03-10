# AuraBot Electron (Windows Edition)

A native Windows desktop application for AuraBot built with Electron.

## Features

- **Native Windows UI** - Custom title bar with Windows-style window controls
- **System Tray Integration** - Minimize to tray and run in background
- **Global Hotkeys** - Quick Enhance with Ctrl+Alt+E from anywhere
- **Auto-updater Support** - Built-in update checking

## Prerequisites

1. **Node.js 18+** - Download from https://nodejs.org/
2. **Go 1.21+** - For compiling the backend (optional if using pre-built)

## Installation

```bash
cd aurabot/electron

# Install dependencies
npm install

# Compile Go backend (requires Go installed)
npm run compile-go

# Or copy the pre-built executable from go/ directory
copy ..\go\aurabot.exe build\aurabot-backend.exe
```

## Development

```bash
# Run in development mode
npm run dev:win

# Or
set NODE_ENV=development
npm start
```

## Building for Production

### Build Installer (NSIS)
```bash
npm run build:win
```

This creates:
- `dist/AuraBot Setup 1.0.0.exe` - Installer
- `dist/AuraBot-Portable-1.0.0.exe` - Portable version

### Build Only
```bash
npm run pack
```

## Project Structure

```
electron/
├── package.json          # Electron dependencies and build config
├── main.js               # Main process (window, tray, backend spawn)
├── preload.js            # Secure IPC bridge
├── src/
│   ├── index.html        # Main UI
│   ├── style.css         # Styles (Windows theme)
│   └── app.js            # Frontend controller
├── build/
│   ├── aurabot-backend.exe  # Compiled Go backend
│   └── icon.ico             # App icon
└── dist/                 # Build output
```

## Architecture

```
┌─────────────────────────────────────────┐
│  Electron Main Process (main.js)        │
│  - Creates window                       │
│  - Spawns Go backend                    │
│  - Manages system tray                  │
│  - Handles global shortcuts             │
└──────────────────┬──────────────────────┘
                   │ IPC
┌──────────────────▼──────────────────────┐
│  Electron Renderer (src/app.js)         │
│  - Dashboard UI                         │
│  - Memories browser                     │
│  - Chat interface                       │
│  - Settings panel                       │
└──────────────────┬──────────────────────┘
                   │ HTTP API (localhost:7345)
┌──────────────────▼──────────────────────┐
│  Go Backend (build/aurabot-backend.exe) │
│  - Screen capture                       │
│  - LLM integration                      │
│  - Memory management                    │
└─────────────────────────────────────────┘
```

## IPC Channels

### Renderer → Main
- `get-status` - Get service status
- `get-config` - Get configuration
- `update-config` - Update settings
- `get-memories` - List memories
- `search-memories` - Search memories
- `add-memory` - Add new memory
- `chat` - Send chat message
- `toggle-capture` - Enable/disable capture
- `enhance-prompt` - Enhance text with memories

### Main → Renderer
- `navigate` - Navigate to view
- `capture-status` - Capture status update
- `backend-status` - Backend connection status
- `trigger-quick-enhance` - Open quick enhance modal

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| Ctrl + K | Focus search (in Memories) |
| Ctrl + N | New memory |
| Ctrl + Alt + E | Quick Enhance (global) |
| Escape | Close modal |
| Ctrl + Enter | Save memory |

## Customization

### Theme
Edit `src/style.css` and modify the CSS variables:

```css
:root {
    --bg-primary: #FDFCF9;
    --bg-secondary: #FFFFFF;
    --accent: #F5D76E;
    /* ... */
}
```

### Window Size
Edit `main.js`:

```javascript
mainWindow = new BrowserWindow({
    width: 1200,
    height: 800,
    // ...
});
```

## Troubleshooting

### Backend not starting
1. Check that `build/aurabot-backend.exe` exists
2. Run `npm run compile-go` to rebuild
3. Check the console for error messages

### Port already in use
Change the port in `main.js`:
```javascript
const BACKEND_PORT = 7346; // Different port
```

### CORS errors
The backend API includes CORS headers. If you see CORS errors, ensure the backend is running and accessible.

## License

MIT
