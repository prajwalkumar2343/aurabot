/**
 * AuraBot Electron - Frontend Controller
 * Handles UI interactions and IPC communication with main process
 */

class AuraApp {
    constructor() {
        console.log('🚀 AuraApp constructor started');
        this.currentView = 'dashboard';
        this.isCaptureEnabled = false;
        this.memories = [];
        this.config = {};
        this.expandedCards = new Set();
        this.backendConnected = false;
        this.init();
    }

    init() {
        const initStep = (name, fn) => {
            try {
                fn();
            } catch (e) {
                console.error(`Init failed for ${name}:`, e);
            }
        };

        initStep('Navigation', () => this.setupNavigation());
        initStep('Dashboard', () => this.setupDashboard());
        initStep('Memories', () => this.setupMemories());
        initStep('Chat', () => this.setupChat());
        initStep('Settings', () => this.setupSettings());
        initStep('Modal', () => this.setupModal());
        initStep('KeyboardShortcuts', () => this.setupKeyboardShortcuts());
        initStep('QuickEnhance', () => this.setupQuickEnhance());
        initStep('WindowControls', () => this.setupWindowControls());
        initStep('IPCListeners', () => this.setupIPCListeners());

        // Load initial data
        this.loadStatus();
        this.loadConfig();
        this.loadMemories();

        // Start polling
        this.startPolling();

        console.log('✨ Aura Electron initialized');
    }
}
