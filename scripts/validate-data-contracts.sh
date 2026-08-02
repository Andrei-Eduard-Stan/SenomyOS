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
check_contract "Avatar catalog" "$STANDARD and any(.data.states[]; .id == \"browsing\" and (.chibi_path | endswith(\"/assets/senomy/senomy_chibi_browsing.jpg\")))" "$CONFIG_DIR/scripts/senomy-avatar.sh" catalog
check_contract "Wiki catalog" "$STANDARD" "$CONFIG_DIR/scripts/wiki-status.py" catalog
check_contract "Battery summary" '.available|type == "boolean"' "$CONFIG_DIR/scripts/battery.sh"
check_contract "Recovery snapshot" "$STANDARD and (.data.automatic_restore == false)" "$CONFIG_DIR/scripts/recovery-status.sh"

printf '\nSenomyOS data contracts: %d collectors passed.\n' "$pass"
