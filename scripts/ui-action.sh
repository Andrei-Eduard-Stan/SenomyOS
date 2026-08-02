#!/usr/bin/env bash

# Validated Eww navigation updates with structured activity recording.
set -u

readonly ACTION="${1:-help}"
readonly VALUE="${2:-none}"
readonly EWW_BIN="${EWW_BIN:-/usr/bin/eww}"
readonly EWW_CONFIG="${EWW_CONFIG:-${XDG_CONFIG_HOME:-${HOME:-/nonexistent}/.config}/eww}"
readonly EVENT_BIN="$EWW_CONFIG/scripts/senomy-event.sh"

update_and_record() {
  local variable="$1" category="$2" event="$3" outcome=failed
  "$EWW_BIN" --config "$EWW_CONFIG" update "$variable=$VALUE" && outcome=succeeded
  "$EVENT_BIN" record "$category" "$event" "$VALUE" "$outcome" >/dev/null 2>&1 || true
  [[ "$outcome" == succeeded ]]
}

case "$ACTION" in
  insights-section)
    case "$VALUE" in briefing | timeline | updates | diagnostics | console | reports | wiki) ;; *) exit 2 ;; esac
    update_and_record insights_section navigation insights-section ;;
  timeline-source)
    case "$VALUE" in activity | session | system | kernel | eww) ;; *) exit 2 ;; esac
    update_and_record timeline_source timeline source ;;
  timeline-follow)
    case "$VALUE" in true | false) ;; *) exit 2 ;; esac
    update_and_record timeline_follow timeline follow ;;
  control-section)
    case "$VALUE" in overview | network | audio | power | calendar | input | devices | apps | appearance | settings) ;; *) exit 2 ;; esac
    update_and_record control_section navigation control-section ;;
  performance-section)
    case "$VALUE" in overview | cpu | memory | storage | network | processes | benchmarks) ;; *) exit 2 ;; esac
    update_and_record performance_section navigation performance-section ;;
  *) exit 2 ;;
esac
