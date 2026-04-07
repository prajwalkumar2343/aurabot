/**
 * AuraBot Electron Main Process
 * Handles window management, Go backend spawning, and IPC
 */

const { app, BrowserWindow, dialog } = require('electron');
const path = require('path');
const { createSplashWindow, updateSplashStatus, closeSplashWindow } = require('./lib/splash');
const { createTray, updateTrayMenu } = require('./lib/tray');
const { startGoBackend, stopBackend } = require('./lib/backendManager');
const { startPythonServer, stopPythonServer } = require('./lib/pythonManager');
const { setupIPC, setBackendPort, createToggleCapture, triggerQuickEnhance } = require('./lib/ipcHandlers');

// Constants
const BACKEND_PORT = 7345;
setBackendPort(BACKEND_PORT);

// State
let mainWindow = null;
let isQuitting = false;
let toggleCaptureImpl = null;

// Paths
const isDev = process.env.NODE_ENV === 'development' || !app.isPackaged;
const ROOT_DIR = isDev ? path.join(__dirname, '..') : process.resourcesPath;
const GO_BACKEND_PATH = isDev
  ? path.join(__dirname, 'build', 'aurabot-backend.exe')
  : path.join(process.resourcesPath, 'aurabot-backend.exe');

// ========================================
// Main Window
// ========================================

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1200,
    height: 800,
    minWidth: 900,
    minHeight: 600,
    titleBarStyle: 'hidden',
    titleBarOverlay: {
      color: '#FDFCF9',
      symbolColor: '#1A1A1A',
      height: 40
    },
    backgroundColor: '#FDFCF9',
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
      preload: path.join(__dirname, 'preload.js')
    },
    show: false, // Don't show until ready
    icon: path.join(__dirname, 'build', 'icon.ico')
  });

  // Load the app
  mainWindow.loadFile(path.join(__dirname, 'src', 'index.html'));

  // Show window when ready
  mainWindow.once('ready-to-show', () => {
    // Close splash and show main window
    closeSplashWindow();
    mainWindow.show();

    // Open DevTools in development
    if (isDev) {
      mainWindow.webContents.openDevTools();
    }
  });

  // Handle window close
  mainWindow.on('close', (event) => {
    if (!isQuitting) {
      event.preventDefault();
      mainWindow.hide();
    }
  });

  mainWindow.on('closed', () => {
    mainWindow = null;
  });
}

// ========================================
// App Lifecycle
// ========================================

app.whenReady().then(async () => {
  // Show splash screen immediately
  createSplashWindow();

  // Start Python server first since Go depends on it
  await startPythonServer(ROOT_DIR, updateSplashStatus);

  // Start backend
  const backendStarted = await startGoBackend({ ROOT_DIR, GO_BACKEND_PATH }, { BACKEND_PORT }, {
    updateSplashStatus,
    mainWindowProvider: () => mainWindow,
    isQuittingProvider: () => isQuitting
  });

  if (!backendStarted) {
    updateSplashStatus('Failed to start AI engine');
    setTimeout(() => {
      closeSplashWindow();
      dialog.showErrorBox('Startup Failed', 'Failed to start the AI backend. Please check your configuration.');
    }, 2000);
    return;
  }

  // Create UI
  createWindow();

  // Setup callbacks
  const trayCallbacks = {
    createWindow,
    triggerQuickEnhance: () => triggerQuickEnhance(() => mainWindow),
    setIsQuitting: (val) => isQuitting = val
  };

  createTray(mainWindow, trayCallbacks);

  // Initialize toggleCapture and set its callback
  createToggleCapture(
    (enabled) => updateTrayMenu(mainWindow, trayCallbacks, enabled),
    () => mainWindow
  ).then(impl => {
    toggleCaptureImpl = impl;
    trayCallbacks.toggleCapture = toggleCaptureImpl;
    // Update tray menu once toggleCapture is available
    updateTrayMenu(mainWindow, trayCallbacks, false);

    // Setup IPC
    setupIPC({
      toggleCapture: toggleCaptureImpl,
      mainWindowProvider: () => mainWindow
    });
  });

  const { registerShortcuts, unregisterShortcuts } = require('./lib/shortcuts');

  // Register global shortcuts AFTER app is ready
  registerShortcuts(() => mainWindow);

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createWindow();
    } else if (mainWindow) {
      mainWindow.show();
    }
  });
});

app.on('window-all-closed', () => {
  // Don't quit on Windows - keep tray icon
});

app.on('before-quit', () => {
  isQuitting = true;
});

app.on('will-quit', () => {
  const { unregisterShortcuts } = require('./lib/shortcuts');
  unregisterShortcuts();

  stopBackend();
  stopPythonServer();
});

// Single instance lock
const gotTheLock = app.requestSingleInstanceLock();

if (!gotTheLock) {
  app.quit();
} else {
  app.on('second-instance', () => {
    if (mainWindow) {
      if (mainWindow.isMinimized()) mainWindow.restore();
      mainWindow.show();
      mainWindow.focus();
    }
  });
}
