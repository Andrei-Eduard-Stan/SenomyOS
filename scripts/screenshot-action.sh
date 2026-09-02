#!/usr/bin/env bash

# Freeze the visible SenomyOS desktop in Flameshot, then release only the live
# layer-shell input regions while the user selects from that frozen image.

set -u

readonly ACTION="${1:-help}"
readonly USER_HOME="${HOME:-/nonexistent}"
readonly EWW_BIN="${SENOMY_EWW_BIN:-/usr/bin/eww}"
readonly EWW_CONFIG="${EWW_CONFIG:-${XDG_CONFIG_HOME:-"$USER_HOME/.config"}/eww}"
readonly FLAMESHOT_BIN="${SENOMY_FLAMESHOT_BIN:-/usr/bin/flameshot}"
readonly SYSTEMCTL_BIN="${SENOMY_SYSTEMCTL_BIN:-/usr/bin/systemctl}"
readonly HYPRCTL_BIN="${SENOMY_HYPRCTL_BIN:-/usr/bin/hyprctl}"
readonly JQ_BIN="${SENOMY_JQ_BIN:-/usr/bin/jq}"
readonly SURFACE_STATE="${SENOMY_SURFACE_STATE_BIN:-$EWW_CONFIG/scripts/surface-state.sh}"
readonly COMPANION_STATE="${SENOMY_COMPANION_STATE_BIN:-$EWW_CONFIG/scripts/companion-state.sh}"
readonly FREEZE_SECONDS="${SENOMY_SCREENSHOT_FREEZE_SECONDS:-0.10}"
readonly APPEAR_ATTEMPTS="${SENOMY_SCREENSHOT_APPEAR_ATTEMPTS:-80}"
readonly POLL_SECONDS="${SENOMY_SCREENSHOT_POLL_SECONDS:-0.05}"
readonly QUERY_FAILURE_LIMIT="${SENOMY_SCREENSHOT_QUERY_FAILURE_LIMIT:-20}"
readonly RUNTIME_ROOT="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/senomyos"
readonly LOCK_FILE="$RUNTIME_ROOT/screenshot.lock"

surface_suspended=false
companion_suspended=false

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
[[ -x "$HYPRCTL_BIN" ]] || fail "hyprctl is unavailable"
[[ -x "$JQ_BIN" ]] || fail "jq is unavailable"
[[ -x "$SURFACE_STATE" ]] || fail "Surface coordinator is unavailable"
[[ -x "$COMPANION_STATE" ]] || fail "Companion coordinator is unavailable"
[[ "$FREEZE_SECONDS" =~ ^0(\.[0-9]+)?$|^[1-9][0-9]*(\.[0-9]+)?$ ]] ||
  fail "Invalid capture freeze delay"
[[ "$POLL_SECONDS" =~ ^0\.[0-9]+$ ]] || fail "Invalid capture poll delay"
[[ "$APPEAR_ATTEMPTS" =~ ^[1-9][0-9]*$ ]] || fail "Invalid capture appearance attempts"
[[ "$QUERY_FAILURE_LIMIT" =~ ^[1-9][0-9]*$ ]] || fail "Invalid capture query failure limit"
command -v flock >/dev/null 2>&1 || fail "flock is unavailable"

mkdir -p "$RUNTIME_ROOT" || fail "Unable to create runtime directory"
exec 9>"$LOCK_FILE" || fail "Unable to open screenshot lock"
flock -n 9 || exit 0

capture_client_state() {
  local clients
  clients="$($HYPRCTL_BIN -j clients 2>/dev/null)" || return 2
  "$JQ_BIN" -e '
    any(.[]?;
      ((.class // "") == "flameshot") and
      ((.initialTitle // "") == "flameshot"))
  ' >/dev/null <<<"$clients"
}

wait_for_capture_open() {
  local attempt status
  for ((attempt = 1; attempt <= APPEAR_ATTEMPTS; attempt++)); do
    capture_client_state
    status=$?
    ((status == 0)) && return 0
    sleep "$POLL_SECONDS"
  done
  return 1
}

wait_for_capture_close() {
  local failures=0 status
  while true; do
    capture_client_state
    status=$?
    case "$status" in
      0)
        failures=0
        sleep "$POLL_SECONDS"
        ;;
      1)
        return 0
        ;;
      *)
        failures=$((failures + 1))
        ((failures < QUERY_FAILURE_LIMIT)) || return 1
        sleep "$POLL_SECONDS"
        ;;
    esac
  done
}

restore_context() {
  local status=0
  if [[ "$surface_suspended" == true ]]; then
    if "$SURFACE_STATE" capture-restore >/dev/null 2>&1; then
      surface_suspended=false
    else
      status=1
    fi
  fi
  if [[ "$companion_suspended" == true ]]; then
    if "$COMPANION_STATE" capture-restore >/dev/null 2>&1; then
      companion_suspended=false
    else
      status=1
    fi
  fi
  return "$status"
}

trap 'restore_context >/dev/null 2>&1 || true' EXIT
trap 'exit 130' HUP INT TERM

capture_client_state
case "$?" in
  0) fail "A Flameshot capture is already active" ;;
  2) fail "Unable to query Hyprland clients" ;;
esac

"$SYSTEMCTL_BIN" --user start flameshot.service ||
  fail "Unable to start flameshot.service"

"$FLAMESHOT_BIN" gui >/dev/null 2>&1 &
wait_for_capture_open || fail "Flameshot did not open its capture client"

# The capture client is mapped only after Flameshot has taken the screencopy.
# One short frame guard lets its frozen texture settle before Eww is unmapped.
sleep "$FREEZE_SECONDS"

if "$EWW_BIN" --no-daemonize --config "$EWW_CONFIG" ping >/dev/null 2>&1; then
  surface_suspended=true
  "$SURFACE_STATE" capture-suspend ||
    fail "Unable to release the active SenomyOS surface for selection"

  companion_suspended=true
  "$COMPANION_STATE" capture-suspend ||
    fail "Unable to release the Senomy companion for selection"
fi

wait_for_capture_close || fail "Lost the Hyprland client state during capture"
restore_context || fail "Unable to restore the SenomyOS context after capture"
trap - EXIT
