/**
 * AuraBot Electron Preload Script
 * Securely exposes main process APIs to the renderer
 */

const { contextBridge, ipcRenderer } = require('electron');

// API exposed to the renderer process
contextBridge.exposeInMainWorld('electronAPI', {
  // Status & Config
  getStatus: () => ipcRenderer.invoke('get-status'),
  getConfig: () => ipcRenderer.invoke('get-config'),
  updateConfig: (config) => ipcRenderer.invoke('update-config', config),

  // Memories
  getMemories: (limit) => ipcRenderer.invoke('get-memories', limit),
  searchMemories: (query, limit) => ipcRenderer.invoke('search-memories', query, limit),
  addMemory: (content, metadata) => ipcRenderer.invoke('add-memory', content, metadata),

  // Chat
  chat: (message) => ipcRenderer.invoke('chat', message),

  // Capture
  toggleCapture: (enabled) => ipcRenderer.invoke('toggle-capture', enabled),

  // Enhance
  enhancePrompt: (prompt, context) => ipcRenderer.invoke('enhance-prompt', prompt, context),

  // Window Controls
  minimizeWindow: () => ipcRenderer.invoke('minimize-window'),
  maximizeWindow: () => ipcRenderer.invoke('maximize-window'),
  closeWindow: () => ipcRenderer.invoke('close-window'),

  // Clipboard
  readClipboard: () => ipcRenderer.invoke('read-clipboard'),
  writeClipboard: (text) => ipcRenderer.invoke('write-clipboard', text),

  // External Links
  openExternal: (url) => ipcRenderer.invoke('open-external', url),

  // Version
  getVersion: () => ipcRenderer.invoke('get-version'),

  // Event Listeners
  onNavigate: (callback) => ipcRenderer.on('navigate', (_, view) => callback(view)),
  onCaptureStatus: (callback) => ipcRenderer.on('capture-status', (_, status) => callback(status)),
  onBackendStatus: (callback) => ipcRenderer.on('backend-status', (_, status) => callback(status)),
  onTriggerQuickEnhance: (callback) => ipcRenderer.on('trigger-quick-enhance', () => callback()),
  onTriggerGhostEnhance: (callback) => ipcRenderer.on('trigger-ghost-enhance', () => callback()),

  // Remove listeners
  removeAllListeners: (channel) => ipcRenderer.removeAllListeners(channel)
});

// Legacy compatibility with Wails-based code
contextBridge.exposeInMainWorld('go', {
  main: {
    App: {
      GetStatus: () => ipcRenderer.invoke('get-status').then(r => r.success ? r.data : {}),
      GetConfig: () => ipcRenderer.invoke('get-config').then(r => r.success ? r.data : {}),
      UpdateConfig: (config) => ipcRenderer.invoke('update-config', config),
      GetMemories: (limit) => ipcRenderer.invoke('get-memories', limit).then(r => r.success ? r.data : []),
      SearchMemories: (query, limit) => ipcRenderer.invoke('search-memories', query, limit).then(r => r.success ? r.data : []),
      Chat: (message) => ipcRenderer.invoke('chat', message).then(r => r.success ? r.data?.response || r.data : 'Error'),
      ToggleCapture: (enabled) => ipcRenderer.invoke('toggle-capture', enabled),
      EnhancePrompt: (prompt, context) => ipcRenderer.invoke('enhance-prompt', prompt, context),
      QuickEnhanceText: (text) => ipcRenderer.invoke('enhance-prompt', text, '').then(r => r.success ? r.data : { enhanced_prompt: text }),
      PasteEnhanced: (text) => Promise.resolve(), // Handled by main process
      AddMemory: (content, metadata) => ipcRenderer.invoke('add-memory', content, metadata)
    }
  }
});

// Runtime events (for Wails compatibility)
contextBridge.exposeInMainWorld('runtime', {
  EventsOn: (event, callback) => {
    if (event === 'quickenhance:triggered') {
      ipcRenderer.on('trigger-quick-enhance', () => callback({ text: '' }));
    }
  },
  EventsOff: (event) => {
    ipcRenderer.removeAllListeners(event);
  }
});
