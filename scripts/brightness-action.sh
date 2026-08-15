#!/usr/bin/env bash

# Apply bounded display-brightness presets through brightnessctl's discovered
# default backlight device. No machine-specific sysfs path is accepted.
set -euo pipefail
export LC_ALL=C

readonly ACTION="${1:-status}"
readonly VALUE="${2:-}"
readonly BRIGHTNESSCTL="${SENOMY_BRIGHTNESSCTL_BIN:-/usr/bin/brightnessctl}"
readonly EWW_BIN="${SENOMY_EWW_BIN:-/usr/bin/eww}"
readonly CONFIG_ROOT="${SENOMY_EWW_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/eww}"
readonly RUNTIME_ROOT="${XDG_RUNTIME_DIR:-/tmp}/senomyos"
readonly OPERATION_FILE="$RUNTIME_ROOT/brightness-operation.json"

fail() { printf 'SenomyOS brightness action: %s\n' "$1" >&2; exit 1; }

write_operation() {
  local state="$1" message="$2" exit_code="${3:-null}" temporary
  mkdir -p -m 700 "$RUNTIME_ROOT"
  temporary="$(mktemp "$RUNTIME_ROOT/brightness-operation.XXXXXX")"
  jq -nc --arg state "$state" --arg action "$ACTION" --arg message "$message" \
    --argjson value "${VALUE:-null}" --argjson at "$(date +%s)" --argjson exit_code "$exit_code" \
    '{schema_version:1,ok:true,source:"brightness-action",observed_at:$at,
      data:{state:$state,state_label:($state|ascii_upcase),action:$action,
      label:(if $action=="set" then "DISPLAY BRIGHTNESS // \($value)%" else "DISPLAY BRIGHTNESS" end),
      message:$message,exit_code:$exit_code},error:null}' >"$temporary"
  chmod 600 "$temporary"
  mv -f "$temporary" "$OPERATION_FILE"
  "$EWW_BIN" --no-daemonize --config "$CONFIG_ROOT" update "brightness_operation_status=$(cat "$OPERATION_FILE")" >/dev/null 2>&1 || true
}

read_operation() {
  if [[ -s "$OPERATION_FILE" ]] && jq -e . "$OPERATION_FILE" >/dev/null 2>&1; then
    cat "$OPERATION_FILE"
  else
    jq -nc --argjson at "$(date +%s)" '{schema_version:1,ok:true,source:"brightness-action",observed_at:$at,
      data:{state:"idle",state_label:"READY",action:"none",label:"DISPLAY BRIGHTNESS",
      message:"No brightness operation has run in this session.",exit_code:null},error:null}'
  fi
}

command -v jq >/dev/null 2>&1 || fail "jq is unavailable"
if [[ "$ACTION" == status ]]; then
  [[ $# -eq 1 ]] || fail "status accepts no arguments"
  read_operation
  exit 0
fi

[[ "$ACTION" == set && $# -eq 2 ]] || fail "Usage: brightness-action.sh set {25|50|75|100}"
case "$VALUE" in 25 | 50 | 75 | 100) ;; *) fail "brightness preset is not allowlisted" ;; esac
[[ -x "$BRIGHTNESSCTL" ]] || fail "brightnessctl is unavailable"

write_operation running "Applying the selected backlight preset."
set +e
output="$("$BRIGHTNESSCTL" set "${VALUE}%" 2>&1)"
exit_code=$?
set -e
if ((exit_code == 0)); then
  write_operation succeeded "Backlight brightness is now ${VALUE}%." 0
else
  message="${output##*$'\n'}"
  [[ -n "$message" ]] || message="The backlight rejected the brightness preset."
  write_operation failed "$message" "$exit_code"
fi

if [[ -x "$CONFIG_ROOT/scripts/control-status.sh" ]]; then
  status="$("$CONFIG_ROOT/scripts/control-status.sh" 2>/dev/null || true)"
  jq -e . >/dev/null 2>&1 <<<"$status" &&
    "$EWW_BIN" --no-daemonize --config "$CONFIG_ROOT" update "control_status=$status" >/dev/null 2>&1 || true
fi
exit "$exit_code"
