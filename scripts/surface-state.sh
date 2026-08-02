#!/usr/bin/env bash

# Serialize SenomyOS primary-surface transitions and provide a restart-based
# reload path that restores validated Eww state after defvars reset.

set -u

export LC_ALL=C

readonly ACTION="${1:-help}"
readonly ACTION_TARGET="${2:-none}"
readonly USER_HOME="${HOME:-/nonexistent}"
readonly EWW_BIN="${EWW_BIN:-/usr/bin/eww}"
readonly HYPRCTL_BIN="${SENOMY_HYPRCTL_BIN:-/usr/bin/hyprctl}"
readonly EWW_CONFIG="${EWW_CONFIG:-${XDG_CONFIG_HOME:-"$USER_HOME/.config"}/eww}"
readonly TIMEOUT_BIN="${SENOMY_TIMEOUT_BIN:-/usr/bin/timeout}"
readonly SETSID_BIN="${SENOMY_SETSID_BIN:-/usr/bin/setsid}"
readonly EWW_CLIENT_TIMEOUT="${EWW_CLIENT_TIMEOUT:-12s}"
readonly EWW_QUERY_ATTEMPTS="${EWW_QUERY_ATTEMPTS:-5}"
readonly EWW_QUERY_DELAY="${EWW_QUERY_DELAY:-0.08}"
readonly READY_ATTEMPTS="${EWW_READY_ATTEMPTS:-50}"
readonly READY_DELAY="${EWW_READY_DELAY:-0.1}"
readonly WINDOW_ATTEMPTS="${EWW_WINDOW_ATTEMPTS:-30}"
readonly WINDOW_DELAY="${EWW_WINDOW_DELAY:-0.05}"
readonly STATE_ATTEMPTS="${EWW_STATE_ATTEMPTS:-30}"
readonly STATE_DELAY="${EWW_STATE_DELAY:-0.05}"
readonly RUNTIME_ROOT="${SENOMY_SURFACE_RUNTIME_DIR:-${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/senomyos}"
readonly LOCK_FILE="$RUNTIME_ROOT/surface-state.lock"
readonly DISMISS_TOKEN_FILE="$RUNTIME_ROOT/dismiss-arm.token"
readonly DISMISS_WINDOW="surface-dismiss"
readonly EVENT_BIN="$EWW_CONFIG/scripts/senomy-event.sh"
readonly STATE_ROOT="${XDG_STATE_HOME:-$USER_HOME/.local/state}/senomyos/recovery"

usage() {
  cat <<'EOF'
Usage: surface-state.sh ACTION [VALUE]

Actions:
  toggle-control SECTION  Toggle or switch the Control Centre section
  toggle-insights         Toggle Senomy Insights
  toggle-performance      Toggle the Performance Dashboard
  toggle-volume           Toggle the compact volume flyout
  toggle-tray             Toggle the native tray overflow
  show-control SECTION    Open a specific Control Centre section
  show-insights [SECTION] Open Insights, optionally on a specific section
  show-performance        Open the Performance Dashboard
  close SURFACE           Close control, insights, or performance
  dismiss                 Close the active flyout or primary surface
  reconcile               Make windows match the current active_surface
  reload                  Reload Eww and restore validated surface state
  status                  Print current state and active windows
  size WINDOW             Print the responsive open size for a known window
EOF
}

fail() {
  printf 'SenomyOS surface state: %s\n' "$1" >&2
  exit 1
}

eww_call() {
  "$TIMEOUT_BIN" \
    --foreground \
    --kill-after=1s \
    "$EWW_CLIENT_TIMEOUT" \
    "$EWW_BIN" \
    --config "$EWW_CONFIG" \
    "$@" 9>&-
}

eww_start_call() {
  "$EWW_BIN" --debug --config "$EWW_CONFIG" "$@" 9>&-
}

eww_open_async() {
  [[ -x "$SETSID_BIN" ]] || return 1
  # Some Eww builds display a window but never acknowledge `open`. Run that
  # one non-idempotent request in its own session and use active-windows as the
  # completion signal instead of blocking the surface controller indefinitely.
  "$SETSID_BIN" --fork \
    "$EWW_BIN" --config "$EWW_CONFIG" "$@" \
    >/dev/null 2>&1 </dev/null 9>&-
}

eww_query() {
  local attempt=1
  local output
  local status=1

  [[ "$EWW_QUERY_ATTEMPTS" =~ ^[1-9][0-9]*$ ]] ||
    fail "EWW_QUERY_ATTEMPTS must be a positive integer"

  while ((attempt <= EWW_QUERY_ATTEMPTS)); do
    if output="$(eww_call "$@")"; then
      printf '%s' "$output"
      [[ -z "$output" ]] || printf '\n'
      return 0
    else
      status=$?
    fi

    attempt=$((attempt + 1))
    ((attempt <= EWW_QUERY_ATTEMPTS)) && sleep "$EWW_QUERY_DELAY"
  done

  return "$status"
}

require_client() {
  [[ -x "$EWW_BIN" ]] ||
    fail "Eww executable is unavailable: $EWW_BIN"
  [[ -x "$TIMEOUT_BIN" ]] ||
    fail "Timeout executable is unavailable: $TIMEOUT_BIN"
}

