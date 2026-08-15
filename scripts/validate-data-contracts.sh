#!/usr/bin/env bash

# Read-only schema checks for the collectors that feed visible shell surfaces.
set -euo pipefail
export LC_ALL=C

readonly CONFIG_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly TEST_ROOT="$(mktemp -d /tmp/senomy-data-contracts.XXXXXX)"
trap 'rm -rf "$TEST_ROOT"' EXIT
export XDG_RUNTIME_DIR="$TEST_ROOT/runtime"
export XDG_CACHE_HOME="$TEST_ROOT/cache"
mkdir -p "$XDG_RUNTIME_DIR" "$XDG_CACHE_HOME"
pass=0

check_contract() {
  local label="$1" filter="$2"
  shift 2
  local payload

  payload="$("$@")" || {
    printf 'FAIL  %-25s collector exited nonzero\n' "$label" >&2
    return 1
  }
  jq -e "$filter" >/dev/null <<<"$payload" || {
    printf 'FAIL  %-25s invalid contract\n' "$label" >&2
    return 1
  }
  printf 'PASS  %s\n' "$label"
  pass=$((pass + 1))
}

readonly STANDARD='.schema_version >= 1 and (.ok|type == "boolean") and (.source|type == "string") and has("data") and has("error")'

check_contract "Rail telemetry" "$STANDARD" "$CONFIG_DIR/scripts/rail-system-status.sh"
check_contract "Detailed power" "$STANDARD" "$CONFIG_DIR/scripts/power-status.sh"
check_contract "Detailed audio" "$STANDARD" "$CONFIG_DIR/scripts/audio-status.sh"
check_contract "Detailed network" "$STANDARD" "$CONFIG_DIR/scripts/network-status.sh"
check_contract "Control inventory" "$STANDARD" "$CONFIG_DIR/scripts/control-status.sh"
check_contract "Bluetooth inventory" "$STANDARD" "$CONFIG_DIR/scripts/bluetooth-status.sh"
check_contract "Performance inventory" "$STANDARD" "$CONFIG_DIR/scripts/performance-status.sh"
check_contract "Performance live" "$STANDARD" "$CONFIG_DIR/scripts/performance-live.sh"
check_contract "Process inventory" "$STANDARD" "$CONFIG_DIR/scripts/performance-processes.sh"
check_contract "Background apps" "$STANDARD" "$CONFIG_DIR/scripts/background-apps-status.sh"
check_contract "Update cache" "$STANDARD" "$CONFIG_DIR/scripts/update-status.sh" read
check_contract "Avatar catalog" "$STANDARD
  and (.data.supported_formats | index(\"png\") != null)
  and (.data.supported_formats | index(\"jpg\") != null)
  and (.data.supported_formats | index(\"gif\") != null)
  and all(.data.states[];
    (.bar_path | type == \"string\")
    and (.observer_path | type == \"string\")
    and (.overview_path | type == \"string\")
    and (.insights_hero_path | type == \"string\")
    and (.power_path | type == \"string\")
    and (.companion_path | type == \"string\")
    and (.companion_compact_path | type == \"string\"))
  and any(.data.states[]; .id == \"browsing\" and (.chibi_path | endswith(\"/assets/senomy/senomy_chibi_browsing.png\")))
  and any(.data.states[]; .id == \"music\" and (.chibi_path | endswith(\"/assets/senomy/senomy_chibi_listening-v1.png\")))" "$CONFIG_DIR/scripts/senomy-avatar.sh" catalog
check_contract "Companion media" "$STANDARD
  and (.data.provider_available | type == \"boolean\")
  and (.data.session_available | type == \"boolean\")
  and (.data.playing | type == \"boolean\")
  and (.data.status | IN(\"playing\",\"paused\",\"stopped\",\"unavailable\"))" "$CONFIG_DIR/scripts/companion-media.sh"
check_contract "Wiki catalog" "$STANDARD" "$CONFIG_DIR/scripts/wiki-status.py" catalog
check_contract "Battery summary" '.available|type == "boolean"' "$CONFIG_DIR/scripts/battery.sh"
check_contract "Recovery snapshot" "$STANDARD and (.data.automatic_restore == false)" "$CONFIG_DIR/scripts/recovery-status.sh"

notification_root="$TEST_ROOT/notifications"
env SENOMY_NOTIFICATION_ROOT="$notification_root" SENOMY_NOTIFICATION_LIMIT=2 \
  SWAYNC_APP_NAME="Contract Test" SWAYNC_SUMMARY="First notification" \
  SWAYNC_BODY='<b>Private fixture</b>' SWAYNC_URGENCY=Normal \
  "$CONFIG_DIR/scripts/notification-history.sh" capture
env SENOMY_NOTIFICATION_ROOT="$notification_root" SENOMY_NOTIFICATION_LIMIT=2 \
  SWAYNC_APP_NAME="Contract Test" SWAYNC_SUMMARY="Second notification" \
  SWAYNC_BODY='Retained after popup closes' SWAYNC_URGENCY=Critical \
  "$CONFIG_DIR/scripts/notification-history.sh" capture
check_contract "Notification history" "$STANDARD
  and .data.retained_count == 2
  and .data.retention_limit == 2
  and .data.entries[0].summary == \"Second notification\"
  and .data.entries[0].urgency == \"critical\"
  and (.data.entries[1].body | contains(\"<b>\") | not)
  and .data.privacy.local_only == true
  and .data.privacy.actions_stored == false" \
  env SENOMY_NOTIFICATION_ROOT="$notification_root" SENOMY_NOTIFICATION_LIMIT=2 \
  XDG_CONFIG_HOME="$TEST_ROOT/config" "$CONFIG_DIR/scripts/notification-history.sh" read

check_contract "SwayNC integration" "$STANDARD and .data.installed == false" \
  env XDG_CONFIG_HOME="$TEST_ROOT/config" "$CONFIG_DIR/scripts/swaync-history-integration.sh" status
check_contract "Benchmark quick plan" "$STANDARD
  and .data.profile == \"quick\"
  and .data.estimated_seconds == 70
  and .data.network == false
  and .data.root == false
  and .data.workloads.storage_mib == 256" \
  "$CONFIG_DIR/scripts/benchmark-action.sh" plan quick
check_contract "Benchmark standard plan" "$STANDARD
  and .data.profile == \"standard\"
  and .data.estimated_seconds == 210
  and .data.workloads.cpu_multi_seconds == 60
  and .data.workloads.storage_mib == 512" \
  "$CONFIG_DIR/scripts/benchmark-action.sh" plan standard
check_contract "Benchmark idle status" "$STANDARD
  and .data.state == \"idle\"
  and (.data.logs | type == \"array\")" \
  env SENOMY_BENCHMARK_ROOT="$TEST_ROOT/benchmarks" "$CONFIG_DIR/scripts/benchmark-status.sh"

printf '\nSenomyOS data contracts: %d collectors passed.\n' "$pass"
