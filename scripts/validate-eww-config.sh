#!/usr/bin/env bash

# Parse the complete on-disk Eww tree through a separate windowless daemon.
# This must never reload or mutate the live daemon: parser errors stay isolated
# inside a temporary config path and runtime log.
set -euo pipefail
export LC_ALL=C

readonly CONFIG_DIR="${SENOMY_EWW_CONFIG_SOURCE:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
readonly EWW_BIN="${EWW_BIN:-/usr/bin/eww}"
readonly TIMEOUT_BIN="${SENOMY_TIMEOUT_BIN:-/usr/bin/timeout}"
readonly SETSID_BIN="${SENOMY_SETSID_BIN:-/usr/bin/setsid}"
readonly RUNTIME_PARENT="${SENOMY_EWW_PREFLIGHT_ROOT:-${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}}"
readonly INSIGHTS_PANEL="$CONFIG_DIR/windows/insights-panel.yuck"

grep -qF '(insights-tab :section "notifications"' "$INSIGHTS_PANEL" || {
  printf 'Senomy Insights is missing its Notifications navigation target.\n' >&2
  exit 1
}
grep -qF '(box :visible {insights_section == "notifications"} (insights-notifications))' "$INSIGHTS_PANEL" || {
  printf 'Senomy Insights is missing its Notifications route body.\n' >&2
  exit 1
}

mkdir -p "$RUNTIME_PARENT"
TEST_ROOT="$(mktemp -d "$RUNTIME_PARENT/senomy-eww-preflight.XXXXXX")"
PROBE_CONFIG="$TEST_ROOT/config"
PROBE_LOG="$TEST_ROOT/daemon.log"
PROBE_PID=""

probe_call() {
  SENOMY_EWW_CONFIG="$PROBE_CONFIG" "$TIMEOUT_BIN" --foreground --kill-after=1s 4s \
    "$EWW_BIN" --no-daemonize --config "$PROBE_CONFIG" "$@"
}

cleanup() {
  local attempt
  probe_call kill >/dev/null 2>&1 || true
  if [[ "$PROBE_PID" =~ ^[1-9][0-9]*$ ]] && kill -0 "$PROBE_PID" 2>/dev/null; then
    kill -TERM "$PROBE_PID" 2>/dev/null || true
    for attempt in {1..20}; do
      kill -0 "$PROBE_PID" 2>/dev/null || break
      sleep 0.05
    done
    kill -KILL "$PROBE_PID" 2>/dev/null || true
  fi
  rm -rf -- "$TEST_ROOT"
}
trap cleanup EXIT INT TERM HUP

mkdir -p "$PROBE_CONFIG"
cp -a \
  "$CONFIG_DIR/eww.yuck" \
  "$CONFIG_DIR/eww.scss" \
  "$CONFIG_DIR/windows" \
  "$CONFIG_DIR/widgets" \
  "$CONFIG_DIR/sections" \
  "$CONFIG_DIR/scripts" \
  "$CONFIG_DIR/data" \
  "$CONFIG_DIR/assets" \
  "$CONFIG_DIR/appearance" \
  "$CONFIG_DIR/wiki" \
  "$CONFIG_DIR/systemd" \
  "$PROBE_CONFIG/"

SENOMY_EWW_CONFIG="$PROBE_CONFIG" "$SETSID_BIN" \
  "$EWW_BIN" --debug --no-daemonize --config "$PROBE_CONFIG" daemon \
  >"$PROBE_LOG" 2>&1 &
PROBE_PID=$!

ready=false
for attempt in {1..50}; do
  if probe_call ping >/dev/null 2>&1; then
    ready=true
    break
  fi
  sleep 0.1
done

if [[ "$ready" != true ]]; then
  printf 'Isolated Eww daemon did not become reachable.\n' >&2
  sed -n '1,160p' "$PROBE_LOG" >&2
  exit 1
fi

if ! windows="$(probe_call list-windows 2>&1)"; then
  printf 'Isolated Eww window query failed.\n%s\n' "$windows" >&2
  sed -n '1,160p' "$PROBE_LOG" >&2
  exit 1
fi

for expected in main-bar surface-dismiss actioncenter insights performance volume-flyout tray-flyout calendar-flyout notifications-flyout power-flyout companion; do
  if ! grep -qx "$expected" <<<"$windows"; then
    printf 'Isolated Eww parse did not define %s.\n' "$expected" >&2
    sed -n '1,160p' "$PROBE_LOG" >&2
    exit 1
  fi
done

printf 'Isolated Eww parse passed: eleven required windows are defined.\n'