require_daemon() {
  require_client
  eww_query ping >/dev/null 2>&1 ||
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

is_flyout() {
  case "$1" in
    none | volume | tray)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

is_control_section() {
  case "$1" in
    overview | network | audio | power | calendar | input | devices | apps | appearance | settings)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

is_insights_section() {
  case "$1" in
    briefing | timeline | updates | diagnostics | console | reports | wiki)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

is_performance_section() {
  case "$1" in
    overview | cpu | memory | storage | network | processes | benchmarks)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

is_timeline_source() {
  case "$1" in
    activity | session | system | kernel | eww)
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

  if value="$(eww_query get "$name" 2>/dev/null)"; then
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

validated_flyout() {
  local value
  value="$(get_value active_flyout none)"
  is_flyout "$value" && printf '%s\n' "$value" || printf 'none\n'
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

validated_performance_section() {
  local value
  value="$(get_value performance_section overview)"
  is_performance_section "$value" && printf '%s\n' "$value" || printf 'overview\n'
}

validated_timeline_source() {
  local value
  value="$(get_value timeline_source activity)"
  is_timeline_source "$value" && printf '%s\n' "$value" || printf 'activity\n'
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

target_screen() {
  local screen="0"

  if [[ -x "$HYPRCTL_BIN" ]] && command -v jq >/dev/null 2>&1; then
    screen="$("$HYPRCTL_BIN" -j monitors 2>/dev/null |
      jq -r '[.[]? | select(.focused == true) | .id][0] // 0' 2>/dev/null || printf 0)"
  fi
  [[ "$screen" =~ ^[0-9]+$ ]] || screen=0
  printf '%s\n' "$screen"
}

window_size() {
  local window="$1" dimensions width height max_width max_height panel_width panel_height

  [[ -x "$HYPRCTL_BIN" ]] && command -v jq >/dev/null 2>&1 || return 0
  dimensions="$($HYPRCTL_BIN -j monitors 2>/dev/null | jq -r '
    ((map(select(.focused == true)) | first) // .[0]) as $m
    | if $m == null then empty else "\(($m.width / ($m.scale // 1)) | floor) \(($m.height / ($m.scale // 1)) | floor)" end
  ' 2>/dev/null)"
  read -r width height <<<"$dimensions"
  [[ "$width" =~ ^[1-9][0-9]*$ && "$height" =~ ^[1-9][0-9]*$ ]] || return 0

  case "$window" in
    actioncenter | insights)
      max_width=$((width * 94 / 100)); max_height=$((height * 88 / 100))
      panel_width=750; panel_height=700
      ((panel_width > max_width)) && panel_width=$max_width
      ((panel_height > max_height)) && panel_height=$max_height
      printf '%sx%s\n' "$panel_width" "$panel_height"
      ;;
    performance)
      printf '%sx%s\n' "$((width * 94 / 100))" "$((height * 82 / 100))"
      ;;
    volume-flyout)
      max_width=$((width * 94 / 100)); panel_width=350; panel_height=62
      ((panel_width > max_width)) && panel_width=$max_width
      ((width < 600)) && panel_height=232
      printf '%sx%s\n' "$panel_width" "$panel_height"
      ;;
    tray-flyout)
      max_width=$((width * 90 / 100)); panel_width=260
      ((panel_width > max_width)) && panel_width=$max_width
      ((width < 480)) && printf '%sx154\n' "$panel_width" || printf '%sx112\n' "$panel_width"
      ;;
  esac
}

window_position() {
  local window="$1" dimensions width height
  [[ -x "$HYPRCTL_BIN" ]] && command -v jq >/dev/null 2>&1 || return 0
  dimensions="$($HYPRCTL_BIN -j monitors 2>/dev/null | jq -r '
    ((map(select(.focused == true)) | first) // .[0]) as $m
    | if $m == null then empty else "\(($m.width / ($m.scale // 1)) | floor) \(($m.height / ($m.scale // 1)) | floor)" end
  ' 2>/dev/null)"
  read -r width height <<<"$dimensions"
  [[ "$width" =~ ^[1-9][0-9]*$ ]] || return 0
  case "$window" in
    volume-flyout) ((width < 600)) && printf '10x10\n' || printf '128x10\n' ;;
    tray-flyout) ((width < 600)) && printf '10x10\n' || printf '286x10\n' ;;
  esac
}

window_for_flyout() {
  case "$1" in
    volume)
      printf 'volume-flyout\n'
      ;;
    tray)
      printf 'tray-flyout\n'
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

  if ! windows="$(eww_query active-windows 2>/dev/null)"; then
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

  if ! windows="$(eww_query list-windows 2>/dev/null)"; then
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

wait_for_value() {
  local name="$1"
  local expected="$2"
  local attempt=0
  local value

  [[ "$STATE_ATTEMPTS" =~ ^[1-9][0-9]*$ ]] ||
    fail "EWW_STATE_ATTEMPTS must be a positive integer"

  while ((attempt < STATE_ATTEMPTS)); do
    if value="$(eww_query get "$name" 2>/dev/null)" &&
      [[ "$value" == "$expected" ]]; then
      return 0
    fi

    attempt=$((attempt + 1))
    sleep "$STATE_DELAY"
  done

  return 1
}

update_and_confirm() {
  local name="$1"
  local expected="$2"
  local error_output
  local status

  shift 2
  error_output="$(eww_call update "$@" 2>&1 >/dev/null)"
  status=$?

  if wait_for_value "$name" "$expected"; then
    return 0
  fi

  [[ -z "$error_output" ]] || printf '%s\n' "$error_output" >&2
  ((status == 0)) && return 1
  return "$status"
}

open_window() {
  local error_output=""
  local position
  local size
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

  size="$(window_size "$window")"
  position="$(window_position "$window")"
  if [[ -n "$size" && -n "$position" ]]; then
    eww_open_async open --screen "$(target_screen)" --size "$size" --pos "$position" "$window"
  elif [[ -n "$size" ]]; then
    eww_open_async open --screen "$(target_screen)" --size "$size" "$window"
  else
    eww_open_async open --screen "$(target_screen)" "$window"
  fi
  status=$?

  if wait_for_window_state "$window" open; then
    sleep "${EWW_WINDOW_CONSTRUCTION_SETTLE:-0.15}"
    return 0
  fi

  [[ -z "$error_output" ]] || printf '%s\n' "$error_output" >&2
  ((status == 0)) && return 1
  return "$status"
}

