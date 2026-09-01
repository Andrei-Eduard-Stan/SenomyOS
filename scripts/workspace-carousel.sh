#!/usr/bin/env bash

# Move or reconcile the bounded Rail workspace viewport. Hyprland remains the
# sole workspace source; this helper owns only the transient viewport offset.

set -euo pipefail
export LC_ALL=C

readonly EWW_BIN="${SENOMY_EWW_BIN:-/usr/bin/eww}"
readonly FLOCK_BIN="${SENOMY_FLOCK_BIN:-/usr/bin/flock}"
readonly JQ_BIN="${SENOMY_JQ_BIN:-/usr/bin/jq}"
readonly EWW_CONFIG="${SENOMY_EWW_CONFIG:-${XDG_CONFIG_HOME:-"$HOME/.config"}/eww}"
readonly FIXTURE_STATE="${SENOMY_WORKSPACE_CAROUSEL_STATE_JSON:-}"
readonly FIXTURE_LAYOUT="${SENOMY_WORKSPACE_CAROUSEL_LAYOUT_JSON:-}"
readonly FIXTURE_OFFSET="${SENOMY_WORKSPACE_CAROUSEL_OFFSET:-}"
readonly FIXTURE_DIRECTION="${SENOMY_WORKSPACE_CAROUSEL_DIRECTION:-next}"
readonly FIXTURE_SLOT="${SENOMY_WORKSPACE_CAROUSEL_SLOT:-0}"

fail() {
  printf 'SenomyOS workspace carousel: %s\n' "$1" >&2
  exit 1
}

usage() {
  printf 'Usage: %s previous|next|reconcile|scroll up|down|left|right\n' "$0" >&2
  exit 2
}

[[ $# -ge 1 && $# -le 2 ]] || usage

action="$1"
case "$action" in
  previous | next | reconcile)
    [[ $# -eq 1 ]] || usage
    ;;
  scroll)
    [[ $# -eq 2 ]] || usage
    case "$2" in
      up | left) action="previous" ;;
      down | right) action="next" ;;
      *) usage ;;
    esac
    ;;
  *)
    usage
    ;;
esac

for command_path in "$JQ_BIN"; do
  [[ -x "$command_path" ]] || fail "required command is unavailable: $command_path"
done

fixture_mode=false
if [[ -n "$FIXTURE_STATE" || -n "$FIXTURE_LAYOUT" || -n "$FIXTURE_OFFSET" ]]; then
  fixture_mode=true
  [[ -n "$FIXTURE_STATE" && -n "$FIXTURE_LAYOUT" && -n "$FIXTURE_OFFSET" ]] ||
    fail "fixture state, layout, and offset must be supplied together"
  state_json="$FIXTURE_STATE"
  layout_json="$FIXTURE_LAYOUT"
  offset="$FIXTURE_OFFSET"
  direction="$FIXTURE_DIRECTION"
  slot="$FIXTURE_SLOT"
else
  [[ -x "$EWW_BIN" ]] || fail "eww is unavailable"
  [[ -x "$FLOCK_BIN" ]] || fail "flock is unavailable"

  runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$EUID}"
  [[ -d "$runtime_dir" ]] || fail "runtime directory is unavailable"
  lock_path="$runtime_dir/senomyos-workspace-carousel.lock"
  exec {lock_fd}>"$lock_path"
  # Arrow clicks and touchpad events can arrive as a short burst. Queue them
  # behind one transaction instead of letting concurrent Eww reads observe a
  # half-updated page-buffer tuple.
  "$FLOCK_BIN" -w 5 "$lock_fd" || fail "carousel update is busy"

  read_eww_value() {
    local variable_name="$1"
    local value=""
    local attempt

    for attempt in 1 2 3; do
      if value="$(
        "$EWW_BIN" --no-daemonize --config "$EWW_CONFIG" get "$variable_name" 2>/dev/null
      )" && [[ -n "$value" ]]; then
        printf '%s\n' "$value"
        return 0
      fi
      sleep 0.02
    done

    return 1
  }

  state_json="$(
    read_eww_value workspace_state
  )" || fail "workspace state is unavailable"
  layout_json="$(
    read_eww_value bar_layout
  )" || fail "bar layout is unavailable"
  offset="$(
    read_eww_value workspace_carousel_offset
  )" || offset=0
  direction="$(
    read_eww_value workspace_carousel_direction
  )" || direction="next"
  slot="$(
    read_eww_value workspace_carousel_slot
  )" || slot=0
