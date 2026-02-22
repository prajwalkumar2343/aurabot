/**
 * AuraBot Electron - Frontend Controller
 * Handles UI interactions and IPC communication with main process
 */

class AuraApp {
    constructor() {
        this.currentView = 'dashboard';
        this.isCaptureEnabled = false;
        this.memories = [];
        this.config = {};
        this.expandedCards = new Set();
        this.backendConnected = false;
        this.init();
    }

    init() {
        this.setupNavigation();
        this.setupDashboard();
        this.setupMemories();
        this.setupChat();
        this.setupSettings();
        this.setupModal();
        this.setupKeyboardShortcuts();
        this.setupQuickEnhance();
        this.setupWindowControls();
        this.setupIPCListeners();

        // Load initial data
        this.loadStatus();
        this.loadConfig();
        this.loadMemories();

        // Start polling
        this.startPolling();

        console.log('✨ Aura Electron initialized');
    }
}