close_window() {
  local error_output
  local window="$1"
  local status

  window_is_open "$window"
  status=$?
  if ((status != 0)); then
    ((status == 1)) && return 0
    return 1
  fi

  error_output="$(eww_call close "$window" 2>&1 >/dev/null)"
  status=$?

  if wait_for_window_state "$window" closed; then
    return 0
  fi

  [[ -z "$error_output" ]] || printf '%s\n' "$error_output" >&2
  ((status == 0)) && return 1
  return "$status"
}

open_dismiss_layer() {
  open_window "$DISMISS_WINDOW"
}

close_dismiss_layer() {
  close_window "$DISMISS_WINDOW"
}

context_window_is_open() {
  local surface
  local flyout
  local window
  local status

  for surface in control performance insights; do
    window="$(window_for_surface "$surface")"
    window_is_open "$window"
    status=$?

    ((status == 0)) && return 0
    ((status == 2)) && return 2
  done

  for flyout in volume tray; do
    window="$(window_for_flyout "$flyout")"
    window_is_open "$window"
    status=$?

    ((status == 0)) && return 0
    ((status == 2)) && return 2
  done

  return 1
}

close_dismiss_layer_if_idle() {
  local status

  context_window_is_open
  status=$?

  if ((status == 0)); then
    return 0
  fi
  ((status == 1)) || return 1

  close_dismiss_layer
}

snapshot_active_windows() {
  ACTIVE_WINDOWS_SNAPSHOT="$(eww_query active-windows 2>/dev/null)" ||
    return 1
}

snapshot_has_window() {
  local target="$1"
  local line

  while IFS= read -r line; do
    [[ "${line#*: }" == "$target" ]] && return 0
  done <<<"${ACTIVE_WINDOWS_SNAPSHOT:-}"

  return 1
}

fast_publish() {
  local expected_name="$1"
  local expected_value="$2"
  local error_output
  local attempt
  local status

  shift 2
  for attempt in 1 2 3; do
    error_output="$(eww_call update "$@" 2>&1 >/dev/null)"
    status=$?

    if ((status == 0)) || wait_for_value "$expected_name" "$expected_value"; then
      return 0
    fi
    sleep 0.10
  done

  [[ -z "$error_output" ]] || printf '%s\n' "$error_output" >&2
  return "$status"
}

fast_mutate_windows() {
  local error_output
  local status

  if [[ "${1:-}" == "open" ]]; then
    eww_open_async "$@"
    return $?
  fi

  # Opening and closing windows is not idempotent. Retrying after a slow GTK
  # response can duplicate a mutation while the first request is still being
  # applied, so rely on the bounded client timeout and reconcile afterward.
  error_output="$(eww_call "$@" 2>&1 >/dev/null)"
  status=$?
  if ((status == 0)); then
    FAST_MUTATION_ERROR=""
    return 0
  fi

  FAST_MUTATION_ERROR="$error_output"
  return "$status"
}

disarm_dismiss() {
  printf '%s-%s\n' "$(date +%s%N)" "$$" >"$DISMISS_TOKEN_FILE"
  fast_publish dismiss_armed false dismiss_armed=false
}

arm_dismiss() {
  # Do not let the pointer release that opened a context hit the new backdrop.
  local token
  token="$(date +%s%N)-$$"
  printf '%s\n' "$token" >"$DISMISS_TOKEN_FILE"
  (
    exec 9>&-
    sleep "${EWW_DISMISS_ARM_DELAY:-0.35}"
    [[ "$(cat "$DISMISS_TOKEN_FILE" 2>/dev/null)" == "$token" ]] || exit 0
    [[ "$(get_value active_surface none)" != none || "$(get_value active_flyout none)" != none ]] || exit 0
    fast_publish dismiss_armed true dismiss_armed=true
  ) >/dev/null 2>&1 &
}

current_context_window() {
  local surface="$1"
  local flyout="$2"

  if [[ "$flyout" != "none" ]]; then
    window_for_flyout "$flyout"
  elif [[ "$surface" != "none" ]]; then
    window_for_surface "$surface"
  else
    return 1
  fi
}

verify_context_open() {
  local target="$1"
  local window

  snapshot_active_windows || return 1
  snapshot_has_window "$DISMISS_WINDOW" || return 1
  snapshot_has_window "$target" || return 1

  for window in actioncenter performance insights volume-flyout tray-flyout; do
    [[ "$window" == "$target" ]] && continue
    snapshot_has_window "$window" && return 1
  done

  return 0
}

wait_for_context_open() {
  local target="$1"
  local attempt
  local attempts="${EWW_CONTEXT_VERIFY_ATTEMPTS:-40}"
  local delay="${EWW_CONTEXT_VERIFY_DELAY:-0.10}"

  for ((attempt = 1; attempt <= attempts; attempt++)); do
    verify_context_open "$target" && return 0
    sleep "$delay"
  done
  return 1
}

verify_context_closed() {
  local window

  snapshot_active_windows || return 1

  for window in \
    "$DISMISS_WINDOW" \
    actioncenter \
    performance \
    insights \
    volume-flyout \
    tray-flyout; do
    snapshot_has_window "$window" && return 1
  done

  return 0
}

wait_for_context_closed() {
  local attempt
  local attempts="${EWW_CONTEXT_VERIFY_ATTEMPTS:-40}"
  local delay="${EWW_CONTEXT_VERIFY_DELAY:-0.10}"

  for ((attempt = 1; attempt <= attempts; attempt++)); do
    verify_context_closed && return 0
    sleep "$delay"
  done
  return 1
}

