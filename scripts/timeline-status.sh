#!/usr/bin/env bash

# Emit a bounded, sanitized event timeline for Senomy Insights. This collector
# is read-only and accepts only the explicit source names below.

set -u

export LC_ALL=C

readonly MODE="${1:-activity}"
readonly LIMIT="${SENOMY_TIMELINE_LIMIT:-40}"
readonly USER_NAME="${USER:-unknown}"
readonly USER_HOME="${HOME:-/nonexistent}"

printf -v observed_at '%(%s)T' -1

emit_error() {
  local source="$1"
  local code="$2"
  local message="$3"

  jq -nc \
    --argjson observed_at "$observed_at" \
    --arg source "$source" \
    --arg mode "$MODE" \
    --arg code "$code" \
    --arg message "$message" \
    '{
      schema_version: 1,
      ok: false,
      source: $source,
      observed_at: $observed_at,
      data: {
        mode: $mode,
        limit: 0,
        count: 0,
        entries: []
      },
      error: {
        code: $code,
        message: $message
      }
    }'
  exit 0
}

if ! command -v jq >/dev/null 2>&1; then
  printf \
    '{"schema_version":1,"ok":false,"source":"timeline","observed_at":%s,"data":{"mode":"%s","limit":0,"count":0,"entries":[]},"error":{"code":"dependency_missing","message":"Required command jq is unavailable"}}\n' \
    "$observed_at" "$MODE"
  exit 0
fi

[[ "$LIMIT" =~ ^[1-9][0-9]*$ ]] ||
  emit_error "timeline" "invalid_configuration" "Timeline limit must be a positive integer"

((LIMIT <= 100)) ||
  emit_error "timeline" "invalid_configuration" "Timeline limit cannot exceed 100 entries"

emit_journal() {
  local source="$1"
  shift
  local journal_json

  command -v journalctl >/dev/null 2>&1 ||
    emit_error "$source" "dependency_missing" "Required command journalctl is unavailable"

  journal_json="$("$@" 2>/dev/null)" ||
    emit_error "$source" "source_unavailable" "The selected journal source is unavailable"

  jq -sc \
    --argjson observed_at "$observed_at" \
    --argjson limit "$LIMIT" \
    --arg source "$source" \
    --arg mode "$MODE" \
    --arg user_home "$USER_HOME" \
    --arg user_name "$USER_NAME" \
    '
      def priority_name:
        (.PRIORITY // "6" | tostring) as $priority
        | if $priority == "0" then "emergency"
          elif $priority == "1" then "alert"
          elif $priority == "2" then "critical"
          elif $priority == "3" then "error"
          elif $priority == "4" then "warning"
          elif $priority == "5" then "notice"
          elif $priority == "7" then "debug"
          else "info"
          end;

      def source_name:
        (
          ._SYSTEMD_USER_UNIT
          // ._SYSTEMD_UNIT
          // .SYSLOG_IDENTIFIER
          // ._COMM
          // "unknown"
        )
        | tostring
        | .[0:64];

      def message_text:
        (
          if (.MESSAGE | type) == "string" then
            .MESSAGE
          elif (.MESSAGE | type) == "array" then
            "[binary journal message]"
          else
            "No message"
          end
        )
        | tostring
        | explode
        | map(if . < 32 or . == 127 then 32 else . end)
        | implode
        | gsub("  +"; " ")
        | gsub($user_home; "$HOME")
        | gsub("/home/" + $user_name; "$HOME")
        | if test("(?i)(password|passwd|secret|token|authorization:|cookie:)") then
            "[redacted potentially sensitive entry]"
          else
            .
          end
        | .[0:240];

      def event_time:
        (
          (.__REALTIME_TIMESTAMP // "0" | tonumber? // 0) / 1000000
        ) as $seconds
        | {
            date: ($seconds | strftime("%Y-%m-%d")),
            time: ($seconds | strftime("%H:%M:%S"))
          };

      map(
        (event_time) as $event_time
        | {
            id: (
              (.__REALTIME_TIMESTAMP // "0")
              + "-"
              + (._PID // "0")
              + "-"
              + (.__SEQNUM // "0")
            ),
            date: $event_time.date,
            time: $event_time.time,
            severity: priority_name,
            source: source_name,
            title: source_name,
            message: message_text
          }
      )
      | reverse
      | {
          schema_version: 1,
          ok: true,
          source: $source,
          observed_at: $observed_at,
          data: {
            mode: $mode,
            limit: $limit,
            count: length,
            entries: .
          },
          error: null
        }
    ' <<< "$journal_json"
}

emit_activity() {
  local event_file="${SENOMY_STATE_HOME:-${XDG_STATE_HOME:-"$USER_HOME/.local/state"}/senomyos}/activity.jsonl"
  local activity_json='[]'

  if [[ -r "$event_file" ]]; then
    activity_json="$(tail -n "$LIMIT" "$event_file" 2>/dev/null | jq -sc 'map(select(type == "object"))')" ||
      emit_error "senomy-activity" "source_unavailable" "Unable to read the Senomy activity journal"
  fi

  jq -nc --argjson observed_at "$observed_at" --argjson limit "$LIMIT" \
    --arg mode "$MODE" --argjson events "$activity_json" '
      def words: gsub("[-_.]"; " ");
      def title: words | split(" ") | map(if length > 0 then (.[0:1] | ascii_upcase) + .[1:] else . end) | join(" ");
      $events | reverse | map(
        (.epoch // 0) as $epoch
        | {
            id: ("activity-" + ($epoch | tostring) + "-" + (.event // "event")),
            date: ($epoch | strftime("%Y-%m-%d")),
            time: ($epoch | strftime("%H:%M:%S")),
            severity: (if .outcome == "failed" then "error" elif .outcome == "requested" then "notice" else "info" end),
            source: ("senomy/" + (.category // "shell")),
            title: ((.event // "event") | title),
            message: (((.event // "event") | words) + " // " + ((.target // "none") | words) + " // " + (.outcome // "succeeded"))
          }
      ) | {
        schema_version: 1, ok: true, source: "senomy-activity", observed_at: $observed_at,
        data: {mode: $mode, limit: $limit, count: length, entries: .}, error: null
      }
    '
}

case "$MODE" in
  activity)
    emit_activity
    ;;
  session | user)
    emit_journal \
      "journalctl-session" \
      journalctl --user -n "$LIMIT" -o json --no-pager
    ;;
  system)
    emit_journal \
      "journalctl-system" \
      journalctl -n "$LIMIT" -o json --no-pager
    ;;
  kernel)
    emit_journal \
      "journalctl-kernel" \
      journalctl -k -n "$LIMIT" -o json --no-pager
    ;;
  *)
    emit_error "timeline" "invalid_source" "Timeline source is not allowlisted"
    ;;
esac
