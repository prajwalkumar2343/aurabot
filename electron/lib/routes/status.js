/**
 * AuraBot Electron - IPC Config & Status Handlers
 */

const { ipcMain } = require('electron');
const { apiRequest } = require('../ipcUtils');
const { loadLocalConfig, saveLocalConfig } = require('../configStore');

function setupStatusHandlers() {
    ipcMain.handle('get-status', async () => {
        try {
            const status = await apiRequest('/api/status');
            return { success: true, data: status };
        } catch (error) {
            return { success: false, error: error.message };
        }
    });

    ipcMain.handle('get-config', async () => {
        try {
            const config = await apiRequest('/api/config');
            // Save to local store for persistence
            saveLocalConfig(config);
            return { success: true, data: config };
        } catch (error) {
            console.log('[IPC] Backend config unavailable, using local store');
            return { success: true, data: loadLocalConfig() };
        }
    });

    ipcMain.handle('update-config', async (event, config) => {
        try {
            // Always update local store first
            saveLocalConfig(config);

            const result = await apiRequest('/api/config', 'POST', config);
            return { success: true, data: result };
        } catch (error) {
            console.log('[IPC] Backend update unavailable, saved to local store only');
            return { success: true, data: config };
        }
    });
}

module.exports = { setupStatusHandlers };
