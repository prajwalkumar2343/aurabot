const { execFile } = require('child_process');
const path = require('path');

console.log('Waiting 3 seconds... please focus a text input.');
setTimeout(() => {
    const start = Date.now();
    execFile(path.join(__dirname, 'GetCaretUIA.exe'), (error, stdout, stderr) => {
        const elapsed = Date.now() - start;
        console.log(`[Time: ${elapsed}ms] Result:`, stdout.trim());
        if (stderr) console.error('Error:', stderr);
    });
}, 3000);
