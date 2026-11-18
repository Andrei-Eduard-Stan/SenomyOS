#!/usr/bin/env bash
set -u
export LC_ALL=C
runtime="${SENOMY_BENCHMARK_ROOT:-${XDG_STATE_HOME:-$HOME/.local/state}/senomyos/benchmarks}"
status="$runtime/status.json"; log="$runtime/current.log"; pid_file="$runtime/runner.pid"
valid_status=false
if [[ -s "$status" ]] && jq -e '.schema_version == 2 and .source == "senomy-benchmark"' "$status" >/dev/null 2>&1; then
  base="$(cat "$status")"
  valid_status=true
else
  base='{"schema_version":2,"ok":true,"source":"senomy-benchmark","observed_at":0,"data":{"state":"idle","state_label":"READY","progress":0,"stage":"none","message":"No benchmark has run yet.","profile":"none","estimated_seconds":0,"thermal_limit_c":95,"started_at":0,"finished_at":0,"markdown_path":"","pdf_path":"","results":{}},"error":null}'
fi

# A killed session can leave the last atomic status at "running". Validate the
# private runner PID and its command before presenting that state; PID reuse
# must never make an unrelated process look like a live benchmark.
if [[ "$(jq -r '.data.state // ""' <<<"$base")" == running ]]; then
  runner_pid=""
  [[ -r "$pid_file" ]] && read -r runner_pid <"$pid_file"
  runner_args=""
  if [[ "$runner_pid" =~ ^[1-9][0-9]*$ ]]; then
    runner_args="$(ps -p "$runner_pid" -o args= 2>/dev/null || true)"
  fi
  if [[ "$runner_args" != *"benchmark-action.sh run"* ]]; then
    base="$(
      jq --argjson observed_at "$(date +%s)" '
        .observed_at = $observed_at
        | .data.state = "interrupted"
        | .data.state_label = "INTERRUPTED"
        | .data.finished_at = $observed_at
        | .data.message = "The recorded benchmark runner is no longer active. Partial measurements were not published."
      ' <<<"$base"
    )"
  fi
fi
logs='[]'
if [[ "$valid_status" == true && -r "$log" ]]; then
  logs="$(tail -n 28 "$log" | jq -Rsc 'split("\n")|map(select(length>0))')"
fi
jq -nc --argjson base "$base" --argjson logs "$logs" '$base | .data.logs=$logs'
