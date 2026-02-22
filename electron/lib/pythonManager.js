/**
 * AuraBot Electron - Python Server Manager Module
 * Handles spawning and managing the Python local server process
 */

const { spawn, exec } = require('child_process');
const path = require('path');
const fs = require('fs');

let pythonProcess = null;

async function startPythonServer(ROOT_DIR, updateSplashStatus) {
    const pythonScript = path.join(ROOT_DIR, 'python', 'src', 'mem0_local.py');

    if (!fs.existsSync(pythonScript)) {
        console.log('Python server script not found, skipping...');
        return false;
    }

    // Check if Python is available
    const pythonCmd = await findPython();
    if (!pythonCmd) {
        console.log('Python not found, skipping local model server...');
        return false;
    }

    console.log('Starting Python server...');
    if (updateSplashStatus) updateSplashStatus('Starting Python services...');

    return new Promise((resolve) => {
        pythonProcess = spawn(pythonCmd, [pythonScript], {
            cwd: path.join(ROOT_DIR, 'python', 'src'),
            stdio: ['ignore', 'pipe', 'pipe']
        });

        pythonProcess.stdout.on('data', (data) => {
            console.log('[Python]', data.toString().trim());
            if (data.toString().includes('Running on') || data.toString().includes('Startup complete')) {
                resolve(true);
            }
        });

        pythonProcess.stderr.on('data', (data) => {
            console.error('[Python Error]', data.toString().trim());
        });

        pythonProcess.on('error', (error) => {
            console.error('Failed to start Python server:', error);
            resolve(false);
        });

        pythonProcess.on('exit', (code) => {
            if (code !== 0) {
                console.log(`Python server exited with code ${code}`);
                resolve(true); // Resolve to allow app to continue without Python
            }
        });

        // Timeout after 30 seconds
        setTimeout(() => resolve(true), 30000);
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
