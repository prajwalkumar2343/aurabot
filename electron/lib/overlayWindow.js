/**
 * AuraBot Electron - Overlay Window Module
 * Creates a transparent, always-on-top window for Pacman animation
 * positioned exactly over the selected text
 */

const { BrowserWindow, screen } = require('electron');
const path = require('path');
const { execFile } = require('child_process');

let overlayWindow = null;

function createOverlayWindow() {
    if (overlayWindow && !overlayWindow.isDestroyed()) {
        return overlayWindow;
    }

    overlayWindow = new BrowserWindow({
        width: 200,
        height: 30,
        transparent: true,
        frame: false,
        alwaysOnTop: true,
        skipTaskbar: true,
        resizable: false,
        movable: false,
        focusable: false,
        hasShadow: false, // No window shadow
        show: false,
        webPreferences: {
            nodeIntegration: false,
            contextIsolation: true,
            preload: path.join(__dirname, '..', 'overlayPreload.js')
        }
    });

    // Remove menu
    overlayWindow.setMenu(null);

    // Disable any system shadows or effects
    overlayWindow.setBackgroundColor('#00000000'); // Fully transparent

    // Load the overlay HTML
    overlayWindow.loadFile(path.join(__dirname, '..', 'src', 'overlay.html'));

    // Handle closed
    overlayWindow.on('closed', () => {
        overlayWindow = null;
    });

    return overlayWindow;
}

function getTextDimensions(text) {
    // Estimate dimensions based on text length
    // Monospace font: ~8px per character, ~20px per line
    const avgCharWidth = 8;
    const lineHeight = 22;

    // Split by newlines to handle multi-line
    const lines = text.split('\n');
    const maxLineLength = Math.max(...lines.map(line => line.length));

    // Calculate size with minimal padding
    const width = Math.max(100, Math.min(1200, maxLineLength * avgCharWidth + 40));
    const height = Math.max(24, lines.length * lineHeight);

    return { width, height, lines: lines.length };
}

function getCaretPosition() {
    return new Promise((resolve) => {
        let resolved = false;
        const timeout = setTimeout(() => {
            if (!resolved) {
                resolved = true;
                console.log('[GetCaret] Timed out after 1500ms');
                resolve(null);
            }
        }, 1500);

        execFile(path.join(__dirname, 'GetCaretUIA.exe'), (error, stdout, stderr) => {
            if (!resolved) {
                resolved = true;
                clearTimeout(timeout);

                if (error) {
                    console.error('[GetCaret] execFile error:', error.message);
                }
                if (stderr) {
                    console.error('[GetCaret] stderr:', stderr);
                }

                console.log('[GetCaret] stdout raw:', stdout);

                try {
                    const result = JSON.parse(stdout.trim());
                    if (result && !result.error && typeof result.x === 'number') {
                        resolve(result);
                    } else {
                        console.log('[GetCaret] Script returned error:', result.error);
                        resolve(null);
                    }
                } catch (e) {
                    console.error('[GetCaret] Failed to parse JSON:', e.message);
                    resolve(null);
                }
            }
        });
    });
}

function showPacmanOverlay(text, mainWindowProvider, caretRect = null) {
    const overlay = createOverlayWindow();

    // Calculate text dimensions
    const { width, height } = getTextDimensions(text);
    let x, y;

    if (caretRect && typeof caretRect.x === 'number' && typeof caretRect.y === 'number') {
        const spacing = 10;
        x = caretRect.x + (caretRect.width / 2) - (width / 2);
        y = caretRect.y + caretRect.height + spacing;

        const activeDisplay = screen.getDisplayNearestPoint({ x: caretRect.x, y: caretRect.y });
        const displayBounds = activeDisplay.workArea;

        // Ensure overlay stays within screen bounds
        if (y + height > displayBounds.y + displayBounds.height) {
            y = caretRect.y - height - spacing;
        }

        x = Math.max(displayBounds.x, Math.min(x, displayBounds.x + displayBounds.width - width));
        y = Math.max(displayBounds.y, Math.min(y, displayBounds.y + displayBounds.height - height));
    } else {
        // Fallback to center screen
        const cursorPoint = screen.getCursorScreenPoint();
        const activeDisplay = screen.getDisplayNearestPoint(cursorPoint);
        const displayBounds = activeDisplay.workArea;

        x = displayBounds.x + (displayBounds.width / 2) - (width / 2);
        y = displayBounds.y + (displayBounds.height / 2) - (height / 2);

        x = Math.max(displayBounds.x, Math.min(x, displayBounds.x + displayBounds.width - width));
        y = Math.max(displayBounds.y, Math.min(y, displayBounds.y + displayBounds.height - height));
    }

    // Set bounds and size
    overlay.setBounds({ x: Math.round(x), y: Math.round(y), width, height });
    overlay.setSize(width, height);

    // Make it click-through so user can still interact with app below
    overlay.setIgnoreMouseEvents(true);

    // Show the overlay
    overlay.show();
    overlay.setAlwaysOnTop(true, 'screen-saver');
    overlay.setVisibleOnAllWorkspaces(true);

    // Send the text to the overlay window
    setTimeout(() => {
        overlay.webContents.send('pacman-start', { text, width, height });
    }, 50);

    return overlay;
}

function hidePacmanOverlay() {
    if (overlayWindow && !overlayWindow.isDestroyed()) {
        overlayWindow.webContents.send('pacman-hide');
        setTimeout(() => {
            if (overlayWindow && !overlayWindow.isDestroyed()) {
                overlayWindow.hide();
            }
        }, 300);
    }
}

function showResultOnOverlay(enhancedText) {
    if (overlayWindow && !overlayWindow.isDestroyed()) {
        overlayWindow.webContents.send('pacman-result', { text: enhancedText });
    }
}

module.exports = {
    createOverlayWindow,
    showPacmanOverlay,
    hidePacmanOverlay,
    showResultOnOverlay,
    getCaretPosition
};

// Also expose to global for IPC handlers
global.overlayWindowFunctions = {
    hidePacmanOverlay,
    showResultOnOverlay
};
