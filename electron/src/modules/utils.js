/**
 * AuraBot Electron - Utils Module
 * Enhances AuraApp with utility functions
 */

AuraApp.prototype.startPolling = function () {
    // Poll status every 5 seconds
    setInterval(() => this.loadStatus(), 5000);
};

AuraApp.prototype.showToast = function (message, type = 'success') {
    const toast = document.getElementById('toast');
    const toastMessage = document.getElementById('toast-message');
    const toastIcon = document.getElementById('toast-icon');

    if (!toast) return;

    toastMessage.textContent = message;
    toastIcon.innerHTML = type === 'error'
        ? '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3"><path d="M6 18L18 6M6 6l12 12"/></svg>'
        : '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3"><path d="M4.5 12.75l6 6 9-13.5"/></svg>';

    toastIcon.className = 'toast-icon ' + (type === 'error' ? 'error' : '');
    toast.classList.add('show');

    setTimeout(() => {
        toast.classList.remove('show');
    }, 3000);
};

AuraApp.prototype.escapeHtml = function (text) {
    if (!text) return '';
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
};
