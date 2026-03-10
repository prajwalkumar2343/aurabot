/**
 * AuraBot Electron Overlay Preload Script
 * For the transparent overlay window
 */

const { contextBridge, ipcRenderer } = require('electron');

// API exposed to the overlay renderer process
contextBridge.exposeInMainWorld('electronAPI', {
  // Event Listeners
  onTriggerGhostEnhance: (callback) => ipcRenderer.on('trigger-ghost-enhance', (_, data) => callback(data)),
  
  // Remove listeners
  removeAllListeners: (channel) => ipcRenderer.removeAllListeners(channel)
});

// Expose ipcRenderer methods directly for the overlay
contextBridge.exposeInMainWorld('ipcRenderer', {
  on: (channel, callback) => ipcRenderer.on(channel, callback),
  once: (channel, callback) => ipcRenderer.once(channel, callback),
  send: (channel, data) => ipcRenderer.send(channel, data)
});
