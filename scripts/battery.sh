#!/usr/bin/env bash

# Emit a compact battery summary without fabricating charge when unavailable.

set -u
export LC_ALL=C

if ! command -v jq >/dev/null 2>&1; then
  printf '{"available":false,"dual":false,"bat0_percent":0,"bat0_icon":"","bat1_percent":0,"bat1_icon":"","percent_total":0,"total_icon":"","state":"unavailable","error":"jq is unavailable"}\n'
  exit 0
fi

emit_unavailable() {
  jq -nc --arg state "$1" --arg error "$2" \
    '{available:false,dual:false,bat0_percent:0,bat0_icon:"",bat1_percent:0,
      bat1_icon:"",percent_total:0,total_icon:"",state:$state,error:$error}'
  exit 0
}

command -v upower >/dev/null 2>&1 ||
  emit_unavailable "unavailable" "UPower is unavailable"

# Collect battery device paths
devices="$(upower -e 2>/dev/null)" ||
  emit_unavailable "unavailable" "UPower is not reachable"
mapfile -t BS < <(grep -E 'BAT|battery' <<<"$devices")
((${#BS[@]} > 0)) ||
  emit_unavailable "absent" "No system battery was detected"

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

# UPower's DisplayDevice weights packs by energy capacity. A plain arithmetic
# average is wrong when installed batteries have different sizes.
DISPLAY_TOTAL="$(
  upower -i /org/freedesktop/UPower/devices/DisplayDevice 2>/dev/null |
    awk -F: '/percentage/{gsub(/[%[:space:]]/, "", $2); printf("%d\n", $2+0); exit}'
)"
if [[ "$DISPLAY_TOTAL" =~ ^[0-9]+$ ]]; then
  TOTAL="$DISPLAY_TOTAL"
fi

P_icon="[D_]"
P0icon="[D0]"
P1icon="[D1]"

if [[ "$TOTAL" -ge 75 ]]; then
  P_icon="󱊣"
elif [[ "$TOTAL" -ge 50 ]]; then
  P_icon="󱊢"
elif [[ "$TOTAL" -ge 25 ]]; then
  P_icon="󱊡"
else
  P_icon="󰂎"
fi

if [[ "$P0" -ge 75 ]]; then
  P0icon="󰁹"
elif [[ "$P0" -ge 50 ]]; then
  P0icon="󰁿"
elif [[ "$P0" -ge 25 ]]; then
  P0icon="󰁼"
else
  P0icon="󰁺"
fi

if [[ "$P1" -ge 75 ]]; then
  P1icon="󰁹"
elif [[ "$P1" -ge 50 ]]; then
  P1icon="󰁿"
elif [[ "$P1" -ge 25 ]]; then
  P1icon="󰁼"
else
  P1icon="󰁺"
fi

jq -nc \
  --argjson available true \
  --argjson dual "$DUAL" \
  --argjson bat0 "$P0" \
  --arg bat0_icon "$P0icon" \
  --argjson bat1 "$P1" \
  --arg bat1_icon "$P1icon" \
  --arg state "$STATE" \
  --argjson total "$TOTAL" \
  --arg total_icon "$P_icon" \
  '{available:$available, dual:$dual,
    bat0_percent:$bat0, bat0_icon:$bat0_icon,
    bat1_percent:$bat1, bat1_icon:$bat1_icon,
    percent_total:$total, total_icon:$total_icon,
    state:$state, error:null}'
