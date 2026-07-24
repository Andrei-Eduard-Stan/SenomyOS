#!/usr/bin/env bash

# Emit normalized, read-only NetworkManager state for the SenomyOS bar,
# Control Centre, and Device Management. This collector never scans for
# networks, connects, disconnects, or reads saved credentials.

set -u

export LC_ALL=C

printf -v observed_at '%(%s)T' -1

if ! command -v jq >/dev/null 2>&1; then
  printf \
    '{"schema_version":1,"ok":false,"source":"nmcli","observed_at":%s,"data":null,"error":{"code":"dependency_missing","message":"Required command jq is unavailable"}}\n' \
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
      source: "nmcli",
      observed_at: $observed_at,
      data: null,
      error: {
        code: $code,
        message: $message
      }
    }'
  exit 0
}

command -v nmcli >/dev/null 2>&1 ||
  emit_error "dependency_missing" "Required command nmcli is unavailable"

general_state="$(nmcli -g STATE general 2>/dev/null)" ||
  emit_error "network_manager_unavailable" "Unable to read NetworkManager state"

connectivity="$(nmcli -g CONNECTIVITY general 2>/dev/null)" ||
  emit_error "network_manager_unavailable" "Unable to read network connectivity"

networking_state="$(nmcli networking 2>/dev/null)" ||
  emit_error "network_manager_unavailable" "Unable to read networking state"

wifi_state="$(nmcli radio wifi 2>/dev/null)" ||
  emit_error "network_manager_unavailable" "Unable to read Wi-Fi radio state"

device_lines="$(nmcli -t --escape no -f DEVICE,TYPE,STATE device status 2>/dev/null)" ||
  emit_error "network_manager_unavailable" "Unable to read network devices"

general_state="${general_state,,}"
general_state="${general_state%% *}"
connectivity="${connectivity,,}"
connectivity="${connectivity%% *}"

networking_enabled=false
[[ "${networking_state,,}" == "enabled" ]] && networking_enabled=true

wifi_enabled=false
[[ "${wifi_state,,}" == "enabled" ]] && wifi_enabled=true

devices_json='[]'

while IFS=: read -r device type state_raw; do
  [[ -n "$device" ]] || continue

  state="${state_raw,,}"
  state="${state%% *}"

  connected=false
  [[ "$state" == "connected" ]] && connected=true

  connection="$(nmcli -g GENERAL.CONNECTION device show "$device" 2>/dev/null || true)"
  [[ "$connection" == "--" ]] && connection=""

  ip4_raw="$(nmcli -g IP4.ADDRESS device show "$device" 2>/dev/null || true)"
  gateway="$(nmcli -g IP4.GATEWAY device show "$device" 2>/dev/null || true)"

  ip4_json="$(
    jq -nc \
      --arg addresses "$ip4_raw" \
      '$addresses | split("\n") | map(select(length > 0))'
  )"

  device_json="$(
    jq -nc \
      --arg id "$device" \
      --arg type "${type,,}" \
      --arg state "$state" \
      --arg connection "$connection" \
      --arg gateway "$gateway" \
      --argjson connected "$connected" \
      --argjson ip4_addresses "$ip4_json" \
      '{
        id: $id,
        type: $type,
        state: $state,
        connected: $connected,
        connection: (
          if $connection == "" then null else $connection end
        ),
        ip4_addresses: $ip4_addresses,
        gateway: (
          if $gateway == "" then null else $gateway end
        )
      }'
  )"

  devices_json="$(
    jq -nc \
      --argjson devices "$devices_json" \
      --argjson device "$device_json" \
      '$devices + [$device]'
  )"
done <<< "$device_lines"

jq -nc \
  --argjson observed_at "$observed_at" \
  --arg state "$general_state" \
  --arg connectivity "$connectivity" \
  --argjson networking_enabled "$networking_enabled" \
  --argjson wifi_enabled "$wifi_enabled" \
  --argjson devices "$devices_json" \
  '
    (
      ($devices | map(select(.connected and .type != "loopback" and .gateway != null)) | first)
      // ($devices | map(select(.connected and .type != "loopback")) | first)
      // null
    ) as $primary
    | ($devices | map(select(.connected and .type == "wifi")) | first // null) as $wifi
    | ($devices | map(select(.connected and .type == "ethernet")) | first // null) as $ethernet
    | {
        schema_version: 1,
        ok: true,
        source: "nmcli",
        observed_at: $observed_at,
        data: {
          state: $state,
          connectivity: $connectivity,
          networking_enabled: $networking_enabled,
          connected: ($primary != null),
          primary: $primary,
          wifi: {
            enabled: $wifi_enabled,
            connected: ($wifi != null),
            device: $wifi
          },
          ethernet: {
            connected: ($ethernet != null),
            device: $ethernet
          },
          devices: $devices,
          device_count: ($devices | length)
        },
        error: null
      }
  '
