#!/usr/bin/env bash

# Acknowledge the current Rail notification badge for this Eww session.

set -euo pipefail

readonly EWW_BIN="${SENOMY_EWW_BIN:-/usr/bin/eww}"
readonly CONFIG_DIR="${SENOMY_EWW_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/eww}"
readonly OBSERVED_AT="${1:-0}"

[[ "$OBSERVED_AT" =~ ^[0-9]+([.][0-9]+)?$ ]] || {
  printf 'notification acknowledgement requires a numeric observation timestamp\n' >&2
  exit 2
}

exec "$EWW_BIN" --no-daemonize --config "$CONFIG_DIR" update \
  "rail_notification_ack_at=$OBSERVED_AT"
