#!/usr/bin/env bash

# Apply only allowlisted TLP power profiles through explicit authorization.

set -u

export LC_ALL=C

readonly ACTION="${1:-}"
readonly TLP_BIN="${SENOMY_TLP_BIN:-/usr/bin/tlp}"
readonly PKEXEC_BIN="${SENOMY_PKEXEC_BIN:-/usr/bin/pkexec}"
readonly EWW_BIN="${SENOMY_EWW_BIN:-/usr/bin/eww}"
readonly CONFIG_ROOT="${SENOMY_EWW_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/eww}"
readonly RUNTIME_ROOT="${XDG_RUNTIME_DIR:-/tmp}/senomyos"
readonly OPERATION_FILE="$RUNTIME_ROOT/power-operation.json"

fail() {
  printf 'SenomyOS power action: %s\n' "$1" >&2
  exit 1
}

write_operation() {
  local state="$1" message="$2" exit_code="${3:-null}" temporary
  mkdir -p "$RUNTIME_ROOT" || return 1
  chmod 700 "$RUNTIME_ROOT"
  temporary="$(mktemp "$RUNTIME_ROOT/power-operation.XXXXXX")" || return 1
  jq -nc --arg state "$state" --arg action "$ACTION" --arg message "$message" \
    --argjson at "$(date +%s)" --argjson exit_code "$exit_code" \
    '{schema_version:1,ok:true,source:"power-action",observed_at:$at,
      data:{state:$state,state_label:($state|ascii_upcase),action:$action,
      label:(if $action=="power-saver" then "Applying Power Saver" elif $action=="balanced" then "Applying Balanced" elif $action=="performance" then "Applying Performance" else "Power control ready" end),
      message:$message,exit_code:$exit_code},error:null}' >"$temporary"
  chmod 600 "$temporary"
  mv -f "$temporary" "$OPERATION_FILE"
  "$EWW_BIN" --config "$CONFIG_ROOT" update "power_operation_status=$(cat "$OPERATION_FILE")" >/dev/null 2>&1 || true
}

read_operation() {
  if [[ -s "$OPERATION_FILE" ]] && jq -e . "$OPERATION_FILE" >/dev/null 2>&1; then
    cat "$OPERATION_FILE"
  else
    jq -nc --argjson at "$(date +%s)" \
      '{schema_version:1,ok:true,source:"power-action",observed_at:$at,
        data:{state:"idle",state_label:"READY",action:"none",label:"Power control ready",
        message:"No power profile operation has run in this session.",exit_code:null},error:null}'
  fi
}

refresh_power_status() {
  local status
  [[ -x "$CONFIG_ROOT/scripts/power-status.sh" ]] || return 0
  status="$("$CONFIG_ROOT/scripts/power-status.sh" 2>/dev/null)" || return 0
  jq -e . >/dev/null 2>&1 <<<"$status" || return 0
  "$EWW_BIN" --config "$CONFIG_ROOT" update "power_status=$status" >/dev/null 2>&1 || true
}

command -v jq >/dev/null 2>&1 || fail "jq is unavailable"

if [[ "$ACTION" == "status" ]]; then
  [[ $# -eq 1 ]] || fail "status accepts no arguments"
  read_operation
  exit 0
fi

case "$ACTION" in
  performance | balanced | power-saver) ;;
  *) fail "Usage: power-action.sh {power-saver|balanced|performance|status}" ;;
esac

[[ -x "$TLP_BIN" ]] ||
  fail "TLP is unavailable"
[[ -x "$PKEXEC_BIN" ]] ||
  fail "pkexec is unavailable"

write_operation running "Waiting for authorization and TLP profile application."
output="$("$PKEXEC_BIN" "$TLP_BIN" "$ACTION" 2>&1)"
exit_code=$?

if ((exit_code == 0)); then
  write_operation succeeded "TLP accepted the profile. Live policy telemetry confirms the effective state." 0
else
  message="${output##*$'\n'}"
  [[ -n "$message" ]] || message="Authorization was cancelled or TLP rejected the profile."
  write_operation failed "$message" "$exit_code"
fi

refresh_power_status
[[ -z "$output" ]] || printf '%s\n' "$output"
exit "$exit_code"
