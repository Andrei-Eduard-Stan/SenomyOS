#!/usr/bin/env bash

# Serialize SenomyOS primary-surface transitions and provide a restart-based
# reload path that restores validated Eww state after defvars reset.

set -u

export LC_ALL=C

readonly ACTION="${1:-help}"
readonly USER_HOME="${HOME:-/nonexistent}"
readonly EWW_BIN="${EWW_BIN:-/usr/bin/eww}"
readonly EWW_CONFIG="${EWW_CONFIG:-${XDG_CONFIG_HOME:-"$USER_HOME/.config"}/eww}"
readonly READY_ATTEMPTS="${EWW_READY_ATTEMPTS:-50}"
readonly READY_DELAY="${EWW_READY_DELAY:-0.1}"
readonly WINDOW_ATTEMPTS="${EWW_WINDOW_ATTEMPTS:-30}"
readonly WINDOW_DELAY="${EWW_WINDOW_DELAY:-0.05}"
readonly RUNTIME_ROOT="${SENOMY_SURFACE_RUNTIME_DIR:-${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/senomyos}"
readonly LOCK_FILE="$RUNTIME_ROOT/surface-state.lock"

usage() {
  cat <<'EOF'
Usage: surface-state.sh ACTION [VALUE]

Actions:
  toggle-control SECTION  Toggle or switch the Control Centre section
  toggle-insights         Toggle Senomy Insights
  show-control SECTION    Open a specific Control Centre section
  show-insights [SECTION] Open Insights, optionally on a specific section
  close SURFACE           Close control, insights, or performance
  reconcile               Make windows match the current active_surface
  reload                  Reload Eww and restore validated surface state
  status                  Print current state and active windows
EOF
}

fail() {
  printf 'SenomyOS surface state: %s\n' "$1" >&2
  exit 1
}

eww_call() {
  "$EWW_BIN" --config "$EWW_CONFIG" "$@" 9>&-
}

require_daemon() {
  [[ -x "$EWW_BIN" ]] ||
    fail "Eww executable is unavailable: $EWW_BIN"

  eww_call ping >/dev/null 2>&1 ||
    fail "Eww daemon is not reachable"
}

acquire_lock() {
  command -v flock >/dev/null 2>&1 ||
    fail "Required command flock is unavailable"

  mkdir -p "$RUNTIME_ROOT" 2>/dev/null ||
    fail "Unable to create runtime state directory"

  exec 9>"$LOCK_FILE" ||
    fail "Unable to open the surface-state lock"

  flock -w 2 9 ||
    fail "Another surface transition is still running"
}

is_surface() {
  case "$1" in
    none | control | performance | insights)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

is_control_section() {
  case "$1" in
    overview | network | audio | power | calendar | input | devices | apps | settings)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

is_insights_section() {
  case "$1" in
    briefing | timeline | updates | diagnostics | reports)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

is_timeline_source() {
  case "$1" in
    user | system | kernel | eww)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

is_boolean() {
  [[ "$1" == "true" || "$1" == "false" ]]
}

get_value() {
  local name="$1"
  local fallback="$2"
  local value

  if value="$(eww_call get "$name" 2>/dev/null)"; then
    printf '%s\n' "$value"
  else
    printf '%s\n' "$fallback"
  fi
}

validated_surface() {
  local value
  value="$(get_value active_surface none)"
  is_surface "$value" && printf '%s\n' "$value" || printf 'none\n'
}

validated_control_section() {
  local value
  value="$(get_value control_section overview)"
  is_control_section "$value" && printf '%s\n' "$value" || printf 'overview\n'
}

validated_insights_section() {
  local value
  value="$(get_value insights_section briefing)"
  is_insights_section "$value" && printf '%s\n' "$value" || printf 'briefing\n'
}

validated_timeline_source() {
  local value
  value="$(get_value timeline_source user)"
  is_timeline_source "$value" && printf '%s\n' "$value" || printf 'user\n'
}

