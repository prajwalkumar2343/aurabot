/**
 * AuraBot Electron - Shortcuts Module
 * Enhances AuraApp with keyboard shortcut functionality
 */

AuraApp.prototype.setupKeyboardShortcuts = function () {
    document.addEventListener('keydown', (e) => {
        // Ctrl + K for search
        if ((e.ctrlKey || e.metaKey) && e.key === 'k') {
            e.preventDefault();
            if (this.currentView === 'memories') {
                document.getElementById('memories-search-input')?.focus();
            } else {
                document.querySelector('[data-view="memories"]')?.click();
            }
        }

        // Ctrl + N for new memory
        if ((e.ctrlKey || e.metaKey) && e.key === 'n') {
            e.preventDefault();
            this.openModal();
        }

        // Escape to close modal
        if (e.key === 'Escape') {
            document.getElementById('modal-overlay')?.classList.remove('active');
            document.getElementById('modal-new-memory')?.classList.remove('active');
            document.getElementById('quick-enhance-overlay')?.classList.remove('active');
            document.getElementById('quick-enhance-modal')?.classList.remove('active');
        }

        // Ctrl + Enter to save memory
        if ((e.ctrlKey || e.metaKey) && e.key === 'Enter') {
            if (document.getElementById('modal-new-memory')?.classList.contains('active')) {
                document.getElementById('btn-save-memory')?.click();
            }
        }

        // DEBUG: Ctrl + Shift + P to test Pacman animation
        if ((e.ctrlKey || e.metaKey) && e.shiftKey && e.key === 'P') {
            e.preventDefault();
            console.log('[DEBUG] Manual Pacman trigger - use Ctrl+Alt+E with selected text instead');
            this.showToast('Use Ctrl+Alt+E with selected text to test', 'info');
        }
    });
};
