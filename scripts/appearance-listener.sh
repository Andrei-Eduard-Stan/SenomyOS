#!/usr/bin/env bash

# Publish appearance on atomic preference changes; periodic fallback also
# catches font capability changes and filesystems without inotify support.
set -u
export LC_ALL=C

readonly CONFIG_DIR="${SENOMY_EWW_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/eww}"
readonly STATUS_BIN="$CONFIG_DIR/scripts/appearance-status.sh"
readonly PREFERENCES="${SENOMY_PREFERENCES:-${XDG_CONFIG_HOME:-$HOME/.config}/senomyos/preferences.json}"
readonly DIRECTORY="$(dirname "$PREFERENCES")"
readonly BASENAME="$(basename "$PREFERENCES")"

emit() {
  "$STATUS_BIN" 2>/dev/null || true
}

emit
mkdir -p "$DIRECTORY" 2>/dev/null || true

if command -v inotifywait >/dev/null 2>&1; then
  while :; do
    changed="$(timeout 60s inotifywait -q -e close_write,create,moved_to --format '%f' "$DIRECTORY" 2>/dev/null || true)"
    [[ -z "$changed" || "$changed" == "$BASENAME" ]] && emit
  done
else
  signature="$(stat -c '%y:%s' "$PREFERENCES" 2>/dev/null || printf missing)"
  ticks=0
  while sleep 0.10; do
    next="$(stat -c '%y:%s' "$PREFERENCES" 2>/dev/null || printf missing)"
    ticks=$((ticks + 1))
    if [[ "$next" != "$signature" || $ticks -ge 600 ]]; then
      signature="$next"
      ticks=0
      emit
    fi
  done
fi
