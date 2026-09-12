const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { execFileSync } = require('node:child_process');
const { test } = require('node:test');

const root = path.resolve(__dirname, '..');
const pkg = path.join(root, 'kpm', 'kindle-dashboard');
const expectedFiles = [
  'manifest.json', 'install.sh', 'launch.sh', 'uninstall.sh',
  'payload/dashboard.env', 'payload/dash-loop.sh',
  'payload/dash-launch.sh', 'scriptlets/kindle-dashboard.sh',
];

test('KPM package has the required user-space files', () => {
  for (const file of expectedFiles) assert.ok(fs.existsSync(path.join(pkg, file)), file);
  const manifest = JSON.parse(fs.readFileSync(path.join(pkg, 'manifest.json'), 'utf8'));
  assert.equal(manifest.manifest_version, 2);
  assert.equal(manifest.id, 'kindle-dashboard');
  assert.deepEqual(manifest.supported_platforms, ['kindlepw2']);
});

test('KPM hooks and payload scripts are POSIX-shell parseable', () => {
  for (const file of expectedFiles.filter((file) => file.endsWith('.sh'))) {
    execFileSync('sh', ['-n', path.join(pkg, file)]);
  }
});

test('default configuration has no real endpoint or credentials', () => {
  const env = fs.readFileSync(path.join(pkg, 'payload/dashboard.env'), 'utf8');
  assert.match(env, /^DASHBOARD_URL='http:\/\/<PC_IP>:8787\/dash\.png'$/m);
  assert.match(env, /^INTERVAL='45'$/m);
  assert.match(env, /^FULL_EVERY='20'$/m);
  assert.match(env, /^WIFI_RETRY_EVERY='3'$/m);
  assert.doesNotMatch(env, /(?:password|token|cookie|192\.168\.)/i);
});
