#!/usr/bin/env bash

# Bounded, privacy-safe SenomyOS interaction journal. It records allowlisted
# shell events, never keystrokes, arbitrary commands, credentials, or content.
set -u
export LC_ALL=C

readonly ACTION="${1:-help}"
readonly CATEGORY="${2:-shell}"
readonly EVENT="${3:-unknown}"
readonly TARGET="${4:-none}"
readonly OUTCOME="${5:-succeeded}"
readonly STATE_ROOT="${SENOMY_STATE_HOME:-${XDG_STATE_HOME:-${HOME:-/nonexistent}/.local/state}/senomyos}"
readonly EVENT_FILE="$STATE_ROOT/activity.jsonl"
readonly LOCK_FILE="$STATE_ROOT/activity.lock"
readonly MAX_ENTRIES="${SENOMY_EVENT_LIMIT:-500}"

valid_token() { [[ "$1" =~ ^[a-z0-9][a-z0-9._-]{0,63}$ ]]; }

if [[ "$ACTION" == path ]]; then printf '%s\n' "$EVENT_FILE"; exit 0; fi
[[ "$ACTION" == record ]] || exit 2
valid_token "$CATEGORY" && valid_token "$EVENT" && valid_token "$TARGET" || exit 2
case "$OUTCOME" in succeeded | failed | requested | cancelled) ;; *) exit 2 ;; esac
[[ "$MAX_ENTRIES" =~ ^[1-9][0-9]*$ ]] && ((MAX_ENTRIES <= 2000)) || exit 2
command -v jq >/dev/null 2>&1 && command -v flock >/dev/null 2>&1 || exit 1

mkdir -p -m 700 "$STATE_ROOT" || exit 1
touch "$EVENT_FILE" || exit 1
chmod 600 "$EVENT_FILE" 2>/dev/null || true
exec 9>"$LOCK_FILE" || exit 1
flock -w 1 9 || exit 1

epoch="$(date +%s)"
jq -nc --argjson epoch "$epoch" --arg timestamp "$(date --iso-8601=seconds)" \
  --arg category "$CATEGORY" --arg event "$EVENT" --arg target "$TARGET" --arg outcome "$OUTCOME" \
  '{epoch:$epoch,timestamp:$timestamp,category:$category,event:$event,target:$target,outcome:$outcome}' >>"$EVENT_FILE"

line_count="$(wc -l <"$EVENT_FILE")"
if ((line_count > MAX_ENTRIES)); then
  temporary="$EVENT_FILE.tmp.$$"
  tail -n "$MAX_ENTRIES" "$EVENT_FILE" >"$temporary" && mv "$temporary" "$EVENT_FILE"
fi
