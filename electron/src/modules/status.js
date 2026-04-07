/**
 * AuraBot Electron - Status Module
 * Enhances AuraApp with backend status polling and UI updates
 */

AuraApp.prototype.loadStatus = async function () {
    try {
        const result = await window.electronAPI?.getStatus();
        if (result?.success) {
            this.updateStatusUI(result.data);
            this.backendConnected = true;
        } else {
            // Demo mode
            this.updateStatusUI({
                running: true,
                config: { capture_enabled: this.isCaptureEnabled, capture_interval: 30 }
            });
        }
    } catch (error) {
        console.error('Failed to load status:', error);
        this.backendConnected = false;
    }
    this.updateBackendStatus();
};

AuraApp.prototype.updateStatusUI = function (status) {
    // Update sidebar status dots
    const llmDot = document.getElementById('status-llm');
    const memDot = document.getElementById('status-memory');
    const capDot = document.getElementById('status-capture');

    if (llmDot) llmDot.className = 'status-dot ' + (status.running ? 'online' : 'offline');
    if (memDot) memDot.className = 'status-dot ' + (status.running ? 'online' : 'offline');
    if (capDot) capDot.className = 'status-dot ' + (status.config?.capture_enabled ? 'online' : 'offline');

    // Update capture toggle
    this.isCaptureEnabled = status.config?.capture_enabled || false;
    const toggle = document.getElementById('sidebar-capture-toggle');
    if (toggle) toggle.checked = this.isCaptureEnabled;

    // Update status text
    const statusText = document.getElementById('capture-status-text');
    if (statusText) statusText.textContent = this.isCaptureEnabled ? 'Active' : 'Paused';

    // Update interval display
    const intervalDisplay = document.getElementById('capture-interval-display');
    if (intervalDisplay) {
        intervalDisplay.textContent = `Interval: ${status.config?.capture_interval || 30}s`;
    }

    // Update stats
    const intervalStat = document.getElementById('stat-interval');
    if (intervalStat) intervalStat.textContent = `${status.config?.capture_interval || 30}s`;

    const lastStat = document.getElementById('stat-last');
    if (lastStat && status.last_state) {
        lastStat.textContent = status.last_state.length > 20
            ? status.last_state.substring(0, 20) + '...'
            : status.last_state;
    }
};

AuraApp.prototype.updateBackendStatus = function () {
    const dot = document.getElementById('backend-dot');
    const text = document.getElementById('backend-text');

    if (dot && text) {
        if (this.backendConnected) {
            dot.className = 'status-dot online';
            text.textContent = 'Connected';
        } else {
            dot.className = 'status-dot offline';
            text.textContent = 'Disconnected';
        }
    }
};

AuraApp.prototype.updateCaptureUI = function () {
    const toggle = document.getElementById('sidebar-capture-toggle');
    const statusText = document.getElementById('capture-status-text');
    const capDot = document.getElementById('status-capture');

    if (toggle) toggle.checked = this.isCaptureEnabled;
    if (statusText) statusText.textContent = this.isCaptureEnabled ? 'Active' : 'Paused';
    if (capDot) capDot.className = 'status-dot ' + (this.isCaptureEnabled ? 'online' : 'offline');
};

AuraApp.prototype.toggleCapture = async function (enabled) {
    try {
        const result = await window.electronAPI?.toggleCapture(enabled);
        if (result?.success) {
            this.isCaptureEnabled = enabled;
            this.updateCaptureUI();
            this.showToast(enabled ? 'Capture started' : 'Capture paused');
        }
    } catch (error) {
        console.error('Failed to toggle capture:', error);
        // Update UI anyway
        this.isCaptureEnabled = enabled;
        this.updateCaptureUI();
    }
};
