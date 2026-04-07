/**
 * AuraBot Electron - IPC Memories Handlers
 */

const { ipcMain } = require('electron');
const { apiRequest } = require('../ipcUtils');

function setupMemoryHandlers() {
    ipcMain.handle('get-memories', async (event, limit = 20) => {
        try {
            const memories = await apiRequest(`/api/memories?limit=${limit}`);
            return { success: true, data: memories };
        } catch (error) {
            return { success: false, error: error.message };
        }
    });

    ipcMain.handle('search-memories', async (event, query, limit = 10) => {
        try {
            const results = await apiRequest(`/api/memories/search?q=${encodeURIComponent(query)}&limit=${limit}`);
            return { success: true, data: results };
        } catch (error) {
            return { success: false, error: error.message };
        }
    });

    ipcMain.handle('add-memory', async (event, content, metadata = {}) => {
        try {
            const result = await apiRequest('/api/memories', 'POST', { content, metadata });
            return { success: true, data: result };
        } catch (error) {
            return { success: false, error: error.message };
        }
    });
}

module.exports = { setupMemoryHandlers };
