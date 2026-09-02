#!/usr/bin/env bash

# Emit an instantaneous, bounded process table while Performance is visible.

set -uo pipefail

export LC_ALL=C

readonly PROC_ROOT="${SENOMY_PROC_ROOT:-/proc}"
readonly JQ_BIN="${SENOMY_JQ_BIN:-/usr/bin/jq}"
readonly PS_BIN="${SENOMY_PS_BIN:-/usr/bin/ps}"
readonly SORT_BIN="${SENOMY_SORT_BIN:-/usr/bin/sort}"
readonly GETCONF_BIN="${SENOMY_GETCONF_BIN:-/usr/bin/getconf}"
readonly PROCESS_LIMIT="${SENOMY_PROCESS_LIMIT:-12}"
readonly SAMPLE_DELAY="${SENOMY_PROCESS_SAMPLE_DELAY:-0.35}"
readonly SORT_STATE="${XDG_RUNTIME_DIR:-/tmp}/senomyos/performance-process-sort"
readonly FILTER_STATE="${XDG_RUNTIME_DIR:-/tmp}/senomyos/performance-process-filter"
SORT_MODE="${1:-}"
if [[ -z "$SORT_MODE" && -r "$SORT_STATE" ]]; then
  read -r SORT_MODE < "$SORT_STATE"
fi
readonly SORT_MODE="${SORT_MODE:-cpu}"
FILTER_MODE="all"
[[ -r "$FILTER_STATE" ]] && read -r FILTER_MODE <"$FILTER_STATE"
[[ "$FILTER_MODE" == all || "$FILTER_MODE" == user || "$FILTER_MODE" == active || "$FILTER_MODE" == heavy ]] || FILTER_MODE=all
readonly FILTER_MODE
readonly CURRENT_USER="$(id -un)"

printf -v observed_at '%(%s)T' -1

emit_error() {
  local code="$1"
  local message="$2"

  "$JQ_BIN" -nc \
    --argjson observed_at "$observed_at" \
    --arg code "$code" \
    --arg message "$message" '
      {
        schema_version: 1,
        ok: false,
        source: "procfs",
        observed_at: $observed_at,
        data: null,
        error: {code: $code, message: $message}
      }
    '
  exit 0
}

is_uint() {
  [[ "${1:-}" =~ ^[0-9]+$ ]]
}

uptime_milliseconds() {
  local raw="$1"
  local whole="${raw%%.*}"
  local fraction="000"

  if [[ "$raw" == *.* ]]; then
    fraction="${raw#*.}000"
    fraction="${fraction:0:3}"
  fi

  is_uint "$whole" && is_uint "$fraction" || return 1
  printf '%s\n' "$((10#$whole * 1000 + 10#$fraction))"
}

process_ticks=0

