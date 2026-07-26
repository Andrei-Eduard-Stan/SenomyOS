#!/usr/bin/env bash

# Start one Eww daemon, wait for its IPC socket, then open the main bar.
# Eww may return from `daemon` before the server is ready, so opening the bar
# immediately can create a disconnected second process.

set -u

EWW_BIN="${EWW_BIN:-/usr/bin/eww}"
EWW_CONFIG="${EWW_CONFIG:-${XDG_CONFIG_HOME:-"$HOME/.config"}/eww}"
READY_ATTEMPTS="${EWW_READY_ATTEMPTS:-50}"
READY_DELAY="${EWW_READY_DELAY:-0.1}"

if ! "$EWW_BIN" --config "$EWW_CONFIG" ping >/dev/null 2>&1; then
  "$EWW_BIN" --config "$EWW_CONFIG" daemon
fi

attempt=0
until "$EWW_BIN" --config "$EWW_CONFIG" ping >/dev/null 2>&1; do
  attempt=$((attempt + 1))
  if [ "$attempt" -ge "$READY_ATTEMPTS" ]; then
    printf 'SenomyOS: Eww daemon did not become ready after %s attempts.\n' \
      "$READY_ATTEMPTS" >&2
    exit 1
  fi
  sleep "$READY_DELAY"
done

if "$EWW_BIN" --config "$EWW_CONFIG" active-windows \
  | grep -qE '^[^:]+: main-bar$'; then
  exit 0
fi

"$EWW_BIN" --config "$EWW_CONFIG" open main-bar
