#!/usr/bin/env bash

# Derive a portable bar density from the focused Hyprland monitor.

set -u
export LC_ALL=C
printf -v observed_at '%(%s)T' -1
preferences="${SENOMY_PREFERENCES:-${XDG_CONFIG_HOME:-$HOME/.config}/senomyos/preferences.json}"
preferred_density="auto"

if [[ -r "$preferences" ]] && command -v jq >/dev/null 2>&1; then
  candidate="$(jq -r '.density // "auto"' "$preferences" 2>/dev/null || printf auto)"
  [[ "$candidate" == auto || "$candidate" == standard || "$candidate" == compact || "$candidate" == narrow ]] &&
    preferred_density="$candidate"
fi

fallback_density="$preferred_density"
[[ "$fallback_density" == auto ]] && fallback_density="standard"
fallback_compact=false
fallback_narrow=false
fallback_phone=false
[[ "$fallback_density" == compact || "$fallback_density" == narrow ]] && fallback_compact=true
[[ "$fallback_density" == narrow ]] && fallback_narrow=true

if ! command -v jq >/dev/null 2>&1 || { [[ -z "${SENOMY_MONITORS_JSON:-}" ]] && ! command -v hyprctl >/dev/null 2>&1; }; then
  printf '{"schema_version":1,"ok":false,"source":"hyprland","observed_at":%s,"data":{"monitor_id":0,"width":1920,"height":1080,"scale":1,"preferred_density":"%s","density":"%s","compact":%s,"narrow":%s,"phone":%s},"error":{"code":"dependency_missing","message":"hyprctl or jq is unavailable"}}\n' "$observed_at" "$preferred_density" "$fallback_density" "$fallback_compact" "$fallback_narrow" "$fallback_phone"
  exit 0
fi

if [[ -n "${SENOMY_MONITORS_JSON:-}" ]]; then
  monitors="$SENOMY_MONITORS_JSON"
else
  monitors="$(hyprctl -j monitors 2>/dev/null || true)"
fi
if ! jq -e 'type == "array" and length > 0' >/dev/null 2>&1 <<<"$monitors"; then
  printf '{"schema_version":1,"ok":false,"source":"hyprland","observed_at":%s,"data":{"monitor_id":0,"width":1920,"height":1080,"scale":1,"preferred_density":"%s","density":"%s","compact":%s,"narrow":%s,"phone":%s},"error":{"code":"source_unavailable","message":"No Hyprland monitor is available"}}\n' "$observed_at" "$preferred_density" "$fallback_density" "$fallback_compact" "$fallback_narrow" "$fallback_phone"
  exit 0
fi

jq -nc --argjson at "$observed_at" --argjson monitors "$monitors" --arg preferred_density "$preferred_density" '
  (($monitors | map(select(.focused == true)) | first) // $monitors[0]) as $monitor
  | (($monitor.width / ($monitor.scale // 1)) | floor) as $logical_width
  | (if $preferred_density == "auto" then
      (if $logical_width < 1100 then "narrow" elif $logical_width < 1500 then "compact" else "standard" end)
    else $preferred_density end) as $density
  | {
      schema_version: 1,
      ok: true,
      source: "hyprland",
      observed_at: $at,
      data: {
        monitor_id: ($monitor.id // 0),
        name: ($monitor.name // "Unknown"),
        width: $logical_width,
        height: (($monitor.height / ($monitor.scale // 1)) | floor),
        scale: ($monitor.scale // 1),
        preferred_density: $preferred_density,
        density: $density,
        compact: ($density == "compact" or $density == "narrow"),
        narrow: ($density == "narrow"),
        phone: ($logical_width < 480)
      },
      error: null
    }'
