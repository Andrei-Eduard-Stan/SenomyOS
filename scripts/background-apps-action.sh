#!/usr/bin/env bash

# Execute only explicitly supported actions for managed background applications.

set -u

readonly FLAMESHOT_BIN="/usr/bin/flameshot"
readonly FLAMESHOT_UNIT="flameshot.service"
readonly FLAMESHOT_BUS="org.flameshot.Flameshot"
readonly SCREENSHOT_ACTION="$HOME/.config/eww/scripts/screenshot-action.sh"
readonly CACHE_FILE="${SENOMY_BACKGROUND_APPS_CACHE:-${XDG_RUNTIME_DIR:-/tmp}/senomyos/background-apps-operation.json}"
readonly CACHE_DIR="$(dirname "$CACHE_FILE")"

fail() {
  printf 'SenomyOS background applications: %s\n' "$1" >&2
  exit 1
}

usage() {
  printf 'Usage: %s flameshot {start|capture|launcher|configure|stop}\n' "$0" >&2
  exit 2
}

write_state() {
  local state="$1" message="$2" exit_code="${3:-null}" temporary
  mkdir -p "$CACHE_DIR" || return 1
  chmod 700 "$CACHE_DIR"
  temporary="$(mktemp "$CACHE_DIR/background-apps.XXXXXX")" || return 1
  jq -nc --arg state "$state" --arg app "$app" --arg action "$action" --arg message "$message" \
    --argjson at "$(date +%s)" --argjson exit_code "$exit_code" \
    '{state:$state,state_label:($state|ascii_upcase),app:$app,action:$action,
      label:((($action|ascii_upcase) + " // " + ($app|ascii_upcase))),message:$message,
      exit_code:$exit_code,finished_at:$at}' >"$temporary"
  chmod 600 "$temporary"
  mv -f "$temporary" "$CACHE_FILE"
}

[[ $# -eq 2 ]] || usage

app="$1"
action="$2"

[[ "$app" == "flameshot" ]] || fail "Application is not allowlisted: $app"
[[ -x "$FLAMESHOT_BIN" ]] || fail "Flameshot is unavailable"
command -v systemctl >/dev/null 2>&1 ||
  fail "systemctl is unavailable"
command -v jq >/dev/null 2>&1 || fail "jq is unavailable"

flameshot_dbus_ready() {
  command -v busctl >/dev/null 2>&1 &&
    busctl --user list --no-legend --no-pager 2>/dev/null |
      awk '{print $1}' |
      grep -Fxq "$FLAMESHOT_BUS"
}

ensure_flameshot() {
  flameshot_dbus_ready && return 0
  systemctl --user start "$FLAMESHOT_UNIT" ||
    fail "Unable to start $FLAMESHOT_UNIT"
}

write_state running "Application operation is in progress."
output=""
status=0
case "$action" in
  start)
    output="$(ensure_flameshot 2>&1)" || status=$?
    ;;
  capture)
    if [[ -x "$SCREENSHOT_ACTION" ]]; then
      output="$("$SCREENSHOT_ACTION" capture 2>&1)" || status=$?
    else
      output="Screenshot action is unavailable"
      status=1
    fi
    ;;
  launcher)
    output="$(ensure_flameshot 2>&1)" || status=$?
    ((status != 0)) || output="$("$FLAMESHOT_BIN" launcher 2>&1)" || status=$?
    ;;
  configure)
    output="$(ensure_flameshot 2>&1)" || status=$?
    ((status != 0)) || output="$("$FLAMESHOT_BIN" config 2>&1)" || status=$?
    ;;
  stop)
    output="$(systemctl --user stop "$FLAMESHOT_UNIT" 2>&1)" || status=$?
    ;;
  *)
    usage
    ;;
esac

if ((status == 0)); then
  write_state succeeded "The application request completed. Live service and tray state will confirm availability." 0
else
  message="${output##*$'\n'}"
  message="${message#SenomyOS background applications: }"
  [[ -n "$message" ]] || message="The application request failed."
  write_state failed "$message" "$status"
fi

[[ -z "$output" ]] || printf '%s\n' "$output"
exit "$status"
