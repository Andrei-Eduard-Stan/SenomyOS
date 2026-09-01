#!/usr/bin/env bash

# Resolve the selected portable hardware/form-factor profile.

set -u
export LC_ALL=C

readonly HOME_DIR="${HOME:-/nonexistent}"
readonly PROFILE="${SENOMY_PROFILE:-${XDG_CONFIG_HOME:-$HOME_DIR/.config}/senomyos/profile.json}"
readonly FALLBACK="${SENOMY_PROFILE_FALLBACK:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/deploy/profiles/automatic.json}"
printf -v observed_at '%(%s)T' -1

source_file="$FALLBACK"
source_name=portable-fallback
if [[ -f "$PROFILE" && ! -L "$PROFILE" ]] && jq -e '
  .schema_version == 1 and
  (.id | IN("automatic", "desktop", "touch", "narrow")) and
  (.display.scale | IN(1, 1.25, 1.5, 1.75, 2)) and
  (.shell.density | IN("auto", "standard", "compact", "narrow")) and
  (.appearance.font_scale | IN("standard", "large", "touch")) and
  (.file_manager.density | IN("auto", "standard", "touch")) and
  (.wallpaper.asset == "obsidian-default") and
  (.wallpaper.mode | IN("fill", "fit", "stretch", "center", "tile"))
' "$PROFILE" >/dev/null 2>&1; then
  source_file="$PROFILE"
  source_name=user-selection
fi

if [[ ! -r "$source_file" ]] || ! jq -e 'type == "object"' "$source_file" >/dev/null 2>&1; then
  jq -nc --argjson at "$observed_at" '{schema_version:1,ok:false,source:"senomy-profile",observed_at:$at,data:null,error:{code:"profile_unavailable",message:"No valid profile source is available"}}'
  exit 0
fi

jq -nc --argjson at "$observed_at" --arg source_name "$source_name" --arg path "$source_file" \
  --slurpfile profile "$source_file" \
  '{schema_version:1,ok:true,source:"senomy-profile",observed_at:$at,data:($profile[0] + {selection_source:$source_name,path:$path}),error:null}'