validated_timeline_follow() {
  local value
  value="$(get_value timeline_follow true)"
  is_boolean "$value" && printf '%s\n' "$value" || printf 'true\n'
}

window_for_surface() {
  case "$1" in
    control)
      printf 'actioncenter\n'
      ;;
    performance)
      printf 'performance\n'
      ;;
    insights)
      printf 'insights\n'
      ;;
    *)
      return 1
      ;;
  esac
}

window_is_open() {
  local target="$1"
  local line
  local windows

  if ! windows="$(eww_call active-windows 2>/dev/null)"; then
    return 2
  fi

  while IFS= read -r line; do
    [[ "${line#*: }" == "$target" ]] && return 0
  done <<<"$windows"

  return 1
}

window_is_defined() {
  local target="$1"
  local line
  local windows

  if ! windows="$(eww_call list-windows 2>/dev/null)"; then
    return 2
  fi

  while IFS= read -r line; do
    [[ "$line" == "$target" ]] && return 0
  done <<<"$windows"

  return 1
}

wait_for_window_state() {
  local target="$1"
  local expected="$2"
  local attempt=0
  local status

  [[ "$WINDOW_ATTEMPTS" =~ ^[1-9][0-9]*$ ]] ||
    fail "EWW_WINDOW_ATTEMPTS must be a positive integer"

  while ((attempt < WINDOW_ATTEMPTS)); do
    window_is_open "$target"
    status=$?

    if [[ "$expected" == "open" && $status -eq 0 ]]; then
      return 0
    fi
    if [[ "$expected" == "closed" && $status -eq 1 ]]; then
      return 0
    fi
    ((status == 2)) && return 1

    attempt=$((attempt + 1))
    sleep "$WINDOW_DELAY"
  done

  return 1
}

open_window() {
  local window="$1"
  local status

  if window_is_open "$window"; then
    return 0
  else
    status=$?
    ((status == 1)) || return 1
  fi

  if ! window_is_defined "$window"; then
    return 1
  fi

  eww_call open "$window" >/dev/null || return 1
  wait_for_window_state "$window" open
}

close_window() {
  local window="$1"
  local status

  window_is_open "$window"
  status=$?
  if ((status != 0)); then
    ((status == 1)) && return 0
    return 1
  fi

  eww_call close "$window" >/dev/null || return 1
  wait_for_window_state "$window" closed
}

close_other_surfaces() {
  local keep="$1"
  local surface
  local window

  for surface in control performance insights; do
    [[ "$surface" == "$keep" ]] && continue
    window="$(window_for_surface "$surface")"
    close_window "$window" || return 1
  done
}

close_all_surfaces() {
  close_other_surfaces "none"
}

set_none() {
  close_all_surfaces || return 1
  eww_call update active_surface=none pending_action=none >/dev/null
}

activate_control() {
  local section="$1"

  is_control_section "$section" ||
    fail "Control Centre section is not allowlisted: $section"

  close_other_surfaces "control" || return 1
  eww_call update active_surface=none pending_action=none "control_section=$section" >/dev/null ||
    return 1

  if ! open_window actioncenter; then
    eww_call update active_surface=none >/dev/null 2>&1
    return 1
  fi

  if ! eww_call update active_surface=control "control_section=$section" >/dev/null; then
    close_window actioncenter >/dev/null 2>&1
    eww_call update active_surface=none >/dev/null 2>&1
    return 1
  fi
}

activate_insights() {
  local section="$1"

  is_insights_section "$section" ||
    fail "Insights section is not allowlisted: $section"

  close_other_surfaces "insights" || return 1
  eww_call update active_surface=none pending_action=none "insights_section=$section" >/dev/null ||
    return 1

  if ! open_window insights; then
    eww_call update active_surface=none >/dev/null 2>&1
    return 1
  fi

  if ! eww_call update active_surface=insights "insights_section=$section" >/dev/null; then
    close_window insights >/dev/null 2>&1
    eww_call update active_surface=none >/dev/null 2>&1
    return 1
  fi
}

