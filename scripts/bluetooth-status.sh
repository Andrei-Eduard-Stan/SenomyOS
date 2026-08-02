#!/usr/bin/env bash

# Bounded BlueZ inventory for Control Centre. No action is performed here.
set -u
export LC_ALL=C

readonly LIMIT="${SENOMY_BLUETOOTH_DEVICE_LIMIT:-30}"
readonly HOME_DIR="${HOME:-/nonexistent}"
readonly ACTION_CACHE="${SENOMY_BLUETOOTH_CACHE:-${XDG_RUNTIME_DIR:-/tmp}/senomyos/bluetooth-action.json}"
printf -v observed_at '%(%s)T' -1

emit_unavailable() {
  jq -nc --argjson at "$observed_at" --arg code "$1" --arg message "$2" \
    '{schema_version:1,ok:false,source:"bluez",observed_at:$at,data:{available:false,controller:null,devices:[],counts:{known:0,paired:0,connected:0}},error:{code:$code,message:$message}}'
  exit 0
}

command -v jq >/dev/null 2>&1 || { printf '{"schema_version":1,"ok":false,"source":"bluez","observed_at":%s,"data":{"available":false,"controller":null,"devices":[],"counts":{"known":0,"paired":0,"connected":0}},"error":{"code":"dependency_missing","message":"jq is unavailable"}}\n' "$observed_at"; exit 0; }
command -v bluetoothctl >/dev/null 2>&1 || emit_unavailable dependency_missing "BlueZ bluetoothctl is unavailable"
[[ "$LIMIT" =~ ^[1-9][0-9]*$ ]] && ((LIMIT <= 100)) || emit_unavailable invalid_configuration "Bluetooth device limit is invalid"

controller_raw="$(timeout 4s bluetoothctl show 2>/dev/null || true)"
[[ -n "$controller_raw" ]] || emit_unavailable controller_unavailable "No Bluetooth controller is available"

field() { sed -n "s/^[[:space:]]*$1: //p" <<<"$2" | head -n1; }
bool_field() { [[ "$(field "$1" "$2")" == yes ]] && printf true || printf false; }

controller_address="$(sed -n 's/^Controller \([0-9A-Fa-f:]\{17\}\).*/\1/p' <<<"$controller_raw" | head -n1)"
controller_name="$(field Alias "$controller_raw")"; [[ -n "$controller_name" ]] || controller_name="$(field Name "$controller_raw")"
powered="$(bool_field Powered "$controller_raw")"
discovering="$(bool_field Discovering "$controller_raw")"
pairable="$(bool_field Pairable "$controller_raw")"
discoverable="$(bool_field Discoverable "$controller_raw")"

devices='[]'
while IFS= read -r row; do
  [[ "$row" =~ ^Device[[:space:]]+([0-9A-Fa-f:]{17})[[:space:]]+(.+)$ ]] || continue
  address="${BASH_REMATCH[1]^^}"
  fallback_name="${BASH_REMATCH[2]}"
  info="$(timeout 3s bluetoothctl info "$address" 2>/dev/null || true)"
  [[ -n "$info" ]] || continue
  name="$(field Alias "$info")"; [[ -n "$name" ]] || name="$(field Name "$info")"; [[ -n "$name" ]] || name="$fallback_name"
  icon="$(field Icon "$info")"; [[ -n "$icon" ]] || icon="device"
  paired="$(bool_field Paired "$info")"; trusted="$(bool_field Trusted "$info")"
  connected="$(bool_field Connected "$info")"; blocked="$(bool_field Blocked "$info")"
  rssi="$(field RSSI "$info" | grep -oE -- '-?[0-9]+' | tail -n1)"; [[ "$rssi" =~ ^-?[0-9]+$ ]] || rssi=null
  battery="$(sed -n 's/^[[:space:]]*Battery Percentage:.*(\([0-9]\+\)).*/\1/p' <<<"$info" | head -n1)"; [[ "$battery" =~ ^[0-9]+$ ]] || battery=null
  audio=false; grep -Eq 'Audio Sink|Headset|Handsfree|A/V Remote Control' <<<"$info" && audio=true
  device="$(jq -nc --arg address "$address" --arg name "$name" --arg icon "$icon" \
    --argjson paired "$paired" --argjson trusted "$trusted" --argjson connected "$connected" \
    --argjson blocked "$blocked" --argjson rssi "$rssi" --argjson battery "$battery" --argjson audio "$audio" \
    '{address:$address,name:$name,icon:$icon,paired:$paired,trusted:$trusted,connected:$connected,blocked:$blocked,rssi:$rssi,battery_percent:$battery,audio_capable:$audio}')"
  devices="$(jq -nc --argjson list "$devices" --argjson device "$device" '$list + [$device]')"
done < <(timeout 4s bluetoothctl devices 2>/dev/null | head -n "$LIMIT")

action='{"state":"idle","state_label":"READY","operation":"none","message":"Bluetooth controls are ready.","finished_at":0}'
if [[ -r "$ACTION_CACHE" ]] && jq -e 'type == "object" and has("state")' "$ACTION_CACHE" >/dev/null 2>&1; then action="$(cat "$ACTION_CACHE")"; fi
action_target="$(jq -r '.target // ""' <<<"$action")"
# RSSI changes every scan and must not reshuffle controls under the pointer.
# Keep the active target first, followed by connected and paired devices, then
# use stable human-readable identity ordering for everything else.
devices="$(jq -nc --argjson devices "$devices" --arg target "$action_target" '
  $devices | sort_by([(.address != $target),(.connected|not),(.paired|not),(.name|ascii_downcase),.address])')"

jq -nc --argjson at "$observed_at" --arg address "$controller_address" --arg name "$controller_name" \
  --argjson powered "$powered" --argjson discovering "$discovering" --argjson pairable "$pairable" --argjson discoverable "$discoverable" \
  --argjson devices "$devices" --argjson action "$action" '
  {schema_version:1,ok:true,source:"bluez+bluetoothctl",observed_at:$at,
   data:{available:true,controller:{address:$address,name:$name,powered:$powered,discovering:$discovering,pairable:$pairable,discoverable:$discoverable},
    devices:$devices,counts:{known:($devices|length),paired:([$devices[]|select(.paired)]|length),connected:([$devices[]|select(.connected)]|length)},action:$action},error:null}'
