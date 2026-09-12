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

test('payload uses only the dedicated user-storage directory', () => {
  const source = [
    'payload/dash-loop.sh', 'payload/dash-launch.sh', 'launch.sh',
  ].map((file) => fs.readFileSync(path.join(pkg, file), 'utf8')).join('\n');
  assert.match(source, /\/mnt\/us\/kindle-dashboard/);
  assert.match(source, /\/mnt\/us\/libkh\/bin\/fbink/);
  assert.match(source, /DASHBOARD_URL/);
  assert.doesNotMatch(source, /\/etc\/upstart|mntroot|\bssh\b|USBNetwork/i);
});

test('hooks preserve configuration on upgrades and avoid rootfs', () => {
  const install = fs.readFileSync(path.join(pkg, 'install.sh'), 'utf8');
  const uninstall = fs.readFileSync(path.join(pkg, 'uninstall.sh'), 'utf8');
  const scriptlet = fs.readFileSync(path.join(pkg, 'scriptlets/kindle-dashboard.sh'), 'utf8');
  assert.match(install, /\[ ! -f "\$ENV_FILE" \]/);
  assert.match(uninstall, /if \[ "\$1" = upgrade \]; then[\s\S]*exit 0/);
  assert.match(scriptlet, /\/var\/local\/kmc\/bin\/kpm launch kindle-dashboard/);
  assert.doesNotMatch(`${install}\n${uninstall}`, /\/etc\/|mntroot|rm -rf \/mnt\/us(?:\s|$)/);
});

test('package helper produces an archive with only package-root paths', () => {
  const artifact = path.join(root, 'release', 'kindle-dashboard_1.0.0_kindlepw2.kpkg');
  fs.rmSync(artifact, { force: true });
  execFileSync(process.execPath, ['scripts/package-kpm.js'], { cwd: root });
  const entries = execFileSync('tar', ['-tzf', artifact], { encoding: 'utf8' }).trim().split('\n');
  assert.ok(entries.includes('./manifest.json'));
  assert.ok(entries.every((entry) => !entry.startsWith('/') && !entry.includes('../')));
});
