/**
 * AuraBot Electron - IPC Chat & Enhance Handlers
 */

const { ipcMain } = require('electron');
const { apiRequest } = require('../ipcUtils');

function setupAIHandlers() {
    ipcMain.handle('chat', async (event, message) => {
        try {
            const response = await apiRequest('/api/chat', 'POST', { message });
            return { success: true, data: response };
        } catch (error) {
            return { success: false, error: error.message };
        }
    });

    ipcMain.handle('enhance-prompt', async (event, prompt, context = '') => {
        try {
            const result = await apiRequest('/api/enhance', 'POST', { prompt, context });
            return { success: true, data: result };
        } catch (error) {
            return { success: false, error: error.message };
        }
    });
}

module.exports = { setupAIHandlers };
