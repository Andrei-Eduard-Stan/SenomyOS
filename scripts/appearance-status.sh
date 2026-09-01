#!/usr/bin/env bash

# Resolve validated shell appearance preferences and installed font capability.
set -u
export LC_ALL=C

readonly HOME_DIR="${HOME:-/nonexistent}"
readonly PREFERENCES="${SENOMY_PREFERENCES:-${XDG_CONFIG_HOME:-$HOME_DIR/.config}/senomyos/preferences.json}"
readonly PROFILE="${SENOMY_PROFILE:-${XDG_CONFIG_HOME:-$HOME_DIR/.config}/senomyos/profile.json}"
printf -v observed_at '%(%s)T' -1

defaults='{"font_family":"jetbrains","font_scale":"standard","heading_scale":"standard","body_scale":"standard","meta_scale":"standard","title_px":16,"body_px":11,"meta_px":9,"nav_px":10,"rail_px":11,"accent":"cyan","gradient":"subtle"}'
current='{}'
profile_defaults='{}'
if [[ -r "$PROFILE" ]] && jq -e '.schema_version == 1 and (.appearance | type == "object")' "$PROFILE" >/dev/null 2>&1; then
  profile_defaults="$(jq -c '.appearance' "$PROFILE")"
fi
if [[ -r "$PREFERENCES" ]] && jq -e 'type == "object"' "$PREFERENCES" >/dev/null 2>&1; then current="$(cat "$PREFERENCES")"; fi

resolved="$(jq -nc --argjson defaults "$defaults" --argjson profile "$profile_defaults" --argjson current "$current" '$defaults + $profile + $current')"
font_family="$(jq -r '.font_family' <<<"$resolved")"; case "$font_family" in jetbrains | iosevka) ;; *) font_family=jetbrains ;; esac
font_scale="$(jq -r '.font_scale' <<<"$resolved")"; case "$font_scale" in standard | large | touch) ;; *) font_scale=standard ;; esac
heading_scale="$(jq -r '.heading_scale' <<<"$resolved")"; case "$heading_scale" in standard | large) ;; *) heading_scale=standard ;; esac
body_scale="$(jq -r '.body_scale' <<<"$resolved")"; case "$body_scale" in standard | large) ;; *) body_scale=standard ;; esac
meta_scale="$(jq -r '.meta_scale' <<<"$resolved")"; case "$meta_scale" in standard | large) ;; *) meta_scale=standard ;; esac
validated_px() { local value="$1" min="$2" max="$3" fallback="$4"; [[ "$value" =~ ^[0-9]+$ ]] && ((value >= min && value <= max)) && printf '%s' "$value" || printf '%s' "$fallback"; }
title_px="$(validated_px "$(jq -r '.title_px' <<<"$resolved")" 12 24 16)"
body_px="$(validated_px "$(jq -r '.body_px' <<<"$resolved")" 9 18 11)"
meta_px="$(validated_px "$(jq -r '.meta_px' <<<"$resolved")" 8 15 9)"
nav_px="$(validated_px "$(jq -r '.nav_px' <<<"$resolved")" 9 18 10)"
rail_px="$(validated_px "$(jq -r '.rail_px' <<<"$resolved")" 9 16 11)"
accent="$(jq -r '.accent' <<<"$resolved")"; case "$accent" in cyan | violet | amber) ;; *) accent=cyan ;; esac
gradient="$(jq -r '.gradient' <<<"$resolved")"; case "$gradient" in off | subtle | strong) ;; *) gradient=subtle ;; esac

jetbrains_match="$(fc-match -f '%{family}' 'JetBrains Mono' 2>/dev/null | head -n1)"
iosevka_match="$(fc-match -f '%{family}' Iosevka 2>/dev/null | head -n1)"
jq -nc --argjson at "$observed_at" --arg font_family "$font_family" --arg font_scale "$font_scale" \
  --arg heading_scale "$heading_scale" --arg body_scale "$body_scale" --arg meta_scale "$meta_scale" \
  --argjson title_px "$title_px" --argjson body_px "$body_px" --argjson meta_px "$meta_px" --argjson nav_px "$nav_px" --argjson rail_px "$rail_px" \
  --arg accent "$accent" --arg gradient "$gradient" --arg jetbrains "$jetbrains_match" --arg iosevka "$iosevka_match" \
  --arg path "$PREFERENCES" --arg stylesheet "$HOME_DIR/.config/eww/eww.scss" '{schema_version:1,ok:true,source:"senomy-appearance",observed_at:$at,
    data:{font_family:$font_family,font_scale:$font_scale,heading_scale:$heading_scale,body_scale:$body_scale,meta_scale:$meta_scale,title_px:$title_px,body_px:$body_px,meta_px:$meta_px,nav_px:$nav_px,rail_px:$rail_px,accent:$accent,gradient:$gradient,
      fonts:{jetbrains:{requested:"JetBrains Mono",resolved:$jetbrains,exact:($jetbrains|contains("JetBrains Mono"))},iosevka:{requested:"Iosevka",resolved:$iosevka,exact:($iosevka|contains("Iosevka"))}},preferences_path:$path,stylesheet_path:$stylesheet},error:null}'