fast_activate_context() {
  local desired_surface="$1"
  local desired_flyout="$2"
  local target="$3"
  local current_surface="$4"
  local current_flyout="$5"
  local section_mapping="${6:-}"
  local current_window=""
  local close_status=0
  local open_status=0
  local expected_name="active_surface"
  local expected_value="$desired_surface"
  local screen
  local size
  local position

  is_surface "$desired_surface" ||
    fail "Desired surface is not allowlisted: $desired_surface"
  is_flyout "$desired_flyout" ||
    fail "Desired flyout is not allowlisted: $desired_flyout"
  is_surface "$current_surface" ||
    fail "Current surface is not allowlisted: $current_surface"
  is_flyout "$current_flyout" ||
    fail "Current flyout is not allowlisted: $current_flyout"

  disarm_dismiss
  screen="$(target_screen)"
  size="$(window_size "$target")"
  position="$(window_position "$target")"

  if [[ "$desired_surface" == "none" ]]; then
    expected_name="active_flyout"
    expected_value="$desired_flyout"
  fi

  current_window="$(current_context_window "$current_surface" "$current_flyout" 2>/dev/null || true)"

  if [[ -n "$current_window" && "$current_window" != "$target" ]]; then
    fast_mutate_windows close "$current_window" || close_status=$?
    # GTK/Eww can drop its application channel when a window is destroyed and
    # its replacement is constructed in the same scheduling slice.
    sleep "${EWW_SURFACE_SWITCH_SETTLE:-0.18}"
  fi

  if [[ "$current_window" != "$target" ]]; then
    if [[ -z "$current_window" ]]; then
      fast_mutate_windows open --screen "$screen" "$DISMISS_WINDOW" || open_status=$?
      if ((open_status == 0)); then
        if [[ -n "$size" && -n "$position" ]]; then
          fast_mutate_windows open --screen "$screen" --size "$size" --pos "$position" "$target" || open_status=$?
        elif [[ -n "$size" ]]; then
          fast_mutate_windows open --screen "$screen" --size "$size" "$target" || open_status=$?
        else
          fast_mutate_windows open --screen "$screen" "$target" || open_status=$?
        fi
      fi
    else
      if [[ -n "$size" && -n "$position" ]]; then
        fast_mutate_windows open --screen "$screen" --size "$size" --pos "$position" "$target" || open_status=$?
      elif [[ -n "$size" ]]; then
        fast_mutate_windows open --screen "$screen" --size "$size" "$target" || open_status=$?
      else
        fast_mutate_windows open --screen "$screen" "$target" || open_status=$?
      fi
    fi
  fi

  if ((open_status == 0)) && [[ "$current_window" != "$target" ]]; then
    wait_for_window_state "$target" open || open_status=$?
    ((open_status == 0)) && sleep "${EWW_WINDOW_CONSTRUCTION_SETTLE:-0.15}"
  fi

  if [[ -n "$section_mapping" ]]; then
    fast_publish "$expected_name" "$expected_value" \
      "active_surface=$desired_surface" \
      "active_flyout=$desired_flyout" \
      pending_action=none \
      "$section_mapping" ||
      return 1
  else
    fast_publish "$expected_name" "$expected_value" \
      "active_surface=$desired_surface" \
      "active_flyout=$desired_flyout" \
      pending_action=none ||
      return 1
  fi

  if wait_for_context_open "$target"; then
    arm_dismiss
    return 0
  fi

  ((close_status == 0 && open_status == 0)) ||
    [[ -z "${FAST_MUTATION_ERROR:-}" ]] ||
    printf '%s\n' "$FAST_MUTATION_ERROR" >&2

  reconcile_surface
}

fast_close_context() {
  local target="$1"
  local state_name="$2"
  local current_surface="$3"
  local current_flyout="$4"
  local close_status=0

  is_surface "$current_surface" ||
    fail "Current surface is not allowlisted: $current_surface"
  is_flyout "$current_flyout" ||
    fail "Current flyout is not allowlisted: $current_flyout"

  disarm_dismiss
  fast_mutate_windows close "$target" "$DISMISS_WINDOW" || close_status=$?
  fast_publish "$state_name" none \
    active_surface=none \
    active_flyout=none \
    pending_action=none ||
    return 1

  if wait_for_context_closed; then
    return 0
  fi

  ((close_status == 0)) ||
    [[ -z "${FAST_MUTATION_ERROR:-}" ]] ||
    printf '%s\n' "$FAST_MUTATION_ERROR" >&2

  set_none
}

fast_toggle_control() {
  local requested="$1"
  local current_surface="$2"
  local current_flyout="$3"
  local current_section="$4"

  is_control_section "$requested" ||
    fail "Control Centre section is not allowlisted: $requested"
  is_control_section "$current_section" ||
    fail "Current Control Centre section is not allowlisted: $current_section"

  if [[ "$current_surface" == "control" && "$current_section" == "$requested" ]]; then
    fast_close_context actioncenter active_surface "$current_surface" "$current_flyout"
  elif [[ "$current_surface" == "control" && "$current_flyout" == "none" ]]; then
    fast_publish active_surface control \
      active_surface=control \
      active_flyout=none \
      pending_action=none \
      "control_section=$requested"
  else
    fast_activate_context \
      control none actioncenter "$current_surface" "$current_flyout" \
      "control_section=$requested"
  fi
}

fast_toggle_insights() {
  local current_surface="$1"
  local current_flyout="$2"
  local section="$3"

  is_insights_section "$section" ||
    fail "Insights section is not allowlisted: $section"

  if [[ "$current_surface" == "insights" ]]; then
    fast_close_context insights active_surface "$current_surface" "$current_flyout"
  else
    fast_activate_context \
      insights none insights "$current_surface" "$current_flyout" \
      "insights_section=$section"
  fi
}