read_process_ticks() {
  local pid="$1"
  local stat_file="$PROC_ROOT/$pid/stat"
  local stat_line stat_tail
  local -a stat_fields=()

  [[ -r "$stat_file" ]] || return 1
  read -r stat_line < "$stat_file" || return 1
  stat_tail="${stat_line##*) }"
  read -ra stat_fields <<< "$stat_tail"
  ((${#stat_fields[@]} >= 20)) || return 1
  is_uint "${stat_fields[11]}" && is_uint "${stat_fields[12]}" || return 1
  process_ticks=$((${stat_fields[11]} + ${stat_fields[12]}))
}

for command_path in "$JQ_BIN" "$PS_BIN" "$SORT_BIN" "$GETCONF_BIN"; do
  [[ -x "$command_path" ]] ||
    emit_error "dependency_missing" "A required process command is unavailable"
done

is_uint "$PROCESS_LIMIT" && ((PROCESS_LIMIT > 0)) ||
  emit_error "invalid_configuration" "Process limit must be a positive integer"
[[ "$SAMPLE_DELAY" =~ ^[0-9]+([.][0-9]+)?$ ]] ||
  emit_error "invalid_configuration" "Process sample delay must be numeric"
[[ "$SORT_MODE" == cpu || "$SORT_MODE" == memory || "$SORT_MODE" == name ]] ||
  emit_error "invalid_sort" "Process sort must be cpu, memory, or name"

clock_ticks="$("$GETCONF_BIN" CLK_TCK 2>/dev/null || true)"
is_uint "$clock_ticks" && ((clock_ticks > 0)) ||
  emit_error "source_unavailable" "Unable to determine the kernel clock tick rate"

mem_total_kib="$(
  awk '
    $1 == "MemTotal:" {
      print $2
      exit
    }
  ' "$PROC_ROOT/meminfo" 2>/dev/null
)"
is_uint "$mem_total_kib" && ((mem_total_kib > 0)) ||
  emit_error "source_unavailable" "Unable to read total memory"

declare -A ticks_before=()
declare -A ticks_after=()

read -r uptime_before_raw _ < "$PROC_ROOT/uptime" ||
  emit_error "source_unavailable" "Unable to read uptime"
uptime_before_ms="$(uptime_milliseconds "$uptime_before_raw")" ||
  emit_error "malformed_source" "Unable to parse uptime"

for process_dir in "$PROC_ROOT"/[0-9]*; do
  [[ -d "$process_dir" ]] || continue
  pid="${process_dir##*/}"
  read_process_ticks "$pid" 2>/dev/null || continue
  ticks_before["$pid"]="$process_ticks"
done

sleep "$SAMPLE_DELAY" 2>/dev/null ||
  emit_error "sample_failed" "Unable to pause between process samples"

read -r uptime_after_raw _ < "$PROC_ROOT/uptime" ||
  emit_error "source_unavailable" "Unable to read uptime"
uptime_after_ms="$(uptime_milliseconds "$uptime_after_raw")" ||
  emit_error "malformed_source" "Unable to parse uptime"
elapsed_ms=$((uptime_after_ms - uptime_before_ms))
((elapsed_ms > 0)) || elapsed_ms=1

for process_dir in "$PROC_ROOT"/[0-9]*; do
  [[ -d "$process_dir" ]] || continue
  pid="${process_dir##*/}"
  read_process_ticks "$pid" 2>/dev/null || continue
  ticks_after["$pid"]="$process_ticks"
done

process_output="$(
  "$PS_BIN" --no-headers \
    -eo pid=,user=,stat=,rss=,nlwp=,etimes=,pri=,ni=,comm= \
    2>/dev/null ||
    true
)"

process_rows=""
process_count=0
thread_count=0
running_count=0
sleeping_count=0
disk_sleep_count=0
stopped_count=0
zombie_count=0

while read -r pid user state rss_kib threads elapsed_seconds priority nice name; do
  is_uint "$pid" && is_uint "$rss_kib" && is_uint "$threads" || continue
  [[ "$pid" != "$$" && "$pid" != "$PPID" ]] || continue
  [[ "$name" != "ps" && "$name" != "awk" && "$name" != "jq" ]] || continue

  ((process_count += 1))
  ((thread_count += threads))
  state_code="${state:0:1}"
  case "$state_code" in
    R)
      ((running_count += 1))
      ;;
    S | I)
      ((sleeping_count += 1))
      ;;
    D)
      ((disk_sleep_count += 1))
      ;;
    T | t)
      ((stopped_count += 1))
      ;;
    Z)
      ((zombie_count += 1))
      ;;
  esac

  process_ticks_after="${ticks_after[$pid]:-0}"
  ticks_start="${ticks_before[$pid]:-$process_ticks_after}"
  if ((process_ticks_after >= ticks_start)); then
    ticks_delta=$((process_ticks_after - ticks_start))
  else
    ticks_delta=0
  fi

  cpu_tenths=$((ticks_delta * 1000000 / (clock_ticks * elapsed_ms)))
  memory_tenths=$((rss_kib * 1000 / mem_total_kib))

  case "$FILTER_MODE" in
    user) [[ "$user" == "$CURRENT_USER" ]] || continue ;;
    active) [[ "$state_code" == R || "$state_code" == D ]] || continue ;;
    heavy) ((cpu_tenths >= 10 || memory_tenths >= 10)) || continue ;;
  esac

  is_uint "$elapsed_seconds" || elapsed_seconds=0
  is_uint "$priority" || priority=0
  [[ "$nice" =~ ^-?[0-9]+$ ]] || nice=0
  user="${user//$'\t'/ }"
  name="${name//$'\t'/ }"

  process_rows+="${cpu_tenths}"$'\t'"${pid}"$'\t'"${user}"$'\t'"${state_code}"$'\t'"${rss_kib}"$'\t'"${memory_tenths}"$'\t'"${threads}"$'\t'"${elapsed_seconds}"$'\t'"${priority}"$'\t'"${nice}"$'\t'"${name}"$'\n'