activate_performance() {
  close_other_surfaces "performance" || return 1
  eww_call update active_surface=none pending_action=none >/dev/null || return 1

  if ! open_window performance; then
    eww_call update active_surface=none >/dev/null 2>&1
    return 1
  fi

  if ! eww_call update active_surface=performance >/dev/null; then
    close_window performance >/dev/null 2>&1
    eww_call update active_surface=none >/dev/null 2>&1
    return 1
  fi
}

close_surface() {
  local surface="$1"
  local active
  local window

  case "$surface" in
    control | performance | insights)
      ;;
    *)
      fail "Surface is not allowlisted: $surface"
      ;;
  esac

  active="$(validated_surface)"
  window="$(window_for_surface "$surface")"

  close_window "$window" || return 1

  if [[ "$active" == "$surface" ]]; then
    eww_call update active_surface=none pending_action=none >/dev/null
  fi
}

toggle_control() {
  local requested="$1"
  local active
  local current
  local open_status

  is_control_section "$requested" ||
    fail "Control Centre section is not allowlisted: $requested"

  active="$(validated_surface)"
  current="$(validated_control_section)"
  window_is_open actioncenter
  open_status=$?
  ((open_status == 2)) &&
    fail "Unable to query the Control Centre window state"

  if [[ "$active" == "control" && "$current" == "$requested" && $open_status -eq 0 ]]; then
    close_surface control
  elif [[ "$active" == "control" && $open_status -eq 0 ]]; then
    eww_call update pending_action=none "control_section=$requested" >/dev/null
  else
    activate_control "$requested"
  fi
}

toggle_insights() {
  local active
  local section
  local open_status

  active="$(validated_surface)"
  section="$(validated_insights_section)"
  window_is_open insights
  open_status=$?
  ((open_status == 2)) &&
    fail "Unable to query the Senomy Insights window state"

  if [[ "$active" == "insights" && $open_status -eq 0 ]]; then
    close_surface insights
  else
    activate_insights "$section"
  fi
}

ensure_main_bar() {
  open_window main-bar ||
    fail "Unable to restore main-bar"
}

reconcile_surface() {
  local active
  local control_section
  local insights_section

  active="$(validated_surface)"
  control_section="$(validated_control_section)"
  insights_section="$(validated_insights_section)"

  ensure_main_bar

  case "$active" in
    none)
      set_none || fail "Unable to close stale primary windows"
      ;;
    control)
      activate_control "$control_section" ||
        fail "Unable to reconcile Control Centre"
      ;;
    insights)
      activate_insights "$insights_section" ||
        fail "Unable to reconcile Senomy Insights"
      ;;
    performance)
      activate_performance ||
        fail "Performance Dashboard is not available; state returned to none"
      ;;
  esac
}

wait_for_daemon() {
  local attempt=0

  [[ "$READY_ATTEMPTS" =~ ^[1-9][0-9]*$ ]] ||
    fail "EWW_READY_ATTEMPTS must be a positive integer"

  until eww_call ping >/dev/null 2>&1; do
    attempt=$((attempt + 1))
    if ((attempt >= READY_ATTEMPTS)); then
      fail "Eww daemon did not become ready after reload"
    fi
    sleep "$READY_DELAY"
  done
}

wait_for_daemon_stop() {
  local attempt=0

  [[ "$READY_ATTEMPTS" =~ ^[1-9][0-9]*$ ]] ||
    fail "EWW_READY_ATTEMPTS must be a positive integer"

  while eww_call ping >/dev/null 2>&1; do
    attempt=$((attempt + 1))
    if ((attempt >= READY_ATTEMPTS)); then
      fail "Eww daemon did not stop cleanly"
    fi
    sleep "$READY_DELAY"
  done
}

