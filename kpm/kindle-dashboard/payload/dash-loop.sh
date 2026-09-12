#!/bin/sh

APP_DIR=/mnt/us/kindle-dashboard
LOG_DIR="$APP_DIR/logs"
IMAGE="$APP_DIR/dash.png"
TEMP_IMAGE="$IMAGE.tmp"
PIDFILE="$APP_DIR/dash-loop.pid"
STOPFILE="$APP_DIR/dash-loop.stop"
LOGFILE="$LOG_DIR/dash-loop.log"
FBINK=/mnt/us/libkh/bin/fbink

[ -x "$FBINK" ] || FBINK=/usr/bin/fbink

log() {
  printf '%s [dash-loop] %s\n' "$(date)" "$*" >> "$LOGFILE"
}

positive_integer() {
  case "$1" in
    ''|*[!0-9]*|0) return 1 ;;
    *) return 0 ;;
  esac
}

cleanup() {
  lipc-set-prop com.lab126.powerd preventScreenSaver 0 >/dev/null 2>&1 || true
  rm -f "$TEMP_IMAGE"
  if [ "$(cat "$PIDFILE" 2>/dev/null)" = "$$" ]; then
    rm -f "$PIDFILE"
  fi
}

trap cleanup EXIT INT TERM

mkdir -p "$LOG_DIR"

if [ ! -x "$FBINK" ]; then
  log "FBInk is unavailable"
  exit 1
fi

case "${DASHBOARD_URL:-}" in
  ''|*'<PC_IP>'*)
    log "dashboard URL is missing or still a placeholder"
    exit 2
    ;;
esac

INTERVAL="${INTERVAL:-45}"
FULL_EVERY="${FULL_EVERY:-20}"
MAX_FAILURES="${MAX_FAILURES:-6}"
positive_integer "$INTERVAL" || INTERVAL=45
positive_integer "$FULL_EVERY" || FULL_EVERY=20
case "$MAX_FAILURES" in ''|*[!0-9]*) MAX_FAILURES=6 ;; esac

if [ -f "$PIDFILE" ]; then
  old_pid=$(cat "$PIDFILE" 2>/dev/null)
  if [ -n "$old_pid" ] && kill -0 "$old_pid" 2>/dev/null; then
    log "loop already running with pid $old_pid"
    exit 0
  fi
fi

printf '%s\n' "$$" > "$PIDFILE"
rm -f "$STOPFILE"

cycle=0
failures=0
log "started with interval=${INTERVAL}s"

while [ ! -f "$STOPFILE" ]; do
  lipc-set-prop com.lab126.powerd preventScreenSaver 1 >/dev/null 2>&1 || true

  if curl -fsS --connect-timeout 10 --max-time 30 "$DASHBOARD_URL" -o "$TEMP_IMAGE" \
      && [ -s "$TEMP_IMAGE" ]; then
    mv "$TEMP_IMAGE" "$IMAGE"
    failures=0
    if [ $((cycle % FULL_EVERY)) -eq 0 ]; then
      "$FBINK" -f -c >/dev/null 2>&1 || log "full refresh failed"
    fi
    "$FBINK" -g "file=$IMAGE" -W GC16 >/dev/null 2>&1 || log "image draw failed"
  else
    rm -f "$TEMP_IMAGE"
    failures=$((failures + 1))
    log "download failed (${failures} consecutive)"
    if [ "$MAX_FAILURES" -gt 0 ] && [ "$failures" -ge "$MAX_FAILURES" ]; then
      log "maximum failures reached; stopping"
      exit 0
    fi
  fi

  cycle=$((cycle + 1))
  sleep "$INTERVAL"
done

log "stop file detected"
