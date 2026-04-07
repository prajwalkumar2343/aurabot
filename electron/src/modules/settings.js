/**
 * AuraBot Electron - Settings Module
 * Enhances AuraApp with settings management functionality
 */

AuraApp.prototype.setupSettings = function () {
    // Tab navigation
    const tabs = document.querySelectorAll('.settings-tab');
    const panels = document.querySelectorAll('.settings-panel');

    tabs.forEach(tab => {
        tab.addEventListener('click', () => {
            const tabName = tab.dataset.tab;

            tabs.forEach(t => t.classList.remove('active'));
            tab.classList.add('active');

            panels.forEach(p => p.classList.remove('active'));
            document.getElementById(`panel-${tabName}`)?.classList.add('active');
        });
    });

    // Capture enabled toggle
    document.getElementById('setting-capture-enabled')?.addEventListener('change', (e) => {
        this.toggleCapture(e.target.checked);
    });

    // Capture interval slider
    const intervalSlider = document.getElementById('setting-capture-interval');
    intervalSlider?.addEventListener('input', (e) => {
        document.getElementById('display-capture-interval').textContent = `${e.target.value}s`;
    });

    // Quality slider
    const qualitySlider = document.getElementById('setting-capture-quality');
    qualitySlider?.addEventListener('input', (e) => {
        document.getElementById('display-capture-quality').textContent = `${e.target.value}%`;
    });

    // Save settings
    document.getElementById('btn-save-settings')?.addEventListener('click', () => {
        this.saveSettings();
    });

    // Reset settings
    document.getElementById('btn-reset-settings')?.addEventListener('click', () => {
        this.resetSettings();
    });

    // Check for updates
    document.getElementById('btn-check-update')?.addEventListener('click', () => {
        this.showToast('Checking for updates...');
        // In a real app, this would check for updates
        setTimeout(() => {
            this.showToast('You have the latest version!');
        }, 1500);
    });
};

AuraApp.prototype.loadConfig = async function () {
    try {
        const result = await window.electronAPI?.getConfig();
        if (result?.success) {
            this.config = result.data;
            this.populateSettings(result.data);
        }
    } catch (error) {
        console.error('Failed to load config:', error);
    }

    // Load version
    try {
        const version = await window.electronAPI?.getVersion();
        const versionEl = document.getElementById('app-version');
        if (versionEl && version) {
            versionEl.textContent = `v${version}`;
        }
    } catch (error) {
        console.error('Failed to get version:', error);
    }
};

AuraApp.prototype.populateSettings = function (config) {
    // Capture settings
    if (config.capture) {
        document.getElementById('setting-capture-enabled').checked = config.capture.enabled;
        document.getElementById('setting-capture-interval').value = config.capture.intervalSeconds || 30;
        document.getElementById('display-capture-interval').textContent = `${config.capture.intervalSeconds || 30}s`;
        document.getElementById('setting-capture-quality').value = config.capture.quality || 60;
        document.getElementById('display-capture-quality').textContent = `${config.capture.quality || 60}%`;
        document.getElementById('setting-process-on-capture').checked = config.capture.processOnCapture !== false;
    }

    // AI settings
    if (config.llm) {
        document.getElementById('setting-llm-url').value = config.llm.baseUrl || 'http://localhost:1234/v1';
        document.getElementById('setting-llm-model').value = config.llm.model || 'local-model';
    }

    if (config.app) {
        document.getElementById('setting-memory-window').value = config.app.memoryWindow || 10;
    }

    if (config.memory) {
        document.getElementById('setting-mem0-url').value = config.memory.baseUrl || 'http://localhost:8000';
    }
};

AuraApp.prototype.saveSettings = async function () {
    const settings = {
        capture: {
            enabled: document.getElementById('setting-capture-enabled')?.checked || false,
            intervalSeconds: parseInt(document.getElementById('setting-capture-interval')?.value || 30),
            quality: parseInt(document.getElementById('setting-capture-quality')?.value || 60),
            processOnCapture: document.getElementById('setting-process-on-capture')?.checked || false
        },
        llm: {
            baseUrl: document.getElementById('setting-llm-url')?.value || 'http://localhost:1234/v1',
            model: document.getElementById('setting-llm-model')?.value || 'local-model'
        },
        app: {
            memoryWindow: parseInt(document.getElementById('setting-memory-window')?.value || 10)
        },
        memory: {
            baseUrl: document.getElementById('setting-mem0-url')?.value || 'http://localhost:8000'
        }
    };

    try {
        const result = await window.electronAPI?.updateConfig(settings);
        if (result?.success) {
            this.config = settings;
            this.showToast('Settings saved successfully');
            this.loadStatus();
        } else {
            throw new Error(result?.error || 'Failed to save settings');
        }
    } catch (error) {
        console.error('Failed to save settings:', error);
        this.showToast('Settings saved locally', 'error');
    }
};

AuraApp.prototype.resetSettings = function () {
    if (confirm('Reset all settings to defaults?')) {
        document.getElementById('setting-capture-enabled').checked = true;
        document.getElementById('setting-capture-interval').value = 30;
        document.getElementById('display-capture-interval').textContent = '30s';
        document.getElementById('setting-capture-quality').value = 60;
        document.getElementById('display-capture-quality').textContent = '60%';
        document.getElementById('setting-process-on-capture').checked = true;
        document.getElementById('setting-memory-window').value = 10;
        this.showToast('Settings reset to defaults');
    }
};
