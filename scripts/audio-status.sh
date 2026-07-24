#!/usr/bin/env bash

# Emit normalized, read-only audio state for the SenomyOS bar, Control Centre,
# and Device Management. The collector never changes volume, mute, or routes.

set -u

export LC_ALL=C

printf -v observed_at '%(%s)T' -1

if ! command -v jq >/dev/null 2>&1; then
  printf \
    '{"schema_version":1,"ok":false,"source":"pactl","observed_at":%s,"data":null,"error":{"code":"dependency_missing","message":"Required command jq is unavailable"}}\n' \
    "$observed_at"
  exit 0
fi

emit_error() {
  local code="$1"
  local message="$2"

  jq -nc \
    --argjson observed_at "$observed_at" \
    --arg code "$code" \
    --arg message "$message" \
    '{
      schema_version: 1,
      ok: false,
      source: "pactl",
      observed_at: $observed_at,
      data: null,
      error: {
        code: $code,
        message: $message
      }
    }'
  exit 0
}

command -v pactl >/dev/null 2>&1 ||
  emit_error "dependency_missing" "Required command pactl is unavailable"

default_sink="$(pactl get-default-sink 2>/dev/null || true)"
default_source="$(pactl get-default-source 2>/dev/null || true)"

sinks_json="$(pactl -f json list sinks 2>/dev/null)" ||
  emit_error "audio_server_unavailable" "Unable to read audio outputs"

sources_json="$(pactl -f json list sources 2>/dev/null)" ||
  emit_error "audio_server_unavailable" "Unable to read audio inputs"

jq -e 'type == "array"' >/dev/null 2>&1 <<< "$sinks_json" ||
  emit_error "malformed_source" "Audio output data is malformed"

jq -e 'type == "array"' >/dev/null 2>&1 <<< "$sources_json" ||
  emit_error "malformed_source" "Audio input data is malformed"

jq -nc \
  --argjson observed_at "$observed_at" \
  --arg default_sink "$default_sink" \
  --arg default_source "$default_source" \
  --argjson sinks "$sinks_json" \
  --argjson sources "$sources_json" \
  '
    def volume_percent:
      [
        (.volume // {} | to_entries[]? | .value.value_percent? // empty)
        | strings
        | sub("%$"; "")
        | tonumber?
      ]
      | if length == 0 then null else ((add / length) | round) end;

    def normalize_endpoint($default_id):
      {
        id: (.name // ""),
        name: (.description // .name // "Unknown audio device"),
        is_default: ((.name // "") == $default_id),
        volume_percent: volume_percent,
        muted: (.mute == true),
        state: ((.state // "unknown") | ascii_downcase),
        active_port: (.active_port // null)
      };

    ($sinks | map(normalize_endpoint($default_sink))) as $outputs
    | (
        $sources
        | map(
            select(
              (.monitor_source // false) != true
              and ((.name // "") | endswith(".monitor") | not)
            )
            | normalize_endpoint($default_source)
          )
      ) as $inputs
    | ($outputs | map(select(.is_default)) | first // null) as $output
    | ($inputs | map(select(.is_default)) | first // null) as $input
    | {
        schema_version: 1,
        ok: true,
        source: "pactl",
        observed_at: $observed_at,
        data: {
          available: ($output != null),
          output: $output,
          input: $input,
          outputs: $outputs,
          inputs: $inputs,
          output_count: ($outputs | length),
          input_count: ($inputs | length)
        },
        error: null
      }
  '
