#!/usr/bin/env bash

# Start one Eww daemon, wait for its IPC socket, then open the main bar.
# Eww may return from `daemon` before the server is ready, so opening the bar
# immediately can create a disconnected second process.

set -euo pipefail

EWW_BIN="${EWW_BIN:-/usr/bin/eww}"
EWW_CONFIG="${EWW_CONFIG:-${XDG_CONFIG_HOME:-"$HOME/.config"}/eww}"
HYPRCTL_BIN="${SENOMY_HYPRCTL_BIN:-/usr/bin/hyprctl}"
SETSID_BIN="${SENOMY_SETSID_BIN:-/usr/bin/setsid}"
READY_ATTEMPTS="${EWW_READY_ATTEMPTS:-50}"
READY_DELAY="${EWW_READY_DELAY:-0.1}"
RUNTIME_ROOT="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/senomyos"
DAEMON_LOG="${SENOMY_EWW_DAEMON_LOG:-$RUNTIME_ROOT/eww-daemon.log}"

fail() {
  printf 'SenomyOS: %s\n' "$*" >&2
  exit 1
}

wait_for_command() {
  local description="$1"
  shift
  local attempt=0

  until "$@"; do
    attempt=$((attempt + 1))
    if [ "$attempt" -ge "$READY_ATTEMPTS" ]; then
      fail "$description after $READY_ATTEMPTS attempts"
    fi
    sleep "$READY_DELAY"
  done
}

daemon_ready() {
  "$EWW_BIN" --config "$EWW_CONFIG" ping >/dev/null 2>&1
}

main_bar_defined() {
  "$EWW_BIN" --config "$EWW_CONFIG" list-windows 2>/dev/null |
    grep -qx 'main-bar'
}

main_bar_active() {
  "$EWW_BIN" --config "$EWW_CONFIG" active-windows 2>/dev/null |
    grep -qE '^[^:]+: main-bar$'
}

stop_config_daemons() {
  local proc pid owner index matched daemon_command
  local -a arguments=()
  "$EWW_BIN" --config "$EWW_CONFIG" kill >/dev/null 2>&1 || true
  sleep 0.4
  for proc in /proc/[0-9]*; do
    pid="${proc##*/}"
    [[ "$pid" != "$$" ]] || continue
    owner="$(stat -c %u "$proc" 2>/dev/null || true)"
    [[ "$owner" == "$(id -u)" ]] || continue
    arguments=()
    mapfile -d '' -t arguments <"$proc/cmdline" 2>/dev/null || true
    [[ "${arguments[0]:-}" == "$EWW_BIN" ]] || continue
    matched=false
    daemon_command=false
    for ((index = 1; index + 1 < ${#arguments[@]}; index++)); do
      if [[ "${arguments[index]}" == --config && "${arguments[index + 1]}" == "$EWW_CONFIG" ]]; then
        matched=true
        break
      fi
    done
    for ((index = 1; index < ${#arguments[@]}; index++)); do
      [[ "${arguments[index]}" == daemon ]] && daemon_command=true
    done
    [[ "$matched" == true && "$daemon_command" == true ]] || continue
    kill -TERM "$pid" 2>/dev/null || true
  done
  for ((attempt = 0; attempt < READY_ATTEMPTS; attempt++)); do
    daemon_ready || return 0
    sleep "$READY_DELAY"
  done
  return 1
}

screen=0
if [ -x "$HYPRCTL_BIN" ] && command -v jq >/dev/null 2>&1; then
  candidate="$($HYPRCTL_BIN -j monitors 2>/dev/null | jq -r '[.[]? | select(.focused == true) | .id][0] // 0' 2>/dev/null || printf 0)"
  case "$candidate" in *[!0-9]*|'') ;; *) screen="$candidate" ;; esac
fi

if daemon_ready && ! main_bar_defined; then
  stop_config_daemons || fail "Unable to replace an empty Eww daemon"
fi

if ! daemon_ready; then
  # IPC can be gone while a detached daemon process still survives. Remove
  # exact config-matched daemon processes before creating the replacement.
  stop_config_daemons || fail "Unable to stop stale Eww daemon processes"
  [[ -x "$SETSID_BIN" ]] || fail "setsid is required to detach the stable Eww server"
  mkdir -p "$RUNTIME_ROOT"
  : >"$DAEMON_LOG"
  # Eww's internal daemonization can leave a live process with a dead IPC
  # thread on this build. Detach foreground mode ourselves so its stable GTK
  # application thread survives the launching terminal and remains observable.
  "$SETSID_BIN" --fork "$EWW_BIN" --debug --no-daemonize --config "$EWW_CONFIG" daemon \
    >"$DAEMON_LOG" 2>&1 </dev/null &
fi

wait_for_command "Eww daemon did not become reachable" daemon_ready
wait_for_command "Eww daemon did not load the main-bar definition" main_bar_defined

if main_bar_active; then
  exit 0
fi

"$EWW_BIN" --config "$EWW_CONFIG" open --screen "$screen" main-bar
wait_for_command "Eww accepted main-bar but did not display it" main_bar_active

# Do not wait for the long-running workspace listener's recovery heartbeat.
"$EWW_CONFIG/scripts/workspaces.sh" --publish-once >/dev/null 2>&1 &
