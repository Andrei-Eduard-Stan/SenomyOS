#!/usr/bin/env bash

# Live, non-destructive surface state-machine regression test. This opens and
# closes SenomyOS windows but performs no hardware or system mutation.
set -euo pipefail
export LC_ALL=C

readonly CONFIG_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly EWW_BIN="${EWW_BIN:-/usr/bin/eww}"
readonly SURFACE_BIN="$CONFIG_DIR/scripts/surface-state.sh"
tests=0

cleanup() {
  "$SURFACE_BIN" dismiss >/dev/null 2>&1 || true
}
trap cleanup EXIT

eww_get() {
  local attempt output
  for attempt in 1 2 3 4 5; do
    if output="$("$EWW_BIN" --config "$CONFIG_DIR" get "$1" 2>/dev/null)" && [[ -n "$output" ]]; then
      printf '%s\n' "$output"
      return 0
    fi
    sleep 0.05
  done
  return 1
}
windows() {
  local attempt output
  for attempt in 1 2 3 4 5; do
    if output="$("$EWW_BIN" --config "$CONFIG_DIR" active-windows 2>/dev/null)"; then
      printf '%s\n' "$output"
      return 0
    fi
    sleep 0.05
  done
  return 1
}
window_count_in() {
  local snapshot="$1" window="$2"
  grep -cE "^[^:]+: $window$" <<<"$snapshot" || true
}

assert_state() {
  local surface="$1" flyout="$2" primary_window="$3" flyout_window="$4"
  local active_surface active_flyout window_snapshot dismiss_expected=0
  active_surface="$(eww_get active_surface)"
  active_flyout="$(eww_get active_flyout)"
  window_snapshot="$(windows)"
  [[ "$active_surface" == "$surface" ]] || { printf 'Expected surface %s, got %s\n' "$surface" "$active_surface" >&2; return 1; }
  [[ "$active_flyout" == "$flyout" ]] || { printf 'Expected flyout %s, got %s\n' "$flyout" "$active_flyout" >&2; return 1; }
  [[ "$(window_count_in "$window_snapshot" main-bar)" -eq 1 ]] || { printf 'main-bar invariant failed\n' >&2; return 1; }
  [[ "$(window_count_in "$window_snapshot" actioncenter)" -eq "$([[ "$primary_window" == actioncenter ]] && printf 1 || printf 0)" ]] || return 1
  [[ "$(window_count_in "$window_snapshot" insights)" -eq "$([[ "$primary_window" == insights ]] && printf 1 || printf 0)" ]] || return 1
  [[ "$(window_count_in "$window_snapshot" performance)" -eq "$([[ "$primary_window" == performance ]] && printf 1 || printf 0)" ]] || return 1
  [[ "$(window_count_in "$window_snapshot" volume-flyout)" -eq "$([[ "$flyout_window" == volume-flyout ]] && printf 1 || printf 0)" ]] || return 1
  [[ "$(window_count_in "$window_snapshot" tray-flyout)" -eq "$([[ "$flyout_window" == tray-flyout ]] && printf 1 || printf 0)" ]] || return 1
  [[ "$surface" != none || "$flyout" != none ]] && dismiss_expected=1
  [[ "$(window_count_in "$window_snapshot" surface-dismiss)" -eq "$dismiss_expected" ]] || { printf 'dismiss-layer invariant failed\n' >&2; return 1; }
}

transition() {
  local label="$1" surface="$2" flyout="$3" primary="$4" flyout_window="$5"
  shift 5
  local start finish elapsed
  start="$(date +%s%3N)"
  "$SURFACE_BIN" "$@" >/dev/null
  finish="$(date +%s%3N)"; elapsed=$((finish - start))
  assert_state "$surface" "$flyout" "$primary" "$flyout_window"
  tests=$((tests + 1))
  printf 'PASS  %-28s %4dms\n' "$label" "$elapsed"
}

"$EWW_BIN" --config "$CONFIG_DIR" ping >/dev/null
cleanup
assert_state none none none none

transition "open Control" control none actioncenter none show-control overview none none
"$CONFIG_DIR/scripts/ui-action.sh" control-section network >/dev/null
[[ "$(eww_get control_section)" == network ]] && assert_state control none actioncenter none
tests=$((tests + 1)); printf 'PASS  %-28s\n' "Control route switch"
transition "switch to Insights" insights none insights none show-insights briefing control none
"$CONFIG_DIR/scripts/ui-action.sh" insights-section console >/dev/null
[[ "$(eww_get insights_section)" == console ]] && assert_state insights none insights none
tests=$((tests + 1)); printf 'PASS  %-28s\n' "Insights route switch"
transition "switch to Performance" performance none performance none show-performance insights none
transition "dismiss primary" none none none none dismiss performance none
transition "open Volume" none volume none volume-flyout toggle-volume none none
transition "repeat-close Volume" none none none none toggle-volume none volume
transition "open Tray" none tray none tray-flyout toggle-tray none none
transition "switch Tray to Volume" none volume none volume-flyout toggle-volume none tray
transition "Volume to Audio" control none actioncenter none show-control audio none volume
transition "dismiss Control" none none none none dismiss control none

trap - EXIT
cleanup
printf '\nSenomyOS interactions: %d transitions passed; idle state restored.\n' "$tests"
