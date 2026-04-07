/**
 * AuraBot Electron - Navigation Module
 * Enhances AuraApp with navigation functionality
 */

AuraApp.prototype.setupNavigation = function () {
    const navItems = document.querySelectorAll('.nav-item[data-view]');
    const views = document.querySelectorAll('.view');

    navItems.forEach(item => {
        item.addEventListener('click', () => {
            const viewName = item.dataset.view;

            // Update nav
            navItems.forEach(n => n.classList.remove('active'));
            item.classList.add('active');

            // Switch view
            views.forEach(v => v.classList.remove('active'));
            document.getElementById(`view-${viewName}`)?.classList.add('active');

            this.currentView = viewName;

            // Load view data
            if (viewName === 'memories') this.loadMemories();
            if (viewName === 'dashboard') this.loadMemories();
        });
    });
};
