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

    // Quick enhance trigger from dashboard
    document.getElementById('btn-quick-enhance-trigger')?.addEventListener('click', () => {
        if (this.openQuickEnhance) this.openQuickEnhance();
    });

    // Quick action buttons with data-view (e.g., "Ask Aura")
    document.querySelectorAll('.quick-action-btn[data-view]').forEach(btn => {
        btn.addEventListener('click', () => {
            const viewName = btn.dataset.view;
            document.querySelector(`.nav-item[data-view="${viewName}"]`)?.click();
        });
    });

    // Welcome greeting logic
    this.updateWelcomeGreeting();
    // Update every minute
    setInterval(() => this.updateWelcomeGreeting(), 60000);
};

AuraApp.prototype.updateWelcomeGreeting = function () {
    const hour = new Date().getHours();
    let greeting;
    if (hour < 12) greeting = 'Good Morning';
    else if (hour < 17) greeting = 'Good Afternoon';
    else greeting = 'Good Evening';

    const greetingEl = document.getElementById('welcome-greeting');
    if (greetingEl) greetingEl.textContent = greeting;

    const timeEl = document.getElementById('welcome-time');
    if (timeEl) {
        const now = new Date();
        const options = { weekday: 'long', month: 'long', day: 'numeric' };
        timeEl.textContent = now.toLocaleDateString('en-US', options);
    }
};
