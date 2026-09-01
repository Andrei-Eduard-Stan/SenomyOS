#!/usr/bin/env bash

# Realistic-cadence live acceptance test for every routed SenomyOS surface.
set -euo pipefail
export LC_ALL=C

readonly CONFIG_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly EWW_BIN="${EWW_BIN:-/usr/bin/eww}"
readonly SURFACE="$CONFIG_DIR/scripts/surface-state.sh"
readonly UI="$CONFIG_DIR/scripts/ui-action.sh"
readonly SETTLE="${SENOMY_PANEL_TEST_SETTLE:-0.65}"
tests=0

cleanup() { "$SURFACE" dismiss >/dev/null 2>&1 || true; }
trap cleanup EXIT

health() {
  local attempt
  for attempt in {1..30}; do
    if timeout 1s "$EWW_BIN" --no-daemonize --config "$CONFIG_DIR" ping >/dev/null 2>&1 \
      && timeout 1s "$EWW_BIN" --no-daemonize --config "$CONFIG_DIR" active-windows 2>/dev/null | grep -q ': main-bar$'; then
      return 0
    fi
    sleep 0.1
  done
  return 1
}

expect_window() {
  local window="$1" snapshot attempt
  for attempt in {1..30}; do
    health
    snapshot="$(timeout 10s "$EWW_BIN" --no-daemonize --config "$CONFIG_DIR" active-windows)"
    grep -qE "^[^:]+: ${window}$" <<<"$snapshot" && return 0
    sleep 0.1
  done
  return 1
}

expect_window_absent() {
  local window="$1" snapshot attempt
  for attempt in {1..30}; do
    health
    snapshot="$(timeout 10s "$EWW_BIN" --no-daemonize --config "$CONFIG_DIR" active-windows)"
    if ! grep -qE "^[^:]+: ${window}$" <<<"$snapshot"; then
      return 0
    fi
    sleep 0.1
  done
  return 1
}

expect_value() {
  local variable="$1" expected="$2" attempt
  for attempt in {1..30}; do
    health
    [[ "$(timeout 10s "$EWW_BIN" --no-daemonize --config "$CONFIG_DIR" get "$variable")" == "$expected" ]] && return 0
    sleep 0.1
  done
  return 1
}

expect_layer_size() {
  local expected="$1" namespace="$2" width height attempt
  width="${expected%x*}"
  height="${expected#*x}"
  for attempt in {1..30}; do
    if hyprctl layers -j 2>/dev/null | jq -e --arg namespace "$namespace" --argjson width "$width" --argjson height "$height" '
      any(to_entries[].value.levels["3"][]?;
        .namespace == $namespace and .w == $width and .h == $height)
    ' >/dev/null; then
      return 0
    fi
    sleep 0.1
  done
  return 1
}

pass() { tests=$((tests + 1)); printf 'PASS  %s\n' "$1"; sleep "$SETTLE"; }

health
cleanup
"$SURFACE" show-control overview
expect_window actioncenter
expect_layer_size "$("$SURFACE" size actioncenter)" senomy-control
pass "Control / overview opens"
for section in network audio power calendar input devices apps appearance settings; do
  "$UI" control-section "$section"
  expect_value control_section "$section"
  expect_window actioncenter
  pass "Control / $section"
done

"$SURFACE" show-insights briefing
expect_window insights
expect_layer_size "$("$SURFACE" size insights)" senomy-insights
pass "Control -> Insights switch"
for section in notifications timeline updates diagnostics console reports wiki; do
  "$UI" insights-section "$section"
  expect_value insights_section "$section"
  expect_window insights
  pass "Insights / $section"
done

"$SURFACE" show-performance
expect_window performance
performance_size="$("$SURFACE" size performance)"
expect_layer_size "$performance_size" senomy-performance
pass "Insights -> Performance switch"
for section in cpu memory storage network processes benchmarks overview; do
  "$UI" performance-section "$section"
  expect_value performance_section "$section"
  expect_window performance
  expect_layer_size "$performance_size" senomy-performance
  pass "Performance / $section"
done

"$SURFACE" dismiss
health
pass "Performance dismiss"
"$SURFACE" toggle-volume
expect_window volume-flyout
expect_layer_size "$("$SURFACE" size volume-flyout)" senomy-flyout
pass "Volume flyout opens"
"$SURFACE" toggle-volume
health
pass "Volume repeat-toggle closes"
"$SURFACE" toggle-tray
expect_window tray-flyout
expect_layer_size "$("$SURFACE" size tray-flyout)" senomy-flyout
pass "Tray flyout opens"
"$SURFACE" toggle-tray
health
pass "Tray repeat-toggle closes"
"$SURFACE" toggle-calendar
expect_window calendar-flyout
expect_layer_size "$("$SURFACE" size calendar-flyout)" senomy-flyout
pass "Calendar flyout opens"
"$SURFACE" toggle-calendar
health
pass "Calendar repeat-toggle closes"
"$SURFACE" toggle-notifications
expect_window notifications-flyout
expect_layer_size "$("$SURFACE" size notifications-flyout)" senomy-flyout
pass "Notifications flyout opens"
"$SURFACE" toggle-notifications
health
pass "Notifications repeat-toggle closes"
"$SURFACE" toggle-power
expect_window power-flyout
expect_layer_size "$("$SURFACE" size power-flyout)" senomy-flyout
pass "Power flyout opens"
"$SURFACE" toggle-power
health
pass "Power repeat-toggle closes"

"$SURFACE" show-control settings
expect_window actioncenter
"$SURFACE" close control
expect_window_absent actioncenter
expect_value active_surface none
pass "Control close action"

"$SURFACE" show-insights briefing
expect_window insights
"$SURFACE" close insights
expect_window_absent insights
expect_value active_surface none
pass "Insights close action"

"$SURFACE" show-performance
expect_window performance
"$SURFACE" close performance
expect_window_absent performance
expect_value active_surface none
pass "Performance close action"

"$SURFACE" toggle-volume
expect_window volume-flyout
"$SURFACE" show-control audio
expect_window actioncenter
expect_window_absent volume-flyout
expect_value active_flyout none
pass "Volume -> Control switch"

"$SURFACE" toggle-tray
expect_window tray-flyout
"$SURFACE" show-insights briefing
expect_window insights
expect_window_absent tray-flyout
expect_value active_flyout none
pass "Tray -> Insights switch"

trap - EXIT
cleanup
health
printf '\nSenomyOS panel acceptance: %d routes/transitions passed; idle bar restored.\n' "$tests"
