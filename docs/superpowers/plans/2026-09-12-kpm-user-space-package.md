# KPM User-Space Package Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a KPM-compatible Kindle Dashboard package that installs only
user-storage files, preserves user endpoint configuration during upgrades, and
starts manually through KPM or its scriptlet.

**Architecture:** The package keeps payload scripts and KPM hooks under
`kpm/kindle-dashboard/`. `install.sh` copies the payload into one dedicated
directory under `/mnt/us`; `launch.sh` starts that installed launcher, while
the scriptlet delegates to `kpm launch kindle-dashboard`. A Node archive helper
creates and inspects the gzip `.kpkg` without adding an operational Python
dependency.

**Tech Stack:** POSIX `sh`, KPM manifest v2 and hooks, Node.js built-in test
runner, Node.js `child_process`, system `tar`.

---

## Planned file structure

- Create: `kpm/kindle-dashboard/manifest.json` — KPM v2 package identity and
  `kindlepw2` compatibility.
- Create: `kpm/kindle-dashboard/install.sh` — safe user-storage installation.
- Create: `kpm/kindle-dashboard/launch.sh` — KPM manual-launch entry point.
- Create: `kpm/kindle-dashboard/uninstall.sh` — upgrade-aware removal.
- Create: `kpm/kindle-dashboard/payload/dashboard.env` — editable placeholder
  configuration.
- Create: `kpm/kindle-dashboard/payload/dash-loop.sh` — atomic PNG download,
  FBInk drawing, single-instance and stop behavior.
- Create: `kpm/kindle-dashboard/payload/dash-launch.sh` — configuration and
  Wi-Fi gate before starting the loop.
- Create: `kpm/kindle-dashboard/scriptlets/kindle-dashboard.sh` — document
  launcher which invokes KPM.
- Create: `scripts/package-kpm.js` — reproducible archive builder and archive
  layout verifier.
- Create: `test/kpm-package.test.js` — package contract, syntax, and archive
  tests.
- Modify: `package.json` — add the `package:kpm` script.
- Modify: `KINDLE-INSTALLATION.md` — replace the SSH/Upstart workflow with the
  KPM workflow and its manual-start limitation.
- Modify: `README.md` — point Kindle setup readers to the KPM guide.

### Task 1: Establish the KPM package contract test

**Files:**
- Create: `test/kpm-package.test.js`

- [ ] **Step 1: Write the failing package-layout test**

```js
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
```

- [ ] **Step 2: Run the focused test and verify the expected missing-file failure**

Run: `node --test test/kpm-package.test.js`

Expected: FAIL because `kpm/kindle-dashboard/manifest.json` does not exist.

- [ ] **Step 3: Commit the failing contract test**

```bash
git add test/kpm-package.test.js
git commit -m "test: define KPM package contract"
```

### Task 2: Add package metadata and safe default configuration

**Files:**
- Create: `kpm/kindle-dashboard/manifest.json`
- Create: `kpm/kindle-dashboard/payload/dashboard.env`
- Modify: `test/kpm-package.test.js`

- [ ] **Step 1: Extend the failing test for privacy and defaults**

```js
test('default configuration has no real endpoint or credentials', () => {
  const env = fs.readFileSync(path.join(pkg, 'payload/dashboard.env'), 'utf8');
  assert.match(env, /^DASHBOARD_URL='http:\/\/<PC_IP>:8787\/dash\.png'$/m);
  assert.match(env, /^INTERVAL='45'$/m);
  assert.match(env, /^FULL_EVERY='20'$/m);
  assert.match(env, /^WIFI_RETRY_EVERY='3'$/m);
  assert.doesNotMatch(env, /(?:password|token|cookie|192\.168\.)/i);
});
```

- [ ] **Step 2: Run the focused test and verify it fails because the default files are absent**

Run: `node --test test/kpm-package.test.js`

Expected: FAIL in the new default-configuration test.

- [ ] **Step 3: Add the minimal v2 manifest and environment file**

```json
{
  "manifest_version": 2,
  "id": "kindle-dashboard",
  "name": "Kindle Dashboard",
  "author": "Kindle Dashboard contributors",
  "description": "Manually launched e-ink dashboard refresh loop.",
  "version": [1, 0, 0],
  "dependencies": [],
  "supported_platforms": ["kindlepw2"]
}
```

