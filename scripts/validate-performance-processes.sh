#!/usr/bin/env bash

# Validate bounded process inspection and exact-identity termination without
# signalling any pre-existing desktop or user application.

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
runtime_root="$(mktemp -d)"
test_pid=""

cleanup() {
  if [[ -n "$test_pid" ]] && kill -0 "$test_pid" 2>/dev/null; then
    kill -TERM "$test_pid" 2>/dev/null || true
    wait "$test_pid" 2>/dev/null || true
  fi
  rm -rf -- "$runtime_root"
}
trap cleanup EXIT

export XDG_RUNTIME_DIR="$runtime_root"

detail="$($repo_root/scripts/performance-process-detail.sh $$)"
jq -e --argjson pid "$$" '.ok and .data.pid == $pid and (.data.start_ticks | type == "number")' <<<"$detail" >/dev/null

if "$repo_root/scripts/performance-action.sh" terminate-exact "$$" 0 >/dev/null 2>&1; then
  printf 'stale process identity was accepted\n' >&2
  exit 1
fi

sleep 30 &
test_pid=$!
test_detail="$($repo_root/scripts/performance-process-detail.sh "$test_pid")"
test_start="$(jq -er '.data.start_ticks' <<<"$test_detail")"
"$repo_root/scripts/performance-action.sh" terminate-exact "$test_pid" "$test_start" >/dev/null
wait "$test_pid" 2>/dev/null || true
if kill -0 "$test_pid" 2>/dev/null; then
  printf 'disposable process remained after exact SIGTERM\n' >&2
  exit 1
fi
test_pid=""

for sort_mode in cpu memory name; do
  SENOMY_PROCESS_SAMPLE_DELAY=0.01 "$repo_root/scripts/performance-processes.sh" "$sort_mode" \
    | jq -e '.ok and (.data.processes | type == "array") and (.data.shown_count <= 12)' >/dev/null
done

for filter_mode in all user active heavy; do
  "$repo_root/scripts/performance-action.sh" set-filter "$filter_mode" >/dev/null
  SENOMY_PROCESS_SAMPLE_DELAY=0.01 "$repo_root/scripts/performance-processes.sh" cpu \
    | jq -e '.ok and (.data.processes | type == "array")' >/dev/null
done

printf 'performance process contract: pass\n'
