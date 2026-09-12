#!/usr/bin/env node

const { execFileSync } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const source = path.join(root, 'kpm', 'kindle-dashboard');
const manifestPath = path.join(source, 'manifest.json');

if (!fs.existsSync(manifestPath)) {
  throw new Error(`Missing KPM manifest: ${manifestPath}`);
}

const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
if (!Array.isArray(manifest.version) || manifest.version.length !== 3) {
  throw new Error('KPM manifest version must have three numeric components');
}

const version = manifest.version.join('.');
const outputDirectory = path.join(root, 'release');
const output = path.join(outputDirectory, `${manifest.id}_${version}_kindlepw2.kpkg`);
fs.mkdirSync(outputDirectory, { recursive: true });

execFileSync('tar', ['-C', source, '-czf', output, '.'], { stdio: 'inherit' });
const entries = execFileSync('tar', ['-tzf', output], { encoding: 'utf8' })
  .trim()
  .split('\n');

if (!entries.includes('./manifest.json')) {
  throw new Error('KPM archive is missing manifest.json');
}
if (entries.some((entry) => entry.startsWith('/') || entry.includes('../'))) {
  throw new Error('KPM archive contains an unsafe path');
}

console.log(output);
