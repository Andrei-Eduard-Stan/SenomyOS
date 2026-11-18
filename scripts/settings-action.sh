#!/usr/bin/env bash

# Update allowlisted SenomyOS user presentation preferences atomically.

set -euo pipefail
export LC_ALL=C

action="${1:-}"
value="${2:-}"
preferences="${SENOMY_PREFERENCES:-${XDG_CONFIG_HOME:-$HOME/.config}/senomyos/preferences.json}"
runtime_root="${SENOMY_SETTINGS_RUNTIME_DIR:-${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/senomyos}"
operation_file="$runtime_root/appearance-operation.json"

fail() { printf 'SenomyOS settings: %s\n' "$1" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || fail "jq is unavailable"

publish_operation() {
  local state="$1" label="$2" message="$3" progress="$4"
  local temporary observed_at
  printf -v observed_at '%(%s)T' -1
  mkdir -p -m 700 "$runtime_root"
  temporary="$(mktemp "$runtime_root/.appearance-operation.XXXXXX")"
  jq -nc --argjson at "$observed_at" --arg state "$state" --arg label "$label" \
    --arg message "$message" --argjson progress "$progress" \
    '{schema_version:1,ok:true,source:"appearance-operation",observed_at:$at,
      data:{state:$state,state_label:($state|ascii_upcase),label:$label,message:$message,
        progress_percent:$progress},error:null}' >"$temporary"
  chmod 600 "$temporary"
  mv -f "$temporary" "$operation_file"
}

read_operation() {
  if [[ -r "$operation_file" ]] && jq -e '.schema_version == 1 and .ok == true' "$operation_file" >/dev/null 2>&1; then
    cat "$operation_file"
  else
    jq -nc '{schema_version:1,ok:true,source:"appearance-operation",observed_at:0,
      data:{state:"idle",state_label:"READY",label:"Appearance ready",
        message:"Changes apply live and persist across restarts.",progress_percent:0},error:null}'
  fi
}

if [[ "$action" == status ]]; then
  [[ $# -eq 1 ]] || fail "status accepts no value"
  read_operation
  exit 0
fi

case "$action" in
  set-density)
    [[ "$value" == auto || "$value" == standard || "$value" == compact || "$value" == narrow ]] ||
      fail "density must be auto, standard, compact, or narrow"
    ;;
  set-font-family) [[ "$value" == jetbrains || "$value" == iosevka ]] || fail "font family is not allowlisted" ;;
  set-font-scale) [[ "$value" == standard || "$value" == large || "$value" == touch ]] || fail "font scale is not allowlisted" ;;
  set-heading-scale | set-body-scale | set-meta-scale) [[ "$value" == standard || "$value" == large ]] || fail "category scale is not allowlisted" ;;
  set-title-px) [[ "$value" =~ ^[0-9]+$ ]] && ((value >= 12 && value <= 24)) || fail "title size must be 12-24px" ;;
  set-body-px) [[ "$value" =~ ^[0-9]+$ ]] && ((value >= 9 && value <= 18)) || fail "body size must be 9-18px" ;;
  set-meta-px) [[ "$value" =~ ^[0-9]+$ ]] && ((value >= 8 && value <= 15)) || fail "metadata size must be 8-15px" ;;
  set-nav-px) [[ "$value" =~ ^[0-9]+$ ]] && ((value >= 9 && value <= 18)) || fail "navigation size must be 9-18px" ;;
  set-rail-px) [[ "$value" =~ ^[0-9]+$ ]] && ((value >= 9 && value <= 16)) || fail "rail size must be 9-16px" ;;
  set-accent) [[ "$value" == cyan || "$value" == violet || "$value" == amber ]] || fail "accent is not allowlisted" ;;
  set-gradient) [[ "$value" == off || "$value" == subtle || "$value" == strong ]] || fail "gradient is not allowlisted" ;;
  *) fail "unknown action" ;;
esac

publish_operation running "Applying appearance" "Writing and publishing ${action#set-}." 35

mkdir -p -m 700 "$(dirname "$preferences")"
current='{"schema_version":3,"density":"auto","font_family":"jetbrains","font_scale":"standard","heading_scale":"standard","body_scale":"standard","meta_scale":"standard","title_px":16,"body_px":11,"meta_px":9,"nav_px":10,"rail_px":11,"accent":"cyan","gradient":"subtle"}'
if [[ -r "$preferences" ]] && jq -e 'type == "object"' >/dev/null 2>&1 <"$preferences"; then
  current="$(<"$preferences")"
fi

tmp="$(mktemp "${preferences}.XXXXXX")"
trap 'rm -f "$tmp"' EXIT
case "$action" in
  set-density) key=density ;;
  set-font-family) key=font_family ;;
  set-font-scale) key=font_scale ;;
  set-heading-scale) key=heading_scale ;;
  set-body-scale) key=body_scale ;;
  set-meta-scale) key=meta_scale ;;
  set-title-px) key=title_px ;;
  set-body-px) key=body_px ;;
  set-meta-px) key=meta_px ;;
  set-nav-px) key=nav_px ;;
  set-rail-px) key=rail_px ;;
  set-accent) key=accent ;;
  set-gradient) key=gradient ;;
esac
if [[ "$action" == set-font-scale ]]; then
  case "$value" in
    standard) title_px=16; body_px=11; meta_px=9; nav_px=10; rail_px=11 ;;
    large) title_px=19; body_px=13; meta_px=11; nav_px=12; rail_px=13 ;;
    touch) title_px=21; body_px=15; meta_px=12; nav_px=14; rail_px=14 ;;
  esac
  jq -nc --argjson current "$current" --arg value "$value" --argjson title "$title_px" --argjson body "$body_px" --argjson meta "$meta_px" --argjson nav "$nav_px" --argjson rail "$rail_px" \
    '$current + {schema_version:3,font_scale:$value,title_px:$title,body_px:$body,meta_px:$meta,nav_px:$nav,rail_px:$rail}' >"$tmp"
elif [[ "$key" == *_px ]]; then
  jq -nc --argjson current "$current" --arg key "$key" --argjson value "$value" '$current + {schema_version:3} + {($key):$value}' >"$tmp"
else
  jq -nc --argjson current "$current" --arg key "$key" --arg value "$value" '$current + {schema_version:3} + {($key):$value}' >"$tmp"
fi
chmod 600 "$tmp"
mv -f "$tmp" "$preferences"
trap - EXIT

publish_operation succeeded "Appearance applied" "${action#set-} was saved; the live listener has been notified." 100