```sh
DASHBOARD_URL='http://<PC_IP>:8787/dash.png'
INTERVAL='45'
FULL_EVERY='20'
WIFI_RETRY_EVERY='3'
MAX_FAILURES='6'
```

- [ ] **Step 4: Run the focused test and verify it passes**

Run: `node --test test/kpm-package.test.js`

Expected: PASS.

- [ ] **Step 5: Commit metadata and configuration**

```bash
git add kpm/kindle-dashboard/manifest.json kpm/kindle-dashboard/payload/dashboard.env test/kpm-package.test.js
git commit -m "feat: add KPM package metadata"
```

### Task 3: Implement the manually launched dashboard payload

**Files:**
- Create: `kpm/kindle-dashboard/payload/dash-loop.sh`
- Create: `kpm/kindle-dashboard/payload/dash-launch.sh`
- Create: `kpm/kindle-dashboard/launch.sh`
- Modify: `test/kpm-package.test.js`

- [ ] **Step 1: Add failing payload-safety assertions**

```js
test('payload uses only the dedicated user-storage directory', () => {
  const source = [
    'payload/dash-loop.sh', 'payload/dash-launch.sh', 'launch.sh',
  ].map((file) => fs.readFileSync(path.join(pkg, file), 'utf8')).join('\n');
  assert.match(source, /\/mnt\/us\/kindle-dashboard/);
  assert.match(source, /\/mnt\/us\/libkh\/bin\/fbink/);
  assert.match(source, /DASHBOARD_URL/);
  assert.doesNotMatch(source, /\/etc\/upstart|mntroot|\bssh\b|USBNetwork/i);
});
```

- [ ] **Step 2: Run the focused test and verify it fails because payload scripts are absent**

Run: `node --test test/kpm-package.test.js`

Expected: FAIL with `ENOENT` for `payload/dash-loop.sh`.

- [ ] **Step 3: Implement the loop, launcher, and KPM launch hook**

Use these fixed paths and behavior in the scripts:

```sh
APP_DIR=/mnt/us/kindle-dashboard
ENV_FILE="$APP_DIR/dashboard.env"
LOG_DIR="$APP_DIR/logs"
PIDFILE="$APP_DIR/dash-loop.pid"
STOPFILE="$APP_DIR/dash-loop.stop"
FBINK=/mnt/us/libkh/bin/fbink
[ -x "$FBINK" ] || FBINK=/usr/bin/fbink
```

`dash-launch.sh` must source `dashboard.env`, reject an empty URL and the
literal `<PC_IP>` placeholder, wait at most 90 seconds for Wi-Fi, remove only
`$STOPFILE`, and start the loop with `setsid sh "$APP_DIR/dash-loop.sh"`.
`dash-loop.sh` must validate positive integer settings, write its PID, download
to `$APP_DIR/dash.png.tmp`, require a nonempty file before `mv`, draw with
FBInk, and clear its PID and temporary file on `EXIT`, `INT`, or `TERM`.
`launch.sh` must only execute `sh /mnt/us/kindle-dashboard/dash-launch.sh` and
return its status.

- [ ] **Step 4: Run the focused test and verify it passes**

Run: `node --test test/kpm-package.test.js`

Expected: PASS.

- [ ] **Step 5: Commit the payload**

```bash
git add kpm/kindle-dashboard/payload kpm/kindle-dashboard/launch.sh test/kpm-package.test.js
git commit -m "feat: add manually launched Kindle payload"
```

### Task 4: Implement install, upgrade, and uninstall hooks

**Files:**
- Create: `kpm/kindle-dashboard/install.sh`
- Create: `kpm/kindle-dashboard/uninstall.sh`
- Create: `kpm/kindle-dashboard/scriptlets/kindle-dashboard.sh`
- Modify: `test/kpm-package.test.js`

- [ ] **Step 1: Add failing hook-contract tests**

