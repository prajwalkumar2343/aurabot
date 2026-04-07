/**
 * AuraBot Electron - Main Process Shortcuts Module
 * Handles registration of global keyboard shortcuts
 */

const { globalShortcut, app } = require('electron');
const { triggerGhostEnhance } = require('./ipcHandlers');

function registerShortcuts(mainWindowProvider) {
    if (!app.isReady()) return;

    // Register global shortcuts
    globalShortcut.register('Ctrl+Alt+E', () => {
        triggerGhostEnhance(mainWindowProvider);
    });
}

function unregisterShortcuts() {
    // Only attempt if app is ready and we won't crash
    try {
        if (app.isReady()) {
            globalShortcut.unregisterAll();
        }
    } catch (e) {
        console.warn('[Shortcuts] Failed to unregister shortcuts (possibly not ready):', e.message);
    }
}

module.exports = {
    registerShortcuts,
    unregisterShortcuts
};
