# Kindle Dashboard KPM Installation

This guide installs the Kindle Dashboard through the Kindle Package Manager
(KPM). It requires an already jailbroken Kindle with KPM and FBInk available.
It does not jailbreak the device, modify the system partition, or require SSH.

## What the Package Does

The package installs these user-storage paths only:

| Kindle path | Purpose |
| --- | --- |
| `/mnt/us/kindle-dashboard/dashboard.env` | User-editable dashboard endpoint and refresh settings. |
| `/mnt/us/kindle-dashboard/dash-launch.sh` | Validates configuration and Wi-Fi before starting the loop. |
| `/mnt/us/kindle-dashboard/dash-loop.sh` | Downloads and draws the PNG with FBInk. |
| `/mnt/us/kindle-dashboard/logs/` | Dedicated runtime logs. |
| `/mnt/us/documents/kindle-dashboard.sh` | Document scriptlet that launches the package through KPM. |

The package uses `/mnt/us/libkh/bin/fbink` when available and falls back to
`/usr/bin/fbink`. It does not create an Upstart job. The dashboard does not start automatically after a reboot; launch it again from KPM or the document scriptlet.

## Prerequisites

- A Kindle with its jailbreak already completed.
- KPM installed and opening successfully.
- FBInk available at `/mnt/us/libkh/bin/fbink` or `/usr/bin/fbink`.
- Kindle and dashboard PC on the same Wi-Fi network.
- A static HTTPS repository that serves the KPM `manifest.json` and the
  generated `.kpkg` artifact.

## Build the Package

From the project root, create the artifact:

```sh
npm run package:kpm
```

The command creates this ignored static repository directory:

```text
release/kpm-repository/
├── manifest.json
└── packages/kindle-dashboard/artifacts/
    └── kindle-dashboard_1.0.0_kindlepw2.kpkg
```

Publish the contents of `release/kpm-repository/` to an owner-controlled HTTPS
location. Do not publish a configuration file containing a real endpoint,
credential, token, cookie, serial number, or private log.

## Install with KPM

In a Kindle shell or through the corresponding KPM interface, add the package
repository, refresh the package index, and install the package:

```sh
kpm add-repo https://<PACKAGE_REPOSITORY>/manifest.json
kpm update
kpm install kindle-dashboard
```

KPM runs the package `install.sh` from its unpacked package directory. On an
upgrade, it runs `uninstall.sh upgrade` before installing the new version; the
package preserves `dashboard.env` during that path.

## Configure and Launch

After KPM installs the package, connect over USB and edit:

```text
/mnt/us/kindle-dashboard/dashboard.env
```

Set the endpoint and refresh intervals with placeholder-safe values:

```sh
DASHBOARD_URL='http://<PC_IP>:8787/dash.png'
INTERVAL='45'
FULL_EVERY='20'
WIFI_RETRY_EVERY='3'
MAX_FAILURES='6'
```

Do not leave `<PC_IP>` in place. Do not add credentials to this file.

Launch manually with either method:

```sh
kpm launch kindle-dashboard
```

Or open `kindle-dashboard.sh` from the Kindle documents list. The launcher
waits up to 90 seconds for Wi-Fi. If the configuration is valid, it starts one
background loop and writes logs under:

```text
/mnt/us/kindle-dashboard/logs/
```

The loop downloads the PNG to a temporary file, checks that it is nonempty,
then atomically replaces the displayed image. It exits after the configured
maximum number of consecutive failures.

## Reboot Behavior

KPM package hooks must not write to or remount the system partition. For that
reason, this package intentionally has no boot integration. After a reboot,
run `kpm launch kindle-dashboard` again or open the document scriptlet.

## Uninstall

Stop and remove the package through KPM:

```sh
kpm uninstall kindle-dashboard
```

The package signals the tracked dashboard loop to stop, removes its document
scriptlet only if it still matches the package version, and removes only
`/mnt/us/kindle-dashboard`. It does not remove KPM, WinterBreak, FBInk,
unrelated documents, or jailbreak components.

## Troubleshooting

- **FBInk unavailable:** Confirm that one of the two documented FBInk paths is
  executable before installation.
- **Configuration rejected:** Replace the `<PC_IP>` placeholder with the
  dashboard PC address, then launch the package again.
- **Wi-Fi timeout:** Connect the Kindle to the same network as the dashboard
  PC, then launch again.
- **PNG download failures:** Check that the PC dashboard is running and that
  `http://<PC_IP>:8787/dash.png` is reachable from the Kindle network.

## Privacy

Keep real addresses, usernames, passwords, tokens, cookies, serial numbers,
local databases, session files, generated PNGs, and logs out of commits and
published package repositories. Use placeholders in all shared examples.
