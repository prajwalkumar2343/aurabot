/**
 * AuraBot Electron - Splash Screen Module
 * Handles the loading window
 */

const { BrowserWindow } = require('electron');

let splashWindow = null;

function createSplashWindow() {
    splashWindow = new BrowserWindow({
        width: 400,
        height: 300,
        frame: false,
        alwaysOnTop: true,
        transparent: true,
        resizable: false,
        skipTaskbar: true,
        webPreferences: {
            nodeIntegration: true,
            contextIsolation: false
        }
    });

    const splashHTML = `
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="UTF-8">
      <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
          width: 400px;
          height: 300px;
          background: linear-gradient(135deg, #F5D76E 0%, #E8C84A 100%);
          display: flex;
          flex-direction: column;
          align-items: center;
          justify-content: center;
          font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
          border-radius: 20px;
          overflow: hidden;
        }
        .container {
          text-align: center;
          padding: 40px;
        }
        .logo {
          width: 80px;
          height: 80px;
          background: #1A1A1A;
          border-radius: 20px;
          display: flex;
          align-items: center;
          justify-content: center;
          margin: 0 auto 20px;
          animation: pulse 2s ease-in-out infinite;
        }
        .logo svg {
          width: 50px;
          height: 50px;
          color: #F5D76E;
        }
        @keyframes pulse {
          0%, 100% { transform: scale(1); }
          50% { transform: scale(1.05); }
        }
        h1 {
          color: #1A1A1A;
          font-size: 28px;
          font-weight: 700;
          margin-bottom: 10px;
        }
        .status {
          color: #1A1A1A;
          font-size: 14px;
          opacity: 0.8;
          margin-bottom: 20px;
        }
        .progress-bar {
          width: 200px;
          height: 4px;
          background: rgba(26, 26, 26, 0.2);
          border-radius: 2px;
          overflow: hidden;
          margin: 0 auto;
        }
        .progress-fill {
          height: 100%;
          background: #1A1A1A;
          border-radius: 2px;
          width: 0%;
          transition: width 0.3s ease;
          animation: loading 2s ease-in-out infinite;
        }
        @keyframes loading {
          0% { width: 0%; transform: translateX(-100%); }
          50% { width: 100%; transform: translateX(0); }
          100% { width: 100%; transform: translateX(100%); }
        }
        .version {
          position: absolute;
          bottom: 20px;
          font-size: 12px;
          color: #1A1A1A;
          opacity: 0.6;
        }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="logo">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M12 2L2 7l10 5 10-5-10-5zM2 17l10 5 10-5M2 12l10 5 10-5"/>
          </svg>
        </div>
        <h1>AuraBot</h1>
        <div class="status" id="status">Starting up...</div>
        <div class="progress-bar">
          <div class="progress-fill"></div>
        </div>
      </div>
      <div class="version">v1.0.0</div>
    </body>
    </html>
  `;

    splashWindow.loadURL('data:text/html;charset=utf-8,' + encodeURIComponent(splashHTML));

    splashWindow.on('closed', () => {
        splashWindow = null;
    });
}

function updateSplashStatus(message) {
    if (splashWindow && !splashWindow.isDestroyed()) {
        splashWindow.webContents.executeJavaScript(`
      document.getElementById('status').textContent = ${JSON.stringify(message)};
    `);
    }
}

function closeSplashWindow() {
    if (splashWindow && !splashWindow.isDestroyed()) {
        // Fade out effect
        splashWindow.webContents.executeJavaScript(`
      document.body.style.transition = 'opacity 0.3s ease';
      document.body.style.opacity = '0';
    `);
        setTimeout(() => {
            if (splashWindow) {
                splashWindow.close();
                splashWindow = null;
            }
        }, 300);
    }
}

module.exports = {
    createSplashWindow,
    updateSplashStatus,
    closeSplashWindow
};
