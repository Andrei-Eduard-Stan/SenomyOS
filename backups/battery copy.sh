#!/usr/bin/env bash
# Requires: upower, jq

# Collect battery device paths
mapfile -t BS < <(upower -e | grep -E 'BAT|battery')

# Helper: fetch and coerce a UPower field to integer percent
get_int_pct() {
  local dev="$1"
  # Extract the numeric part after "percentage:"; strip spaces and '%'; cast to int
  upower -i "$dev" | awk -F: '/percentage/{gsub(/[%[:space:]]/, "", $2); printf("%d\n", $2+0)}'
}

# Helper: fetch a simple string field
get_field() {
  local dev="$1" key="$2"
  upower -i "$dev" | awk -F: -v k="$key" '$1~k{gsub(/^[ \t]+/, "", $2); print $2}'
}

B0="${BS[0]:-}"
B1="${BS[1]:-}"

P0=0; P1=0; S0="unknown"; S1="unknown"

if [[ -n "$B0" ]]; then
  P0="$(get_int_pct "$B0")"; S0="$(get_field "$B0" state)"
fi
if [[ -n "$B1" ]]; then
  P1="$(get_int_pct "$B1")"; S1="$(get_field "$B1" state)"
fi

DUAL=false
TOTAL="$P0"
STATE="$S0"

if [[ -n "$B1" ]]; then
  DUAL=true
  # Simple average of two integer percentages (you can weight later if you want)
  TOTAL=$(( (P0 + P1) / 2 ))
  # Aggregate state: if either is charging, call it charging; else discharging/unknown
  if [[ "$S0" == "charging" || "$S1" == "charging" ]]; then
    STATE="charging"
  elif [[ "$S0" == "discharging" || "$S1" == "discharging" ]]; then
    STATE="discharging"
  else
    STATE="${S0:-$S1}"
  fi
fi

jq -nc \
  --argjson dual "$DUAL" \
  --argjson bat0 "$P0" \
  --argjson bat1 "$P1" \
  --arg state "$STATE" \
  --argjson total "$TOTAL" \
  '{dual:$dual, bat0_percent:$bat0, bat1_percent:$bat1, percent_total:$total, state:$state}'
