/**
 * AuraBot Electron - Settings Module
 */

// Provider Presets
const PROVIDER_PRESETS = {
    openai: { url: 'https://api.openai.com/v1', llm: 'gpt-4o', vision: 'gpt-4o', embeddings: 'text-embedding-3-small' },
    anthropic: { url: 'https://api.anthropic.com/v1', llm: 'claude-3-5-sonnet-20240620', vision: 'claude-3-5-sonnet-20240620', embeddings: '' },
    gemini: { url: 'https://generativelanguage.googleapis.com/v1beta', llm: 'gemini-2.0-flash', vision: 'gemini-2.0-flash', embeddings: 'text-embedding-004' },
    groq: { url: 'https://api.groq.com/openai/v1', llm: 'llama-3.3-70b-versatile', vision: 'llama-3.2-90b-vision-preview', embeddings: '' },
    cerebras: { url: 'https://api.cerebras.ai/v1', llm: 'llama-3.3-70b', vision: '', embeddings: '' },
    ollama: { url: 'http://localhost:11434/v1', llm: 'llama3', vision: 'llava', embeddings: 'nomic-embed-text' },
    'lm-studio': { url: 'http://localhost:1234/v1', llm: 'local-model', vision: 'local-model', embeddings: 'local-model' },
    custom: { url: '', llm: '', vision: '', embeddings: '' }
};

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

    // Provider Change Handlers
    const setupProviderListener = (type) => {
        const select = document.getElementById(`setting-${type}-provider`);
        select?.addEventListener('change', (e) => {
            const provider = e.target.value;
            const preset = PROVIDER_PRESETS[provider];
            if (preset) {
                const urlInput = document.getElementById(type === 'llm' ? `setting-llm-url-new` : `setting-${type}-url`);
                const modelInput = document.getElementById(type === 'llm' ? `setting-llm-model-new` : `setting-${type}-model`);

                if (urlInput) urlInput.value = preset.url;
                if (modelInput) modelInput.value = preset[type] || '';
            }
        });
    };

    ['llm', 'vision', 'embeddings'].forEach(setupProviderListener);

    // API Key Toggle Handlers
    document.querySelectorAll('.api-key-toggle').forEach(btn => {
        btn.addEventListener('click', () => {
            const targetId = btn.dataset.target;
            const input = document.getElementById(targetId);
            if (input) {
                const isPassword = input.type === 'password';
                input.type = isPassword ? 'text' : 'password';
                btn.innerHTML = isPassword ?
                    `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14"><path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19m-6.72-1.07a3 3 0 1 1-4.24-4.24M1 1l22 22"/></svg>` :
                    `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z" /><circle cx="12" cy="12" r="3" /></svg>`;
            }
        });
    });

    // Capture settings
    document.getElementById('setting-capture-enabled')?.addEventListener('change', (e) => {
        this.toggleCapture(e.target.checked);
    });

    const intervalSlider = document.getElementById('setting-capture-interval');
    intervalSlider?.addEventListener('input', (e) => {
        document.getElementById('display-capture-interval').textContent = `${e.target.value}s`;
    });

    const qualitySlider = document.getElementById('setting-capture-quality');
    qualitySlider?.addEventListener('input', (e) => {
        document.getElementById('display-capture-quality').textContent = `${e.target.value}%`;
    });

    // Final actions
    document.getElementById('btn-save-settings')?.addEventListener('click', () => this.saveSettings());
    document.getElementById('btn-reset-settings')?.addEventListener('click', () => this.resetSettings());
    document.getElementById('btn-check-update')?.addEventListener('click', () => {
        this.showToast('Checking for updates...');
        setTimeout(() => this.showToast('You have the latest version!'), 1500);
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

    try {
        const version = await window.electronAPI?.getVersion();
        if (version && document.getElementById('app-version')) {
            document.getElementById('app-version').textContent = `v${version}`;
        }
    } catch (error) {
        console.error('Failed to get version:', error);
    }
};

AuraApp.prototype.populateSettings = function (config) {
    if (!config) return;

    // Capture
    if (config.capture) {
        const enabledEl = document.getElementById('setting-capture-enabled');
        if (enabledEl) enabledEl.checked = config.capture.enabled;

        const intervalEl = document.getElementById('setting-capture-interval');
        if (intervalEl) intervalEl.value = config.capture.interval_seconds || 30;

        const displayIntervalEl = document.getElementById('display-capture-interval');
        if (displayIntervalEl) displayIntervalEl.textContent = `${config.capture.interval_seconds || 30}s`;

        const qualityEl = document.getElementById('setting-capture-quality');
        if (qualityEl) qualityEl.value = config.capture.quality || 60;

        const displayQualityEl = document.getElementById('display-capture-quality');
        if (displayQualityEl) displayQualityEl.textContent = `${config.capture.quality || 60}%`;

        const processOnCaptureEl = document.getElementById('setting-process-on-capture');
        if (processOnCaptureEl) processOnCaptureEl.checked = config.app?.process_on_capture !== false;
    }

    // Providers
    const populateProvider = (type) => {
        const section = config[type];
        if (!section) return;

        const prefix = type === 'llm' ? 'llm' : type;
        const suffix = type === 'llm' ? '-new' : '';

        const provEl = document.getElementById(`setting-${prefix}-provider`);
        const urlEl = document.getElementById(`setting-${prefix}-url${suffix}`);
        const keyEl = document.getElementById(`setting-${prefix}-key`);
        const modelEl = document.getElementById(`setting-${prefix}-model${suffix}`);

        if (provEl) provEl.value = section.provider || 'custom';
        if (urlEl) urlEl.value = section.base_url || '';
        if (keyEl) keyEl.value = section.api_key || '';
        if (modelEl) modelEl.value = section.model || '';
    };

    ['llm', 'vision', 'embeddings'].forEach(populateProvider);

    // Memory & App
    if (config.app) {
        const memWindowEl = document.getElementById('setting-memory-window');
        if (memWindowEl) memWindowEl.value = config.app.memory_window || 10;
    }
    if (config.memory) {
        const mem0UrlEl = document.getElementById('setting-mem0-url');
        if (mem0UrlEl) mem0UrlEl.value = config.memory.base_url || 'http://localhost:8000';
    }
};

AuraApp.prototype.saveSettings = async function () {
    const settings = {
        capture: {
            enabled: document.getElementById('setting-capture-enabled')?.checked || false,
            interval_seconds: parseInt(document.getElementById('setting-capture-interval')?.value || 30),
            quality: parseInt(document.getElementById('setting-capture-quality')?.value || 60)
        },
        llm: {
            provider: document.getElementById('setting-llm-provider')?.value,
            base_url: document.getElementById('setting-llm-url-new')?.value,
            api_key: document.getElementById('setting-llm-key')?.value,
            model: document.getElementById('setting-llm-model-new')?.value
        },
        vision: {
            provider: document.getElementById('setting-vision-provider')?.value,
            base_url: document.getElementById('setting-vision-url')?.value,
            api_key: document.getElementById('setting-vision-key')?.value,
            model: document.getElementById('setting-vision-model')?.value
        },
        embeddings: {
            provider: document.getElementById('setting-embeddings-provider')?.value,
            base_url: document.getElementById('setting-embeddings-url')?.value,
            api_key: document.getElementById('setting-embeddings-key')?.value,
            model: document.getElementById('setting-embeddings-model')?.value
        },
        app: {
            memory_window: parseInt(document.getElementById('setting-memory-window')?.value || 10),
            process_on_capture: document.getElementById('setting-process-on-capture')?.checked || false
        },
        memory: {
            base_url: document.getElementById('setting-mem0-url')?.value || 'http://localhost:8000'
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
        this.showToast('Error saving settings', 'error');
    }
};

AuraApp.prototype.resetSettings = function () {
    if (confirm('Reset all settings to defaults?')) {
        // Just trigger a re-save with defaults if you have them, 
        // or clear the form and populate with PROVIDER_PRESETS['lm-studio']
        const defaults = {
            capture: { enabled: true, interval_seconds: 30, quality: 60 },
            llm: { provider: 'lm-studio', base_url: 'http://localhost:1234/v1', api_key: '', model: 'local-model' },
            vision: { provider: 'lm-studio', base_url: 'http://localhost:1234/v1', api_key: '', model: 'local-model' },
            embeddings: { provider: 'lm-studio', base_url: 'http://localhost:1234/v1', api_key: '', model: 'local-model' },
            app: { memory_window: 10, process_on_capture: true },
            memory: { base_url: 'http://localhost:8000' }
        };
        this.populateSettings(defaults);
        this.showToast('Settings reset to defaults');
    }
};
