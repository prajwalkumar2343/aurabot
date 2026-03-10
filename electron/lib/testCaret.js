const { execFile } = require('child_process');
const path = require('path');

console.log('Waiting 3 seconds... please focus a text input.');
setTimeout(() => {
    execFile(path.join(__dirname, 'GetCaret.exe'), (error, stdout, stderr) => {
        console.log('Result:', stdout);
    });
}, 3000);
