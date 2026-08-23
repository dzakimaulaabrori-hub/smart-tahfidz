const fs = require('fs');
const html = fs.readFileSync('index.html', 'utf8');
const match = html.match(/<script>\s*(const SMART_CONFIG[\s\S]*?)\s*<\/script>\s*<\/body>/);
if (!match) throw new Error('Application script block was not found');
new Function(match[1]);
console.log('SMART TAHFIDZ application script: syntax OK');
