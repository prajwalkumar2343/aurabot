/**
 * AuraBot Electron - Backend Manager Module
 * Handles spawning and managing the Go and Python backend processes
 */

const { spawn, exec } = require('child_process');
const path = require('path');
const fs = require('fs');
const { dialog } = require('electron');

let backendProcess = null;
let pythonProcess = null;
let backendReady = false;

async function startGoBackend(roots, ports, callbacks) {
    const { ROOT_DIR, GO_BACKEND_PATH } = roots;
    const { BACKEND_PORT } = ports;
    const { updateSplashStatus, mainWindowProvider, isQuittingProvider } = callbacks;

    if (!fs.existsSync(GO_BACKEND_PATH)) {
        console.error('Go backend not found at:', GO_BACKEND_PATH);
        dialog.showErrorBox('Backend Not Found',
            `Go backend executable not found. Please run "npm run compile-go" first.`);
        return false;
    }

    console.log('Starting Go backend...');
    if (updateSplashStatus) updateSplashStatus('Starting AI engine...');

    return new Promise((resolve) => {
        const env = {
            ...process.env,
            AURABOT_ELECTRON_MODE: '1',
            AURABOT_EXTENSION_PORT: BACKEND_PORT.toString()
        };

        backendProcess = spawn(GO_BACKEND_PATH, [], {
            cwd: ROOT_DIR,
            env,
            stdio: ['ignore', 'pipe', 'pipe']
        });

        let stdout = '';
        let stderr = '';

        backendProcess.stdout.on('data', (data) => {
            stdout += data.toString();
            console.log('[Go Backend]', data.toString().trim());

            // Update status based on startup messages
            const msg = data.toString();
            if (updateSplashStatus) {
                if (msg.includes('LLM connected') || msg.includes('✓ LLM')) {
                    updateSplashStatus('Connecting to AI models...');
                } else if (msg.includes('Mem0 connected') || msg.includes('✓ Mem0')) {
                    updateSplashStatus('Initializing memory system...');
                } else if (msg.includes('started') || msg.includes('running')) {
                    updateSplashStatus('Starting UI...');
                }
            }

            // Check if backend is ready
            if (msg.includes('Extension API server started') ||
                msg.includes('started') ||
                msg.includes('running')) {
                backendReady = true;
                resolve(true);
            }
        });

        backendProcess.stderr.on('data', (data) => {
            stderr += data.toString();
            console.error('[Go Backend Error]', data.toString().trim());
        });

        backendProcess.on('error', (error) => {
            console.error('Failed to start Go backend:', error);
            if (updateSplashStatus) updateSplashStatus('Error starting AI engine');
            dialog.showErrorBox('Backend Error',
                `Failed to start backend: ${error.message}`);
            resolve(false);
        });

        backendProcess.on('exit', (code) => {
            console.log(`Go backend exited with code ${code}`);
            backendReady = false;
            const mainWindow = mainWindowProvider ? mainWindowProvider() : null;
            const isQuitting = isQuittingProvider ? isQuittingProvider() : false;
            if (mainWindow && !isQuitting) {
                mainWindow.webContents.send('backend-status', {
                    running: false,
                    error: `Backend exited with code ${code}`
                });
            }
        });

        // Timeout after 10 seconds
        setTimeout(() => {
            if (!backendReady) {
                console.log('Backend startup timeout - assuming ready');
                backendReady = true;
                resolve(true);
            }
        }, 10000);
    });
}

function stopBackend() {
    if (backendProcess) {
        console.log('Stopping Go backend...');
        backendProcess.kill('SIGTERM');

        // Force kill after 5 seconds
        setTimeout(() => {
            if (backendProcess && !backendProcess.killed) {
                backendProcess.kill('SIGKILL');
            }
        }, 5000);

        backendProcess = null;
        backendReady = false;
    }
}

module.exports = {
    startGoBackend,
    stopBackend
};
