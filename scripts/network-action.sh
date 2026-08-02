#!/usr/bin/env bash

# Apply a small, validated NetworkManager action vocabulary.

set -euo pipefail
export LC_ALL=C
readonly NMCLI="${SENOMY_NMCLI_BIN:-/usr/bin/nmcli}"
readonly KITTY="${SENOMY_KITTY_BIN:-/usr/bin/kitty}"
readonly CONNECTION_EDITOR="${SENOMY_CONNECTION_EDITOR_BIN:-/usr/bin/nm-connection-editor}"
readonly XDG_OPEN="${SENOMY_XDG_OPEN_BIN:-/usr/bin/xdg-open}"
readonly EWW_BIN="${SENOMY_EWW_BIN:-/usr/bin/eww}"
readonly CONFIG_ROOT="${SENOMY_EWW_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/eww}"
readonly RUNTIME_ROOT="${XDG_RUNTIME_DIR:-/tmp}/senomyos"
readonly OPERATION_FILE="$RUNTIME_ROOT/network-operation.json"

fail() { printf 'SenomyOS network action: %s\n' "$1" >&2; exit 1; }

operation_label() {
  case "$1" in
    wifi-enable) printf 'Enabling Wi-Fi' ;;
    wifi-disable) printf 'Disabling Wi-Fi' ;;
    networking-enable) printf 'Enabling networking' ;;
    networking-disable) printf 'Disabling networking' ;;
    disconnect|deactivate-profile) printf 'Disconnecting network' ;;
    rescan) printf 'Refreshing access points' ;;
    activate-profile|connect-open) printf 'Connecting network' ;;
    connect-interactive) printf 'Opening secure authentication' ;;
    forget-profile) printf 'Forgetting saved network' ;;
    toggle-autoconnect) printf 'Updating autoconnect policy' ;;
    open-portal) printf 'Opening captive portal' ;;
    edit-profile) printf 'Opening profile editor' ;;
    create-profile) printf 'Opening network editor' ;;
    *) printf 'Network operation' ;;
  esac
}

write_operation() {
  local state="$1" action="$2" message="$3" exit_code="${4:-null}" temporary
  mkdir -p "$RUNTIME_ROOT"
  chmod 700 "$RUNTIME_ROOT"
  temporary="$(mktemp "$RUNTIME_ROOT/network-operation.XXXXXX")"
  jq -nc --arg state "$state" --arg action "$action" --arg label "$(operation_label "$action")" \
    --arg message "$message" --argjson at "$(date +%s)" --argjson exit_code "$exit_code" \
    '{schema_version:1,ok:true,source:"network-action",observed_at:$at,
      data:{state:$state,state_label:($state|ascii_upcase),action:$action,label:$label,
      message:$message,exit_code:$exit_code},error:null}' >"$temporary"
  chmod 600 "$temporary"
  mv -f "$temporary" "$OPERATION_FILE"
  "$EWW_BIN" --config "$CONFIG_ROOT" update "network_operation_status=$(cat "$OPERATION_FILE")" >/dev/null 2>&1 || true
}

refresh_network_status() {
  local status
  [[ -x "$CONFIG_ROOT/scripts/network-status.sh" ]] || return 0
  status="$("$CONFIG_ROOT/scripts/network-status.sh" 2>/dev/null)" || return 0
  jq -e . >/dev/null 2>&1 <<<"$status" || return 0
  "$EWW_BIN" --config "$CONFIG_ROOT" update "network_status=$status" >/dev/null 2>&1 || true
}

read_operation() {
  if [[ -s "$OPERATION_FILE" ]] && jq -e . "$OPERATION_FILE" >/dev/null 2>&1; then
    cat "$OPERATION_FILE"
  else
    jq -nc --argjson at "$(date +%s)" \
      '{schema_version:1,ok:true,source:"network-action",observed_at:$at,
        data:{state:"idle",state_label:"READY",action:"none",label:"Network control ready",
        message:"No network operation has run in this session.",exit_code:null},error:null}'
  fi
}

validate_uuid() {
  local uuid="$1"
  [[ "$uuid" =~ ^[[:xdigit:]]{8}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{12}$ ]] ||
    fail "invalid connection UUID"
  type="$("$NMCLI" -g connection.type connection show uuid "$uuid" 2>/dev/null)" ||
    fail "unknown connection profile"
  [[ "$type" == "802-11-wireless" || "$type" == "wifi" ]] ||
    fail "profile is not Wi-Fi"
}

validate_wifi_device() {
  local device="$1"
  [[ "$device" =~ ^[[:alnum:]_.:-]+$ ]] || fail "invalid device ID"
  type="$("$NMCLI" -g GENERAL.TYPE device show "$device" 2>/dev/null)" ||
    fail "unknown device"
  [[ "${type,,}" == *wifi* ]] || fail "device is not Wi-Fi"
}

