#!/bin/sh

APP_DIR=/mnt/us/kindle-dashboard
ENV_FILE="$APP_DIR/dashboard.env"
LOOP="$APP_DIR/dash-loop.sh"
LOG_DIR="$APP_DIR/logs"
LOGFILE="$LOG_DIR/dash-launch.log"
PIDFILE="$APP_DIR/dash-loop.pid"
STOPFILE="$APP_DIR/dash-loop.stop"

log() {
  printf '%s [dash-launch] %s\n' "$(date)" "$*" >> "$LOGFILE"
}

mkdir -p "$LOG_DIR"

if [ ! -r "$ENV_FILE" ]; then
  log "missing configuration"
  exit 2
fi

# dashboard.env is created locally by this package and is user-editable over USB.
. "$ENV_FILE"

case "${DASHBOARD_URL:-}" in
  ''|*'<PC_IP>'*)
    log "dashboard URL is missing or still a placeholder"
    exit 2
    ;;
esac

if [ ! -f "$LOOP" ]; then
  log "missing dashboard loop"
  exit 1
fi

if [ -f "$PIDFILE" ]; then
  old_pid=$(cat "$PIDFILE" 2>/dev/null)
  if [ -n "$old_pid" ] && kill -0 "$old_pid" 2>/dev/null; then
    log "loop already running with pid $old_pid"
    exit 0
  fi
fi

remaining=90
state=unknown
while [ "$remaining" -gt 0 ]; do
  state=$(lipc-get-prop com.lab126.wifid cmState 2>/dev/null || true)
  [ "$state" = CONNECTED ] && break
  sleep 3
  remaining=$((remaining - 3))
done

if [ "$state" != CONNECTED ]; then
  log "Wi-Fi did not connect within 90 seconds"
  exit 1
fi

rm -f "$STOPFILE"
export DASHBOARD_URL INTERVAL FULL_EVERY WIFI_RETRY_EVERY MAX_FAILURES
setsid sh "$LOOP" </dev/null >> "$LOG_DIR/dash-loop.log" 2>&1 &
log "started dashboard loop"
