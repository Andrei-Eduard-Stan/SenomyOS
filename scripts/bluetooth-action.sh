#!/usr/bin/env bash

# Validated state-changing BlueZ actions. Widget-provided text is never passed
# to a shell; only fixed actions and strict Bluetooth MAC addresses are accepted.
set -u
export LC_ALL=C

readonly ACTION="${1:-help}"
readonly TARGET="${2:-none}"
readonly HOME_DIR="${HOME:-/nonexistent}"
readonly CONFIG_DIR="${EWW_CONFIG:-${XDG_CONFIG_HOME:-$HOME_DIR/.config}/eww}"
readonly CACHE_FILE="${SENOMY_BLUETOOTH_CACHE:-${XDG_RUNTIME_DIR:-/tmp}/senomyos/bluetooth-action.json}"
readonly CACHE_DIR="$(dirname "$CACHE_FILE")"
readonly LOCK_FILE="$CACHE_FILE.lock"

valid_address() { [[ "$1" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]]; }
needs_address() { case "$1" in pair | connect | disconnect | forget | trust | untrust) return 0 ;; *) return 1 ;; esac; }

write_state() {
  local state="$1" label="$2" message="$3" code="${4:-none}" tmp
  mkdir -p -m 700 "$CACHE_DIR" || return 1
  tmp="$(mktemp "$CACHE_DIR/.bluetooth.XXXXXX")" || return 1
  jq -nc --arg state "$state" --arg label "$label" --arg operation "$ACTION" \
    --arg target "${TARGET^^}" --arg message "$message" --arg code "$code" --argjson at "$(date +%s)" \
    '{state:$state,state_label:$label,operation:$operation,target:$target,message:$message,code:$code,finished_at:$at}' >"$tmp"
  chmod 600 "$tmp"; mv "$tmp" "$CACHE_FILE"
}

command -v jq >/dev/null 2>&1 && command -v bluetoothctl >/dev/null 2>&1 && command -v flock >/dev/null 2>&1 || exit 3
needs_address "$ACTION" && ! valid_address "$TARGET" && exit 2
mkdir -p -m 700 "$CACHE_DIR" || exit 1
exec 9>"$LOCK_FILE"; flock -w 2 9 || exit 1
write_state running WORKING "Bluetooth operation is in progress."
trap 'write_state failed INTERRUPTED "Bluetooth operation was interrupted; no connection was claimed." interrupted; exit 130' HUP INT TERM

device_field() {
  timeout 5s bluetoothctl info "${TARGET^^}" 2>/dev/null | sed -n "s/^[[:space:]]*$1: //p" | head -n1
}

wait_for_field() {
  local field="$1" expected="$2" attempts="${3:-12}" value
  while ((attempts-- > 0)); do
    value="$(device_field "$field")"
    [[ "$value" == "$expected" ]] && return 0
    sleep 0.5
  done
  return 1
}

run_step() {
  local seconds="$1"; shift
  output="$(timeout "$seconds" bluetoothctl "$@" 2>&1)" || status=$?
}

output='' status=0
case "$ACTION" in
  power-on) run_step 8s power on ;;
  power-off) output="$(timeout 8s bluetoothctl power off 2>&1)" || status=$? ;;
  scan) output="$(timeout 14s bluetoothctl --timeout 12 scan on 2>&1)" || status=$?; [[ "$status" == 124 ]] && status=0 ;;
  pair)
    # Audio accessories normally use Just Works. Pairing is only complete when
    # BlueZ reports Paired=yes, Trusted=yes and Connected=yes afterward.
    run_step 8s power on
    ((status == 0)) && run_step 8s pairable on
    ((status == 0)) && run_step 42s --timeout 35 --agent NoInputNoOutput pair "${TARGET^^}"
    if ((status == 0)) && ! wait_for_field Paired yes 16; then status=1; fi
    ((status == 0)) && run_step 10s trust "${TARGET^^}"
    if ((status == 0)) && ! wait_for_field Trusted yes 10; then status=1; fi
    if ((status == 0)) && ! wait_for_field Connected yes 4; then
      run_step 22s --timeout 18 connect "${TARGET^^}"
    fi
    if ((status == 0)) && ! wait_for_field Connected yes 20; then status=1; fi
    ;;
  connect)
    run_step 22s --timeout 18 connect "${TARGET^^}"
    if ((status != 0)) || ! wait_for_field Connected yes 4; then
      status=0
      # A short discovery pass wakes accessories that stopped advertising
      # immediately after pairing or moved back to another multipoint peer.
      run_step 10s --timeout 8 scan on
      status=0
      run_step 22s --timeout 18 connect "${TARGET^^}"
    fi
    if ((status == 0)) && ! wait_for_field Connected yes 20; then status=1; fi
    ;;
  disconnect) output="$(timeout 15s bluetoothctl --timeout 10 disconnect "${TARGET^^}" 2>&1)" || status=$? ;;
  trust) output="$(timeout 10s bluetoothctl trust "${TARGET^^}" 2>&1)" || status=$? ;;
  untrust) output="$(timeout 10s bluetoothctl untrust "${TARGET^^}" 2>&1)" || status=$? ;;
  forget) output="$(timeout 15s bluetoothctl remove "${TARGET^^}" 2>&1)" || status=$? ;;
  clear) write_state idle READY "Bluetooth controls are ready."; exit 0 ;;
  *) exit 2 ;;
esac

message="$(printf '%s' "$output" | tail -n 1 | sed $'s/\033\\[[0-9;]*[[:alpha:]]//g' | tr -cd '[:print:]' | sed -E 's/([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}/device/g' | cut -c1-180)"
if ((status == 0)); then
  case "$ACTION" in
    pair) message="Paired, trusted, and connected. Audio services are ready." ;;
    connect) message="Connection verified by BlueZ." ;;
    *) [[ -n "$message" ]] || message="Bluetooth operation completed." ;;
  esac
  write_state succeeded COMPLETE "$message"
  "$CONFIG_DIR/scripts/senomy-event.sh" record bluetooth "$ACTION" device succeeded >/dev/null 2>&1 || true
else
  if [[ "$ACTION" == pair || "$ACTION" == connect ]]; then
    paired="$(device_field Paired)"; connected="$(device_field Connected)"
    if [[ "$output" == *"br-connection-page-timeout"* ]]; then
      message="The device did not answer BlueZ. Keep it awake/in pairing mode and ensure a multipoint slot is free, then retry."
    else
      message="BlueZ did not verify the connection (paired: ${paired:-unknown}, connected: ${connected:-unknown}). Keep the device in pairing mode and retry."
    fi
  else
    [[ -n "$message" ]] || message="Bluetooth operation failed."
  fi
  write_state failed FAILED "$message" "exit-$status"
  "$CONFIG_DIR/scripts/senomy-event.sh" record bluetooth "$ACTION" device failed >/dev/null 2>&1 || true
fi
exit "$status"
