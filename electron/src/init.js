/**
 * AuraBot Electron - Renderer Initialization
 * Acts as the entry point for the frontend app
 */

(function () {
    console.log('🔌 init.js executing...');
    const setStatus = (txt) => {
        const el = document.getElementById('ui-debug-status');
        if (el) el.textContent = txt;
    };

    setStatus('UI_INIT_START');

    // Initialize AuraApp
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', () => {
            console.log('📦 DOMContentLoaded fired, creating AuraApp...');
            setStatus('UI_INIT_DOM');
            window.app = new AuraApp();
            setStatus('UI_INIT_OK');
        });
    } else {
        console.log('📦 DOM already ready, creating AuraApp...');
        window.app = new AuraApp();
        setStatus('UI_INIT_OK');
    }
})();
