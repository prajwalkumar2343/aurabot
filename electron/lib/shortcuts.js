/**
 * AuraBot Electron - Main Process Shortcuts Module
 * Handles registration of global keyboard shortcuts
 */

const { globalShortcut } = require('electron');
const { triggerQuickEnhance } = require('./ipcHandlers');

function registerShortcuts(mainWindowProvider) {
    // Register global shortcuts
    globalShortcut.register('Ctrl+Alt+E', () => {
        triggerQuickEnhance(mainWindowProvider);
    });
}

function unregisterShortcuts() {
    // Unregister all global shortcuts
    globalShortcut.unregisterAll();
}

module.exports = {
    registerShortcuts,
    unregisterShortcuts
};
