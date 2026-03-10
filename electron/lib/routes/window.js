/**
 * AuraBot Electron - IPC Window Controls Handlers
 */

const { ipcMain, shell, app, clipboard } = require('electron');

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

    // Clipboard handlers
    ipcMain.handle('read-clipboard', () => {
        return clipboard.readText();
    });

    ipcMain.handle('write-clipboard', (event, text) => {
        clipboard.writeText(text);
        return true;
    });

    // Text capture error event - for renderer to show notifications
    ipcMain.on('text-capture-error', (event, { error }) => {
        const mainWindow = mainWindowProvider ? mainWindowProvider() : null;
        if (mainWindow) {
            // Show a brief notification or flash the window
            mainWindow.flashFrame(true);
            setTimeout(() => mainWindow.flashFrame(false), 1000);
        }
        console.log('[Window] Text capture error:', error);
    });

    // Paste handler - sends Ctrl+V to the active window
    ipcMain.handle('paste-clipboard', () => {
        const { execSync } = require('child_process');
        const fs = require('fs');
        const os = require('os');
        const path = require('path');
        
        const pasteScript = `
$wshell = New-Object -ComObject wscript.shell
$wshell.SendKeys("^v")
Start-Sleep -Milliseconds 100
`;
        const tempFile = path.join(os.tmpdir(), `aura-paste-${Date.now()}.ps1`);
        
        try {
            fs.writeFileSync(tempFile, '\ufeff' + pasteScript, 'utf8');
            execSync(
                `powershell -NoProfile -ExecutionPolicy Bypass -File "${tempFile}"`,
                { timeout: 5000, windowsHide: true }
            );
            return { success: true };
        } catch (error) {
            console.error('[Paste] Failed:', error.message);
            return { success: false, error: error.message };
        } finally {
            try { fs.unlinkSync(tempFile); } catch {}
        }
    });
}

module.exports = { setupWindowHandlers };
