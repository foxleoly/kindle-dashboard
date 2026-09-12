#!/bin/sh

APP_DIR=/mnt/us/kindle-dashboard
PIDFILE="$APP_DIR/dash-loop.pid"
STOPFILE="$APP_DIR/dash-loop.stop"
SCRIPTLET=/mnt/us/documents/kindle-dashboard.sh

stop_loop() {
  touch "$STOPFILE"
  pid=$(cat "$PIDFILE" 2>/dev/null)
  if [ -z "$pid" ] || ! kill -0 "$pid" 2>/dev/null; then
    return 0
  fi

  kill "$pid" 2>/dev/null || return 1
  remaining=5
  while kill -0 "$pid" 2>/dev/null && [ "$remaining" -gt 0 ]; do
    sleep 1
    remaining=$((remaining - 1))
  done

  if kill -0 "$pid" 2>/dev/null; then
    echo "dashboard loop did not stop" >&2
    return 1
  fi
}

stop_loop || exit 1

if [ "$1" = upgrade ]; then
  exit 0
fi

if [ -f "$SCRIPTLET" ] && cmp -s scriptlets/kindle-dashboard.sh "$SCRIPTLET"; then
  rm -f "$SCRIPTLET"
fi

rm -rf "$APP_DIR"
