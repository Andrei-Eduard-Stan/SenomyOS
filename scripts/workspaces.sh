#!/usr/bin/env bash
# Stable 1..N workspaces with [active] pushed to Eww
# - Single-sample per cycle (less race)
# - Debounce shrink (avoid flicker)
# - Push on change with periodic Eww resync

EW="/usr/bin/eww"
HY="/usr/bin/hyprctl"
JQ="/usr/bin/jq"
AWK="/usr/bin/awk"
EWW_CFG="$HOME/.config/eww"

last_out=""
last_max=1
shrink_streak=0            # how many consecutive polls suggest shrinking N
SHRINK_THRESHOLD=3         # require 3 consecutive polls before shrinking
SYNC_INTERVAL=10           # republish every 10 seconds
next_out=""
sync_age=0

build_once() {
  next_out="$last_out"

  # Sample both endpoints once per cycle
  ws_json="$("$HY" -j workspaces 2>/dev/null)" || ws_json=""
  act_json="$("$HY" -j activeworkspace 2>/dev/null)" || act_json=""

  # Parse IDs; tolerate transient empties
  ids="$(printf '%s' "$ws_json" | "$JQ" -r '.[].id' 2>/dev/null)" || ids=""
  active="$(printf '%s' "$act_json" | "$JQ" -r '.id // 1' 2>/dev/null)" || active=1

  # If we got absolutely nothing, keep last good
  if [ -z "$ids$active" ]; then
    return
  fi

  # Compute proposed max from current sample
  max="$active"
  if [ -n "$ids" ]; then
    ids_max="$(printf '%s\n' $ids | "$AWK" 'max<$1{max=$1} END{print (max==""?0:max)}')"
    [ -n "$ids_max" ] && [ "$ids_max" -gt "$max" ] && max="$ids_max"
  fi
  case "$max" in (*[!0-9]*) max="$last_max";; esac

  # Debounce shrink: only allow lowering max after SHRINK_THRESHOLD consistent polls
  if [ "$max" -lt "$last_max" ]; then
    shrink_streak=$((shrink_streak+1))
    # hold previous view until shrink is stable
    if [ "$shrink_streak" -lt "$SHRINK_THRESHOLD" ]; then
      return
    fi
  else
    shrink_streak=0
  fi

  # Build "1 2 [3] 4 ..."
  out=""
  i=1
  while [ "$i" -le "$max" ]; do
    if [ "$i" -eq "$active" ]; then out="$out [$i]"; else out="$out $i"; fi
    i=$((i+1))
  done
  out="${out# }"

  last_max="$max"
  next_out="$out"
}

push() {
  build_once
  new_out="$next_out"
  [ -z "$new_out" ] && return

  sync_age=$((sync_age + 1))

  if [ "$new_out" != "$last_out" ] || [ "$sync_age" -ge "$SYNC_INTERVAL" ]; then
    if "$EW" -c "$EWW_CFG" update workspaces="$new_out" >/dev/null 2>&1; then
      last_out="$new_out"
      sync_age=0
    fi
  fi
}

# main loop
while true; do
  push
  sleep 1
done
