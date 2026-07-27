#!/usr/bin/env bash

# Emit a bounded, sanitized event timeline for Senomy Insights. This collector
# is read-only and accepts only the explicit source names below.

set -u

export LC_ALL=C

readonly MODE="${1:-user}"
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

emit_eww() {
  local cache_root="${XDG_CACHE_HOME:-"$USER_HOME/.cache"}/eww"
  local log_file
  local log_text

  log_file="$(
    find "$cache_root" -maxdepth 1 -type f -name 'eww_*.log' \
      -printf '%T@ %p\n' 2>/dev/null |
      sort -nr |
      head -n 1 |
      cut -d' ' -f2-
  )"

  [[ -n "$log_file" && -r "$log_file" ]] ||
    emit_error "eww-log" "source_unavailable" "No readable Eww log is available"

  log_text="$(tail -n "$LIMIT" "$log_file" 2>/dev/null)" ||
    emit_error "eww-log" "source_unavailable" "Unable to read the Eww log"

  jq -Rsc \
    --argjson observed_at "$observed_at" \
    --argjson limit "$LIMIT" \
    --arg mode "$MODE" \
    --arg user_home "$USER_HOME" \
    --arg user_name "$USER_NAME" \
    '
      def sanitize:
        explode
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

      split("\n")
      | map(select(length > 0))
      | to_entries
      | map({
          id: ("eww-" + (.key | tostring)),
          date: (
            if (.value | length) >= 10 then .value[0:10] else "unknown" end
          ),
          time: (
            if (.value | length) >= 20 then .value[11:19] else "--:--:--" end
          ),
          severity: (
            if (.value | test(" ERROR ")) then "error"
            elif (.value | test(" WARN ")) then "warning"
            elif (.value | test(" DEBUG ")) then "debug"
            else "info"
            end
          ),
          source: "eww",
          message: (.value | sanitize)
        })
      | reverse
      | {
          schema_version: 1,
          ok: true,
          source: "eww-log",
          observed_at: $observed_at,
          data: {
            mode: $mode,
            limit: $limit,
            count: length,
            entries: .
          },
          error: null
        }
    ' <<< "$log_text"
}

case "$MODE" in
  user)
    emit_journal \
      "journalctl-user" \
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
  eww)
    emit_eww
    ;;
  *)
    emit_error "timeline" "invalid_source" "Timeline source is not allowlisted"
    ;;
esac
