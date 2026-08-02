#!/usr/bin/env bash

# Stream default-output changes to Eww without polling the full audio inventory.

set -u
export LC_ALL=C

emit() {
  local observed_at available=false muted=false volume=0 name="Unavailable" line
  printf -v observed_at '%(%s)T' -1

  if command -v wpctl >/dev/null 2>&1; then
    line="$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null || true)"
    if [[ "$line" =~ Volume:[[:space:]]+([0-9]+([.][0-9]+)?) ]]; then
      available=true
      volume="$(awk -v value="${BASH_REMATCH[1]}" 'BEGIN { printf "%.0f", value * 100 }')"
      [[ "$line" == *"[MUTED]"* ]] && muted=true
    fi
  fi

  if command -v pactl >/dev/null 2>&1; then
    name="$(pactl get-default-sink 2>/dev/null || true)"
    [[ -n "$name" ]] || name="Default output"
  fi

  jq -nc --argjson at "$observed_at" --argjson available "$available" \
    --argjson muted "$muted" --argjson volume "$volume" --arg name "$name" \
    '{schema_version:1,ok:true,source:"PipeWire event",observed_at:$at,
      data:{available:$available,muted:$muted,volume_percent:$volume,name:$name},error:null}'
}

emit
command -v pactl >/dev/null 2>&1 || exit 0

pactl subscribe 2>/dev/null | while IFS= read -r event; do
  case "$event" in
    *" on sink "*|*" on server "*|*" on card "*) emit ;;
  esac
done
