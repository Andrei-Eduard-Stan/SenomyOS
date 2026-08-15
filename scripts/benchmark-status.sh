#!/usr/bin/env bash
set -u
export LC_ALL=C
runtime="${SENOMY_BENCHMARK_ROOT:-${XDG_STATE_HOME:-$HOME/.local/state}/senomyos/benchmarks}"
status="$runtime/status.json"; log="$runtime/current.log"
valid_status=false
if [[ -s "$status" ]] && jq -e '.schema_version == 2 and .source == "senomy-benchmark"' "$status" >/dev/null 2>&1; then
  base="$(cat "$status")"
  valid_status=true
else
  base='{"schema_version":2,"ok":true,"source":"senomy-benchmark","observed_at":0,"data":{"state":"idle","state_label":"READY","progress":0,"stage":"none","message":"No benchmark has run yet.","profile":"none","estimated_seconds":0,"thermal_limit_c":95,"started_at":0,"finished_at":0,"markdown_path":"","pdf_path":"","results":{}},"error":null}'
fi
logs='[]'
if [[ "$valid_status" == true && -r "$log" ]]; then
  logs="$(tail -n 28 "$log" | jq -Rsc 'split("\n")|map(select(length>0))')"
fi
jq -nc --argjson base "$base" --argjson logs "$logs" '$base | .data.logs=$logs'