```js
test('hooks preserve configuration on upgrades and avoid rootfs', () => {
  const install = fs.readFileSync(path.join(pkg, 'install.sh'), 'utf8');
  const uninstall = fs.readFileSync(path.join(pkg, 'uninstall.sh'), 'utf8');
  const scriptlet = fs.readFileSync(path.join(pkg, 'scriptlets/kindle-dashboard.sh'), 'utf8');
  assert.match(install, /\[ ! -f "\$ENV_FILE" \]/);
  assert.match(uninstall, /\[ "\$1" = upgrade \].*exit 0/s);
  assert.match(scriptlet, /\/var\/local\/kmc\/bin\/kpm launch kindle-dashboard/);
  assert.doesNotMatch(`${install}\n${uninstall}`, /\/etc\/|mntroot|rm -rf \/mnt\/us(?:\s|$)/);
});
```

- [ ] **Step 2: Run the focused test and verify it fails because hooks are absent**

Run: `node --test test/kpm-package.test.js`

Expected: FAIL with `ENOENT` for `install.sh`.

- [ ] **Step 3: Implement the hooks and scriptlet**

`install.sh` must preflight `/mnt/us` and an executable FBInk path, create
`$APP_DIR/logs`, copy each payload file to a same-directory temporary name,
then rename it into place. It creates `dashboard.env` only when it does not
exist, installs the scriptlet in `/mnt/us/documents`, and uses a trap to remove
only files created by a failed first installation.

`uninstall.sh` must create the stop file, terminate only the PID named in
`$APP_DIR/dash-loop.pid` after confirming it is live, and wait at most five
seconds. With `upgrade` as its first argument it stops and exits without
removing `$APP_DIR` or `dashboard.env`. On normal uninstall it removes the
scriptlet only when `cmp -s scriptlets/kindle-dashboard.sh "$SCRIPTLET"` is
true, then removes the exact `$APP_DIR` directory. It must never delete package
files from the unpacked `./` directory.

```sh
#!/bin/sh
exec /var/local/kmc/bin/kpm launch kindle-dashboard
```

- [ ] **Step 4: Run the focused test and verify it passes**

Run: `node --test test/kpm-package.test.js`

Expected: PASS.

- [ ] **Step 5: Commit package hooks**

```bash
git add kpm/kindle-dashboard/install.sh kpm/kindle-dashboard/uninstall.sh kpm/kindle-dashboard/scriptlets/kindle-dashboard.sh test/kpm-package.test.js
git commit -m "feat: add safe KPM install hooks"
```

### Task 5: Add reproducible archive construction and inspection

**Files:**
- Create: `scripts/package-kpm.js`
- Modify: `package.json`
- Modify: `test/kpm-package.test.js`

- [ ] **Step 1: Add a failing archive test**

```js
test('package helper produces an archive with only package-root paths', () => {
  const artifact = path.join(root, 'release', 'kindle-dashboard_1.0.0_kindlepw2.kpkg');
  fs.rmSync(artifact, { force: true });
  execFileSync(process.execPath, ['scripts/package-kpm.js'], { cwd: root });
  const entries = execFileSync('tar', ['-tzf', artifact], { encoding: 'utf8' }).trim().split('\n');
  assert.ok(entries.includes('./manifest.json'));
  assert.ok(entries.every((entry) => !entry.startsWith('/') && !entry.includes('../')));
});
```

- [ ] **Step 2: Run the focused test and verify it fails because the helper is absent**

Run: `node --test test/kpm-package.test.js`

Expected: FAIL because `scripts/package-kpm.js` cannot be found.

- [ ] **Step 3: Implement the Node archive helper and package script**

```js
const { execFileSync } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const source = path.join(root, 'kpm', 'kindle-dashboard');
const manifest = JSON.parse(fs.readFileSync(path.join(source, 'manifest.json'), 'utf8'));
const version = manifest.version.join('.');
const output = path.join(root, 'release', `${manifest.id}_${version}_kindlepw2.kpkg`);
fs.mkdirSync(path.dirname(output), { recursive: true });
execFileSync('tar', ['-C', source, '-czf', output, '.'], { stdio: 'inherit' });
const entries = execFileSync('tar', ['-tzf', output], { encoding: 'utf8' }).split('\n');
if (!entries.includes('./manifest.json')) throw new Error('manifest missing from archive');
console.log(output);
```

Add:

