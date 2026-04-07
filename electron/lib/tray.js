/**
 * AuraBot Electron - Tray Module
 * Handles the system tray icon and menu
 */

const { Tray, Menu, nativeImage, app } = require('electron');
const path = require('path');
const fs = require('fs');

let tray = null;

function createTray(mainWindow, callbacks) {
    const iconPath = path.join(__dirname, '..', 'build', 'tray-icon.png');

    // Create a simple 16x16 icon if not exists
    let trayIcon;
    if (fs.existsSync(iconPath)) {
        trayIcon = nativeImage.createFromPath(iconPath);
    } else {
        trayIcon = nativeImage.createEmpty();
    }

    tray = new Tray(trayIcon.resize({ width: 16, height: 16 }));

    const contextMenu = buildContextMenu(mainWindow, callbacks);

    tray.setToolTip('AuraBot - AI Memory Assistant');
    tray.setContextMenu(contextMenu);

    tray.on('click', () => {
        if (mainWindow) {
            if (mainWindow.isVisible()) {
                mainWindow.hide();
            } else {
                mainWindow.show();
                mainWindow.focus();
            }
        } else if (callbacks.createWindow) {
            callbacks.createWindow();
        }
    });

    return tray;
}

function buildContextMenu(mainWindow, callbacks, isCaptureEnabled = false) {
    return Menu.buildFromTemplate([
        {
            label: 'Show AuraBot',
            click: () => {
                if (mainWindow) {
                    mainWindow.show();
                    mainWindow.focus();
                } else if (callbacks.createWindow) {
                    callbacks.createWindow();
                }
            }
        },
        {
            label: 'Quick Enhance',
            accelerator: 'Ctrl+Alt+E',
            click: () => callbacks.triggerQuickEnhance && callbacks.triggerQuickEnhance()
        },
        { type: 'separator' },
        {
            label: 'Start Capture',
            id: 'start-capture',
            click: () => callbacks.toggleCapture && callbacks.toggleCapture(true),
            visible: !isCaptureEnabled
        },
        {
            label: 'Stop Capture',
            id: 'stop-capture',
            click: () => callbacks.toggleCapture && callbacks.toggleCapture(false),
            visible: isCaptureEnabled
        },
        { type: 'separator' },
        {
            label: 'Settings',
            click: () => {
                if (mainWindow) {
                    mainWindow.show();
                    mainWindow.webContents.send('navigate', 'settings');
                }
            }
        },
        {
            label: 'Quit',
            click: () => {
                if (callbacks.setIsQuitting) callbacks.setIsQuitting(true);
                app.quit();
            }
        }
    ]);
}

function updateTrayMenu(mainWindow, callbacks, isCaptureEnabled) {
    if (tray) {
        const contextMenu = buildContextMenu(mainWindow, callbacks, isCaptureEnabled);
        tray.setContextMenu(contextMenu);
    }
}

module.exports = {
    createTray,
    updateTrayMenu
};
