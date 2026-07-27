#!/usr/bin/env bash

# Emit normalized status for allowlisted background desktop applications.

set -u

export LC_ALL=C

readonly REGISTRY="${SENOMY_BACKGROUND_APPS_REGISTRY:-${XDG_CONFIG_HOME:-"$HOME/.config"}/eww/data/background-apps.json}"

printf -v observed_at '%(%s)T' -1

if ! command -v jq >/dev/null 2>&1; then
  printf \
    '{"schema_version":1,"ok":false,"source":"background-apps","observed_at":%s,"data":{"tray":{"host_available":false,"registered_count":0,"registered_ids":[]},"app_count":0,"running_count":0,"apps":[]},"error":{"code":"dependency_missing","message":"Required command jq is unavailable"}}\n' \
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
      source: "background-apps",
      observed_at: $observed_at,
      data: {
        tray: {
          host_available: false,
          registered_count: 0,
          registered_ids: []
        },
        app_count: 0,
        running_count: 0,
        apps: []
      },
      error: {
        code: $code,
        message: $message
      }
    }'
  exit 0
}

[[ -r "$REGISTRY" ]] ||
  emit_error "registry_unavailable" "The background application registry is unavailable"

registry_json="$(< "$REGISTRY")"

jq -e '
  .schema_version == 1
  and (.apps | type == "array")
  and all(
    .apps[];
    (.id | type == "string" and test("^[a-z0-9-]+$"))
    and (.name | type == "string" and length > 0)
    and (.description | type == "string")
    and (.executable | type == "string" and startswith("/"))
    and (.icon | type == "string" and length > 0)
    and (.unit | type == "string" and test("^[A-Za-z0-9_.@:-]+[.]service$"))
    and (.bus_name | type == "string" and test("^[A-Za-z0-9_.-]+$"))
    and (.tray_id | type == "string")
    and (.expects_tray | type == "boolean")
  )
' >/dev/null 2>&1 <<< "$registry_json" ||
  emit_error "registry_invalid" "The background application registry is malformed"

bus_names=""
if command -v busctl >/dev/null 2>&1; then
  bus_names="$(busctl --user list --no-legend --no-pager 2>/dev/null |
    awk '{print $1}' || true)"
fi

tray_host_available=false
if grep -Fxq "org.kde.StatusNotifierWatcher" <<< "$bus_names"; then
  tray_host_available=true
fi

registered_items='[]'
registered_ids='[]'

if [[ "$tray_host_available" == true ]]; then
  tray_property="$(
    busctl --user --json=short get-property \
      org.kde.StatusNotifierWatcher \
      /StatusNotifierWatcher \
      org.kde.StatusNotifierWatcher \
      RegisteredStatusNotifierItems 2>/dev/null || true
  )"

  if jq -e '.type == "as" and (.data | type == "array")' \
    >/dev/null 2>&1 <<< "$tray_property"; then
    registered_items="$(jq -c '.data' <<< "$tray_property")"
  fi
fi

while IFS= read -r item; do
  [[ -n "$item" ]] || continue

  if [[ "$item" == */* ]]; then
    item_service="${item%%/*}"
    item_path="/${item#*/}"
  else
    item_service="$item"
    item_path="/StatusNotifierItem"
  fi

  item_property="$(
    busctl --user --json=short get-property \
      "$item_service" \
      "$item_path" \
      org.kde.StatusNotifierItem \
      Id 2>/dev/null || true
  )"

  item_id="$(jq -r 'if .type == "s" then .data else empty end' \
    <<< "$item_property" 2>/dev/null || true)"
  [[ -n "$item_id" ]] || continue

  registered_ids="$(
    jq -nc \
      --argjson ids "$registered_ids" \
      --arg id "$item_id" \
      '$ids + [$id] | unique'
  )"
done < <(jq -r '.[]' <<< "$registered_items")

apps='[]'