```json
"package:kpm": "node scripts/package-kpm.js"
```

- [ ] **Step 4: Run the focused test and package command**

Run: `node --test test/kpm-package.test.js && npm run package:kpm`

Expected: PASS and one ignored `.kpkg` artifact under `release/`.

- [ ] **Step 5: Commit the packaging tool**

```bash
git add scripts/package-kpm.js package.json test/kpm-package.test.js
git commit -m "build: package Kindle Dashboard for KPM"
```

### Task 6: Replace the legacy installation documentation

**Files:**
- Modify: `KINDLE-INSTALLATION.md`
- Modify: `README.md`
- Modify: `test/kpm-package.test.js`

- [ ] **Step 1: Add a failing documentation contract test**

```js
test('KPM documentation does not instruct rootfs or SSH installation', () => {
  const guide = fs.readFileSync(path.join(root, 'KINDLE-INSTALLATION.md'), 'utf8');
  assert.match(guide, /kpm add-repo https:\/\/<PACKAGE_REPOSITORY>\/manifest\.json/);
  assert.match(guide, /kpm update/);
  assert.match(guide, /kpm install kindle-dashboard/);
  assert.match(guide, /does not start automatically after a reboot/i);
  assert.doesNotMatch(guide, /mntroot|\/etc\/upstart|SSH Password|USBNetwork/);
});
```

- [ ] **Step 2: Run the focused test and verify it fails against the legacy guide**

Run: `node --test test/kpm-package.test.js`

Expected: FAIL because the existing guide documents SSH and Upstart.

- [ ] **Step 3: Rewrite the guide and add README navigation**

Document: build with `npm run package:kpm`; publish `manifest.json` plus the
generated artifact at an owner-controlled HTTPS repository; run `kpm add-repo
https://<PACKAGE_REPOSITORY>/manifest.json`, `kpm update`, and `kpm install
kindle-dashboard`; edit `/mnt/us/kindle-dashboard/dashboard.env`; use `kpm
launch kindle-dashboard` or open `kindle-dashboard.sh`; and uninstall with
`kpm uninstall kindle-dashboard`. State that no SSH, rootfs write, or automatic
post-reboot launch is provided. Use only placeholders for endpoints and no
credentials in any example.

- [ ] **Step 4: Run the focused test and full project suite**

Run: `node --test test/kpm-package.test.js && npm test`

Expected: all tests PASS.

- [ ] **Step 5: Commit documentation**

```bash
git add KINDLE-INSTALLATION.md README.md test/kpm-package.test.js
git commit -m "docs: document KPM Kindle installation"
```

### Task 7: Perform final local verification and prepare device validation

**Files:**
- Verify: `kpm/kindle-dashboard/`
- Verify: `release/kindle-dashboard_1.0.0_kindlepw2.kpkg`

- [ ] **Step 1: Run all local checks**

Run: `npm test && npm run typecheck && npm run package:kpm && tar -tzf release/kindle-dashboard_1.0.0_kindlepw2.kpkg`

Expected: all tests and type checks PASS; the archive contains only relative
package-root entries, including `manifest.json`, hooks, `payload/`, and
`scriptlets/`.

- [ ] **Step 2: Run the privacy and rootfs scan**

Run: `rg -n '192\.168\.|password|token|cookie|/etc/upstart|mntroot|USBNetwork' kpm/kindle-dashboard KINDLE-INSTALLATION.md README.md`

Expected: no matches except explanatory prose that does not contain a secret;
remove any endpoint, credential, or rootfs-writing instruction found.

- [ ] **Step 3: Commit any verification-only fixes**

```bash
git add kpm/kindle-dashboard KINDLE-INSTALLATION.md README.md test/kpm-package.test.js scripts/package-kpm.js package.json
git commit -m "test: verify KPM package artifact"
```

- [ ] **Step 4: Validate on the physical Kindle only after user confirms the repository URL**

Use the documented KPM commands, edit `dashboard.env` through USB with the
owner's endpoint, launch manually, inspect
`/mnt/us/kindle-dashboard/logs/`, reboot to confirm no automatic launch, then
uninstall and confirm that only the dedicated directory and matching scriptlet
were removed. Do not write any other Kindle path.
