/**
 * AuraBot Electron - IPC Handlers Module
 * Sets up IPC communication between main and renderer processes
 */

const { ipcMain, shell, app } = require('electron');
const { setBackendPort, apiRequest } = require('./ipcUtils');

const { setupStatusHandlers } = require('./routes/status');
const { setupMemoryHandlers } = require('./routes/memories');
const { setupAIHandlers } = require('./routes/ai');
const { setupWindowHandlers } = require('./routes/window');

const { hidePacmanOverlay, showResultOnOverlay } = require('./overlayWindow');

function setupIPC(callbacks) {
    const { toggleCapture, mainWindowProvider } = callbacks;

    // Load separated route handlers
    setupStatusHandlers();
    setupMemoryHandlers();
    setupAIHandlers();
    setupWindowHandlers(mainWindowProvider);

    // Capture Control (Kept small enough to remain here or could be moved)
    ipcMain.handle('toggle-capture', async (event, enabled) => {
        if (toggleCapture) return toggleCapture(enabled);
        return { success: false, error: 'toggleCapture not configured' };
    });

    // Overlay window control
    ipcMain.handle('hide-overlay', async () => {
        hidePacmanOverlay();
        return { success: true };
    });

    ipcMain.handle('show-overlay-result', async (event, text) => {
        showResultOnOverlay(text);
        return { success: true };
    });
}

// Reusable capture toggle function that updates tray and UI
async function createToggleCapture(trayUpdater, mainWindowProvider) {
    return async function toggleCapture(enabled) {
        try {
            const result = await apiRequest('/api/capture/toggle', 'POST', { enabled });

            const mainWindow = mainWindowProvider ? mainWindowProvider() : null;
            if (trayUpdater) trayUpdater(enabled);

            // Notify renderer
            if (mainWindow) {
                mainWindow.webContents.send('capture-status', { enabled });
            }

            return { success: true, data: result };
        } catch (error) {
            return { success: false, error: error.message };
        }
    };
}

function triggerQuickEnhance(mainWindowProvider) {
    const mainWindow = mainWindowProvider ? mainWindowProvider() : null;
    if (mainWindow) {
        mainWindow.webContents.send('trigger-quick-enhance');
        mainWindow.show();
        mainWindow.focus();
    }
}

function triggerGhostEnhance(mainWindowProvider, capturedText = '') {
    const mainWindow = mainWindowProvider ? mainWindowProvider() : null;
    if (mainWindow) {
        // Send ghost trigger with captured text
        mainWindow.webContents.send('trigger-ghost-enhance', { text: capturedText });
    }
}

module.exports = {
    setupIPC,
    setBackendPort,
    createToggleCapture,
    triggerQuickEnhance,
    triggerGhostEnhance
};
