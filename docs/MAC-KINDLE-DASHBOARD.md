# macOS Standalone Dashboard

This fork can run the local backend and PNG renderer on a Mac without opening
the Electron UI. A jailbroken Kindle downloads the resulting image through the
KPM package described in [KINDLE-INSTALLATION.md](../KINDLE-INSTALLATION.md).
The rendered image is a high-contrast, two-by-two grid: Claude Code, OpenAI
Codex, OpenCode, and Mac Status. The header includes the render time and the
last battery and Wi-Fi status reported by the Kindle.

## Changes in This Fork

- Replaced the old Kindle usage layout with a high-contrast, two-by-two grid.
- Added CC Switch local usage for Claude and OpenCode, with token-share bars
  and a rolling 24-hour cost summary.
- Replaced the former Hermes card with a two-column Mac Status card.
- Added Claude Code and OpenCode CLI versions beside their titles. The Codex
  title deliberately uses the installed ChatGPT.app version.
- Moved Kindle battery and Wi-Fi state beside the render time.
- Added a sleep-friendly Kindle mode and power-button wake handling, while
  retaining an optional higher-power resident mode.
- Expanded `.gitignore` to exclude local backups, configuration, databases,
  and common private-key files from accidental staging.

## Data Shown

| Card | Source and meaning |
| --- | --- |
| Claude Code | Claude's available usage windows. When Claude usage is unavailable, local CC Switch data can supply requests, tokens, cost, and token share. The title shows the installed `claude --version` value when available. |
| OpenAI Codex | Available Codex usage windows and local usage data. Its title version is the installed **ChatGPT.app** version, as a display choice; it is not the Codex CLI version. |
| OpenCode | CC Switch proxy request logs for OpenCode: rolling 24-hour and seven-day requests and tokens, cumulative tokens, and cost. The title shows the installed `opencode --version` value when available. |
| Mac Status | Hostname, network status and Wi-Fi name, LAN and public IP, DNS, CPU and load, GPU, used/total memory and SSD, power source, battery, and CC Switch cost for the previous 24 hours. |

The two-column Mac Status card puts Public IP directly below LAN IP. Public IP
comes from an outbound request to `api.ipify.org`; the collector honors
`HTTPS_PROXY` or `ALL_PROXY` when set. Failed or unavailable lookups display
`-`. The cost summary includes only Claude and OpenCode requests recorded by
CC Switch; it is a rolling 24-hour total, not a calendar-day bill or an
all-provider total.

The local token-share bar divides a tool's cumulative CC Switch tokens by the
combined Claude and OpenCode cumulative tokens in that database. Codex is not
part of this denominator. Codex's usage-window bars represent rate-limit
consumption, not its share of the three tools' total tokens. Claude's local
bar appears only when the local CC Switch result is selected instead of a
healthy Claude usage result.

## Run on the Mac

Requirements: Node.js 24 or newer, Google Chrome, and network access between
the Mac and Kindle. Install the `sqlite3` command and run CC Switch's proxy
logging if you want local Claude and OpenCode metrics. Other cards can still
render when that database is unavailable, but the OpenCode card is omitted.

From the repository root:

```sh
npm install
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" npm run supervisor
```

`CHROME` must point to an installed Chrome executable. The supervisor starts
the backend, renders `out/dash.png`, and refreshes it every 60 seconds by
default. Set `RENDER_INTERVAL` to change the Mac render interval, and `PORT`
to change the default port `8787`. The Kindle's download interval is separate;
the default KPM value is 45 seconds. The supervisor writes runtime logs and a
PID file under ignored `out/`.

Check `http://127.0.0.1:8787/api/ping` for backend availability and
`http://127.0.0.1:8787/dash.png` for the rendered image. The Kindle endpoint
must use the Mac's reachable LAN address, not `127.0.0.1`. The local launchd
service used on one Mac is machine-specific and is not installed by this repo.
Check its status separately if you choose to run the supervisor at login.

## Kindle Display and Power

Install and configure the KPM package using the
[installation guide](../KINDLE-INSTALLATION.md). `SCREEN_MODE='sleep'` is the
default: normal Kindle sleep remains enabled, and the loop continues its
download/draw attempts. The power button uses normal Kindle sleep/wake
behavior. On wake, the loop watches for the event, allows up to 30 seconds for
Wi-Fi reconnection, and redraws on its next refresh cycle. It does not force
the display to stay lit.

`SCREEN_MODE='resident'` keeps the dashboard in the foreground by pausing the
Kindle UI and preventing the screen saver. It uses more power. Stop the loop
before expecting the normal Kindle UI to remain interactive.

The KPM package has no boot hook. Launch it again after a Kindle reboot. The
screen may show the Kindle screen saver while sleeping; a new dashboard image
is not guaranteed to become visible until the device wakes and redraws.

The current package configuration adds `SCREEN_MODE='sleep'` beside the image
URL, interval, full-refresh frequency, and failure limit. The display loop
tries `/var/local/kmc/bin/fbink`, then `/mnt/us/libkh/bin/fbink`, then
`/usr/bin/fbink`; installation checks the latter two locations.
`WIFI_RETRY_EVERY` remains in the configuration but is not used by the current
KPM loop. Wake reconnection has a fixed 30-second window.

## Privacy and Limits

The backend listens on the LAN and serves `/api/usage` and `/dash.png` without
authentication. These responses can contain the Mac hostname, IP addresses,
DNS servers, Wi-Fi name, and usage costs. Use only a trusted local network; do
not forward this port to the public internet. Public IP lookup sends a request
to the external IP service. No local CC Switch database or credential needs
to be copied to the Kindle or committed to Git.

Keep real addresses, proxy URLs with credentials, tokens, logs, generated PNGs,
database files, and backups out of commits and shared documentation. Use
placeholders such as `<PC_IP>` in examples. A missing data source or failed
lookup should be treated as unavailable, not as zero usage.