fast_toggle_performance() {
  local current_surface="$1"
  local current_flyout="$2"

  if [[ "$current_surface" == "performance" ]]; then
    fast_close_context performance active_surface "$current_surface" "$current_flyout"
  else
    fast_activate_context \
      performance none performance "$current_surface" "$current_flyout"
  fi
}

fast_toggle_flyout() {
  local requested="$1"
  local current_surface="$2"
  local current_flyout="$3"
  local target

  is_flyout "$requested" && [[ "$requested" != "none" ]] ||
    fail "Flyout is not allowlisted: $requested"

  target="$(window_for_flyout "$requested")"

  if [[ "$current_flyout" == "$requested" ]]; then
    fast_close_context "$target" active_flyout "$current_surface" "$current_flyout"
  else
    fast_activate_context \
      none "$requested" "$target" "$current_surface" "$current_flyout"
  fi
}

fast_dismiss_active() {
  local current_surface="${1:-none}"
  local current_flyout="${2:-none}"
  local window
  local -a windows=()
  local close_status=0

  is_surface "$current_surface" ||
    fail "Current surface is not allowlisted: $current_surface"
  is_flyout "$current_flyout" ||
    fail "Current flyout is not allowlisted: $current_flyout"

  disarm_dismiss
  snapshot_active_windows ||
    fail "Unable to query contextual windows"

  for window in \
    actioncenter \
    performance \
    insights \
    volume-flyout \
    tray-flyout \
    "$DISMISS_WINDOW"; do
    snapshot_has_window "$window" && windows+=("$window")
  done

  if ((${#windows[@]} > 0)); then
    fast_mutate_windows close "${windows[@]}" || close_status=$?
  fi

  fast_publish active_surface none \
    active_surface=none \
    active_flyout=none \
    pending_action=none ||
    {
      dismiss_active
      return
    }

  wait_for_context_closed && return 0

  ((close_status == 0)) ||
    [[ -z "${FAST_MUTATION_ERROR:-}" ]] ||
    printf '%s\n' "$FAST_MUTATION_ERROR" >&2
  set_none
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

close_all_flyouts() {
  local flyout
  local window

  for flyout in volume tray; do
    window="$(window_for_flyout "$flyout")"
    close_window "$window" || return 1
  done

  update_and_confirm active_flyout none active_flyout=none
}

set_none() {
  disarm_dismiss
  close_all_surfaces || return 1
  close_all_flyouts || return 1
  close_dismiss_layer || return 1
  update_and_confirm active_surface none \
    active_surface=none \
    active_flyout=none \
    pending_action=none &&
    wait_for_value active_flyout none
}

activate_control() {
  local section="$1"

  is_control_section "$section" ||
    fail "Control Centre section is not allowlisted: $section"

  disarm_dismiss
  close_all_flyouts || return 1
  close_other_surfaces "control" || return 1
  update_and_confirm active_surface none \
    active_surface=none \
    active_flyout=none \
    pending_action=none \
    "control_section=$section" ||
    return 1
  wait_for_value control_section "$section" || return 1

  if ! open_dismiss_layer; then
    eww_call update active_surface=none >/dev/null 2>&1
    return 1
  fi

  if ! open_window actioncenter; then
    close_dismiss_layer >/dev/null 2>&1
    eww_call update active_surface=none >/dev/null 2>&1
    return 1
  fi

  if ! update_and_confirm active_surface control \
    active_surface=control "control_section=$section" ||
    ! wait_for_value control_section "$section"; then
    close_window actioncenter >/dev/null 2>&1
    close_dismiss_layer >/dev/null 2>&1
    eww_call update active_surface=none >/dev/null 2>&1
    return 1
  fi
  arm_dismiss
}

activate_insights() {
  local section="$1"

  is_insights_section "$section" ||
    fail "Insights section is not allowlisted: $section"

  disarm_dismiss
  close_all_flyouts || return 1
  close_other_surfaces "insights" || return 1
  update_and_confirm active_surface none \
    active_surface=none \
    active_flyout=none \
    pending_action=none \
    "insights_section=$section" ||
    return 1
  wait_for_value insights_section "$section" || return 1

  if ! open_dismiss_layer; then
    eww_call update active_surface=none >/dev/null 2>&1
    return 1
  fi

  if ! open_window insights; then
    close_dismiss_layer >/dev/null 2>&1
    eww_call update active_surface=none >/dev/null 2>&1
    return 1
  fi

  if ! update_and_confirm active_surface insights \
    active_surface=insights "insights_section=$section" ||
    ! wait_for_value insights_section "$section"; then
    close_window insights >/dev/null 2>&1
    close_dismiss_layer >/dev/null 2>&1
    eww_call update active_surface=none >/dev/null 2>&1
    return 1
  fi
  arm_dismiss
}

activate_performance() {
  disarm_dismiss
  close_all_flyouts || return 1
  close_other_surfaces "performance" || return 1
  update_and_confirm active_surface none \
    active_surface=none \
    active_flyout=none \
    pending_action=none ||
    return 1

  if ! open_dismiss_layer; then
    eww_call update active_surface=none >/dev/null 2>&1
    return 1
  fi

  if ! open_window performance; then
    close_dismiss_layer >/dev/null 2>&1
    eww_call update active_surface=none >/dev/null 2>&1
    return 1
  fi

  if ! update_and_confirm active_surface performance \
    active_surface=performance; then
    close_window performance >/dev/null 2>&1
    close_dismiss_layer >/dev/null 2>&1
    eww_call update active_surface=none >/dev/null 2>&1
    return 1
  fi
  arm_dismiss
}

activate_flyout() {
  local flyout="$1"
  local window

  is_flyout "$flyout" && [[ "$flyout" != "none" ]] ||
    fail "Flyout is not allowlisted: $flyout"

  disarm_dismiss
  window="$(window_for_flyout "$flyout")"

  close_all_surfaces || return 1
  close_all_flyouts || return 1
  update_and_confirm active_surface none \
    active_surface=none \
    active_flyout=none \
    pending_action=none ||
    return 1
  wait_for_value active_flyout none || return 1

  if ! open_dismiss_layer; then
    eww_call update active_flyout=none >/dev/null 2>&1
    return 1
  fi

  if ! open_window "$window"; then
    close_dismiss_layer >/dev/null 2>&1
    eww_call update active_flyout=none >/dev/null 2>&1
    return 1
  fi

  if ! update_and_confirm active_flyout "$flyout" \
    "active_flyout=$flyout"; then
    close_window "$window" >/dev/null 2>&1
    close_dismiss_layer >/dev/null 2>&1
    eww_call update active_flyout=none >/dev/null 2>&1
    return 1
  fi
  arm_dismiss
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

  disarm_dismiss
  close_window "$window" || return 1

  if [[ "$active" == "$surface" ]]; then
    update_and_confirm active_surface none \
      active_surface=none pending_action=none ||
      return 1
  fi

  close_dismiss_layer_if_idle
}

close_flyout() {
  local flyout="$1"
  local active
  local window

  is_flyout "$flyout" && [[ "$flyout" != "none" ]] ||
    fail "Flyout is not allowlisted: $flyout"

  active="$(validated_flyout)"
  window="$(window_for_flyout "$flyout")"

  disarm_dismiss
  close_window "$window" || return 1

  if [[ "$active" == "$flyout" ]]; then
    update_and_confirm active_flyout none \
      active_flyout=none pending_action=none ||
      return 1
  fi

  close_dismiss_layer_if_idle
}

toggle_control() {
  local requested="$1"
  local current
  local open_status

  is_control_section "$requested" ||
    fail "Control Centre section is not allowlisted: $requested"

  current="$(validated_control_section)"
  window_is_open actioncenter
  open_status=$?
  ((open_status == 2)) &&
    fail "Unable to query the Control Centre window state"

  if [[ "$current" == "$requested" && $open_status -eq 0 ]]; then
    close_surface control
  elif ((open_status == 0)); then
    open_dismiss_layer &&
      update_and_confirm active_surface control \
        active_surface=control \
        active_flyout=none \
        pending_action=none \
        "control_section=$requested" &&
      wait_for_value control_section "$requested"
  else
    activate_control "$requested"
  fi
}

toggle_performance() {
  local open_status

  window_is_open performance
  open_status=$?
  ((open_status == 2)) &&
    fail "Unable to query the Performance Dashboard window state"

  if ((open_status == 0)); then
    close_surface performance
  else
    activate_performance
  fi
}

toggle_insights() {
  local section
  local open_status

  section="$(validated_insights_section)"
  window_is_open insights
  open_status=$?
  ((open_status == 2)) &&
    fail "Unable to query the Senomy Insights window state"

  if ((open_status == 0)); then
    close_surface insights
  else
    activate_insights "$section"
  fi
}

toggle_volume() {
  local open_status

  window_is_open volume-flyout
  open_status=$?
  ((open_status == 2)) &&
    fail "Unable to query the volume flyout window state"

  if ((open_status == 0)); then
    close_flyout volume
  else
    activate_flyout volume
  fi
}

toggle_tray() {
  local open_status

  window_is_open tray-flyout
  open_status=$?
  ((open_status == 2)) &&
    fail "Unable to query the tray flyout window state"

  if ((open_status == 0)); then
    close_flyout tray
  else
    activate_flyout tray
  fi
}

dismiss_active() {
  local active
  local flyout
  local status
  local surface
  local window

  disarm_dismiss
  active="$(validated_flyout)"
  if [[ "$active" != "none" ]]; then
    close_flyout "$active"
    return
  fi

  for flyout in volume tray; do
    window="$(window_for_flyout "$flyout")"
    window_is_open "$window"
    status=$?

    ((status == 2)) &&
      fail "Unable to query transient flyout window state"

    if ((status == 0)); then
      close_window "$window" || return 1
    fi
  done

  active="$(validated_surface)"
  if [[ "$active" != "none" ]]; then
    close_surface "$active"
    return
  fi

  for surface in control performance insights; do
    window="$(window_for_surface "$surface")"
    window_is_open "$window"
    status=$?

    ((status == 2)) &&
      fail "Unable to query primary surface window state"

    if ((status == 0)); then
      close_window "$window" || return 1
    fi
  done

  update_and_confirm active_surface none \
    active_surface=none \
    active_flyout=none \
    pending_action=none ||
    return 1
  wait_for_value active_flyout none || return 1
  close_dismiss_layer
}

ensure_main_bar() {
  local status
  if window_is_open main-bar; then
    return 0
  else
    status=$?
  fi
  ((status == 1)) || fail "Unable to query main-bar state"
  open_window main-bar || fail "Unable to restore main-bar"
}

reconcile_surface() {
  local active
  local flyout
  local control_section
  local insights_section
  local performance_section

  active="$(validated_surface)"
  flyout="$(validated_flyout)"
  control_section="$(validated_control_section)"
  insights_section="$(validated_insights_section)"
  performance_section="$(validated_performance_section)"

  ensure_main_bar

  if [[ "$active" != "none" ]]; then
    close_all_flyouts ||
      fail "Unable to close stale flyouts"
  elif [[ "$flyout" != "none" ]]; then
    activate_flyout "$flyout" ||
      fail "Unable to reconcile the transient flyout"
    return
  fi

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
      update_and_confirm performance_section "$performance_section" \
        "performance_section=$performance_section" ||
        fail "Unable to restore the Performance section"
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

  if ! window_is_defined "$DISMISS_WINDOW"; then
    fail "$DISMISS_WINDOW is not defined"
  fi

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
  local screen
  local size

  screen="$(target_screen)"
  eww_start_call open --screen "$screen" main-bar >/dev/null 2>&1 ||
    fail "Unable to start Eww with the main bar"
  wait_for_daemon

  wait_for_window_state main-bar open ||
    fail "main-bar did not open after restart"

  (exec 9>&-; "$EWW_CONFIG/scripts/workspaces.sh" --publish-once) >/dev/null 2>&1 &

  if [[ "$active" != "none" ]]; then
    target="$(window_for_surface "$active")"
    size="$(window_size "$target")"
    eww_call open --screen "$screen" "$DISMISS_WINDOW" >/dev/null 2>&1 ||
      fail "Unable to restore the dismiss layer"
    if [[ -n "$size" ]]; then
      eww_call open --screen "$screen" --size "$size" "$target" >/dev/null 2>&1 ||
        fail "Unable to restore the primary window"
    else
      eww_call open --screen "$screen" "$target" >/dev/null 2>&1 ||
        fail "Unable to restore the primary window"
    fi
    wait_for_window_state "$DISMISS_WINDOW" open ||
      fail "The dismiss layer did not open after restart"
    wait_for_window_state "$target" open ||
      fail "The restored primary window did not open after restart"
  fi
}

preflight_reload() {
  local attempt compiled error_output status
  command -v sassc >/dev/null 2>&1 || fail "sassc is required for safe reload validation"
  compiled="$(mktemp "${TMPDIR:-/tmp}/senomyos-eww.XXXXXX.css")" || fail "Unable to create SCSS preflight output"
  if ! sassc -t compressed "$EWW_CONFIG/eww.scss" "$compiled"; then
    rm -f "$compiled"
    fail "SCSS preflight failed; the running bar was left untouched"
  fi
  rm -f "$compiled"

  error_output="$(eww_call reload 2>&1 >/dev/null)"
  status=$?
  if ((status != 0)); then
    [[ -z "$error_output" ]] || printf '%s\n' "$error_output" >&2
    fail "Eww/Yuck preflight failed; the running daemon was not restarted"
  fi
  for attempt in {1..30}; do
    window_is_defined main-bar && return 0
    sleep 0.10
  done
  fail "Preflight configuration does not define main-bar"
}

snapshot_last_known_good() {
  local compiled archive_tmp checksum_tmp
  mkdir -p -m 700 "$STATE_ROOT" 2>/dev/null || return 0
  compiled="$STATE_ROOT/eww.css"
  sassc -t compressed "$EWW_CONFIG/eww.scss" "$compiled" 2>/dev/null || return 0
  install -m 600 "$EWW_CONFIG/eww.scss" "$STATE_ROOT/eww.scss"
  install -m 600 "$EWW_CONFIG/eww.yuck" "$STATE_ROOT/eww.yuck"
  chmod 600 "$compiled"
  printf '%(%s)T\n' -1 >"$STATE_ROOT/validated-at"
  chmod 600 "$STATE_ROOT/validated-at"

  archive_tmp="$(mktemp "$STATE_ROOT/senomyos-shell.XXXXXX.tar.gz")" || return 0
  if ! tar -C "$EWW_CONFIG" --exclude='scripts/__pycache__' -czf "$archive_tmp" \
    eww.yuck eww.scss windows widgets sections scripts data assets wiki systemd hyprland.conf; then
    rm -f "$archive_tmp"
    return 0
  fi
  chmod 600 "$archive_tmp"
  mv -f "$archive_tmp" "$STATE_ROOT/senomyos-shell.tar.gz"
  checksum_tmp="$(mktemp "$STATE_ROOT/senomyos-shell.XXXXXX.sha256")" || return 0
  (cd "$STATE_ROOT" && sha256sum senomyos-shell.tar.gz) >"$checksum_tmp" || {
    rm -f "$checksum_tmp"
    return 0
  }
  chmod 600 "$checksum_tmp"
  mv -f "$checksum_tmp" "$STATE_ROOT/senomyos-shell.sha256"
}

reload_and_restore() {
  local active
  local control_section
  local insights_section
  local performance_section
  local timeline_source
  local timeline_follow

  active="$(validated_surface)"
  control_section="$(validated_control_section)"
  insights_section="$(validated_insights_section)"
  performance_section="$(validated_performance_section)"
  timeline_source="$(validated_timeline_source)"
  timeline_follow="$(validated_timeline_follow)"

  preflight_reload

  if ! validate_reload_surface "$active"; then
    active=none
  fi

  eww_call close-all >/dev/null 2>&1 ||
    fail "Unable to close Eww windows before restart"
  eww_call kill >/dev/null 2>&1 ||
    fail "Unable to stop the Eww daemon"
  wait_for_daemon_stop

  start_reload_windows "$active"

  update_and_confirm active_surface "$active" \
    "active_surface=$active" \
    "active_flyout=none" \
    "pending_action=none" \
    "control_section=$control_section" \
    "insights_section=$insights_section" \
    "performance_section=$performance_section" \
    "timeline_source=$timeline_source" \
    "timeline_follow=$timeline_follow" ||
    fail "Unable to restore Eww section state"
  wait_for_value active_flyout none ||
    fail "Unable to verify restored flyout state"

  if [[ "$active" != "none" ]]; then
    arm_dismiss
  else
    disarm_dismiss
  fi
  snapshot_last_known_good
}

print_status() {
  printf 'active_surface=%s\n' "$(validated_surface)"
  printf 'active_flyout=%s\n' "$(validated_flyout)"
  printf 'control_section=%s\n' "$(validated_control_section)"
  printf 'insights_section=%s\n' "$(validated_insights_section)"
  printf 'performance_section=%s\n' "$(validated_performance_section)"
  printf 'timeline_source=%s\n' "$(validated_timeline_source)"
  printf 'timeline_follow=%s\n' "$(validated_timeline_follow)"
  printf '%s\n' 'active_windows:'
  eww_query active-windows
}

record_surface_transition() {
  local status="$1" target="none" outcome="succeeded"
  ((status == 0)) || outcome="failed"

  case "$ACTION" in
    toggle-control | show-control) target="${ACTION_TARGET:-overview}" ;;
    show-insights) target="${ACTION_TARGET:-briefing}" ;;
    close) target="${ACTION_TARGET:-surface}" ;;
    toggle-insights) target="insights" ;;
    toggle-performance | show-performance) target="performance" ;;
    toggle-volume) target="volume" ;;
    toggle-tray) target="tray" ;;
    dismiss) target="active" ;;
    reload) target="eww" ;;
    *) return 0 ;;
  esac

  "$EVENT_BIN" record surface "$ACTION" "$target" "$outcome" >/dev/null 2>&1 || true
}

