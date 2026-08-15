#!/usr/bin/env bash

# Own the single Senomy companion window without joining the primary-surface
# state machine. The companion is an optional overlay, not a fourth panel.

set -u

export LC_ALL=C

readonly ACTION="${1:-status}"
readonly VALUE="${2:-}"
readonly USER_HOME="${HOME:-/nonexistent}"
readonly EWW_BIN="${EWW_BIN:-/usr/bin/eww}"
readonly HYPRCTL_BIN="${SENOMY_HYPRCTL_BIN:-/usr/bin/hyprctl}"
readonly EWW_CONFIG="${EWW_CONFIG:-${XDG_CONFIG_HOME:-$USER_HOME/.config}/eww}"
readonly TIMEOUT_BIN="${SENOMY_TIMEOUT_BIN:-/usr/bin/timeout}"
readonly SETSID_BIN="${SENOMY_SETSID_BIN:-/usr/bin/setsid}"
readonly RUNTIME_ROOT="${SENOMY_COMPANION_RUNTIME_DIR:-${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/senomyos}"
readonly LOCK_FILE="$RUNTIME_ROOT/companion-state.lock"
readonly EXPIRY_FILE="$RUNTIME_ROOT/companion-expiry.token"
readonly WINDOW="companion"
readonly CLIENT_TIMEOUT="${SENOMY_COMPANION_CLIENT_TIMEOUT:-8s}"
readonly EXPANDED_SECONDS="${SENOMY_COMPANION_EXPANDED_SECONDS:-30}"

fail() {
  printf 'SenomyOS companion: %s\n' "$1" >&2
  exit 1
}

is_mode() { case "$1" in closed | expanded | compact) return 0 ;; *) return 1 ;; esac; }
is_dock() { case "$1" in left | right) return 0 ;; *) return 1 ;; esac; }
is_boolean() { [[ "$1" == true || "$1" == false ]]; }

eww_call() {
  "$TIMEOUT_BIN" --foreground --kill-after=1s "$CLIENT_TIMEOUT" \
    "$EWW_BIN" --no-daemonize --config "$EWW_CONFIG" "$@" 9>&-
}

eww_query() {
  local output status attempt
  for attempt in 1 2 3 4 5; do
    if output="$(eww_call "$@")"; then
      printf '%s\n' "$output"
      return 0
    else
      status=$?
    fi
    sleep 0.08
  done
  return "$status"
}

get_value() {
  local name="$1" fallback="$2" value
  if value="$(eww_query get "$name" 2>/dev/null)"; then
    printf '%s\n' "$value"
  else
    printf '%s\n' "$fallback"
  fi
}

window_is_open() {
  eww_query active-windows 2>/dev/null | awk -F': ' -v target="$WINDOW" '$2 == target {found=1} END {exit !found}'
}

wait_for_window() {
  local expected="$1" attempt
  for attempt in {1..40}; do
    if window_is_open; then
      [[ "$expected" == open ]] && return 0
    else
      [[ "$expected" == closed ]] && return 0
    fi
    sleep 0.08
  done
  return 1
}

target_screen() {
  local screen="0"
  if [[ -x "$HYPRCTL_BIN" ]] && command -v jq >/dev/null 2>&1; then
    screen="$("$HYPRCTL_BIN" -j monitors 2>/dev/null |
      jq -r '[.[]? | select(.focused == true) | .id][0] // 0' 2>/dev/null || printf 0)"
  fi
  [[ "$screen" =~ ^[0-9]+$ ]] || screen=0
  printf '%s\n' "$screen"
}

