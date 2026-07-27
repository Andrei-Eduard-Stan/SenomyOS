#!/usr/bin/env bash

# Execute only explicitly supported actions for managed background applications.

set -u

readonly FLAMESHOT_BIN="/usr/bin/flameshot"
readonly FLAMESHOT_UNIT="flameshot.service"
readonly FLAMESHOT_BUS="org.flameshot.Flameshot"

fail() {
  printf 'SenomyOS background applications: %s\n' "$1" >&2
  exit 1
}

usage() {
  printf 'Usage: %s flameshot {start|capture|launcher|configure|stop}\n' "$0" >&2
  exit 2
}

[[ $# -eq 2 ]] || usage

app="$1"
action="$2"

[[ "$app" == "flameshot" ]] || fail "Application is not allowlisted: $app"
[[ -x "$FLAMESHOT_BIN" ]] || fail "Flameshot is unavailable"
command -v systemctl >/dev/null 2>&1 ||
  fail "systemctl is unavailable"

flameshot_dbus_ready() {
  command -v busctl >/dev/null 2>&1 &&
    busctl --user list --no-legend --no-pager 2>/dev/null |
      awk '{print $1}' |
      grep -Fxq "$FLAMESHOT_BUS"
}

ensure_flameshot() {
  flameshot_dbus_ready && return 0
  systemctl --user start "$FLAMESHOT_UNIT" ||
    fail "Unable to start $FLAMESHOT_UNIT"
}

case "$action" in
  start)
    ensure_flameshot
    ;;
  capture)
    ensure_flameshot
    exec "$FLAMESHOT_BIN" gui
    ;;
  launcher)
    ensure_flameshot
    exec "$FLAMESHOT_BIN" launcher
    ;;
  configure)
    ensure_flameshot
    exec "$FLAMESHOT_BIN" config
    ;;
  stop)
    systemctl --user stop "$FLAMESHOT_UNIT" ||
      fail "Unable to stop $FLAMESHOT_UNIT"
    ;;
  *)
    usage
    ;;
esac
