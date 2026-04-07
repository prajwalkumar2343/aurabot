/**
 * AuraBot Electron - Dashboard Module
 * Enhances AuraApp with dashboard functionality
 */

AuraApp.prototype.setupDashboard = function () {
    // New Memory button
    document.getElementById('btn-new-memory')?.addEventListener('click', () => {
        this.openModal();
    });

    // Start capture from empty state
    document.getElementById('btn-start-capture-empty')?.addEventListener('click', () => {
        this.toggleCapture(true);
    });

    // View all memories
    document.getElementById('btn-view-all-memories')?.addEventListener('click', () => {
        document.querySelector('[data-view="memories"]')?.click();
    });

    // Sidebar capture toggle
    document.getElementById('sidebar-capture-toggle')?.addEventListener('change', (e) => {
        this.toggleCapture(e.target.checked);
    });
};
