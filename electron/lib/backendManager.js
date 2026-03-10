/**
 * AuraBot Electron - Backend Manager Module
 * Handles spawning and managing the Go and Python backend processes
 */

const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');
const http = require('http');
// dialog import removed — backend startup is now optional

let backendProcess = null;
let pythonProcess = null;
let backendReady = false;

function waitForBackend(port, timeout = 15000) {
    const startTime = Date.now();
    return new Promise((resolve) => {
        const check = async () => {
            if (Date.now() - startTime > timeout) {
                resolve(false);
                return;
            }
            try {
                const response = await new Promise((res, rej) => {
                    const req = http.get(`http://localhost:${port}/health`, (r) => {
                        let data = '';
                        r.on('data', chunk => data += chunk);
                        r.on('end', () => res({ status: r.statusCode, data }));
                    });
                    req.on('error', rej);
                    req.setTimeout(1000, () => req.destroy());
                });
                if (response.status === 200) {
                    resolve(true);
                    return;
                }
            } catch {
                // Not ready yet
            }
            setTimeout(check, 500);
        };
        check();
    });
}
const WAILS_GUARD_SIGNATURE = Buffer.from(
    'Wails applications will not build without the correct build tags.',
    'utf8'
);

function isWailsGuardBinary(binaryPath) {
    try {
        const contents = fs.readFileSync(binaryPath);
        return contents.includes(WAILS_GUARD_SIGNATURE);
    } catch (error) {
        console.error('[Go Backend] Failed to inspect backend binary:', error.message);
        return false;
    }
}

function buildBackendFromSource(ROOT_DIR, GO_BACKEND_PATH, updateSplashStatus) {
    const goSourceDir = path.join(ROOT_DIR, 'go');
    const goMainFile = path.join(goSourceDir, 'main.go');

    if (!fs.existsSync(goMainFile)) {
        console.error('[Go Backend] Cannot rebuild backend: go/main.go not found at', goMainFile);
        return Promise.resolve(false);
    }

    if (updateSplashStatus) {
        updateSplashStatus('Rebuilding backend...');
    }

    console.log('[Go Backend] Rebuilding backend binary from go/main.go');

    return new Promise((resolve) => {
        const buildProcess = spawn('go', ['build', '-o', GO_BACKEND_PATH, 'main.go'], {
            cwd: goSourceDir,
            env: process.env,
            stdio: ['ignore', 'pipe', 'pipe']
        });

        let buildStdout = '';
        let buildStderr = '';

        buildProcess.stdout.on('data', (data) => {
            buildStdout += data.toString();
        });

        buildProcess.stderr.on('data', (data) => {
            buildStderr += data.toString();
        });

        buildProcess.on('error', (error) => {
            console.error('[Go Backend] Failed to start go build:', error.message);
            resolve(false);
        });

        buildProcess.on('exit', (code) => {
            if (code !== 0) {
                console.error('[Go Backend] go build failed with code', code);
                if (buildStdout.trim()) {
                    console.error('[Go Backend] go build stdout:', buildStdout.trim());
                }
                if (buildStderr.trim()) {
                    console.error('[Go Backend] go build stderr:', buildStderr.trim());
                }
                resolve(false);
                return;
            }

            const rebuiltBinaryLooksWrong = isWailsGuardBinary(GO_BACKEND_PATH);
            if (rebuiltBinaryLooksWrong) {
                console.error('[Go Backend] Rebuild completed but backend binary still looks like a Wails app');
                resolve(false);
                return;
            }

            console.log('[Go Backend] Backend rebuild completed successfully');
            resolve(true);
        });
    });
}

async function startGoBackend(roots, ports, callbacks) {
    const { ROOT_DIR, GO_BACKEND_PATH } = roots;
    const { BACKEND_PORT } = ports;
    const { updateSplashStatus, mainWindowProvider, isQuittingProvider } = callbacks;

    if (!fs.existsSync(GO_BACKEND_PATH)) {
        console.log('[Go Backend] Backend not found at:', GO_BACKEND_PATH, '— skipping (app will run without backend)');
        return false;
    }

    if (isWailsGuardBinary(GO_BACKEND_PATH)) {
        console.error('[Go Backend] Detected Wails desktop binary at backend path:', GO_BACKEND_PATH);
        const rebuilt = await buildBackendFromSource(ROOT_DIR, GO_BACKEND_PATH, updateSplashStatus);
        if (!rebuilt) {
            console.error('[Go Backend] Could not repair backend binary automatically');
            if (updateSplashStatus) updateSplashStatus('Backend unavailable — continuing without it');
            return false;
        }
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
        let startupFailed = false;

        backendProcess.stdout.on('data', (data) => {
            stdout += data.toString();
            const msg = data.toString().trim();
            console.log('[Go Backend]', msg);

            // Update status based on startup messages
            if (updateSplashStatus) {
                if (msg.includes('LLM connected') || msg.includes('✓ LLM')) {
                    updateSplashStatus('Connecting to AI models...');
                } else if (msg.includes('Mem0 connected') || msg.includes('✓ Mem0')) {
                    updateSplashStatus('Initializing memory system...');
                } else if (msg.includes('API server starting')) {
                    updateSplashStatus('Starting UI...');
                }
            }
        });

        backendProcess.stderr.on('data', (data) => {
            stderr += data.toString();
            const msg = data.toString().trim();
            console.error('[Go Backend Error]', msg);
            
            // Detect fatal startup failures only (not dependency warnings)
            // The backend now stays running even if dependencies fail
            if (msg.includes('Failed to start API server') ||
                msg.includes('Failed to load config') ||
                msg.includes('Failed to create service')) {
                startupFailed = true;
            }
        });

        backendProcess.on('error', (error) => {
            console.error('[Go Backend] Failed to start:', error.message);
            if (updateSplashStatus) updateSplashStatus('Backend unavailable — continuing without it');
            resolve(false);
        });

        backendProcess.on('exit', (code) => {
            console.log(`Go backend exited with code ${code}`);
            backendReady = false;
            if (startupFailed || code !== 0) {
                console.log('[Go Backend] Startup failed - app will run without backend services');
                if (updateSplashStatus) updateSplashStatus('Backend unavailable — continuing without it');
                resolve(false);
                return;
            }
            const mainWindow = mainWindowProvider ? mainWindowProvider() : null;
            const isQuitting = isQuittingProvider ? isQuittingProvider() : false;
            if (mainWindow && !isQuitting) {
                mainWindow.webContents.send('backend-status', {
                    running: false,
                    error: `Backend exited with code ${code}`
                });
            }
        });

        // Wait for actual HTTP health check instead of log messages
        // Give more time since dependency checks happen in background
        waitForBackend(BACKEND_PORT, 20000).then(ready => {
            if (ready && !startupFailed) {
                console.log('[Go Backend] Health check passed - server is ready');
                backendReady = true;
                resolve(true);
            } else {
                console.log('[Go Backend] Health check failed or startup error detected');
                // Kill the process if it's stuck
                if (backendProcess && !backendProcess.killed) {
                    backendProcess.kill('SIGTERM');
                }
                if (updateSplashStatus) updateSplashStatus('Backend unavailable — continuing without it');
                resolve(false);
            }
        });
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
