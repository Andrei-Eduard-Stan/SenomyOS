#!/usr/bin/env bash

# Execute every read-only Insights task against isolated state and assert that
# each one reaches a bounded, truthful terminal result.
set -euo pipefail
export LC_ALL=C

readonly CONFIG_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly TEST_ROOT="$(mktemp -d /tmp/senomy-insights-actions.XXXXXX)"
trap 'rm -rf "$TEST_ROOT"' EXIT
mkdir -p "$TEST_ROOT/cache"

pass=0
while IFS= read -r task; do
  if [[ "$task" == "bluetooth" ]] && ! busctl --user list --no-legend --no-pager >/dev/null 2>&1; then
    continue
  fi
  cache="$TEST_ROOT/cache/console-$task.json"
  SENOMY_CONSOLE_CACHE="$cache" SENOMY_CONSOLE_TIMEOUT=3 \
    SENOMY_EWW_BIN=/usr/bin/false EWW_CONFIG="$CONFIG_DIR" \
    "$CONFIG_DIR/scripts/console-status.sh" run "$task" >/dev/null 2>&1 || true
  payload="$(SENOMY_CONSOLE_CACHE="$cache" "$CONFIG_DIR/scripts/console-status.sh" read)"
  jq -e --arg task "$task" '
    .data.task_id == $task
    and (.data.state | IN("ready","failed"))
    and (.data.exit_code | type == "number")
    and (.data.output | type == "array" and length <= 80)
  ' >/dev/null <<<"$payload"
  pass=$((pass + 1))
done < <("$CONFIG_DIR/scripts/console-status.sh" catalog | jq -r '.data.tasks[].id')

while IFS= read -r task; do
  cache="$TEST_ROOT/cache/diagnostics-$task.json"
  SENOMY_DIAGNOSTICS_CACHE="$cache" SENOMY_DIAGNOSTICS_TIMEOUT=3 \
    "$CONFIG_DIR/scripts/diagnostics-status.sh" run "$task" >/dev/null 2>&1 || true
  payload="$(SENOMY_DIAGNOSTICS_CACHE="$cache" "$CONFIG_DIR/scripts/diagnostics-status.sh" read)"
  jq -e --arg task "$task" '
    .data.task_id == $task
    and (.data.state | IN("ready","succeeded","failed","unavailable"))
    and (.data.output | type == "array" and length <= 60)
  ' >/dev/null <<<"$payload"
  pass=$((pass + 1))
done < <("$CONFIG_DIR/scripts/diagnostics-status.sh" catalog | jq -r '.data.tasks[].id')

printf 'SenomyOS Insights actions: %d bounded tasks reached terminal state.\n' "$pass"
