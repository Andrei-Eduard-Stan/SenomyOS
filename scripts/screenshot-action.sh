#!/usr/bin/env bash

# Close SenomyOS context surfaces before asking Flameshot to capture the screen.

set -u

readonly ACTION="${1:-help}"
readonly USER_HOME="${HOME:-/nonexistent}"
readonly EWW_BIN="${SENOMY_EWW_BIN:-/usr/bin/eww}"
readonly EWW_CONFIG="${EWW_CONFIG:-${XDG_CONFIG_HOME:-"$USER_HOME/.config"}/eww}"
readonly FLAMESHOT_BIN="${SENOMY_FLAMESHOT_BIN:-/usr/bin/flameshot}"
readonly SYSTEMCTL_BIN="${SENOMY_SYSTEMCTL_BIN:-/usr/bin/systemctl}"
readonly SURFACE_STATE="${SENOMY_SURFACE_STATE_BIN:-$EWW_CONFIG/scripts/surface-state.sh}"
readonly SETTLE_SECONDS="${SENOMY_SCREENSHOT_SETTLE_SECONDS:-0.18}"
readonly RUNTIME_ROOT="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/senomyos"
readonly LOCK_FILE="$RUNTIME_ROOT/screenshot.lock"

fail() {
  printf 'SenomyOS screenshot: %s\n' "$1" >&2
  exit 1
}

usage() {
  printf 'Usage: %s capture\n' "$0" >&2
  exit 2
}

[[ "$ACTION" == "capture" && $# -eq 1 ]] || usage
[[ -x "$EWW_BIN" ]] || fail "Eww is unavailable"
[[ -x "$FLAMESHOT_BIN" ]] || fail "Flameshot is unavailable"
[[ -x "$SYSTEMCTL_BIN" ]] || fail "systemctl is unavailable"
[[ -x "$SURFACE_STATE" ]] || fail "Surface coordinator is unavailable"
[[ "$SETTLE_SECONDS" =~ ^0(\.[0-9]+)?$|^[1-9][0-9]*(\.[0-9]+)?$ ]] ||
  fail "Invalid compositor settle delay"
command -v flock >/dev/null 2>&1 || fail "flock is unavailable"

mkdir -p "$RUNTIME_ROOT" || fail "Unable to create runtime directory"
exec 9>"$LOCK_FILE" || fail "Unable to open screenshot lock"
flock -n 9 || exit 0

if "$EWW_BIN" --config "$EWW_CONFIG" --no-daemonize ping >/dev/null 2>&1; then
  "$SURFACE_STATE" dismiss ||
    fail "Unable to close the active SenomyOS surface"
fi

# Let Hyprland repaint the closed layer before Flameshot reads the framebuffer.
sleep "$SETTLE_SECONDS"

"$SYSTEMCTL_BIN" --user start flameshot.service ||
  fail "Unable to start flameshot.service"

exec "$FLAMESHOT_BIN" gui
