#!/usr/bin/env bash

# Install or inspect the narrow SwayNC hook that forwards notification metadata
# to SenomyOS. Installation preserves the rest of the user's SwayNC config and
# creates a private timestamped backup when one already exists.
set -euo pipefail
export LC_ALL=C
umask 077

readonly ACTION="${1:-status}"
readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly USER_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/swaync/config.json"
readonly SYSTEM_CONFIG="/etc/xdg/swaync/config.json"
readonly COMMAND="$SCRIPT_DIR/notification-history.sh capture"

fail() {
  printf 'SenomyOS SwayNC integration: %s\n' "$*" >&2
  exit 1
}

emit_status() {
  local installed=false config_available=false
  [[ -r "$USER_CONFIG" ]] && config_available=true
  if [[ "$config_available" == true ]] && jq -e --arg command "$COMMAND" '
      .scripts["senomy-history"]
      | .exec == $command and .["app-name"] == ".*" and .["run-on"] == "receive"
    ' "$USER_CONFIG" >/dev/null 2>&1; then
    installed=true
  fi
  jq -nc --arg path "$USER_CONFIG" --arg command "$COMMAND" \
    --argjson config_available "$config_available" --argjson installed "$installed" '
      {schema_version:1,ok:true,source:"swaync-integration",data:{
        installed:$installed,config_available:$config_available,path:$path,command:$command
      },error:null}
    '
}

install_hook() {
  local source temporary backup
  command -v jq >/dev/null 2>&1 || fail "jq is required"
  [[ -x "$SCRIPT_DIR/notification-history.sh" ]] ||
    fail "notification-history.sh is not executable"

  if [[ -r "$USER_CONFIG" ]]; then
    jq -e . "$USER_CONFIG" >/dev/null 2>&1 || fail "existing SwayNC config is invalid JSON"
    source="$USER_CONFIG"
  else
    [[ -r "$SYSTEM_CONFIG" ]] || fail "SwayNC system config is unavailable"
    source="$SYSTEM_CONFIG"
  fi

  install -d -m 700 "$(dirname "$USER_CONFIG")"
  if [[ -e "$USER_CONFIG" ]]; then
    backup="${USER_CONFIG}.senomy-backup-$(date +%Y%m%d-%H%M%S)"
    install -m 600 "$USER_CONFIG" "$backup"
    printf 'Existing SwayNC config backed up to %s\n' "$backup" >&2
  fi

  temporary="$(mktemp "$(dirname "$USER_CONFIG")/.config.XXXXXX")"
  jq --arg command "$COMMAND" '
    .scripts = (.scripts // {})
    | .scripts["senomy-history"] = {
        "exec": $command,
        "app-name": ".*",
        "run-on": "receive"
      }
  ' "$source" >"$temporary"
  jq -e . "$temporary" >/dev/null
  chmod 600 "$temporary"
  mv -f "$temporary" "$USER_CONFIG"
  emit_status
}

remove_hook() {
  local temporary
  [[ -r "$USER_CONFIG" ]] || { emit_status; return; }
  temporary="$(mktemp "$(dirname "$USER_CONFIG")/.config.XXXXXX")"
  jq 'del(.scripts["senomy-history"])' "$USER_CONFIG" >"$temporary"
  chmod 600 "$temporary"
  mv -f "$temporary" "$USER_CONFIG"
  emit_status
}

case "$ACTION" in
  status) emit_status ;;
  install) install_hook ;;
  remove) remove_hook ;;
  *) fail "usage: swaync-history-integration.sh [status|install|remove]" ;;
esac
