const { execFileSync } = require('child_process');
const path = require('path');
const fs = require('fs');

const config = require('../src/config/config');

if (!config.mongodbUri) {
  console.error('MONGODB_URI is required for backups');
  process.exit(1);
}

const outDir = path.resolve(process.cwd(), 'backups');
fs.mkdirSync(outDir, { recursive: true });

const stamp = new Date().toISOString().replace(/[:.]/g, '-');
const outFile = path.join(outDir, `roadwatch-${stamp}.archive.gz`);

try {
  execFileSync('mongodump', [
    `--uri=${config.mongodbUri}`,
    `--archive=${outFile}`,
    '--gzip',
  ], { stdio: 'inherit' });
  console.log(`Backup created: ${outFile}`);
} catch (error) {
  console.error('Backup failed. Ensure mongodump is installed and reachable in PATH.');
  process.exit(1);
}