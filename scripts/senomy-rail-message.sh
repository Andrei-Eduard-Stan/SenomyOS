#!/usr/bin/env bash

# Emit a bounded TFL-style message viewport for the rail without interpolating
# dynamic text into a shell command.
set -u
export LC_ALL=C.UTF-8

readonly CONFIG_DIR="${SENOMY_EWW_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/eww}"
readonly EWW_BIN="${SENOMY_EWW_BIN:-/usr/bin/eww}"
readonly BATTERY_BIN="${SENOMY_BATTERY_BIN:-$CONFIG_DIR/scripts/battery.sh}"
readonly DIALOGUE_BIN="${SENOMY_DIALOGUE_BIN:-$CONFIG_DIR/scripts/senomy-dialogue.sh}"
readonly WIDTH="${SENOMY_RAIL_MESSAGE_WIDTH:-52}"
readonly STEP_DELAY="${SENOMY_RAIL_MESSAGE_STEP_DELAY:-0.22}"
readonly HOLD_STEPS="${SENOMY_RAIL_MESSAGE_HOLD_STEPS:-7}"
readonly RESET_DELAY="${SENOMY_RAIL_MESSAGE_RESET_DELAY:-6}"

frame() {
  jq -nr --arg text "$1" --argjson start "${2:-0}" --argjson width "$WIDTH" \
    '($text + (" " * $width))[$start:($start + $width)]'
}

resolve_message() {
  local battery ambient
  battery="$($BATTERY_BIN 2>/dev/null || printf '{}')"
  if jq -e '.available == true and .percent_total <= 10' >/dev/null 2>&1 <<<"$battery"; then
    jq -r '"Battery is at \(.percent_total)%. Connect power now."' <<<"$battery"
    return
  fi
  if jq -e '.available == true and .percent_total <= 20' >/dev/null 2>&1 <<<"$battery"; then
    printf 'Low battery. Keep a charger nearby.\n'
    return
  fi
  ambient="$(timeout --foreground 1s "$EWW_BIN" --config "$CONFIG_DIR" --no-daemonize get senomy_ambient 2>/dev/null || printf '{}')"
  if ! jq -e '.data.text | type == "string"' >/dev/null 2>&1 <<<"$ambient"; then
    ambient="$($DIALOGUE_BIN ambient 2>/dev/null || printf '{}')"
  fi
  jq -r '.data.text // "Everything looks steady."' <<<"$ambient"
}

while :; do
  message="$(resolve_message)"
  length="$(jq -nr --arg text "$message" '$text | length')"
  if ((length <= WIDTH)); then
    frame "$message" 0
    sleep 15
    continue
  fi

  for ((hold = 0; hold < HOLD_STEPS; hold++)); do
    frame "$message" 0
    sleep "$STEP_DELAY"
  done
  max_offset=$((length - WIDTH))
  for ((offset = 1; offset <= max_offset; offset++)); do
    frame "$message" "$offset"
    sleep "$STEP_DELAY"
  done
  sleep 2
  frame "$message" 0
  sleep "$RESET_DELAY"
done
