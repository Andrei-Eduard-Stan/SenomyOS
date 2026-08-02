#!/usr/bin/env bash
set -u
export LC_ALL=C
runtime="${XDG_STATE_HOME:-$HOME/.local/state}/senomyos/benchmarks"
status="$runtime/status.json"; log="$runtime/current.log"
if [[ -s "$status" ]] && jq -e . "$status" >/dev/null 2>&1; then base="$(cat "$status")"; else
  base='{"schema_version":1,"ok":true,"source":"benchmark","observed_at":0,"data":{"state":"idle","state_label":"READY","progress":0,"stage":"none","message":"No benchmark has run yet.","started_at":0,"finished_at":0,"markdown_path":"","pdf_path":""},"error":null}'
fi
logs='[]'; [[ -r "$log" ]] && logs="$(tail -n 18 "$log" | jq -Rsc 'split("\n")|map(select(length>0))')"
jq -nc --argjson base "$base" --argjson logs "$logs" '$base | .data.logs=$logs'