done <<< "$process_output"

case "$SORT_MODE" in
  cpu) sorted_rows="$("$SORT_BIN" -t $'\t' -k1,1nr -k5,5nr <<< "$process_rows")" ;;
  memory) sorted_rows="$("$SORT_BIN" -t $'\t' -k5,5nr -k1,1nr <<< "$process_rows")" ;;
  name) sorted_rows="$("$SORT_BIN" -t $'\t' -k11,11f -k1,1nr <<< "$process_rows")" ;;
esac

"$JQ_BIN" -Rsc \
  --argjson observed_at "$observed_at" \
  --argjson sample_seconds "$elapsed_ms" \
  --argjson process_limit "$PROCESS_LIMIT" \
  --argjson process_count "$process_count" \
  --argjson thread_count "$thread_count" \
  --argjson running_count "$running_count" \
  --argjson sleeping_count "$sleeping_count" \
  --argjson disk_sleep_count "$disk_sleep_count" \
  --argjson stopped_count "$stopped_count" \
  --argjson zombie_count "$zombie_count" '
    def duration($seconds):
      if $seconds >= 86400 then
        (($seconds / 86400 | floor | tostring) + "d " +
          (($seconds % 86400) / 3600 | floor | tostring) + "h")
      elif $seconds >= 3600 then
        (($seconds / 3600 | floor | tostring) + "h " +
          (($seconds % 3600) / 60 | floor | tostring) + "m")
      elif $seconds >= 60 then
        (($seconds / 60 | floor | tostring) + "m " +
          ($seconds % 60 | floor | tostring) + "s")
      else
        (($seconds | tostring) + "s")
      end;

    split("\n")
    | map(
        select(length > 0)
        | split("\t")
        | {
            pid: (.[1] | tonumber),
            user: .[2],
            state: .[3],
            cpu_percent: ((.[0] | tonumber) / 10),
            memory_mib: ((.[4] | tonumber) / 1024 * 10 | round / 10),
            memory_percent: ((.[5] | tonumber) / 10),
            threads: (.[6] | tonumber),
            elapsed_seconds: (.[7] | tonumber),
            elapsed: duration(.[7] | tonumber),
            priority: (.[8] | tonumber),
            nice: (.[9] | tonumber),
            name: .[10]
          }
      )
    | .[:$process_limit]
    | to_entries
    | map(.value + {rank: (.key + 1)})
    | {
        schema_version: 1,
        ok: true,
        source: "procfs",
        observed_at: $observed_at,
        data: {
          sample_seconds: (($sample_seconds / 1000 * 100 | round) / 100),
          processes: .,
          shown_count: length,
          process_count: $process_count,
          thread_count: $thread_count,
          states: {
            running: $running_count,
            sleeping: $sleeping_count,
            disk_sleep: $disk_sleep_count,
            stopped: $stopped_count,
            zombie: $zombie_count
          }
        },
        error: null
      }
  ' <<< "$sorted_rows"
