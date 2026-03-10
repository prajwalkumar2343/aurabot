const { execFile } = require('child_process');
const path = require('path');

console.log('Waiting 3 seconds... please focus a text input.');
setTimeout(() => {
    execFile('powershell', ['-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden', '-File', path.join(__dirname, 'GetCaret.ps1')], { windowsHide: true }, (error, stdout, stderr) => {
        console.log('Result:', stdout.trim());
        if (stderr) console.error('Error:', stderr);
    });
}, 3000);
