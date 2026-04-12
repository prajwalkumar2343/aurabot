/**
 * AuraBot Electron - IPC Module
 * Enhances AuraApp with IPC listeners
 */

AuraApp.prototype.setupIPCListeners = function () {
    // Navigate event from main process
    window.electronAPI?.onNavigate?.((view) => {
        const navItem = document.querySelector(`[data-view="${view}"]`);
        if (navItem) navItem.click();
    });

    // Capture status updates
    window.electronAPI?.onCaptureStatus?.((status) => {
        this.isCaptureEnabled = status.enabled;
        this.updateCaptureUI();
    });

    // Backend status updates
    window.electronAPI?.onBackendStatus?.((status) => {
        this.backendConnected = status.running;
        this.updateBackendStatus();
    });

    // Quick enhance trigger
    window.electronAPI?.onTriggerQuickEnhance?.(() => {
        this.openQuickEnhance();
    });

    // Ghost enhance trigger is handled by quickEnhance module
    // DO NOT add a listener here to avoid conflicts

    // Text capture error
    window.electronAPI?.onTextCaptureError?.(({ error }) => {
        this.showToast('Text capture failed: ' + error, 'error');
    });
};
