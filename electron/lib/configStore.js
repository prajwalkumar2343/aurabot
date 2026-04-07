/**
 * AuraBot Electron - Local Config Store
 * Handles persistent storage of settings when Go backend is unavailable
 */

const fs = require('fs');
const path = require('path');
const { app } = require('electron');

const CONFIG_FILE = path.join(app.getPath('userData'), 'aurabot-config.json');

const DEFAULTS = {
    capture: {
        interval_seconds: 30,
        quality: 60,
        max_width: 1280,
        max_height: 720,
        enabled: true
    },
    llm: {
        provider: "lm-studio",
        base_url: "http://127.0.0.1:1234/v1",
        api_key: "",
        model: "local-model",
        max_tokens: 512,
        temperature: 0.7
    },
    vision: {
        provider: "lm-studio",
        base_url: "http://127.0.0.1:1234/v1",
        api_key: "",
        model: "local-model"
    },
    embeddings: {
        provider: "lm-studio",
        base_url: "http://127.0.0.1:1234/v1",
        api_key: "",
        model: "local-model",
        dimensions: 768
    },
    memory: {
        api_key: "",
        base_url: "http://127.0.0.1:8000",
        user_id: "default_user",
        collection_name: "screen_memories"
    },
    app: {
        verbose: false,
        process_on_capture: true,
        memory_window: 10
    }
};

function loadLocalConfig() {
    try {
        if (fs.existsSync(CONFIG_FILE)) {
            const data = fs.readFileSync(CONFIG_FILE, 'utf8');
            return JSON.parse(data);
        }
    } catch (error) {
        console.error('Failed to load local config:', error);
    }
    return JSON.parse(JSON.stringify(DEFAULTS)); // Deep copy defaults
}

function saveLocalConfig(config) {
    try {
        // Ensure directory exists
        const dir = path.dirname(CONFIG_FILE);
        if (!fs.existsSync(dir)) {
            fs.mkdirSync(dir, { recursive: true });
        }

        // Load current for merging (don't overwrite EVERYTHING if not provided)
        const current = loadLocalConfig();
        const merged = { ...current, ...config };

        fs.writeFileSync(CONFIG_FILE, JSON.stringify(merged, null, 2));
        return true;
    } catch (error) {
        console.error('Failed to save local config:', error);
        return false;
    }
}

function getDefaults() {
    return JSON.parse(JSON.stringify(DEFAULTS));
}

module.exports = {
    loadLocalConfig,
    saveLocalConfig,
    getDefaults
};
