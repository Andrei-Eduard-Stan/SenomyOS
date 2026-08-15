#!/usr/bin/env bash

# Emit one bounded, truthful MPRIS snapshot for the Senomy companion.

set -u

export LC_ALL=C

readonly PLAYERCTL_BIN="${PLAYERCTL_BIN:-/usr/bin/playerctl}"
readonly JQ_BIN="${JQ_BIN:-/usr/bin/jq}"

clean_text() {
  tr '\r\n\t' '   ' | cut -c 1-160
}

emit() {
  local provider_available="$1" session_available="$2" status="$3"
  local player="$4" artist="$5" title="$6" message="$7"
  local observed_at

  observed_at="$(date +%s)"
  "$JQ_BIN" -cn \
    --argjson observed_at "$observed_at" \
    --argjson provider_available "$provider_available" \
    --argjson session_available "$session_available" \
    --arg status "$status" \
    --arg player "$player" \
    --arg artist "$artist" \
    --arg title "$title" \
    --arg message "$message" '
      {
        schema_version: 1,
        ok: true,
        source: "playerctl-mpris",
        observed_at: $observed_at,
        data: {
          provider_available: $provider_available,
          session_available: $session_available,
          playing: ($status == "playing"),
          status: $status,
          player: $player,
          artist: $artist,
          title: $title,
          message: $message
        },
        error: null
      }'
}

if [[ ! -x "$JQ_BIN" ]]; then
  printf '{"schema_version":1,"ok":false,"source":"playerctl-mpris","observed_at":0,"data":null,"error":{"code":"dependency_missing","message":"jq is unavailable"}}\n'
  exit 0
fi

if [[ ! -x "$PLAYERCTL_BIN" ]]; then
  emit false false unavailable "" "" "" "Media controls are unavailable on this device."
  exit 0
fi

mapfile -t players < <("$PLAYERCTL_BIN" -l 2>/dev/null | sed '/^[[:space:]]*$/d' | head -n 24)
if ((${#players[@]} == 0)); then
  emit true false stopped "" "" "" "No MPRIS media session is currently available."
  exit 0
fi

selected="${players[0]}"
selected_status=""
for player_name in "${players[@]}"; do
  candidate_status="$("$PLAYERCTL_BIN" --player "$player_name" status 2>/dev/null || true)"
  if [[ "${candidate_status,,}" == playing ]]; then
    selected="$player_name"
    selected_status="$candidate_status"
    break
  fi
done

[[ -n "$selected_status" ]] || selected_status="$("$PLAYERCTL_BIN" --player "$selected" status 2>/dev/null || printf Stopped)"
status="${selected_status,,}"
case "$status" in playing | paused | stopped) ;; *) status="stopped" ;; esac

artist="$("$PLAYERCTL_BIN" --player "$selected" metadata --format '{{artist}}' 2>/dev/null | clean_text || true)"
title="$("$PLAYERCTL_BIN" --player "$selected" metadata --format '{{title}}' 2>/dev/null | clean_text || true)"
player_label="$(printf '%s' "$selected" | clean_text)"

case "$status" in
  playing) message="Music is playing // listening quietly" ;;
  paused) message="Media is paused // standing by" ;;
  *) message="Media session detected // currently stopped" ;;
esac

emit true true "$status" "$player_label" "$artist" "$title" "$message"