logical_dimensions() {
  local dimensions=""
  if [[ -x "$HYPRCTL_BIN" ]] && command -v jq >/dev/null 2>&1; then
    dimensions="$("$HYPRCTL_BIN" -j monitors 2>/dev/null | jq -r '
      ((map(select(.focused == true)) | first) // .[0]) as $m
      | if $m == null then empty else "\(($m.width / ($m.scale // 1)) | floor) \(($m.height / ($m.scale // 1)) | floor)" end
    ' 2>/dev/null || true)"
  fi
  [[ "$dimensions" =~ ^[1-9][0-9]*\ [1-9][0-9]*$ ]] || dimensions="1920 1080"
  printf '%s\n' "$dimensions"
}

geometry_for() {
  local mode="$1" width height panel_width panel_height
  read -r width height <<<"$(logical_dimensions)"
  if [[ "$mode" == expanded ]]; then
    panel_width=330
    panel_height=760
    ((panel_width > width * 92 / 100)) && panel_width=$((width * 92 / 100))
    ((panel_height > height * 84 / 100)) && panel_height=$((height * 84 / 100))
  else
    panel_width=300
    panel_height=410
    ((panel_width > width * 78 / 100)) && panel_width=$((width * 78 / 100))
    ((panel_height > height * 62 / 100)) && panel_height=$((height * 62 / 100))
  fi
  printf '%sx%s\n' "$panel_width" "$panel_height"
}

cancel_expiry() {
  printf '%s-%s-cancelled\n' "$(date +%s%N)" "$$" >"$EXPIRY_FILE"
}

schedule_expiry() {
  local token
  token="$(date +%s%N)-$$"
  printf '%s\n' "$token" >"$EXPIRY_FILE"
  (
    exec 9>&-
    sleep "$EXPANDED_SECONDS"
    [[ "$(cat "$EXPIRY_FILE" 2>/dev/null)" == "$token" ]] || exit 0
    "$EWW_CONFIG/scripts/companion-state.sh" expire "$token" >/dev/null 2>&1
  ) &
}

publish() {
  local name="$1" expected="$2"
  shift 2
  eww_call update "$@" >/dev/null 2>&1 || true
  [[ "$(get_value "$name" invalid)" == "$expected" ]]
}

close_window() {
  cancel_expiry
  if window_is_open; then
    eww_call close "$WINDOW" >/dev/null 2>&1 || true
    wait_for_window closed || return 1
  fi
  publish companion_mode closed companion_mode=closed
}

open_mode() {
  local mode="$1" dock pinned anchor size position screen
  is_mode "$mode" && [[ "$mode" != closed ]] || fail "Mode is not allowlisted: $mode"
  dock="$(get_value companion_dock right)"; is_dock "$dock" || dock=right
  pinned="$(get_value companion_pinned false)"; is_boolean "$pinned" || pinned=false
  anchor="top $dock"
  size="$(geometry_for "$mode")"
  position="12x72"
  screen="$(target_screen)"

  cancel_expiry
  if window_is_open; then
    eww_call close "$WINDOW" >/dev/null 2>&1 || true
    wait_for_window closed || fail "Unable to reposition the companion"
  fi

  publish companion_mode "$mode" \
    "companion_mode=$mode" "companion_dock=$dock" "companion_pinned=$pinned" ||
    fail "Unable to publish companion state"

  "$SETSID_BIN" --fork "$EWW_BIN" --no-daemonize --config "$EWW_CONFIG" \
    open --screen "$screen" --anchor "$anchor" --pos "$position" --size "$size" "$WINDOW" \
    >/dev/null 2>&1 </dev/null 9>&-
  wait_for_window open || {
    publish companion_mode closed companion_mode=closed >/dev/null 2>&1 || true
    fail "The companion window did not open"
  }

  if [[ "$mode" == expanded && "$pinned" == false ]]; then
    schedule_expiry
  fi
}

toggle_pin() {
  local pinned
  pinned="$(get_value companion_pinned false)"
  is_boolean "$pinned" || pinned=false
  if [[ "$pinned" == true ]]; then
    publish companion_pinned false companion_pinned=false || fail "Unable to unpin the companion"
    [[ "$(get_value companion_mode closed)" == expanded ]] && schedule_expiry
  else
    cancel_expiry
    publish companion_pinned true companion_pinned=true || fail "Unable to pin the companion"
  fi
}

toggle_dock() {
  local dock mode
  dock="$(get_value companion_dock right)"; is_dock "$dock" || dock=right
  [[ "$dock" == right ]] && dock=left || dock=right
  publish companion_dock "$dock" "companion_dock=$dock" || fail "Unable to change companion edge"
  mode="$(get_value companion_mode closed)"; is_mode "$mode" || mode=closed
  [[ "$mode" == closed ]] || open_mode "$mode"
}

mkdir -p "$RUNTIME_ROOT" || fail "Unable to create the runtime directory"
if [[ "$ACTION" != status ]]; then
  command -v flock >/dev/null 2>&1 || fail "flock is unavailable"
  exec 9>"$LOCK_FILE" || fail "Unable to open the companion lock"
  flock -w 2 9 || fail "Another companion transition is still running"
fi

case "$ACTION" in
  toggle)
    if window_is_open; then close_window || fail "Unable to close the companion"; else open_mode expanded; fi
    ;;
  open | expand) open_mode expanded ;;
  collapse) window_is_open && open_mode compact || true ;;
  close) close_window || fail "Unable to close the companion" ;;
  pin) toggle_pin ;;
  dock) toggle_dock ;;
  expire)
    [[ -n "$VALUE" && "$(cat "$EXPIRY_FILE" 2>/dev/null)" == "$VALUE" ]] || exit 0
    [[ "$(get_value companion_pinned false)" == false ]] || exit 0
    [[ "$(get_value companion_mode closed)" == expanded ]] || exit 0
    open_mode compact
    ;;
  status)
    printf 'mode=%s\n' "$(get_value companion_mode closed)"
    printf 'dock=%s\n' "$(get_value companion_dock right)"
    printf 'pinned=%s\n' "$(get_value companion_pinned false)"
    if window_is_open; then printf 'window=open\n'; else printf 'window=closed\n'; fi
    ;;
  *) fail "Usage: companion-state.sh {toggle|open|expand|collapse|close|pin|dock|status}" ;;
esac
