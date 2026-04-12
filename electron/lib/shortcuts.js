/**
 * AuraBot Electron - Main Process Shortcuts Module
 * Handles registration of global keyboard shortcuts
 */

const { globalShortcut, app, clipboard } = require('electron');
const { triggerGhostEnhance } = require('./ipcHandlers');
const { grabSelectedText } = require('./textCapture');
const { showPacmanOverlay, hidePacmanOverlay, showResultOnOverlay, getCaretPosition } = require('./overlayWindow');

// Store captured text temporarily
global.capturedTextBuffer = '';

function registerShortcuts(mainWindowProvider) {
    if (!app.isReady()) return;

    // Register global shortcuts
    globalShortcut.register('Ctrl+Alt+E', async () => {
        const mainWindow = mainWindowProvider ? mainWindowProvider() : null;

        console.log('[Shortcuts] Ctrl+Alt+E pressed, capturing text immediately...');

        try {
            // 1) First fetch caret position while focus is completely un-interfered with
            const caretRect = await getCaretPosition();

            if (caretRect) {
                console.log('[Shortcuts] Caret position found:', caretRect);
            } else {
                console.log('[Shortcuts] Caret position not found, will center dialog.');
            }

            // 2) Now capture the text (this sends simulated keystrokes that might lose focus)
            const capturedText = await grabSelectedText();

            if (!capturedText || capturedText.trim().length === 0) {
                throw new Error('No text was captured.');
            }

            console.log('[Shortcuts] Text captured, length:', capturedText.length);

            // Store captured text in global buffer
            global.capturedTextBuffer = capturedText;

            // Show the Pacman overlay window on top of the active application
            showPacmanOverlay(capturedText, mainWindowProvider, caretRect);

            // Also notify the main window for enhancement processing
            triggerGhostEnhance(mainWindowProvider, capturedText);
        } catch (error) {
            console.error('[Shortcuts] Failed to grab selected text:', error.message);

            // Send error to renderer
            if (mainWindow && mainWindow.webContents) {
                mainWindow.webContents.send('text-capture-error', {
                    error: error.message
                });
            }
        }
    });

    console.log('[Shortcuts] Global shortcuts registered: Ctrl+Alt+E');
}

function unregisterShortcuts() {
    try {
        if (app.isReady()) {
            globalShortcut.unregisterAll();
            console.log('[Shortcuts] All global shortcuts unregistered');
        }
    } catch (e) {
        console.warn('[Shortcuts] Failed to unregister shortcuts:', e.message);
    }
}

module.exports = {
    registerShortcuts,
    unregisterShortcuts
};
