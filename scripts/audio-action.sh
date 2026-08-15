#!/usr/bin/env bash

# Apply only validated audio endpoint actions.

set -euo pipefail
export LC_ALL=C
readonly PACTL="${SENOMY_PACTL_BIN:-/usr/bin/pactl}"
readonly EWW_BIN="${SENOMY_EWW_BIN:-/usr/bin/eww}"
readonly CONFIG_ROOT="${SENOMY_EWW_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/eww}"
readonly RUNTIME_ROOT="${XDG_RUNTIME_DIR:-/tmp}/senomyos"
readonly OPERATION_FILE="$RUNTIME_ROOT/audio-operation.json"

fail() { printf 'SenomyOS audio action: %s\n' "$1" >&2; exit 1; }

operation_label() {
  case "$1" in
    toggle-input-mute) printf 'Changing microphone mute' ;;
    set-default-output) printf 'Selecting default output' ;;
    set-default-input) printf 'Selecting default input' ;;
    set-output-port) printf 'Routing output port' ;;
    set-input-port) printf 'Routing input port' ;;
    set-card-profile) printf 'Applying hardware profile' ;;
    *) printf 'Audio operation' ;;
  esac
}

write_operation() {
  local state="$1" action="$2" message="$3" exit_code="${4:-null}" temporary
  mkdir -p "$RUNTIME_ROOT"
  chmod 700 "$RUNTIME_ROOT"
  temporary="$(mktemp "$RUNTIME_ROOT/audio-operation.XXXXXX")"
  jq -nc --arg state "$state" --arg action "$action" --arg label "$(operation_label "$action")" \
    --arg message "$message" --argjson at "$(date +%s)" --argjson exit_code "$exit_code" \
    '{schema_version:1,ok:true,source:"audio-action",observed_at:$at,
      data:{state:$state,state_label:($state|ascii_upcase),action:$action,label:$label,
      message:$message,exit_code:$exit_code},error:null}' >"$temporary"
  chmod 600 "$temporary"
  mv -f "$temporary" "$OPERATION_FILE"
  "$EWW_BIN" --no-daemonize --config "$CONFIG_ROOT" update "audio_operation_status=$(cat "$OPERATION_FILE")" >/dev/null 2>&1 || true
}

read_operation() {
  if [[ -s "$OPERATION_FILE" ]] && jq -e . "$OPERATION_FILE" >/dev/null 2>&1; then
    cat "$OPERATION_FILE"
  else
    jq -nc --argjson at "$(date +%s)" \
      '{schema_version:1,ok:true,source:"audio-action",observed_at:$at,
        data:{state:"idle",state_label:"READY",action:"none",label:"Audio control ready",
        message:"No discrete audio operation has run in this session.",exit_code:null},error:null}'
  fi
}

refresh_audio_status() {
  local status
  [[ -x "$CONFIG_ROOT/scripts/audio-status.sh" ]] || return 0
  status="$("$CONFIG_ROOT/scripts/audio-status.sh" 2>/dev/null)" || return 0
  jq -e . >/dev/null 2>&1 <<<"$status" || return 0
  "$EWW_BIN" --no-daemonize --config "$CONFIG_ROOT" update "audio_status=$status" >/dev/null 2>&1 || true
}

perform_action() {
  local action="$1" id port profile
  case "$action" in
  toggle-input-mute)
    [[ $# -eq 1 ]] || fail "toggle-input-mute accepts no arguments"
    "$PACTL" set-source-mute @DEFAULT_SOURCE@ toggle
    ;;
  set-default-output|set-default-input)
    [[ $# -eq 2 ]] || fail "$action requires one endpoint ID"
    id="$2"
    if [[ "$action" == "set-default-output" ]]; then
      "$PACTL" -f json list sinks | jq -e --arg id "$id" 'any(.name == $id)' >/dev/null ||
        fail "unknown output"
      "$PACTL" set-default-sink "$id"
    else
      "$PACTL" -f json list sources | jq -e --arg id "$id" \
        'any(.name == $id and (.monitor_source // false) != true)' >/dev/null ||
        fail "unknown input"
      "$PACTL" set-default-source "$id"
    fi
    ;;
  set-output-port|set-input-port)
    [[ $# -eq 3 ]] || fail "$action requires endpoint and port IDs"
    id="$2"; port="$3"
    if [[ "$action" == "set-output-port" ]]; then
      "$PACTL" -f json list sinks | jq -e --arg id "$id" --arg port "$port" \
        'any(.name == $id and any(.ports[]?; .name == $port))' >/dev/null || fail "invalid output port"
      "$PACTL" set-sink-port "$id" "$port"
    else
      "$PACTL" -f json list sources | jq -e --arg id "$id" --arg port "$port" \
        'any(.name == $id and any(.ports[]?; .name == $port))' >/dev/null || fail "invalid input port"
      "$PACTL" set-source-port "$id" "$port"
    fi
    ;;
  set-card-profile)
    [[ $# -eq 3 ]] || fail "set-card-profile requires card and profile IDs"
    id="$2"; profile="$3"
    "$PACTL" -f json list cards | jq -e --arg id "$id" --arg profile "$profile" '
      any(.[]; .name == $id and any(.profiles[]?; .name == $profile and .available != false))
    ' >/dev/null || fail "invalid or unavailable hardware profile"
    "$PACTL" set-card-profile "$id" "$profile"
    ;;
    *) fail "unknown action" ;;
  esac
}

action="${1:-}"
if [[ "$action" == "status" ]]; then
  [[ $# -eq 1 ]] || fail "status accepts no arguments"
  read_operation
  exit 0
fi

command -v jq >/dev/null 2>&1 || fail "jq is unavailable"
[[ -x "$PACTL" ]] || fail "pactl is unavailable"
[[ -n "$action" ]] || fail "an action is required"

write_operation "running" "$action" "$(operation_label "$action") is in progress."
set +e
output="$(perform_action "$@" 2>&1)"
exit_code=$?
set -e

if (( exit_code == 0 )); then
  write_operation "succeeded" "$action" "$(operation_label "$action") completed. Live PipeWire state confirms the result." 0
else
  message="${output##*$'\n'}"
  message="${message#SenomyOS audio action: }"
  [[ -n "$message" ]] || message="$(operation_label "$action") failed."
  write_operation "failed" "$action" "$message" "$exit_code"
fi

refresh_audio_status
[[ -z "$output" ]] || printf '%s\n' "$output"
exit "$exit_code"
