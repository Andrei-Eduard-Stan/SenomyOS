#!/usr/bin/env bash

# Cheap procfs status for the permanent Rail and compact summaries. Detailed
# disk, network, thermal, pressure and per-core work belongs to Performance.
set -euo pipefail
export LC_ALL=C
umask 077

readonly RUNTIME_ROOT="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/senomyos"
readonly CACHE_FILE="$RUNTIME_ROOT/rail-cpu-counters"
readonly LOCK_FILE="$RUNTIME_ROOT/rail-status.lock"

mkdir -p "$RUNTIME_ROOT"
chmod 700 "$RUNTIME_ROOT" 2>/dev/null || true
exec 9>"$LOCK_FILE"
flock -w 1 9

read_cpu() {
  local cpu user nice system idle iowait irq softirq steal rest
  read -r cpu user nice system idle iowait irq softirq steal rest </proc/stat
  printf '%s %s\n' "$((user + nice + system + idle + iowait + irq + softirq + steal))" "$((idle + iowait))"
}

read -r total idle < <(read_cpu)
if [[ -r "$CACHE_FILE" ]]; then
  read -r previous_total previous_idle <"$CACHE_FILE" || true
else
  previous_total=""; previous_idle=""
fi

if [[ ! "$previous_total" =~ ^[0-9]+$ || ! "$previous_idle" =~ ^[0-9]+$ || "$total" -le "$previous_total" ]]; then
  sleep 0.05
  previous_total="$total"; previous_idle="$idle"
  read -r total idle < <(read_cpu)
fi

printf '%s %s\n' "$total" "$idle" >"$CACHE_FILE"
chmod 600 "$CACHE_FILE" "$LOCK_FILE" 2>/dev/null || true

delta_total=$((total - previous_total)); delta_idle=$((idle - previous_idle))
if ((delta_total > 0)); then cpu_hundredths=$(((delta_total - delta_idle) * 10000 / delta_total)); else cpu_hundredths=0; fi

mem_total_kib=0; mem_available_kib=0
while read -r key value _; do
  case "$key" in
    MemTotal:) mem_total_kib="$value" ;;
    MemAvailable:) mem_available_kib="$value" ;;
  esac
  ((mem_total_kib > 0 && mem_available_kib > 0)) && break
done </proc/meminfo
mem_used_kib=$((mem_total_kib - mem_available_kib))
if ((mem_total_kib > 0)); then memory_hundredths=$((mem_used_kib * 10000 / mem_total_kib)); else memory_hundredths=0; fi

read -r uptime_seconds _ </proc/uptime
uptime_seconds="${uptime_seconds%.*}"
days=$((uptime_seconds / 86400)); hours=$((uptime_seconds % 86400 / 3600)); minutes=$((uptime_seconds % 3600 / 60)); seconds=$((uptime_seconds % 60))
if ((days > 0)); then
  uptime_human="$(printf '%dd %02d:%02d:%02d' "$days" "$hours" "$minutes" "$seconds")"
else
  uptime_human="$(printf '%02d:%02d:%02d' "$hours" "$minutes" "$seconds")"
fi
read -r load_one load_five load_fifteen _ </proc/loadavg
logical_count=0
while read -r key _; do [[ "$key" =~ ^cpu[0-9]+$ ]] && logical_count=$((logical_count + 1)); done </proc/stat
((logical_count > 0)) || logical_count=1
printf -v observed_at '%(%s)T' -1

jq -nc \
  --argjson at "$observed_at" --argjson cpu_hundredths "$cpu_hundredths" \
  --argjson logical "$logical_count" --argjson memory_hundredths "$memory_hundredths" \
  --argjson used "$((mem_used_kib * 1024))" --argjson total_memory "$((mem_total_kib * 1024))" \
  --argjson available "$((mem_available_kib * 1024))" --argjson uptime "$uptime_seconds" \
  --arg uptime_human "$uptime_human" --argjson load_one "$load_one" \
  --argjson load_five "$load_five" --argjson load_fifteen "$load_fifteen" '
  {schema_version:1,ok:true,source:"procfs-rail",observed_at:$at,
    data:{cpu:{percent:($cpu_hundredths/100),logical_count:$logical,logical_cpus:$logical},
      memory:{percent:($memory_hundredths/100),used_bytes:$used,total_bytes:$total_memory,available_bytes:$available},
      uptime:{seconds:$uptime,human:$uptime_human},
      load:{one:$load_one,five:$load_five,fifteen:$load_fifteen}},error:null}'
