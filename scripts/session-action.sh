#!/usr/bin/env bash

# Execute only the fixed session actions exposed by the guarded power flyout.
# The Eww control requires a separate confirmation state before calling here.

set -euo pipefail
export LC_ALL=C

readonly ACTION="${1:-help}"
readonly HYPRCTL_BIN="${SENOMY_HYPRCTL_BIN:-/usr/bin/hyprctl}"
readonly SYSTEMCTL_BIN="${SENOMY_SYSTEMCTL_BIN:-/usr/bin/systemctl}"
readonly LOCK_BIN="${SENOMY_LOCK_BIN:-$HOME/.local/bin/senomy-lock}"

fail() {
  printf 'SenomyOS session action: %s\n' "$*" >&2
  exit 1
}

case "$ACTION" in
  lock)
    [[ -x "$LOCK_BIN" ]] || fail "Senomy lock launcher is unavailable"
    exec "$LOCK_BIN"
    ;;
  suspend)
    [[ -x "$SYSTEMCTL_BIN" ]] || fail "systemctl is unavailable"
    exec "$SYSTEMCTL_BIN" suspend
    ;;
  logout)
    [[ -x "$HYPRCTL_BIN" ]] || fail "hyprctl is unavailable"
    exec "$HYPRCTL_BIN" dispatch exit
    ;;
  reboot)
    [[ -x "$SYSTEMCTL_BIN" ]] || fail "systemctl is unavailable"
    exec "$SYSTEMCTL_BIN" reboot
    ;;
  poweroff)
    [[ -x "$SYSTEMCTL_BIN" ]] || fail "systemctl is unavailable"
    exec "$SYSTEMCTL_BIN" poweroff
    ;;
  *)
    fail "usage: session-action.sh [lock|suspend|logout|reboot|poweroff]"
    ;;
esac
