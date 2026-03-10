/**
 * AuraBot Electron - IPC HTTP Utilities Module
 * Handles HTTP requests to the local Go backend
 */

const http = require('http');

let BACKEND_PORT = 7345;

function setBackendPort(port) {
    BACKEND_PORT = port;
}

async function apiRequest(endpoint, method = 'GET', data = null) {
    return new Promise((resolve, reject) => {
        const options = {
            hostname: '127.0.0.1',
            port: BACKEND_PORT,
            path: endpoint,
            method: method,
            headers: {
                'Content-Type': 'application/json'
            }
        };

        const req = http.request(options, (res) => {
            let body = '';
            res.on('data', (chunk) => body += chunk);
            res.on('end', () => {
                // Check for error status codes
                if (res.statusCode < 200 || res.statusCode >= 300) {
                    reject(new Error(`HTTP ${res.statusCode}: ${body || 'Request failed'}`));
                    return;
                }
                try {
                    const parsed = JSON.parse(body);
                    resolve(parsed);
                } catch {
                    resolve(body);
                }
            });
        });

        req.on('error', (error) => {
            reject(error);
        });

        if (data) {
            req.write(JSON.stringify(data));
        }
        req.end();
    });
}

module.exports = {
    setBackendPort,
    apiRequest
};