finalize_transition() {
  local status="$1"

  trap - EXIT
  record_surface_transition "$status"
  exit "$status"
}

trap 'finalize_transition $?' EXIT

case "$ACTION" in
  help | --help | -h)
    usage
    ;;
  status)
    require_daemon
    print_status
    ;;
  size)
    [[ $# -eq 2 ]] || fail "size requires one window"
    case "$2" in actioncenter | insights | performance | volume-flyout | tray-flyout) ;; *) fail "Window is not allowlisted: $2" ;; esac
    window_size "$2"
    ;;
  toggle-control)
    [[ $# -eq 2 || $# -eq 5 ]] ||
      fail "toggle-control requires a section and optional current state"
    if [[ $# -eq 5 ]]; then require_client; else require_daemon; fi
    acquire_lock
    if [[ $# -eq 5 ]]; then
      fast_toggle_control "$2" "$3" "$4" "$5"
    else
      toggle_control "$2"
    fi
    ;;
  toggle-insights)
    [[ $# -eq 1 || $# -eq 4 ]] ||
      fail "toggle-insights accepts optional current state"
    if [[ $# -eq 4 ]]; then require_client; else require_daemon; fi
    acquire_lock
    if [[ $# -eq 4 ]]; then
      fast_toggle_insights "$2" "$3" "$4"
    else
      toggle_insights
    fi
    ;;
  toggle-performance)
    [[ $# -eq 1 || $# -eq 3 ]] ||
      fail "toggle-performance accepts optional current state"
    if [[ $# -eq 3 ]]; then require_client; else require_daemon; fi
    acquire_lock
    if [[ $# -eq 3 ]]; then
      fast_toggle_performance "$2" "$3"
    else
      toggle_performance
    fi
    ;;
  toggle-volume)
    [[ $# -eq 1 || $# -eq 3 ]] ||
      fail "toggle-volume accepts optional current state"
    if [[ $# -eq 3 ]]; then require_client; else require_daemon; fi
    acquire_lock
    if [[ $# -eq 3 ]]; then
      fast_toggle_flyout volume "$2" "$3"
    else
      toggle_volume
    fi
    ;;
  toggle-tray)
    [[ $# -eq 1 || $# -eq 3 ]] ||
      fail "toggle-tray accepts optional current state"
    if [[ $# -eq 3 ]]; then require_client; else require_daemon; fi
    acquire_lock
    if [[ $# -eq 3 ]]; then
      fast_toggle_flyout tray "$2" "$3"
    else
      toggle_tray
    fi
    ;;
  show-control)
    [[ $# -eq 2 || $# -eq 4 ]] ||
      fail "show-control requires a section and optional current state"
    if [[ $# -eq 4 ]]; then require_client; else require_daemon; fi
    acquire_lock
    if [[ $# -eq 4 ]]; then
      is_control_section "$2" ||
        fail "Control Centre section is not allowlisted: $2"
      fast_activate_context \
        control none actioncenter "$3" "$4" "control_section=$2"
    else
      activate_control "$2"
    fi
    ;;
  show-insights)
    [[ $# -le 2 || $# -eq 4 ]] ||
      fail "show-insights accepts a section and optional current state"
    if [[ $# -eq 4 ]]; then require_client; else require_daemon; fi
    acquire_lock
    if [[ $# -eq 4 ]]; then
      is_insights_section "$2" ||
        fail "Insights section is not allowlisted: $2"
      fast_activate_context \
        insights none insights "$3" "$4" "insights_section=$2"
    else
      activate_insights "${2:-$(validated_insights_section)}"
    fi
    ;;
  show-performance)
    [[ $# -eq 1 || $# -eq 3 ]] ||
      fail "show-performance accepts optional current state"
    if [[ $# -eq 3 ]]; then require_client; else require_daemon; fi
    acquire_lock
    if [[ $# -eq 3 ]]; then
      fast_activate_context performance none performance "$2" "$3"
    else
      activate_performance
    fi
    ;;
  close)
    [[ $# -eq 2 || $# -eq 4 ]] ||
      fail "close requires a surface and optional current state"
    if [[ $# -eq 4 ]]; then require_client; else require_daemon; fi
    acquire_lock
    if [[ $# -eq 4 ]]; then
      case "$2" in
        control)
          fast_close_context actioncenter active_surface "$3" "$4"
          ;;
        insights | performance)
          fast_close_context "$2" active_surface "$3" "$4"
          ;;
        *)
          fail "Surface is not allowlisted: $2"
          ;;
      esac
    else
      close_surface "$2"
    fi
    ;;
  dismiss)
    [[ $# -eq 1 || $# -eq 3 ]] ||
      fail "dismiss accepts optional current state"
    require_client
    acquire_lock
    fast_dismiss_active "${2:-none}" "${3:-none}"
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
