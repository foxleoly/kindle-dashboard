# KPM Kindle Dashboard Installer Design

## Goal

Provide a local KPM package that installs and launches the Kindle Dashboard
refresh loop on a jailbroken Kindle running the modern WinterBreak/KPM stack.
The package avoids SSH, rootfs writes, and credentials or account data on the
Kindle.

## Scope

The package installs only the following dedicated paths:

- `/mnt/us/kindle-dashboard/dashboard.env`
- `/mnt/us/kindle-dashboard/dash-loop.sh`
- `/mnt/us/kindle-dashboard/dash-autostart.sh`
- `/mnt/us/kindle-dashboard/logs/`
- `/mnt/us/documents/kindle-dashboard.sh`, a KPM launcher scriptlet.

It uses the existing Kindle Dashboard PNG endpoint. Its initial configuration
contains only the placeholder `http://<PC_IP>:8787/dash.png`; the owner edits
the environment file over USB to set the local endpoint without reinstalling.

## Package Layout

The KPM artifact contains a v2 manifest, `install.sh`, `launch.sh`,
`uninstall.sh`, the Kindle loop and launcher scripts, and a KPM scriptlet.
KPM invokes the hooks with `sh` from the unpacked package directory.

`install.sh` creates `/mnt/us/kindle-dashboard` with restrictive permissions,
copies scripts atomically, installs the scriptlet, and creates `dashboard.env`
only when it does not already exist. An upgrade preserves the existing
environment file. The scriptlet invokes `kpm launch kindle-dashboard`.

The environment file contains only the image URL and refresh settings. It must
never contain an SSH password, token, cookie, serial number, or local account
data.

## Runtime Behavior

`launch.sh` delegates to the launcher. The launcher waits for Wi-Fi and starts
only one loop instance. The loop downloads the PNG to a temporary file,
requires a nonempty download, then atomically moves it into place before
drawing it. It uses
`/mnt/us/libkh/bin/fbink` when present and falls back to `/usr/bin/fbink`.
It keeps the display awake while active, performs periodic full refreshes, and
writes logs only under `/mnt/us/kindle-dashboard`.

The launcher exits without changing the display when the configuration is
missing, disabled, or still contains the placeholder endpoint.

## Installation and Safety

KPM hooks must not write to or remount rootfs. The installer requires `/mnt/us`
and a working FBInk path before making any Dashboard change. It must not depend
on `initctl`, `mntroot`, Upstart, SSH, legacy USBNetwork, or a legacy Hotfix.

If a user-storage installation step fails, it removes only paths created during
that attempt. It must not alter unrelated documents, KPM state, or jailbreak
components.

KPM supports manual launch, not a supported boot hook. The user starts the
Dashboard after installation from KPM or by opening the installed scriptlet;
after a Kindle reboot, the user starts it again. This package deliberately does
not claim boot persistence.

## Uninstall

Uninstall first signals the loop to stop and waits briefly for its pidfile
process. It removes only the dedicated Dashboard directory and the scriptlet
when the scriptlet matches the package-owned content. It never removes KPM,
WinterBreak, FBInk, other documents, or jailbreak files.

## Validation

1. Package the artifact locally and inspect its manifest and archive paths.
2. Publish the artifact in a KPM-compatible repository, add that repository,
   and install it through KPM.
3. Set the endpoint in `dashboard.env`, launch the package, and confirm the
   first PNG download and FBInk draw using its dedicated log.
4. Reboot the Kindle and confirm that the package does not start implicitly.
5. Launch it manually again, then uninstall through KPM and verify that only
   dedicated paths and the matching scriptlet are removed.

## Explicit Limitations

This design cannot guarantee compatibility with every modern KPM environment.
It intentionally does not implement boot persistence because upstream KPM does
not support rootfs writes from package hooks. Device-side behavior is only
verified after installation on the target Kindle.
