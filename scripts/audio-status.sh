#!/usr/bin/env bash

# Emit normalized PipeWire/Pulse compatibility telemetry without changing state.

set -u
export LC_ALL=C

printf -v observed_at '%(%s)T' -1

emit_error() {
  jq -nc --argjson at "$observed_at" --arg code "$1" --arg message "$2" \
    '{schema_version:2,ok:false,source:"pipewire/pactl",observed_at:$at,data:null,
      error:{code:$code,message:$message}}'
  exit 0
}

command -v jq >/dev/null 2>&1 || {
  printf '{"schema_version":2,"ok":false,"source":"pipewire/pactl","observed_at":%s,"data":null,"error":{"code":"dependency_missing","message":"Required command jq is unavailable"}}\n' "$observed_at"
  exit 0
}
command -v pactl >/dev/null 2>&1 ||
  emit_error "dependency_missing" "Required command pactl is unavailable"

info="$(pactl -f json info 2>/dev/null)" ||
  emit_error "audio_server_unavailable" "PipeWire Pulse is not reachable"
sinks="$(pactl -f json list sinks 2>/dev/null)" ||
  emit_error "audio_server_unavailable" "Unable to read audio outputs"
sources="$(pactl -f json list sources 2>/dev/null)" ||
  emit_error "audio_server_unavailable" "Unable to read audio inputs"
cards="$(pactl -f json list cards 2>/dev/null)" ||
  emit_error "audio_server_unavailable" "Unable to read audio hardware profiles"

jq -e 'type == "object"' >/dev/null 2>&1 <<<"$info" ||
  emit_error "malformed_source" "Audio server metadata is malformed"
for payload in "$sinks" "$sources" "$cards"; do
  jq -e 'type == "array"' >/dev/null 2>&1 <<<"$payload" ||
    emit_error "malformed_source" "Audio endpoint data is malformed"
done

pipewire_active=false
wireplumber_active=false
systemctl --user is-active --quiet pipewire.service 2>/dev/null && pipewire_active=true
systemctl --user is-active --quiet wireplumber.service 2>/dev/null && wireplumber_active=true

jq -nc \
  --argjson at "$observed_at" --argjson info "$info" \
  --argjson sinks "$sinks" --argjson sources "$sources" --argjson cards "$cards" \
  --argjson pipewire_active "$pipewire_active" --argjson wireplumber_active "$wireplumber_active" '
  def percent:
    [.volume // {} | to_entries[]?.value.value_percent? | strings
      | sub("%$";"") | tonumber?]
    | if length == 0 then null else (add / length | round) end;
  def ports($active):
    [(.ports // [])[]? | {
      name:(.name // ""), description:(.description // .name // "Unknown port"),
      availability:(.availability // "unknown"),
      active:((.name // "") == ($active // ""))
    }];
  def endpoint($default):
    . as $root | {
      id:(.name // ""), index:(.index // null),
      name:(.description // .name // "Unknown endpoint"),
      is_default:((.name // "") == $default),
      volume_percent:percent, muted:(.mute == true),
      state:((.state // "unknown") | ascii_downcase),
      active_port:(.active_port // null),
      active_port_description:(
        [(.ports // [])[]? | select(.name == ($root.active_port // "")) | .description]
        | first // "No active port"),
      ports:ports(.active_port),
      sample_spec:(.sample_specification // "Unavailable"),
      channel_map:(.channel_map // "Unavailable"),
      driver:(.driver // "Unavailable"),
      hardware:{
        product:(.properties."device.product.name" // .properties."alsa.card_name" // "Unavailable"),
        codec:(.properties."alsa.mixer_name" // "Unavailable"),
        bus:(.properties."device.bus" // "Unavailable"),
        profile:(.properties."device.profile.description" // "Unavailable")
      }
    };
  ($info.default_sink_name // "") as $default_sink |
  ($info.default_source_name // "") as $default_source |
  ($sinks | map(endpoint($default_sink))) as $outputs |
  ($sources | map(select(
    (.monitor_source // false) != true and
    ((.name // "") | endswith(".monitor") | not)
  ) | endpoint($default_source))) as $inputs |
  ($cards | map(. as $card | {
    id:(.name // ""), index:(.index // null),
    name:(.properties."device.product.name" // .properties."alsa.card_name" // .name // "Unknown hardware"),
    driver:(.driver // "Unavailable"),
    active_profile:(if (.active_profile | type) == "object" then (.active_profile.name // "off") else (.active_profile // "off") end),
    profiles:[(.profiles // [])[]? | select(.available != false) | {
      name:(.name // ""), description:(.description // .name // "Unknown profile"),
      available:(.available != false),
      active:(.name == (if ($card.active_profile | type) == "object" then ($card.active_profile.name // "off") else ($card.active_profile // "off") end))
    }]
  })) as $hardware |
  {
    schema_version:2,ok:true,source:"pipewire/pactl",observed_at:$at,
    data:{
      available:([ $outputs[] | select(.is_default) ] | length > 0),
      server:{
        name:($info.server_name // "Unknown server"),
        version:($info.server_version // "Unavailable"),
        protocol:($info.server_protocol_version // null),
        sample_spec:($info.sample_specification // "Unavailable"),
        pipewire_active:$pipewire_active,wireplumber_active:$wireplumber_active
      },
      output:([$outputs[] | select(.is_default)] | first // null),
      input:([$inputs[] | select(.is_default)] | first // null),
      outputs:$outputs,inputs:$inputs,hardware:$hardware,
      output_count:($outputs|length),input_count:($inputs|length),
      physical_output_count:([$outputs[] | select(.id != "auto_null")] | length),
      hardware_count:($hardware|length),
      degraded:(($hardware|length) > 0 and ([$outputs[] | select(.id != "auto_null")] | length) == 0),
      degraded_reason:(if (($hardware|length) > 0 and ([$outputs[] | select(.id != "auto_null")] | length) == 0)
        then "Audio hardware is detected, but PipeWire exposes no physical output profile; auto_null is only a dummy sink."
        else null end)
    },error:null
  }'