fi

"$JQ_BIN" -e 'type == "object"' >/dev/null <<<"$state_json" ||
  fail "workspace state is invalid"
"$JQ_BIN" -e 'type == "object"' >/dev/null <<<"$layout_json" ||
  fail "bar layout is invalid"

[[ "$offset" =~ ^[0-9]+$ ]] || offset=0
case "$direction" in
  previous | next) ;;
  *) direction="next" ;;
esac
case "$slot" in
  0 | 1) ;;
  *) slot=0 ;;
esac

result_json="$(
  "$JQ_BIN" -cn \
    --argjson state "$state_json" \
    --argjson layout "$layout_json" \
    --argjson current_offset "$offset" \
    --argjson current_slot "$slot" \
    --arg current_direction "$direction" \
    --arg action "$action" '
      def clamp($value; $minimum; $maximum):
        if $value < $minimum then $minimum
        elif $value > $maximum then $maximum
        else $value
        end;

      ($state.data.workspaces // []) as $all_workspaces
      | (
          if ($layout.data.phone // false) then
            [$all_workspaces[] | select(.active == true)]
          elif ($layout.data.narrow // false) then
            [$all_workspaces[] | select(.active == true or .occupied == true)]
          else
            $all_workspaces
          end
        ) as $workspaces
      | (if ($layout.data.phone // false) then 1 else 4 end) as $capacity
      | ($workspaces | length) as $count
      | ([range(0; $count) | select($workspaces[.].active == true)][0] // -1) as $active_index
      | (($count - $capacity) | if . > 0 then . else 0 end) as $max_offset
      | clamp($current_offset; 0; $max_offset) as $clamped_offset
      | (
          if $action == "previous" then
            clamp($clamped_offset - 1; 0; $max_offset)
          elif $action == "next" then
            clamp($clamped_offset + 1; 0; $max_offset)
          elif $count <= $capacity then
            0
          elif $active_index < 0 then
            $clamped_offset
          elif $active_index < $clamped_offset then
            $active_index
          elif $active_index >= ($clamped_offset + $capacity) then
            clamp($active_index - $capacity + 1; 0; $max_offset)
          else
            $clamped_offset
          end
        ) as $next_offset
      # A workspace removal can make the stored offset invalid even when the
      # reconciled offset equals the clamped value. Compare against the stored
      # value so Eww actually receives the correction and cannot retain a
      # short/blank end page.
      | ($next_offset != $current_offset) as $offset_changed
      | (
          if $next_offset < $clamped_offset then "previous"
          elif $next_offset > $clamped_offset then "next"
          else $current_direction
          end
        ) as $next_direction
      | {
          offset: $next_offset,
          previous_offset: $clamped_offset,
          slot: (if $offset_changed then (1 - $current_slot) else $current_slot end),
          direction: $next_direction,
          capacity: $capacity,
          count: $count,
          max_offset: $max_offset,
          active_index: $active_index,
          overflow: ($count > $capacity),
          changed: $offset_changed
        }
    '
)" || fail "unable to calculate carousel state"

if [[ "$fixture_mode" == true ]]; then
  printf '%s\n' "$result_json"
  exit 0
fi

next_offset="$("$JQ_BIN" -r '.offset' <<<"$result_json")"
previous_offset="$("$JQ_BIN" -r '.previous_offset' <<<"$result_json")"
next_slot="$("$JQ_BIN" -r '.slot' <<<"$result_json")"
next_direction="$("$JQ_BIN" -r '.direction' <<<"$result_json")"
changed="$("$JQ_BIN" -r '.changed' <<<"$result_json")"

if [[ "$changed" == true ]]; then
  "$EWW_BIN" --no-daemonize --config "$EWW_CONFIG" update \
    "workspace_carousel_previous_offset=$previous_offset" \
    "workspace_carousel_offset=$next_offset" \
    "workspace_carousel_slot=$next_slot" \
    "workspace_carousel_direction=$next_direction" >/dev/null ||
    fail "unable to update the carousel viewport"
fi
