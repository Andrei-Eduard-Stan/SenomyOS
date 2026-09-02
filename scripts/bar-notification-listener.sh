#!/usr/bin/env bash

# Publish a cheap event-driven SwayNotificationCenter summary for the Rail.

set -uo pipefail
export LC_ALL=C

readonly SWAYNC_CLIENT_BIN="${SENOMY_SWAYNC_CLIENT_BIN:-/usr/bin/swaync-client}"
readonly JQ_BIN="${SENOMY_JQ_BIN:-/usr/bin/jq}"

emit_unavailable() {
  local code="$1" message="$2"
  "$JQ_BIN" -nc \
    --arg code "$code" \
    --arg message "$message" \
    '{
      schema_version: 1,
      ok: false,
      source: "swaync-client",
      observed_at: now,
      data: {
        available: false,
        count: 0,
        dnd: false,
        visible: false,
        inhibited: false
      },
      error: {code: $code, message: $message}
    }'
}

if [[ ! -x "$JQ_BIN" ]]; then
  printf '%s\n' '{"schema_version":1,"ok":false,"source":"missing-jq","observed_at":0,"data":{"available":false,"count":0,"dnd":false,"visible":false,"inhibited":false},"error":{"code":"dependency_missing","message":"jq is unavailable"}}'
  exit 0
fi

if [[ ! -x "$SWAYNC_CLIENT_BIN" ]]; then
  emit_unavailable "dependency_missing" "SwayNotificationCenter is unavailable"
  exit 0
fi

while true; do
  "$SWAYNC_CLIENT_BIN" --subscribe 2>/dev/null |
    "$JQ_BIN" --unbuffered -c '
      select(type == "object")
      | {
          schema_version: 1,
          ok: true,
          source: "swaync-client",
          observed_at: now,
          data: {
            available: true,
            count: ((.count // 0) | if type == "number" and . >= 0 then floor else 0 end),
            dnd: ((.dnd // false) == true),
            visible: ((.visible // false) == true),
            inhibited: ((.inhibited // false) == true)
          },
          error: null
        }'

  emit_unavailable "provider_unavailable" "SwayNotificationCenter event stream is unavailable"
  sleep 2
done