while IFS= read -r app; do
  id="$(jq -r '.id' <<< "$app")"
  name="$(jq -r '.name' <<< "$app")"
  description="$(jq -r '.description' <<< "$app")"
  executable="$(jq -r '.executable' <<< "$app")"
  icon="$(jq -r '.icon' <<< "$app")"
  unit="$(jq -r '.unit' <<< "$app")"
  bus_name="$(jq -r '.bus_name' <<< "$app")"
  tray_id="$(jq -r '.tray_id' <<< "$app")"
  expects_tray="$(jq -r '.expects_tray' <<< "$app")"

  available=false
  [[ -x "$executable" ]] && available=true

  load_state="unknown"
  unit_file_state="unknown"
  active_state="unknown"
  sub_state="unknown"
  result="unknown"
  main_pid=0

  if command -v systemctl >/dev/null 2>&1; then
    unit_properties="$(
      systemctl --user show "$unit" --no-pager \
        --property=LoadState \
        --property=UnitFileState \
        --property=ActiveState \
        --property=SubState \
        --property=Result \
        --property=MainPID 2>/dev/null || true
    )"

    while IFS='=' read -r key value; do
      case "$key" in
        LoadState) load_state="${value:-unknown}" ;;
        UnitFileState) unit_file_state="${value:-unknown}" ;;
        ActiveState) active_state="${value:-unknown}" ;;
        SubState) sub_state="${value:-unknown}" ;;
        Result) result="${value:-unknown}" ;;
        MainPID)
          [[ "$value" =~ ^[0-9]+$ ]] && main_pid="$value"
          ;;
      esac
    done <<< "$unit_properties"
  fi

  managed=false
  [[ "$load_state" == "loaded" ]] && managed=true

  autostart_enabled=false
  case "$unit_file_state" in
    enabled | enabled-runtime) autostart_enabled=true ;;
  esac

  dbus_ready=false
  if grep -Fxq "$bus_name" <<< "$bus_names"; then
    dbus_ready=true
  fi

  tray_registered=false
  if [[ "$expects_tray" == true ]] &&
    jq -e --arg id "$tray_id" 'index($id) != null' \
      >/dev/null 2>&1 <<< "$registered_ids"; then
    tray_registered=true
  fi

  state="unknown"
  state_label="UNKNOWN"

  if [[ "$available" != true ]]; then
    state="unavailable"
    state_label="UNAVAILABLE"
  elif [[ "$active_state" == "failed" || "$result" == "failed" ]]; then
    state="failed"
    state_label="FAILED"
  elif [[ "$active_state" == "activating" ]]; then
    state="starting"
    state_label="STARTING"
  elif [[ "$active_state" == "active" && "$dbus_ready" == true ]]; then
    state="running"
    state_label="RUNNING"
  elif [[ "$dbus_ready" == true ]]; then
    state="external"
    state_label="EXTERNAL"
  elif [[ "$managed" == true ]]; then
    state="stopped"
    state_label="STOPPED"
  fi

  apps="$(
    jq -nc \
      --argjson apps "$apps" \
      --arg id "$id" \
      --arg name "$name" \
      --arg description "$description" \
      --arg executable "$executable" \
      --arg icon "$icon" \
      --arg unit "$unit" \
      --arg bus_name "$bus_name" \
      --arg tray_id "$tray_id" \
      --arg state "$state" \
      --arg state_label "$state_label" \
      --arg load_state "$load_state" \
      --arg unit_file_state "$unit_file_state" \
      --arg active_state "$active_state" \
      --arg sub_state "$sub_state" \
      --arg result "$result" \
      --argjson main_pid "$main_pid" \
      --argjson available "$available" \
      --argjson expects_tray "$expects_tray" \
      --argjson managed "$managed" \
      --argjson autostart_enabled "$autostart_enabled" \
      --argjson dbus_ready "$dbus_ready" \
      --argjson tray_registered "$tray_registered" \
      '$apps + [{
        id: $id,
        name: $name,
        description: $description,
        executable: $executable,
        icon: $icon,
        unit: $unit,
        bus_name: $bus_name,
        tray_id: $tray_id,
        available: $available,
        expects_tray: $expects_tray,
        state: $state,
        state_label: $state_label,
        service: {
          managed: $managed,
          load_state: $load_state,
          unit_file_state: $unit_file_state,
          active_state: $active_state,
          sub_state: $sub_state,
          result: $result,
          main_pid: $main_pid,
          autostart_enabled: $autostart_enabled
        },
        dbus_ready: $dbus_ready,
        tray_registered: $tray_registered
      }]'
  )"
done < <(jq -c '.apps[]' <<< "$registry_json")

jq -nc \
  --argjson observed_at "$observed_at" \
  --argjson tray_host_available "$tray_host_available" \
  --argjson registered_items "$registered_items" \
  --argjson registered_ids "$registered_ids" \
  --argjson apps "$apps" \
  '{
    schema_version: 1,
    ok: true,
    source: "systemd-user+session-dbus",
    observed_at: $observed_at,
    data: {
      tray: {
        host_available: $tray_host_available,
        registered_count: ($registered_items | length),
        registered_ids: $registered_ids
      },
      app_count: ($apps | length),
      running_count: ([
        $apps[]
        | select(.state == "running" or .state == "external")
      ] | length),
      apps: $apps
    },
    error: null
  }'
