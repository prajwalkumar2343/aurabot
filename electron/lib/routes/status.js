/**
 * AuraBot Electron - IPC Config & Status Handlers
 */

const { ipcMain } = require('electron');
const { apiRequest } = require('../ipcUtils');

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
            return { success: true, data: config };
        } catch (error) {
            return { success: false, error: error.message };
        }
    });

    ipcMain.handle('update-config', async (event, config) => {
        try {
            const result = await apiRequest('/api/config', 'POST', config);
            return { success: true, data: result };
        } catch (error) {
            return { success: false, error: error.message };
        }
    });
}

module.exports = { setupStatusHandlers };
