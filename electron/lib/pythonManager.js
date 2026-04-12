/**
 * AuraBot Electron - Python Server Manager Module
 * Handles spawning and managing the Python local server process
 */

const { spawn, exec } = require('child_process');
const path = require('path');
const fs = require('fs');
const http = require('http');

let pythonProcess = null;

async function waitForServer(port, timeout = 30000) {
    const startTime = Date.now();
    while (Date.now() - startTime < timeout) {
        try {
            const response = await new Promise((resolve, reject) => {
                const req = http.get(`http://127.0.0.1:${port}/health`, (res) => {
                    let data = '';
                    res.on('data', chunk => data += chunk);
                    res.on('end', () => resolve({ status: res.statusCode, data }));
                });
                req.on('error', reject);
                req.setTimeout(2000, () => req.destroy());
            });
            if (response.status === 200) {
                return true;
            }
        } catch {
            // Server not ready yet
        }
        await new Promise(r => setTimeout(r, 500));
    }
    return false;
}

async function startPythonServer(ROOT_DIR, updateSplashStatus) {
    // Check if Python is available first (quick check)
    const pythonCmd = await findPython();
    if (!pythonCmd) {
        console.log('[Python] Python not found, skipping Python server...');
        return false;
    }

    // Try simpler server first (mem0_server.py uses external APIs)
    // Fall back to local server if available
    const serverScripts = [
        path.join(ROOT_DIR, 'python', 'src', 'mem0_server.py'),
        path.join(ROOT_DIR, 'python', 'src', 'mem0_local.py')
    ];

    let pythonScript = null;
    for (const script of serverScripts) {
        if (fs.existsSync(script)) {
            pythonScript = script;
            break;
        }
    }

    if (!pythonScript) {
        console.log('[Python] Python server script not found, skipping...');
        return false;
    }

    // Check if LM Studio is running (required for mem0_local.py)
    const lmStudioRunning = await checkLmStudio();
    if (pythonScript.includes('mem0_local.py') && !lmStudioRunning) {
        console.log('[Python] LM Studio not detected on port 1234, skipping local Python server');
        console.log('[Python] To use local models, start LM Studio with server on port 1234');
        return false;
    }

    console.log('[Python] Starting Python server...');
    if (updateSplashStatus) updateSplashStatus('Starting Python services...');

    return new Promise((resolve) => {
        const env = {
            ...process.env,
            MEM0_PORT: '8000',
            MEM0_HOST: '127.0.0.1',
            PYTHONUNBUFFERED: '1'
        };

        pythonProcess = spawn(pythonCmd, [pythonScript], {
            cwd: path.join(ROOT_DIR, 'python', 'src'),
            env,
            stdio: ['ignore', 'pipe', 'pipe']
        });

        let isReady = false;

        pythonProcess.stdout.on('data', (data) => {
            const msg = data.toString().trim();
            console.log('[Python]', msg);
            // Check for various startup completion messages
            if (msg.includes('Server starting') || msg.includes('Running on') ||
                msg.includes('Startup complete') || msg.includes('OK')) {
                isReady = true;
            }
        });

        pythonProcess.stderr.on('data', (data) => {
            console.error('[Python Error]', data.toString().trim());
        });

        pythonProcess.on('error', (error) => {
            console.error('[Python] Failed to start Python server:', error);
            resolve(false);
        });

        pythonProcess.on('exit', (code) => {
            if (code !== 0 && code !== null) {
                console.log(`[Python] Python server exited with code ${code}`);
            }
            if (!isReady) {
                resolve(false);
            }
        });

        // Wait for actual health check response instead of just timeout
        // Use shorter timeout (15s) since we already checked LM Studio
        waitForServer(8000, 15000).then(ready => {
            if (ready) {
                console.log('[Python] Server is healthy and responding');
                isReady = true;
                resolve(true);
            } else {
                console.log('[Python] Server failed health check, continuing without Python');
                // Kill the process if it's not healthy
                if (pythonProcess && !pythonProcess.killed) {
                    pythonProcess.kill('SIGTERM');
                }
                resolve(false);
            }
        });
    });
}

async function checkLmStudio() {
    return new Promise((resolve) => {
        const req = http.get('http://localhost:1234/v1/models', (res) => {
            resolve(res.statusCode === 200);
        });
        req.on('error', () => resolve(false));
        req.setTimeout(2000, () => req.destroy());
    });
}

async function findPython() {
    const commands = ['python', 'python3', 'py'];

    for (const cmd of commands) {
        try {
            await new Promise((resolve, reject) => {
                exec(`${cmd} --version`, (error) => {
                    if (error) reject(error);
                    else resolve();
                });
            });
            return cmd;
        } catch {
            continue;
        }
    }
    return null;
}

function stopPythonServer() {
    if (pythonProcess) {
        console.log('Stopping Python server...');
        pythonProcess.kill('SIGTERM');
        setTimeout(() => {
            if (pythonProcess && !pythonProcess.killed) {
                pythonProcess.kill('SIGKILL');
            }
        }, 5000);
        pythonProcess = null;
    }
}

module.exports = {
    startPythonServer,
    stopPythonServer
};
