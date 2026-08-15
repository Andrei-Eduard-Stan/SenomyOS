#!/usr/bin/env bash

# Record a bounded, private copy of SwayNC notification metadata for Senomy
# Insights. Notification bodies may contain personal information, so the cache
# is mode 0600, never uploaded, and deliberately excludes actions and hints.
set -euo pipefail
export LC_ALL=C.UTF-8
umask 077

readonly ACTION="${1:-read}"
readonly STATE_ROOT="${SENOMY_NOTIFICATION_ROOT:-${XDG_STATE_HOME:-$HOME/.local/state}/senomyos/notifications}"
readonly HISTORY_FILE="$STATE_ROOT/history.jsonl"
readonly LOCK_FILE="$STATE_ROOT/history.lock"
readonly HISTORY_LIMIT="${SENOMY_NOTIFICATION_LIMIT:-120}"
readonly USER_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/swaync/config.json"

fail() {
  printf 'SenomyOS notifications: %s\n' "$*" >&2
  exit 1
}

require_limit() {
  [[ "$HISTORY_LIMIT" =~ ^[1-9][0-9]*$ ]] && ((HISTORY_LIMIT <= 500)) ||
    fail "SENOMY_NOTIFICATION_LIMIT must be between 1 and 500"
}

sanitize() {
  local value="${1:-}" limit="${2:-512}"
  [[ "$value" == "(null)" ]] && value=""
  jq -rRn --arg value "$value" --argjson limit "$limit" '
    $value
    | gsub("<[^>]*>"; " ")
    | explode
    | map(if (. < 32 or . == 127) then 32 else . end)
    | implode
    | gsub("[[:space:]]+"; " ")
    | sub("^ "; "")
    | sub(" $"; "")
    | .[0:$limit]
  '
}

capture() {
  local app summary body urgency category desktop_entry notification_id replaces_id
  local received_at entry temporary keep

  require_limit
  mkdir -p -m 700 "$STATE_ROOT"
  touch "$HISTORY_FILE" "$LOCK_FILE"
  chmod 600 "$HISTORY_FILE" "$LOCK_FILE"

  app="$(sanitize "${SWAYNC_APP_NAME:-Unknown application}" 96)"
  summary="$(sanitize "${SWAYNC_SUMMARY:-Notification}" 180)"
  body="$(sanitize "${SWAYNC_BODY:-}" 700)"
  category="$(sanitize "${SWAYNC_CATEGORY:-}" 96)"
  desktop_entry="$(sanitize "${SWAYNC_DESKTOP_ENTRY:-}" 128)"
  urgency="${SWAYNC_URGENCY:-Normal}"
  urgency="${urgency,,}"
  case "$urgency" in low | normal | critical) ;; *) urgency="normal" ;; esac
  notification_id="${SWAYNC_ID:-0}"
  replaces_id="${SWAYNC_REPLACES_ID:-0}"
  [[ "$notification_id" =~ ^[0-9]+$ ]] || notification_id=0
  [[ "$replaces_id" =~ ^[0-9]+$ ]] || replaces_id=0
  printf -v received_at '%(%s)T' -1

  entry="$(jq -nc \
    --argjson received_at "$received_at" \
    --argjson notification_id "$notification_id" \
    --argjson replaces_id "$replaces_id" \
    --arg app "$app" --arg summary "$summary" --arg body "$body" \
    --arg urgency "$urgency" --arg category "$category" \
    --arg desktop_entry "$desktop_entry" '
      {
        schema_version: 1,
        received_at: $received_at,
        notification_id: $notification_id,
        replaces_id: $replaces_id,
        app: (if $app == "" then "Unknown application" else $app end),
        summary: (if $summary == "" then "Notification" else $summary end),
        body: $body,
        urgency: $urgency,
        category: $category,
        desktop_entry: $desktop_entry
      }
    ')"

  exec 9>"$LOCK_FILE"
  flock -w 2 9 || fail "notification history is busy"
  temporary="$(mktemp "$STATE_ROOT/.history.XXXXXX")"
  keep=$((HISTORY_LIMIT - 1))
  if ((keep > 0)) && [[ -s "$HISTORY_FILE" ]]; then
    tail -n "$keep" "$HISTORY_FILE" >"$temporary"
  fi
  printf '%s\n' "$entry" >>"$temporary"
  chmod 600 "$temporary"
  mv -f "$temporary" "$HISTORY_FILE"
}

read_status() {
  local observed_at provider_available=false capture_configured=false dnd=false
  local active_count=0 entries='[]' candidate

  require_limit
  printf -v observed_at '%(%s)T' -1
  if command -v swaync-client >/dev/null 2>&1; then
    provider_available=true
    candidate="$(timeout 0.4s swaync-client --count 2>/dev/null || printf 0)"
    [[ "$candidate" =~ ^[0-9]+$ ]] && active_count="$candidate"
    [[ "$(timeout 0.4s swaync-client --get-dnd 2>/dev/null || printf false)" == true ]] && dnd=true
  fi
  if [[ -r "$USER_CONFIG" ]] && jq -e '
      .scripts["senomy-history"].exec
      | type == "string" and contains("notification-history.sh")
    ' "$USER_CONFIG" >/dev/null 2>&1; then
    capture_configured=true
  fi
  if [[ -s "$HISTORY_FILE" ]]; then
    entries="$(jq -sc --argjson now "$observed_at" '
      map(select(type == "object" and (.received_at | type == "number")))
      | reverse
      | map(
          . + {
            category: (if .category == "(null)" then "" else (.category // "") end),
            received_label: (.received_at | localtime | strftime("%Y-%m-%d %H:%M:%S")),
            age_seconds: ([0, ($now - .received_at)] | max),
            age_label: (
              ([0, ($now - .received_at)] | max) as $age
              | if $age < 60 then "JUST NOW"
                elif $age < 3600 then "\(($age / 60) | floor)M AGO"
                elif $age < 86400 then "\(($age / 3600) | floor)H AGO"
                else "\(($age / 86400) | floor)D AGO"
                end
            )
          }
        )
    ' "$HISTORY_FILE" 2>/dev/null || printf '[]')"
  fi

  jq -nc --argjson at "$observed_at" \
    --argjson provider_available "$provider_available" \
    --argjson capture_configured "$capture_configured" \
    --argjson active_count "$active_count" --argjson dnd "$dnd" \
    --argjson limit "$HISTORY_LIMIT" --argjson entries "$entries" '
      {
        schema_version: 1,
        ok: true,
        source: "swaync+senomy-private-history",
        observed_at: $at,
        data: {
          provider: "SwayNotificationCenter",
          provider_available: $provider_available,
          capture_configured: $capture_configured,
          active_count: $active_count,
          do_not_disturb: $dnd,
          retained_count: ($entries | length),
          retention_limit: $limit,
          entries: $entries,
          privacy: {
            local_only: true,
            file_mode: "0600",
            actions_stored: false,
            hints_stored: false,
            automatic_upload: false
          }
        },
        error: null
      }
    '
}

clear_history() {
  mkdir -p -m 700 "$STATE_ROOT"
  touch "$LOCK_FILE"
  chmod 600 "$LOCK_FILE"
  exec 9>"$LOCK_FILE"
  flock -w 2 9 || fail "notification history is busy"
  : >"$HISTORY_FILE"
  chmod 600 "$HISTORY_FILE"
  read_status
}

case "$ACTION" in
  capture) capture ;;
  read | status) read_status ;;
  clear) clear_history ;;
  *) fail "usage: notification-history.sh [capture|read|clear]" ;;
esac
