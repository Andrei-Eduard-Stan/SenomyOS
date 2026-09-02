#!/usr/bin/env bash

# Emit a compact, read-only system summary for the SenomyOS bar and dashboard.
# Data comes from Linux procfs so the collector does not depend on a particular
# laptop model, monitor, battery layout, or desktop session.

set -u

export LC_ALL=C

readonly PROC_ROOT="${SENOMY_PROC_ROOT:-/proc}"
readonly CPU_SAMPLE_DELAY="${SENOMY_CPU_SAMPLE_DELAY:-0.2}"

printf -v observed_at '%(%s)T' -1

if ! command -v jq >/dev/null 2>&1; then
  printf \
    '{"schema_version":1,"ok":false,"source":"procfs","observed_at":%s,"data":null,"error":{"code":"dependency_missing","message":"Required command jq is unavailable"}}\n' \
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
      source: "procfs",
      observed_at: $observed_at,
      data: null,
      error: {
        code: $code,
        message: $message
      }
    }'
  exit 0
}

is_uint() {
  [[ "$1" =~ ^[0-9]+$ ]]
}

is_number() {
  [[ "$1" =~ ^[0-9]+([.][0-9]+)?$ ]]
}

read_cpu_sample() {
  local label user nice system idle iowait irq softirq steal guest guest_nice

  if ! read -r label user nice system idle iowait irq softirq steal guest guest_nice < "$PROC_ROOT/stat"; then
    return 1
  fi

  [[ "$label" == "cpu" ]] || return 1

  user="${user:-0}"
  nice="${nice:-0}"
  system="${system:-0}"
  idle="${idle:-0}"
  iowait="${iowait:-0}"
  irq="${irq:-0}"
  softirq="${softirq:-0}"
  steal="${steal:-0}"

  for value in "$user" "$nice" "$system" "$idle" "$iowait" "$irq" "$softirq" "$steal"; do
    is_uint "$value" || return 1
  done

  CPU_IDLE=$((idle + iowait))
  CPU_TOTAL=$((user + nice + system + idle + iowait + irq + softirq + steal))
}

for required_file in stat meminfo uptime loadavg; do
  [[ -r "$PROC_ROOT/$required_file" ]] ||
    emit_error "source_unavailable" "Required procfs source is unavailable"
done

is_number "$CPU_SAMPLE_DELAY" ||
  emit_error "invalid_configuration" "CPU sample delay must be numeric"

CPU_IDLE=0
CPU_TOTAL=0
read_cpu_sample ||
  emit_error "malformed_source" "Unable to read CPU counters"

cpu_idle_before="$CPU_IDLE"
cpu_total_before="$CPU_TOTAL"

sleep "$CPU_SAMPLE_DELAY" 2>/dev/null ||
  emit_error "sample_failed" "Unable to sample CPU counters"

read_cpu_sample ||
  emit_error "malformed_source" "Unable to read CPU counters"

cpu_idle_delta=$((CPU_IDLE - cpu_idle_before))
cpu_total_delta=$((CPU_TOTAL - cpu_total_before))

((cpu_total_delta > 0)) ||
  emit_error "sample_failed" "CPU counters did not advance"

cpu_busy_delta=$((cpu_total_delta - cpu_idle_delta))
((cpu_busy_delta < 0)) && cpu_busy_delta=0

cpu_tenths=$(((cpu_busy_delta * 1000 + cpu_total_delta / 2) / cpu_total_delta))
((cpu_tenths > 1000)) && cpu_tenths=1000
printf -v cpu_percent '%d.%d' "$((cpu_tenths / 10))" "$((cpu_tenths % 10))"

mem_total_kib=""
mem_available_kib=""

while read -r key value unit; do
  case "$key" in
    MemTotal:)
      mem_total_kib="$value"
      ;;
    MemAvailable:)
      mem_available_kib="$value"
      ;;
  esac

  [[ -n "$mem_total_kib" && -n "$mem_available_kib" ]] && break
done < "$PROC_ROOT/meminfo"

is_uint "$mem_total_kib" &&
  is_uint "$mem_available_kib" &&
  ((mem_total_kib > 0)) ||
  emit_error "malformed_source" "Unable to read memory counters"

((mem_available_kib > mem_total_kib)) && mem_available_kib="$mem_total_kib"

mem_used_kib=$((mem_total_kib - mem_available_kib))
mem_tenths=$(((mem_used_kib * 1000 + mem_total_kib / 2) / mem_total_kib))
printf -v mem_percent '%d.%d' "$((mem_tenths / 10))" "$((mem_tenths % 10))"

read -r uptime_raw _ < "$PROC_ROOT/uptime" ||
  emit_error "malformed_source" "Unable to read system uptime"

is_number "$uptime_raw" ||
  emit_error "malformed_source" "Unable to read system uptime"

uptime_seconds="${uptime_raw%%.*}"
is_uint "$uptime_seconds" ||
  emit_error "malformed_source" "Unable to read system uptime"

uptime_days=$((uptime_seconds / 86400))
uptime_hours=$(((uptime_seconds % 86400) / 3600))
uptime_minutes=$(((uptime_seconds % 3600) / 60))
uptime_remaining_seconds=$((uptime_seconds % 60))

if ((uptime_days > 0)); then
  printf -v uptime_human '%dd %02d:%02d:%02d' \
    "$uptime_days" "$uptime_hours" "$uptime_minutes" "$uptime_remaining_seconds"
else
  printf -v uptime_human '%02d:%02d:%02d' \
    "$uptime_hours" "$uptime_minutes" "$uptime_remaining_seconds"
fi

read -r load_one load_five load_fifteen _ < "$PROC_ROOT/loadavg" ||
  emit_error "malformed_source" "Unable to read system load"

is_number "$load_one" &&
  is_number "$load_five" &&
  is_number "$load_fifteen" ||
  emit_error "malformed_source" "Unable to read system load"

jq -nc \
  --argjson observed_at "$observed_at" \
  --argjson cpu_percent "$cpu_percent" \
  --argjson cpu_sample_seconds "$CPU_SAMPLE_DELAY" \
  --argjson memory_total_bytes "$((mem_total_kib * 1024))" \
  --argjson memory_used_bytes "$((mem_used_kib * 1024))" \
  --argjson memory_available_bytes "$((mem_available_kib * 1024))" \
  --argjson memory_percent "$mem_percent" \
  --argjson uptime_seconds "$uptime_seconds" \
  --arg uptime_human "$uptime_human" \
  --argjson load_one "$load_one" \
  --argjson load_five "$load_five" \
  --argjson load_fifteen "$load_fifteen" \
  '{
    schema_version: 1,
    ok: true,
    source: "procfs",
    observed_at: $observed_at,
    data: {
      cpu: {
        percent: $cpu_percent,
        sample_seconds: $cpu_sample_seconds
      },
      memory: {
        total_bytes: $memory_total_bytes,
        used_bytes: $memory_used_bytes,
        available_bytes: $memory_available_bytes,
        percent: $memory_percent
      },
      uptime: {
        seconds: $uptime_seconds,
        human: $uptime_human
      },
      load: {
        one: $load_one,
        five: $load_five,
        fifteen: $load_fifteen
      }
    },
    error: null
  }'