validate_reload_surface() {
  local active="$1"
  local target
  local status

  if ! window_is_defined main-bar; then
    fail "main-bar is not defined"
  fi

  [[ "$active" == "none" ]] && return 0

  target="$(window_for_surface "$active")"
  window_is_defined "$target"
  status=$?

  if ((status == 2)); then
    fail "Unable to query Eww window definitions"
  fi
  if ((status == 1)); then
    return 1
  fi
}

start_reload_windows() {
  local active="$1"
  local target
  local windows=(main-bar)

  if [[ "$active" != "none" ]]; then
    target="$(window_for_surface "$active")"
    windows+=("$target")
  fi

  eww_call open-many "${windows[@]}" >/dev/null 2>&1 ||
    fail "Unable to start Eww with the restored window set"
  wait_for_daemon

  wait_for_window_state main-bar open ||
    fail "main-bar did not open after restart"

  if [[ "$active" != "none" ]]; then
    wait_for_window_state "$target" open ||
      fail "The restored primary window did not open after restart"
  fi
}

reload_and_restore() {
  local active
  local control_section
  local insights_section
  local timeline_source
  local timeline_follow

  active="$(validated_surface)"
  control_section="$(validated_control_section)"
  insights_section="$(validated_insights_section)"
  timeline_source="$(validated_timeline_source)"
  timeline_follow="$(validated_timeline_follow)"

  if ! validate_reload_surface "$active"; then
    active=none
  fi

  eww_call close-all >/dev/null 2>&1 ||
    fail "Unable to close Eww windows before restart"
  eww_call kill >/dev/null 2>&1 ||
    fail "Unable to stop the Eww daemon"
  wait_for_daemon_stop

  start_reload_windows "$active"

  eww_call update \
    "active_surface=$active" \
    "pending_action=none" \
    "control_section=$control_section" \
    "insights_section=$insights_section" \
    "timeline_source=$timeline_source" \
    "timeline_follow=$timeline_follow" >/dev/null ||
    fail "Unable to restore Eww section state"
}

print_status() {
  printf 'active_surface=%s\n' "$(validated_surface)"
  printf 'control_section=%s\n' "$(validated_control_section)"
  printf 'insights_section=%s\n' "$(validated_insights_section)"
  printf 'timeline_source=%s\n' "$(validated_timeline_source)"
  printf 'timeline_follow=%s\n' "$(validated_timeline_follow)"
  printf '%s\n' 'active_windows:'
  eww_call active-windows
}

case "$ACTION" in
  help | --help | -h)
    usage
    ;;
  status)
    require_daemon
    print_status
    ;;
  toggle-control)
    [[ $# -eq 2 ]] || fail "toggle-control requires one section"
    require_daemon
    acquire_lock
    toggle_control "$2"
    ;;
  toggle-insights)
    [[ $# -eq 1 ]] || fail "toggle-insights accepts no value"
    require_daemon
    acquire_lock
    toggle_insights
    ;;
  show-control)
    [[ $# -eq 2 ]] || fail "show-control requires one section"
    require_daemon
    acquire_lock
    activate_control "$2"
    ;;
  show-insights)
    [[ $# -le 2 ]] || fail "show-insights accepts at most one section"
    require_daemon
    acquire_lock
    activate_insights "${2:-$(validated_insights_section)}"
    ;;
  close)
    [[ $# -eq 2 ]] || fail "close requires one surface"
    require_daemon
    acquire_lock
    close_surface "$2"
    ;;
  reconcile)
    [[ $# -eq 1 ]] || fail "reconcile accepts no value"
    require_daemon
    acquire_lock
    reconcile_surface
    ;;
  reload)
    [[ $# -eq 1 ]] || fail "reload accepts no value"
    require_daemon
    acquire_lock
    reload_and_restore
    ;;
  *)
    fail "Unknown action: $ACTION"
    ;;
esac
