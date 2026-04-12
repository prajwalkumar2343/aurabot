const { execSync } = require('child_process');
const { clipboard } = require('electron');
const fs = require('fs');
const path = require('path');
const os = require('os');

function grabSelectedTextSync() {
    // Store original clipboard content
    const originalClipboard = clipboard.readText();
    console.log('[TextCapture] Original clipboard length:', originalClipboard.length);
    
    // Script to send Ctrl+C (try selection first)
    const sendCopyScript = `
$wshell = New-Object -ComObject wscript.shell
$wshell.SendKeys("^c")
Start-Sleep -Milliseconds 200
`;

    // Script to send Ctrl+A then Ctrl+C (Select All + Copy)
    const sendSelectAllScript = `
$wshell = New-Object -ComObject wscript.shell
$wshell.SendKeys("^a")
Start-Sleep -Milliseconds 100
$wshell.SendKeys("^c")
Start-Sleep -Milliseconds 200
`;
    
    const tempFile = path.join(os.tmpdir(), `aura-send-${Date.now()}.ps1`);
    
    try {
        // === STEP 1: Try to copy selected text ===
        fs.writeFileSync(tempFile, '\ufeff' + sendCopyScript, 'utf8');
        
        execSync(
            `powershell -NoProfile -ExecutionPolicy Bypass -File "${tempFile}"`,
            { timeout: 5000, windowsHide: true, encoding: 'utf8' }
        );
        
        // Wait for clipboard
        busyWait(150);
        let capturedText = clipboard.readText();
        
        // Check if we got something new (different from original and not empty)
        const gotSelection = capturedText && 
                            capturedText.trim().length > 0 && 
                            capturedText !== originalClipboard;
        
        if (gotSelection) {
            console.log('[TextCapture] Captured selected text, length:', capturedText.length);
            return capturedText;
        }
        
        // === STEP 2: No selection, try Select All ===
        console.log('[TextCapture] No selection detected, trying Select All...');
        
        fs.writeFileSync(tempFile, '\ufeff' + sendSelectAllScript, 'utf8');
        
        execSync(
            `powershell -NoProfile -ExecutionPolicy Bypass -File "${tempFile}"`,
            { timeout: 5000, windowsHide: true, encoding: 'utf8' }
        );
        
        // Wait for clipboard
        busyWait(200);
        capturedText = clipboard.readText();
        
        if (capturedText && capturedText.trim().length > 0) {
            console.log('[TextCapture] Captured all text via Select All, length:', capturedText.length);
            return capturedText;
        }
        
        // Nothing worked
        throw new Error('Could not capture any text from the active window.');
        
    } finally {
        try { fs.unlinkSync(tempFile); } catch {}
    }
}

// Busy wait for precise timing (ms)
function busyWait(ms) {
    const start = Date.now();
    while (Date.now() - start < ms) {}
}

module.exports = { 
    grabSelectedText: async () => grabSelectedTextSync()
};
