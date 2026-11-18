#!/usr/bin/env bash

# Emit cheap, read-only state for controls that remain visible on the main bar.

set -u
export LC_ALL=C
printf -v observed_at '%(%s)T' -1

audio_available=false
audio_muted=false
audio_volume=0
audio_name="Unavailable"

if command -v wpctl >/dev/null 2>&1; then
  volume_line="$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null || true)"
  if [[ "$volume_line" =~ Volume:[[:space:]]+([0-9]+([.][0-9]+)?) ]]; then
    audio_available=true
    audio_volume="$(awk -v value="${BASH_REMATCH[1]}" 'BEGIN { printf "%.0f", value * 100 }')"
    [[ "$volume_line" == *"[MUTED]"* ]] && audio_muted=true
  fi
fi

if command -v pactl >/dev/null 2>&1; then
  audio_name="$(pactl get-default-sink 2>/dev/null || true)"
  [[ -n "$audio_name" ]] || audio_name="Default output"
fi

network_available=false
networking_enabled=false
wifi_enabled=false
connected=false
connectivity="unknown"
connection_name="Offline"
signal_percent=0

if command -v nmcli >/dev/null 2>&1; then
  network_available=true
  [[ "$(nmcli networking 2>/dev/null || true)" == "enabled" ]] && networking_enabled=true
  [[ "$(nmcli radio wifi 2>/dev/null || true)" == "enabled" ]] && wifi_enabled=true
  connectivity="$(nmcli -g CONNECTIVITY general 2>/dev/null || printf unknown)"
  connection_name="$(nmcli -t --escape no -f TYPE,STATE,CONNECTION device status 2>/dev/null |
    awk -F: '$2 ~ /^connected/ && $1 != "loopback" {print $3; exit}')"
  if [[ -n "$connection_name" ]]; then
    connected=true
  else
    connection_name="Offline"
  fi
  signal_percent="$(nmcli -t --escape no -f IN-USE,SIGNAL device wifi list --rescan no 2>/dev/null |
    awk -F: '$1=="*" {print $2; exit}')"
  [[ "$signal_percent" =~ ^[0-9]+$ ]] || signal_percent=0
fi

jq -nc \
  --argjson observed_at "$observed_at" \
  --argjson audio_available "$audio_available" \
  --argjson audio_muted "$audio_muted" \
  --argjson audio_volume "$audio_volume" \
  --arg audio_name "$audio_name" \
  --argjson network_available "$network_available" \
  --argjson networking_enabled "$networking_enabled" \
  --argjson wifi_enabled "$wifi_enabled" \
  --argjson connected "$connected" \
  --arg connectivity "$connectivity" \
  --arg connection_name "$connection_name" \
  --argjson signal_percent "$signal_percent" '
  {
    schema_version: 1,
    ok: true,
    source: "wpctl/NetworkManager",
    observed_at: $observed_at,
    data: {
      audio: {
        available: $audio_available,
        muted: $audio_muted,
        volume_percent: $audio_volume,
        name: $audio_name
      },
      network: {
        available: $network_available,
        networking_enabled: $networking_enabled,
        wifi_enabled: $wifi_enabled,
        connected: $connected,
        connectivity: $connectivity,
        connection_name: $connection_name,
        signal_percent: $signal_percent
      }
    },
    error: null
  }'