perform_action() {
  local action="$1" device type bssid security_record security
  case "$action" in
  wifi-enable) [[ $# -eq 1 ]] || fail "unexpected arguments"; "$NMCLI" radio wifi on ;;
  wifi-disable) [[ $# -eq 1 ]] || fail "unexpected arguments"; "$NMCLI" radio wifi off ;;
  networking-enable) [[ $# -eq 1 ]] || fail "unexpected arguments"; "$NMCLI" networking on ;;
  networking-disable) [[ $# -eq 1 ]] || fail "unexpected arguments"; "$NMCLI" networking off ;;
  disconnect|rescan)
    [[ $# -eq 2 ]] || fail "$action requires one device"
    device="$2"
    [[ "$device" =~ ^[[:alnum:]_.:-]+$ ]] || fail "invalid device ID"
    type="$("$NMCLI" -g GENERAL.TYPE device show "$device" 2>/dev/null)" || fail "unknown device"
    if [[ "$action" == "rescan" ]]; then
      [[ "${type,,}" == *wifi* ]] || fail "device is not Wi-Fi"
      "$NMCLI" device wifi rescan ifname "$device"
    else
      "$NMCLI" device disconnect "$device"
    fi
    ;;
  activate-profile)
    [[ $# -eq 2 ]] || fail "activate-profile requires one UUID"
    validate_uuid "$2"
    "$NMCLI" connection up uuid "$2"
    ;;
  deactivate-profile)
    [[ $# -eq 2 ]] || fail "deactivate-profile requires one UUID"
    validate_uuid "$2"
    "$NMCLI" connection down uuid "$2"
    ;;
  forget-profile)
    [[ $# -eq 2 ]] || fail "forget-profile requires one UUID"
    validate_uuid "$2"
    "$NMCLI" connection delete uuid "$2"
    ;;
  toggle-autoconnect)
    [[ $# -eq 3 ]] || fail "toggle-autoconnect requires UUID and yes/no"
    validate_uuid "$2"
    [[ "$3" == "yes" || "$3" == "no" ]] || fail "autoconnect must be yes or no"
    "$NMCLI" connection modify uuid "$2" connection.autoconnect "$3"
    ;;
  connect-interactive)
    [[ $# -eq 3 ]] || fail "connect-interactive requires BSSID and device"
    bssid="${2^^}"
    device="$3"
    [[ "$bssid" =~ ^([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}$ ]] || fail "invalid BSSID"
    validate_wifi_device "$device"
    "$NMCLI" -t --escape no -f BSSID device wifi list --rescan no 2>/dev/null |
      grep -Fqx "$bssid" || fail "access point is not in the current cache"
    [[ -x "$KITTY" ]] || fail "kitty is unavailable for secure authentication"
    "$KITTY" --class senomy-network-auth --title "SenomyOS Network Authentication" \
      "$NMCLI" --ask device wifi connect "$bssid" ifname "$device" >/dev/null 2>&1 &
    ;;
  connect-open)
    [[ $# -eq 3 ]] || fail "connect-open requires BSSID and device"
    bssid="${2^^}"
    device="$3"
    [[ "$bssid" =~ ^([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}$ ]] || fail "invalid BSSID"
    validate_wifi_device "$device"
    security_record="$(
      "$NMCLI" -t --escape no -f BSSID,SECURITY device wifi list --rescan no 2>/dev/null |
        awk -F: -v target="$bssid" '
          $1 ":" $2 ":" $3 ":" $4 ":" $5 ":" $6 == target {
            sub(/^([^:]*:){6}/, "")
            print "FOUND:" $0
            exit
          }
        '
    )"
    [[ "$security_record" == FOUND:* ]] || fail "access point is not in the current cache"
    security="${security_record#FOUND:}"
    [[ -z "$security" || "$security" == "--" ]] || fail "access point is not open"
    "$NMCLI" device wifi connect "$bssid" ifname "$device"
    ;;
  open-portal)
    [[ $# -eq 1 ]] || fail "open-portal accepts no arguments"
    connectivity="$("$NMCLI" networking connectivity check 2>/dev/null || true)"
    [[ "$connectivity" != "full" ]] || fail "global connectivity is already available"
    [[ -x "$XDG_OPEN" ]] || fail "xdg-open is unavailable"
    "$XDG_OPEN" "http://neverssl.com/" >/dev/null 2>&1 &
    ;;
  edit-profile)
    [[ $# -eq 2 ]] || fail "edit-profile requires one UUID"
    validate_uuid "$2"
    [[ -x "$CONNECTION_EDITOR" ]] || fail "nm-connection-editor is unavailable"
    "$CONNECTION_EDITOR" --edit "$2" >/dev/null 2>&1 &
    ;;
  create-profile)
    [[ $# -eq 1 ]] || fail "create-profile accepts no arguments"
    [[ -x "$CONNECTION_EDITOR" ]] || fail "nm-connection-editor is unavailable"
    "$CONNECTION_EDITOR" --create --type wifi >/dev/null 2>&1 &
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
[[ -x "$NMCLI" ]] || fail "nmcli is unavailable"
[[ -n "$action" ]] || fail "an action is required"

write_operation "running" "$action" "$(operation_label "$action") is in progress."
set +e
output="$(perform_action "$@" 2>&1)"
exit_code=$?
set -e

if (( exit_code == 0 )); then
  write_operation "succeeded" "$action" "$(operation_label "$action") completed. Live state will confirm the result." 0
else
  message="${output##*$'\n'}"
  message="${message#SenomyOS network action: }"
  [[ -n "$message" ]] || message="$(operation_label "$action") failed."
  write_operation "failed" "$action" "$message" "$exit_code"
fi

refresh_network_status

[[ -z "$output" ]] || printf '%s\n' "$output"
exit "$exit_code"
