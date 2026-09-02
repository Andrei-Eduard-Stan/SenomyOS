#!/usr/bin/env bash

# Apply allowlisted changes to the default audio sink.

set -u

export LC_ALL=C

readonly ACTION="${1:-get}"
readonly PACTL_BIN="${SENOMY_PACTL_BIN:-/usr/bin/pactl}"

fail() {
  printf 'SenomyOS audio action: %s\n' "$1" >&2
  exit 1
}

[[ -x "$PACTL_BIN" ]] ||
  fail "pactl is unavailable"

case "$ACTION" in
  get)
    [[ $# -le 1 ]] ||
      fail "get accepts no value"

    "$PACTL_BIN" get-sink-volume @DEFAULT_SINK@ |
      awk '
        NR == 1 {
          for (field = 1; field <= NF; field++) {
            if ($field ~ /^[0-9]+%$/) {
              gsub(/%/, "", $field)
              print $field
              exit
            }
          }
        }
      '
    ;;
  set)
    [[ $# -eq 2 ]] ||
      fail "set requires one percentage"

    requested="$2"
    [[ "$requested" =~ ^[0-9]+([.][0-9]+)?$ ]] ||
      fail "volume must be numeric"

    volume="$(awk -v requested="$requested" 'BEGIN { printf "%.0f", requested }')"
    ((volume >= 0 && volume <= 100)) ||
      fail "volume must be between 0 and 100"

    "$PACTL_BIN" set-sink-volume @DEFAULT_SINK@ "${volume}%"
    ;;
  toggle-mute)
    [[ $# -eq 1 ]] ||
      fail "toggle-mute accepts no value"

    "$PACTL_BIN" set-sink-mute @DEFAULT_SINK@ toggle
    ;;
  *)
    fail "unknown action: $ACTION"
    ;;
esac
