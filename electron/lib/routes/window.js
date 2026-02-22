/**
 * AuraBot Electron - IPC Window Controls Handlers
 */

const { ipcMain, shell, app } = require('electron');

function setupWindowHandlers(mainWindowProvider) {
    ipcMain.handle('minimize-window', () => {
        const mainWindow = mainWindowProvider ? mainWindowProvider() : null;
        if (mainWindow) mainWindow.minimize();
    });

    ipcMain.handle('maximize-window', () => {
        const mainWindow = mainWindowProvider ? mainWindowProvider() : null;
        if (mainWindow) {
            if (mainWindow.isMaximized()) {
                mainWindow.unmaximize();
            } else {
                mainWindow.maximize();
            }
        }
    });

    ipcMain.handle('close-window', () => {
        const mainWindow = mainWindowProvider ? mainWindowProvider() : null;
        if (mainWindow) mainWindow.hide();
    });

    ipcMain.handle('open-external', (event, url) => {
        shell.openExternal(url);
    });

    ipcMain.handle('get-version', () => {
        return app.getVersion();
    });
}

module.exports = { setupWindowHandlers };
