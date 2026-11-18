#!/usr/bin/env bash

set -euo pipefail
export LC_ALL=C
fail(){ printf 'SenomyOS performance action: %s\n' "$1" >&2; exit 1; }
action="${1:-}"
readonly RUNTIME_ROOT="${XDG_RUNTIME_DIR:-/tmp}/senomyos"
readonly OPERATION_FILE="$RUNTIME_ROOT/performance-operation.json"

write_operation() {
  local state="$1" message="$2" exit_code="${3:-null}" temporary
  mkdir -p -m 700 "$RUNTIME_ROOT"
  temporary="$(mktemp "$RUNTIME_ROOT/performance-operation.XXXXXX")"
  jq -nc --arg state "$state" --arg action "$action" --arg message "$message" \
    --argjson at "$(date +%s)" --argjson exit_code "$exit_code" \
    '{schema_version:1,ok:true,source:"performance-action",observed_at:$at,
      data:{state:$state,state_label:($state|ascii_upcase),action:$action,
      label:(($action|gsub("-";" ")|ascii_upcase)),message:$message,exit_code:$exit_code},error:null}' >"$temporary"
  chmod 600 "$temporary"
  mv -f "$temporary" "$OPERATION_FILE"
}

read_operation() {
  if [[ -s "$OPERATION_FILE" ]] && jq -e . "$OPERATION_FILE" >/dev/null 2>&1; then
    cat "$OPERATION_FILE"
  else
    jq -nc --argjson at "$(date +%s)" '{schema_version:1,ok:true,source:"performance-action",observed_at:$at,
      data:{state:"idle",state_label:"READY",action:"none",label:"PERFORMANCE CONTROL READY",
      message:"No performance operation has run in this session.",exit_code:null},error:null}'
  fi
}

validate_pid(){
  [[ "${1:-}" =~ ^[1-9][0-9]*$ ]] || fail "invalid PID"
  [[ -d "/proc/$1" ]] || fail "process no longer exists"
  owner="$(stat -c %u "/proc/$1")"
  [[ "$owner" == "$(id -u)" ]] || fail "process is not owned by the current user"
  [[ "$1" != "$$" && "$1" != "$PPID" && "$1" != 1 ]] || fail "refusing to signal a protected process"
  local comm
  read -r comm <"/proc/$1/comm" || fail "process no longer exists"
  case "$comm" in Hyprland|quickshell|qs|systemd) fail "desktop/session core processes are protected" ;; esac
}

validate_process_identity(){
  local pid="$1" expected_start="$2" stat_line stat_tail
  [[ "$expected_start" =~ ^[0-9]+$ ]] || fail "invalid process identity"
  validate_pid "$pid"
  read -r stat_line <"/proc/$pid/stat" || fail "unable to read process identity"
  stat_tail="${stat_line##*) }"
  read -ra stat_fields <<< "$stat_tail"
  ((${#stat_fields[@]} >= 20)) || fail "unable to parse process identity"
  [[ "${stat_fields[19]}" == "$expected_start" ]] || fail "process identity changed"
}

perform_action() {
case "$action" in
  terminate-exact|kill-exact|stop-exact|continue-exact)
    [[ $# -eq 3 ]] || fail "$action requires one PID and start time"
    validate_process_identity "$2" "$3"
    case "$action" in
      terminate-exact) kill -TERM "$2" ;;
      kill-exact) kill -KILL "$2" ;;
      stop-exact) kill -STOP "$2" ;;
      continue-exact) kill -CONT "$2" ;;
    esac
    ;;
  terminate|kill)
    [[ $# -eq 2 ]] || fail "$action requires one PID"
    validate_pid "$2"
    if [[ "$action" == terminate ]]; then kill -TERM "$2"; else kill -KILL "$2"; fi
    ;;
  restart-user-unit)
    [[ $# -eq 2 ]] || fail "restart-user-unit requires one unit"
    unit="$2"
    [[ "$unit" =~ ^[A-Za-z0-9_.@:-]+\.(service|socket|timer|path|mount)$ ]] || fail "invalid unit"
    systemctl --user --failed --no-legend --plain | awk '{print $1}' | grep -Fqx "$unit" || fail "unit is not currently failed"
    systemctl --user restart "$unit"
    ;;
  set-sort)
    [[ $# -eq 2 ]] || fail "set-sort requires one mode"
    [[ "$2" == cpu || "$2" == memory || "$2" == name ]] || fail "invalid sort mode"
    runtime="${XDG_RUNTIME_DIR:-/tmp}/senomyos"
    mkdir -p -m 700 "$runtime"
    printf '%s\n' "$2" >"$runtime/performance-process-sort"
    chmod 600 "$runtime/performance-process-sort"
    ;;
  set-selection)
    [[ $# -eq 2 ]] || fail "set-selection requires one PID"
    [[ "$2" =~ ^[0-9]+$ ]] || fail "invalid PID"
    if [[ "$2" != 0 ]]; then
      [[ -d "/proc/$2" ]] || fail "process no longer exists"
    fi
    runtime="${XDG_RUNTIME_DIR:-/tmp}/senomyos"
    mkdir -p -m 700 "$runtime"
    printf '%s\n' "$2" >"$runtime/performance-process-selection"
    chmod 600 "$runtime/performance-process-selection"
    ;;
  set-filter)
    [[ $# -eq 2 ]] || fail "set-filter requires one mode"
    [[ "$2" == all || "$2" == user || "$2" == active || "$2" == heavy ]] || fail "invalid filter mode"
    runtime="${XDG_RUNTIME_DIR:-/tmp}/senomyos"
    mkdir -p -m 700 "$runtime"
    printf '%s\n' "$2" >"$runtime/performance-process-filter"
    chmod 600 "$runtime/performance-process-filter"
    ;;
  *) fail "unknown action";;
esac
}

command -v jq >/dev/null 2>&1 || fail "jq is unavailable"
if [[ "$action" == status ]]; then
  [[ $# -eq 1 ]] || fail "status accepts no arguments"
  read_operation
  exit 0
fi
[[ -n "$action" ]] || fail "an action is required"

write_operation running "The validated performance operation is in progress."
set +e
output="$(perform_action "$@" 2>&1)"
exit_code=$?
set -e
if ((exit_code == 0)); then
  write_operation succeeded "The operation completed; live process and service telemetry will confirm the result." 0
else
  message="${output##*$'\n'}"
  message="${message#SenomyOS performance action: }"
  [[ -n "$message" ]] || message="The performance operation failed."
  write_operation failed "$message" "$exit_code"
fi
[[ -z "$output" ]] || printf '%s\n' "$output"
exit "$exit_code"
