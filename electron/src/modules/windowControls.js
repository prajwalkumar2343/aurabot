/**
 * AuraBot Electron - Window Controls Module
 * Enhances AuraApp with window control buttons functionality
 */

AuraApp.prototype.setupWindowControls = function () {
    document.getElementById('btn-minimize')?.addEventListener('click', () => {
        window.electronAPI?.minimizeWindow();
    });

    document.getElementById('btn-maximize')?.addEventListener('click', () => {
        window.electronAPI?.maximizeWindow();
    });

    document.getElementById('btn-close')?.addEventListener('click', () => {
        window.electronAPI?.closeWindow();
    });
};
