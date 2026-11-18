#!/usr/bin/env bash

# Allowlisted SwayNotificationCenter actions for the dedicated Rail flyout.

set -euo pipefail
export LC_ALL=C

readonly ACTION="${1:-help}"
readonly SWAYNC_CLIENT_BIN="${SENOMY_SWAYNC_CLIENT_BIN:-/usr/bin/swaync-client}"

fail() {
  printf 'SenomyOS notification action: %s\n' "$*" >&2
  exit 1
}

[[ -x "$SWAYNC_CLIENT_BIN" ]] || fail "SwayNotificationCenter is unavailable"

case "$ACTION" in
  toggle-dnd)
    "$SWAYNC_CLIENT_BIN" --toggle-dnd >/dev/null
    ;;
  close-all)
    "$SWAYNC_CLIENT_BIN" --close-all >/dev/null
    ;;
  *)
    fail "usage: notification-action.sh [toggle-dnd|close-all]"
    ;;
esac
