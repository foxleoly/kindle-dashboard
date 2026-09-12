#!/bin/sh

APP_DIR=/mnt/us/kindle-dashboard
LOG_DIR="$APP_DIR/logs"
ENV_FILE="$APP_DIR/dashboard.env"
SCRIPTLET=/mnt/us/documents/kindle-dashboard.sh
FBINK=/mnt/us/libkh/bin/fbink
created_app_dir=0

[ -x "$FBINK" ] || FBINK=/usr/bin/fbink

rollback() {
  status=$?
  if [ "$status" -ne 0 ] && [ "$created_app_dir" -eq 1 ]; then
    rm -rf "$APP_DIR"
  fi
  exit "$status"
}

trap rollback EXIT INT TERM

if [ ! -d /mnt/us ]; then
  echo "Kindle user storage is unavailable" >&2
  exit 1
fi

if [ ! -x "$FBINK" ]; then
  echo "FBInk is unavailable" >&2
  exit 1
fi

if [ ! -d "$APP_DIR" ]; then
  mkdir -p "$LOG_DIR"
  created_app_dir=1
else
  mkdir -p "$LOG_DIR"
fi

install_file() {
  source_file=$1
  destination=$2
  mode=$3
  temporary="$destination.tmp.$$"
  cp "$source_file" "$temporary"
  chmod "$mode" "$temporary"
  mv "$temporary" "$destination"
}

install_file payload/dash-loop.sh "$APP_DIR/dash-loop.sh" 755
install_file payload/dash-launch.sh "$APP_DIR/dash-launch.sh" 755

if [ ! -f "$ENV_FILE" ]; then
  install_file payload/dashboard.env "$ENV_FILE" 600
fi

install_file scriptlets/kindle-dashboard.sh "$SCRIPTLET" 755
trap - EXIT INT TERM
exit 0
