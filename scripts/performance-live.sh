#!/usr/bin/env bash

# Emit one synchronized, read-only performance sample. Counter-based metrics
# are derived from deltas across the same short interval so rates line up.

set -uo pipefail

export LC_ALL=C

readonly PROC_ROOT="${SENOMY_PROC_ROOT:-/proc}"
readonly SYS_ROOT="${SENOMY_SYS_ROOT:-/sys}"
readonly SAMPLE_DELAY="${SENOMY_PERFORMANCE_SAMPLE_DELAY:-0.25}"
readonly JQ_BIN="${SENOMY_JQ_BIN:-/usr/bin/jq}"
readonly FINDMNT_BIN="${SENOMY_FINDMNT_BIN:-/usr/bin/findmnt}"
readonly LSBLK_BIN="${SENOMY_LSBLK_BIN:-/usr/bin/lsblk}"
readonly READLINK_BIN="${SENOMY_READLINK_BIN:-/usr/bin/readlink}"

printf -v observed_at '%(%s)T' -1

emit_error() {
  local code="$1"
  local message="$2"

  if [[ -x "$JQ_BIN" ]]; then
    "$JQ_BIN" -nc \
      --argjson observed_at "$observed_at" \
      --arg code "$code" \
      --arg message "$message" \
      '{
        schema_version: 1,
        ok: false,
        source: "procfs+sysfs",
        observed_at: $observed_at,
        data: null,
        error: {code: $code, message: $message}
      }'
  else
    printf \
      '{"schema_version":1,"ok":false,"source":"procfs+sysfs","observed_at":%s,"data":null,"error":{"code":"dependency_missing","message":"Required command jq is unavailable"}}\n' \
      "$observed_at"
  fi
  exit 0
}

is_uint() {
  [[ "${1:-}" =~ ^[0-9]+$ ]]
}

is_number() {
  [[ "${1:-}" =~ ^[0-9]+([.][0-9]+)?$ ]]
}

nonnegative_delta() {
  local after="${1:-0}"
  local before="${2:-0}"

  if is_uint "$after" && is_uint "$before" && ((after >= before)); then
    printf '%s\n' "$((after - before))"
  else
    printf '0\n'
  fi
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

declare -A cpu_before=()
declare -A cpu_after=()
declare -A core_total_before=()
declare -A core_total_after=()
declare -A core_idle_before=()
declare -A core_idle_after=()

read_cpu_snapshot() {
  local fields_name="$1"
  local core_total_name="$2"
  local core_idle_name="$3"
  local -n fields_ref="$fields_name"
  local -n core_total_ref="$core_total_name"
  local -n core_idle_ref="$core_idle_name"
  local label user nice system idle iowait irq softirq steal guest guest_nice
  local value

  while read -r label user nice system idle iowait irq softirq steal guest guest_nice; do
    case "$label" in
      cpu | cpu[0-9]*)
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

        if [[ "$label" == "cpu" ]]; then
          fields_ref[user]="$user"
          fields_ref[nice]="$nice"
          fields_ref[system]="$system"
          fields_ref[idle]="$idle"
          fields_ref[iowait]="$iowait"
          fields_ref[irq]="$irq"
          fields_ref[softirq]="$softirq"
          fields_ref[steal]="$steal"
          fields_ref[total]="$((user + nice + system + idle + iowait + irq + softirq + steal))"
        else
          core_id="${label#cpu}"
          core_total_ref["$core_id"]="$((user + nice + system + idle + iowait + irq + softirq + steal))"
          core_idle_ref["$core_id"]="$((idle + iowait))"
        fi
        ;;
      ctxt | intr | processes | procs_running | procs_blocked)
        value="${user:-0}"
        is_uint "$value" || value=0
        fields_ref["$label"]="$value"
        ;;
    esac
  done < "$PROC_ROOT/stat"

  [[ -n "${fields_ref[total]:-}" ]]
}

declare -A memory=()

read_memory() {
  local key value unit

  while read -r key value unit; do
    key="${key%:}"
    is_uint "${value:-}" || continue
    memory["$key"]="$value"
  done < "$PROC_ROOT/meminfo"

  is_uint "${memory[MemTotal]:-}" && ((${memory[MemTotal]} > 0))
}

declare -A pressure=()

read_pressure() {
  local resource="$1"
  local file="$PROC_ROOT/pressure/$resource"
  local scope pair key value

  [[ -r "$file" ]] || return 0

  while read -r scope pair; do
    for pair in $pair; do
      key="${pair%%=*}"
      value="${pair#*=}"
      pressure["${resource}_${scope}_${key}"]="$value"
    done
  done < "$file"
}

root_source=""
root_device=""
root_parent=""

detect_root_device() {
  local resolved

  [[ -x "$FINDMNT_BIN" ]] || return 0
  root_source="$("$FINDMNT_BIN" -n -o SOURCE / 2>/dev/null || true)"
  [[ "$root_source" == /dev/* ]] || return 0

  resolved="$root_source"
  if [[ -x "$READLINK_BIN" ]]; then
    resolved="$("$READLINK_BIN" -f "$root_source" 2>/dev/null || printf '%s' "$root_source")"
  fi
  root_device="${resolved##*/}"

  if [[ -x "$LSBLK_BIN" ]]; then
    root_parent="$("$LSBLK_BIN" -ndo PKNAME "$resolved" 2>/dev/null | head -n 1 || true)"
  fi
}

declare -A disk_before=()
declare -A disk_after=()

read_disk_snapshot() {
  local device="$1"
  local target_name="$2"
  local -n target_ref="$target_name"
  local major minor name
  local reads read_merged sectors_read read_ms
  local writes write_merged sectors_written write_ms
  local in_flight io_ms weighted_ms
  local discard_ios discard_merged discard_sectors discard_ms
  local flush_ios flush_ms

  [[ -n "$device" && -r "$PROC_ROOT/diskstats" ]] || return 1

  while read -r \
      major minor name \
      reads read_merged sectors_read read_ms \
      writes write_merged sectors_written write_ms \
      in_flight io_ms weighted_ms \
      discard_ios discard_merged discard_sectors discard_ms \
      flush_ios flush_ms; do
    [[ "$name" == "$device" ]] || continue
    target_ref[reads]="${reads:-0}"
    target_ref[sectors_read]="${sectors_read:-0}"
    target_ref[writes]="${writes:-0}"
    target_ref[sectors_written]="${sectors_written:-0}"
    target_ref[in_flight]="${in_flight:-0}"
    target_ref[io_ms]="${io_ms:-0}"
    return 0
  done < "$PROC_ROOT/diskstats"

  return 1
}

active_interface=""

detect_active_interface() {
  local iface destination gateway flags rest
  local candidate operstate

  if [[ -r "$PROC_ROOT/net/route" ]]; then
    while read -r iface destination gateway flags rest; do
      [[ "$iface" == "Iface" ]] && continue
      if [[ "$destination" == "00000000" && "$iface" != "lo" ]]; then
        active_interface="$iface"
        return
      fi
    done < "$PROC_ROOT/net/route"
  fi

  for candidate in "$SYS_ROOT"/class/net/*; do
    [[ -e "$candidate" ]] || continue
    iface="${candidate##*/}"
    [[ "$iface" != "lo" ]] || continue
    operstate=""
    [[ -r "$candidate/operstate" ]] && read -r operstate < "$candidate/operstate"
    if [[ "$operstate" == "up" ]]; then
      active_interface="$iface"
      return
    fi
  done

  if [[ -r "$PROC_ROOT/net/dev" ]]; then
    while IFS=': ' read -r iface rest; do
      [[ -n "$rest" && "$iface" != "lo" ]] || continue
      active_interface="$iface"
      return
    done < "$PROC_ROOT/net/dev"
  fi
}

declare -A network_before=()
declare -A network_after=()

read_network_snapshot() {
  local iface="$1"
  local target_name="$2"
  local -n target_ref="$target_name"
  local line_name
  local rx_bytes rx_packets rx_errors rx_drops rx_fifo rx_frame rx_compressed rx_multicast
  local tx_bytes tx_packets tx_errors tx_drops tx_fifo tx_collisions tx_carrier tx_compressed

  [[ -n "$iface" && -r "$PROC_ROOT/net/dev" ]] || return 1

  while IFS=': ' read -r line_name \
      rx_bytes rx_packets rx_errors rx_drops rx_fifo rx_frame rx_compressed rx_multicast \
      tx_bytes tx_packets tx_errors tx_drops tx_fifo tx_collisions tx_carrier tx_compressed; do
    [[ "$line_name" == "$iface" ]] || continue
    target_ref[rx_bytes]="${rx_bytes:-0}"
    target_ref[rx_packets]="${rx_packets:-0}"
    target_ref[rx_errors]="${rx_errors:-0}"
    target_ref[rx_drops]="${rx_drops:-0}"
    target_ref[tx_bytes]="${tx_bytes:-0}"
    target_ref[tx_packets]="${tx_packets:-0}"
    target_ref[tx_errors]="${tx_errors:-0}"
    target_ref[tx_drops]="${tx_drops:-0}"
    return 0
  done < "$PROC_ROOT/net/dev"

  return 1
}

cpu_temperature_available=false
cpu_temperature_millicelsius=0
cpu_temperature_source=""
fan_available=false
fan_rpm=0

read_thermal_data() {
  local hwmon name_file name input label_file label raw
  local zone type_file source

  for hwmon in "$SYS_ROOT"/class/hwmon/hwmon*; do
    [[ -d "$hwmon" ]] || continue
    name_file="$hwmon/name"
    name=""
    [[ -r "$name_file" ]] && read -r name < "$name_file"

    if [[ "$name" == "coretemp" ]]; then
      for input in "$hwmon"/temp*_input; do
        [[ -r "$input" ]] || continue
        label_file="${input%_input}_label"
        label=""
        [[ -r "$label_file" ]] && read -r label < "$label_file"
        [[ "$label" == Package* || -z "$label" ]] || continue
        read -r raw < "$input" || continue
        is_uint "$raw" || continue
        cpu_temperature_available=true
        cpu_temperature_millicelsius="$raw"
        cpu_temperature_source="${name}:${label:-package}"
        break 2
      done
    fi
  done

  if [[ "$cpu_temperature_available" != true ]]; then
    for zone in "$SYS_ROOT"/class/thermal/thermal_zone*; do
      [[ -r "$zone/temp" ]] || continue
      read -r raw < "$zone/temp" || continue
      is_uint "$raw" || continue
      ((raw >= 0 && raw <= 150000)) || continue
      type_file="$zone/type"
      source="thermal"
      [[ -r "$type_file" ]] && read -r source < "$type_file"
      if ((raw > cpu_temperature_millicelsius)); then
        cpu_temperature_available=true
        cpu_temperature_millicelsius="$raw"
        cpu_temperature_source="$source"
      fi
    done
  fi

  for input in "$SYS_ROOT"/class/hwmon/hwmon*/fan*_input; do
    [[ -r "$input" ]] || continue
    read -r raw < "$input" || continue
    is_uint "$raw" || continue
    fan_available=true
    fan_rpm="$raw"
    break
  done
}

frequency_available=false
frequency_current_khz=0
frequency_min_khz=0
frequency_max_khz=0
frequency_base_khz=0
frequency_policy_count=0
frequency_governor=""
frequency_driver=""
frequency_preference=""

read_frequency_data() {
  local policy value
  local current_sum=0
  local current_count=0

  for policy in "$SYS_ROOT"/devices/system/cpu/cpufreq/policy*; do
    [[ -d "$policy" ]] || continue
    ((frequency_policy_count += 1))

    if [[ -r "$policy/scaling_cur_freq" ]]; then
      read -r value < "$policy/scaling_cur_freq" || value=""
      if is_uint "$value"; then
        ((current_sum += value))
        ((current_count += 1))
      fi
    fi

    if [[ -r "$policy/scaling_min_freq" ]]; then
      read -r value < "$policy/scaling_min_freq" || value=""
      if is_uint "$value" && ((frequency_min_khz == 0 || value < frequency_min_khz)); then
        frequency_min_khz="$value"
      fi
    fi

    if [[ -r "$policy/scaling_max_freq" ]]; then
      read -r value < "$policy/scaling_max_freq" || value=""
      if is_uint "$value" && ((value > frequency_max_khz)); then
        frequency_max_khz="$value"
      fi
    fi

    if [[ -r "$policy/base_frequency" ]]; then
      read -r value < "$policy/base_frequency" || value=""
      if is_uint "$value" && ((value > frequency_base_khz)); then
        frequency_base_khz="$value"
      fi
    fi

    [[ -n "$frequency_governor" || ! -r "$policy/scaling_governor" ]] ||
      read -r frequency_governor < "$policy/scaling_governor"
    [[ -n "$frequency_driver" || ! -r "$policy/scaling_driver" ]] ||
      read -r frequency_driver < "$policy/scaling_driver"
    [[ -n "$frequency_preference" || ! -r "$policy/energy_performance_preference" ]] ||
      read -r frequency_preference < "$policy/energy_performance_preference"
  done

  if ((current_count > 0)); then
    frequency_available=true
    frequency_current_khz=$((current_sum / current_count))
  fi
}

graphics_available=false
graphics_driver=""
graphics_card=""
graphics_busy_percent="null"
graphics_current_mhz="null"
graphics_min_mhz="null"
graphics_max_mhz="null"

read_graphics_data() {
  local card device driver_path value

  for card in "$SYS_ROOT"/class/drm/card[0-9]*; do
    [[ -d "$card/device" ]] || continue
    device="$card/device"
    graphics_card="${card##*/}"
    graphics_available=true

    if [[ -L "$device/driver" && -x "$READLINK_BIN" ]]; then
      driver_path="$("$READLINK_BIN" -f "$device/driver" 2>/dev/null || true)"
      graphics_driver="${driver_path##*/}"
    fi

    if [[ -r "$device/gpu_busy_percent" ]]; then
      read -r value < "$device/gpu_busy_percent" || value=""
      is_uint "$value" && graphics_busy_percent="$value"
    fi

    for value_file in \
      "$card/gt_cur_freq_mhz" \
      "$device/gt/gt0/rps_cur_freq_mhz"; do
      [[ -r "$value_file" ]] || continue
      read -r value < "$value_file" || value=""
      is_uint "$value" && graphics_current_mhz="$value"
      break
    done

    for value_file in \
      "$card/gt_min_freq_mhz" \
      "$device/gt/gt0/rps_min_freq_mhz"; do
      [[ -r "$value_file" ]] || continue
      read -r value < "$value_file" || value=""
      is_uint "$value" && graphics_min_mhz="$value"
      break
    done

    for value_file in \
      "$card/gt_max_freq_mhz" \
      "$device/gt/gt0/rps_max_freq_mhz"; do
      [[ -r "$value_file" ]] || continue
      read -r value < "$value_file" || value=""
      is_uint "$value" && graphics_max_mhz="$value"
      break
    done

    break
  done
}

[[ -x "$JQ_BIN" ]] || emit_error "dependency_missing" "Required command jq is unavailable"

for required_file in stat meminfo uptime loadavg; do
  [[ -r "$PROC_ROOT/$required_file" ]] ||
    emit_error "source_unavailable" "Required procfs source is unavailable"
done

is_number "$SAMPLE_DELAY" ||
  emit_error "invalid_configuration" "Performance sample delay must be numeric"

read_memory ||
  emit_error "malformed_source" "Unable to read memory counters"

detect_root_device
detect_active_interface

read -r uptime_before_raw _ < "$PROC_ROOT/uptime" ||
  emit_error "malformed_source" "Unable to read uptime"
uptime_before_ms="$(uptime_milliseconds "$uptime_before_raw")" ||
  emit_error "malformed_source" "Unable to parse uptime"

read_cpu_snapshot cpu_before core_total_before core_idle_before ||
  emit_error "malformed_source" "Unable to read CPU counters"

disk_available=false
if read_disk_snapshot "$root_device" disk_before; then
  disk_available=true
elif [[ -n "$root_parent" ]] && read_disk_snapshot "$root_parent" disk_before; then
  root_device="$root_parent"
  disk_available=true
fi

network_available=false
if read_network_snapshot "$active_interface" network_before; then
  network_available=true
fi

sleep "$SAMPLE_DELAY" 2>/dev/null ||
  emit_error "sample_failed" "Unable to pause between counter samples"

read_cpu_snapshot cpu_after core_total_after core_idle_after ||
  emit_error "malformed_source" "Unable to read CPU counters"

if [[ "$disk_available" == true ]]; then
  read_disk_snapshot "$root_device" disk_after || disk_available=false
fi

if [[ "$network_available" == true ]]; then
  read_network_snapshot "$active_interface" network_after || network_available=false
fi

read -r uptime_after_raw _ < "$PROC_ROOT/uptime" ||
  emit_error "malformed_source" "Unable to read uptime"
uptime_after_ms="$(uptime_milliseconds "$uptime_after_raw")" ||
  emit_error "malformed_source" "Unable to parse uptime"
elapsed_ms=$((uptime_after_ms - uptime_before_ms))
((elapsed_ms > 0)) || elapsed_ms=1

cpu_total_delta="$(nonnegative_delta "${cpu_after[total]}" "${cpu_before[total]}")"
((cpu_total_delta > 0)) ||
  emit_error "sample_failed" "CPU counters did not advance"

cpu_user_delta="$(nonnegative_delta "${cpu_after[user]}" "${cpu_before[user]}")"
cpu_nice_delta="$(nonnegative_delta "${cpu_after[nice]}" "${cpu_before[nice]}")"
cpu_system_delta="$(nonnegative_delta "${cpu_after[system]}" "${cpu_before[system]}")"
cpu_idle_delta="$(nonnegative_delta "${cpu_after[idle]}" "${cpu_before[idle]}")"
cpu_iowait_delta="$(nonnegative_delta "${cpu_after[iowait]}" "${cpu_before[iowait]}")"
cpu_irq_delta="$(nonnegative_delta "${cpu_after[irq]}" "${cpu_before[irq]}")"
cpu_softirq_delta="$(nonnegative_delta "${cpu_after[softirq]}" "${cpu_before[softirq]}")"
cpu_steal_delta="$(nonnegative_delta "${cpu_after[steal]}" "${cpu_before[steal]}")"
cpu_busy_delta=$((cpu_total_delta - cpu_idle_delta - cpu_iowait_delta))
((cpu_busy_delta < 0)) && cpu_busy_delta=0

core_rows=""
logical_cpus=0
mapfile -t core_ids < <(printf '%s\n' "${!core_total_after[@]}" | sort -n)
for core_id in "${core_ids[@]}"; do
  [[ -n "$core_id" && -n "${core_total_before[$core_id]:-}" ]] || continue
  core_total_delta="$(
    nonnegative_delta \
      "${core_total_after[$core_id]}" \
      "${core_total_before[$core_id]}"
  )"
  core_idle_delta="$(
    nonnegative_delta \
      "${core_idle_after[$core_id]}" \
      "${core_idle_before[$core_id]}"
  )"
  core_busy_delta=$((core_total_delta - core_idle_delta))
  ((core_busy_delta < 0)) && core_busy_delta=0
  core_percent_tenths=0
  if ((core_total_delta > 0)); then
    core_percent_tenths=$(((core_busy_delta * 1000 + core_total_delta / 2) / core_total_delta))
  fi
  ((core_percent_tenths > 1000)) && core_percent_tenths=1000

  core_frequency_khz="null"
  core_frequency_file="$SYS_ROOT/devices/system/cpu/cpu${core_id}/cpufreq/scaling_cur_freq"
  if [[ -r "$core_frequency_file" ]]; then
    read -r core_frequency_khz < "$core_frequency_file" || core_frequency_khz="null"
    is_uint "$core_frequency_khz" || core_frequency_khz="null"
  fi

  printf -v core_percent '%d.%d' \
    "$((core_percent_tenths / 10))" \
    "$((core_percent_tenths % 10))"
  core_rows+="${core_id}"$'\t'"${core_percent}"$'\t'"${core_frequency_khz}"$'\n'
  ((logical_cpus += 1))
done

cores_json="$(
  "$JQ_BIN" -Rsc '
    split("\n")
    | map(
        select(length > 0)
        | split("\t")
        | {
            id: (.[0] | tonumber),
            percent: (.[1] | tonumber),
            frequency_mhz: (
              if .[2] == "null" then null else ((.[2] | tonumber) / 1000 | round) end
            )
          }
      )
  ' <<< "$core_rows"
)"

mem_total_kib="${memory[MemTotal]}"
mem_available_kib="${memory[MemAvailable]:-${memory[MemFree]:-0}}"
((mem_available_kib > mem_total_kib)) && mem_available_kib="$mem_total_kib"
mem_used_kib=$((mem_total_kib - mem_available_kib))
mem_free_kib="${memory[MemFree]:-0}"
mem_buffers_kib="${memory[Buffers]:-0}"
mem_cached_kib="${memory[Cached]:-0}"
mem_reclaimable_kib="${memory[SReclaimable]:-0}"
mem_anon_kib="${memory[AnonPages]:-0}"
mem_slab_kib="${memory[Slab]:-0}"
mem_shared_kib="${memory[Shmem]:-0}"
mem_dirty_kib="${memory[Dirty]:-0}"
mem_writeback_kib="${memory[Writeback]:-0}"
mem_page_tables_kib="${memory[PageTables]:-0}"
mem_kernel_stack_kib="${memory[KernelStack]:-0}"
swap_total_kib="${memory[SwapTotal]:-0}"
swap_free_kib="${memory[SwapFree]:-0}"
((swap_free_kib > swap_total_kib)) && swap_free_kib="$swap_total_kib"
swap_used_kib=$((swap_total_kib - swap_free_kib))
commit_limit_kib="${memory[CommitLimit]:-0}"
committed_kib="${memory[Committed_AS]:-0}"

read_pressure cpu
read_pressure memory
read_pressure io
read_pressure irq
read_frequency_data
read_thermal_data
read_graphics_data

read -r load_one load_five load_fifteen task_counts _ < "$PROC_ROOT/loadavg" ||
  emit_error "malformed_source" "Unable to read load averages"
is_number "$load_one" && is_number "$load_five" && is_number "$load_fifteen" ||
  emit_error "malformed_source" "Unable to parse load averages"

tasks_total=0
if [[ "$task_counts" == */* ]]; then
  tasks_total="${task_counts#*/}"
  is_uint "$tasks_total" || tasks_total=0
fi

uptime_seconds="${uptime_after_raw%%.*}"
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

context_switch_delta="$(
  nonnegative_delta "${cpu_after[ctxt]:-0}" "${cpu_before[ctxt]:-0}"
)"
interrupt_delta="$(
  nonnegative_delta "${cpu_after[intr]:-0}" "${cpu_before[intr]:-0}"
)"
fork_delta="$(
  nonnegative_delta "${cpu_after[processes]:-0}" "${cpu_before[processes]:-0}"
)"

disk_read_delta=0
disk_write_delta=0
disk_reads_delta=0
disk_writes_delta=0
disk_io_ms_delta=0
disk_read_total=0
disk_write_total=0
disk_in_flight=0
if [[ "$disk_available" == true ]]; then
  disk_read_delta="$(
    nonnegative_delta "${disk_after[sectors_read]}" "${disk_before[sectors_read]}"
  )"
  disk_write_delta="$(
    nonnegative_delta "${disk_after[sectors_written]}" "${disk_before[sectors_written]}"
  )"
  disk_reads_delta="$(
    nonnegative_delta "${disk_after[reads]}" "${disk_before[reads]}"
  )"
  disk_writes_delta="$(
    nonnegative_delta "${disk_after[writes]}" "${disk_before[writes]}"
  )"
  disk_io_ms_delta="$(
    nonnegative_delta "${disk_after[io_ms]}" "${disk_before[io_ms]}"
  )"
  disk_read_total=$((disk_after[sectors_read] * 512))
  disk_write_total=$((disk_after[sectors_written] * 512))
  disk_in_flight="${disk_after[in_flight]}"
fi

network_rx_delta=0
network_tx_delta=0
network_rx_packets_delta=0
network_tx_packets_delta=0
network_rx_total=0
network_tx_total=0
network_rx_errors=0
network_tx_errors=0
network_rx_drops=0
network_tx_drops=0
if [[ "$network_available" == true ]]; then
  network_rx_delta="$(
    nonnegative_delta "${network_after[rx_bytes]}" "${network_before[rx_bytes]}"
  )"
  network_tx_delta="$(
    nonnegative_delta "${network_after[tx_bytes]}" "${network_before[tx_bytes]}"
  )"
  network_rx_packets_delta="$(
    nonnegative_delta "${network_after[rx_packets]}" "${network_before[rx_packets]}"
  )"
  network_tx_packets_delta="$(
    nonnegative_delta "${network_after[tx_packets]}" "${network_before[tx_packets]}"
  )"
  network_rx_total="${network_after[rx_bytes]}"
  network_tx_total="${network_after[tx_bytes]}"
  network_rx_errors="${network_after[rx_errors]}"
  network_tx_errors="${network_after[tx_errors]}"
  network_rx_drops="${network_after[rx_drops]}"
  network_tx_drops="${network_after[tx_drops]}"
fi

network_state="unavailable"
network_kind="none"
network_mtu="null"
network_speed_mbps="null"
network_signal_dbm="null"
if [[ -n "$active_interface" ]]; then
  interface_root="$SYS_ROOT/class/net/$active_interface"
  if [[ -r "$interface_root/operstate" ]]; then
    read -r network_state < "$interface_root/operstate" || network_state="unknown"
  else
    network_state="unknown"
  fi
  if [[ -d "$interface_root/wireless" ]]; then
    network_kind="wireless"
  else
    network_kind="ethernet"
  fi
  if [[ -r "$interface_root/mtu" ]]; then
    read -r network_mtu < "$interface_root/mtu" || network_mtu="null"
    is_uint "$network_mtu" || network_mtu="null"
  fi
  if [[ -r "$interface_root/speed" ]]; then
    read -r network_speed_mbps 2>/dev/null < "$interface_root/speed" ||
      network_speed_mbps="null"
    is_uint "$network_speed_mbps" || network_speed_mbps="null"
  fi
  if [[ -r "$PROC_ROOT/net/wireless" ]]; then
    signal_raw="$(
      awk -v iface="$active_interface" '
        $1 == iface ":" {
          gsub(/[.]/, "", $4)
          print $4
          exit
        }
      ' "$PROC_ROOT/net/wireless"
    )"
    [[ "$signal_raw" =~ ^-?[0-9]+$ ]] && network_signal_dbm="$signal_raw"
  fi
fi

"$JQ_BIN" -nc \
  --argjson observed_at "$observed_at" \
  --argjson elapsed_ms "$elapsed_ms" \
  --argjson sample_delay "$SAMPLE_DELAY" \
  --argjson cpu_total_delta "$cpu_total_delta" \
  --argjson cpu_busy_delta "$cpu_busy_delta" \
  --argjson cpu_user_delta "$cpu_user_delta" \
  --argjson cpu_nice_delta "$cpu_nice_delta" \
  --argjson cpu_system_delta "$cpu_system_delta" \
  --argjson cpu_idle_delta "$cpu_idle_delta" \
  --argjson cpu_iowait_delta "$cpu_iowait_delta" \
  --argjson cpu_irq_delta "$cpu_irq_delta" \
  --argjson cpu_softirq_delta "$cpu_softirq_delta" \
  --argjson cpu_steal_delta "$cpu_steal_delta" \
  --argjson cores "$cores_json" \
  --argjson logical_cpus "$logical_cpus" \
  --argjson frequency_available "$frequency_available" \
  --argjson frequency_current_khz "$frequency_current_khz" \
  --argjson frequency_min_khz "$frequency_min_khz" \
  --argjson frequency_max_khz "$frequency_max_khz" \
  --argjson frequency_base_khz "$frequency_base_khz" \
  --argjson frequency_policy_count "$frequency_policy_count" \
  --arg frequency_governor "$frequency_governor" \
  --arg frequency_driver "$frequency_driver" \
  --arg frequency_preference "$frequency_preference" \
  --argjson context_switch_delta "$context_switch_delta" \
  --argjson interrupt_delta "$interrupt_delta" \
  --argjson fork_delta "$fork_delta" \
  --argjson processes_running "${cpu_after[procs_running]:-0}" \
  --argjson processes_blocked "${cpu_after[procs_blocked]:-0}" \
  --argjson tasks_total "$tasks_total" \
  --argjson mem_total_kib "$mem_total_kib" \
  --argjson mem_used_kib "$mem_used_kib" \
  --argjson mem_available_kib "$mem_available_kib" \
  --argjson mem_free_kib "$mem_free_kib" \
  --argjson mem_buffers_kib "$mem_buffers_kib" \
  --argjson mem_cached_kib "$mem_cached_kib" \
  --argjson mem_reclaimable_kib "$mem_reclaimable_kib" \
  --argjson mem_anon_kib "$mem_anon_kib" \
  --argjson mem_slab_kib "$mem_slab_kib" \
  --argjson mem_shared_kib "$mem_shared_kib" \
  --argjson mem_dirty_kib "$mem_dirty_kib" \
  --argjson mem_writeback_kib "$mem_writeback_kib" \
  --argjson mem_page_tables_kib "$mem_page_tables_kib" \
  --argjson mem_kernel_stack_kib "$mem_kernel_stack_kib" \
  --argjson swap_total_kib "$swap_total_kib" \
  --argjson swap_used_kib "$swap_used_kib" \
  --argjson commit_limit_kib "$commit_limit_kib" \
  --argjson committed_kib "$committed_kib" \
  --argjson pressure_cpu_some "${pressure[cpu_some_avg10]:-null}" \
  --argjson pressure_memory_some "${pressure[memory_some_avg10]:-null}" \
  --argjson pressure_memory_full "${pressure[memory_full_avg10]:-null}" \
  --argjson pressure_io_some "${pressure[io_some_avg10]:-null}" \
  --argjson pressure_io_full "${pressure[io_full_avg10]:-null}" \
  --argjson pressure_irq_full "${pressure[irq_full_avg10]:-null}" \
  --argjson disk_available "$disk_available" \
  --arg disk_source "$root_source" \
  --arg disk_device "$root_device" \
  --argjson disk_read_delta "$disk_read_delta" \
  --argjson disk_write_delta "$disk_write_delta" \
  --argjson disk_reads_delta "$disk_reads_delta" \
  --argjson disk_writes_delta "$disk_writes_delta" \
  --argjson disk_io_ms_delta "$disk_io_ms_delta" \
  --argjson disk_read_total "$disk_read_total" \
  --argjson disk_write_total "$disk_write_total" \
  --argjson disk_in_flight "$disk_in_flight" \
  --argjson network_available "$network_available" \
  --arg network_interface "$active_interface" \
  --arg network_state "$network_state" \
  --arg network_kind "$network_kind" \
  --argjson network_mtu "$network_mtu" \
  --argjson network_speed_mbps "$network_speed_mbps" \
  --argjson network_signal_dbm "$network_signal_dbm" \
  --argjson network_rx_delta "$network_rx_delta" \
  --argjson network_tx_delta "$network_tx_delta" \
  --argjson network_rx_packets_delta "$network_rx_packets_delta" \
  --argjson network_tx_packets_delta "$network_tx_packets_delta" \
  --argjson network_rx_total "$network_rx_total" \
  --argjson network_tx_total "$network_tx_total" \
  --argjson network_rx_errors "$network_rx_errors" \
  --argjson network_tx_errors "$network_tx_errors" \
  --argjson network_rx_drops "$network_rx_drops" \
  --argjson network_tx_drops "$network_tx_drops" \
  --argjson temperature_available "$cpu_temperature_available" \
  --argjson temperature_millicelsius "$cpu_temperature_millicelsius" \
  --arg temperature_source "$cpu_temperature_source" \
  --argjson fan_available "$fan_available" \
  --argjson fan_rpm "$fan_rpm" \
  --argjson graphics_available "$graphics_available" \
  --arg graphics_card "$graphics_card" \
  --arg graphics_driver "$graphics_driver" \
  --argjson graphics_busy_percent "$graphics_busy_percent" \
  --argjson graphics_current_mhz "$graphics_current_mhz" \
  --argjson graphics_min_mhz "$graphics_min_mhz" \
  --argjson graphics_max_mhz "$graphics_max_mhz" \
  --argjson uptime_seconds "$uptime_seconds" \
  --arg uptime_human "$uptime_human" \
  --argjson load_one "$load_one" \
  --argjson load_five "$load_five" \
  --argjson load_fifteen "$load_fifteen" '
    def clamp($low; $high):
      if . < $low then $low elif . > $high then $high else . end;
    def percent($part; $whole):
      if $whole > 0 then (($part * 1000 / $whole | round) / 10) else 0 end;
    def per_second($delta):
      if $elapsed_ms > 0 then (($delta * 1000 / $elapsed_ms * 10 | round) / 10) else 0 end;
    def byte_rate($delta):
      if $elapsed_ms > 0 then ($delta * 1000 / $elapsed_ms | round) else 0 end;

    ($mem_total_kib * 1024) as $memory_total |
    ($mem_used_kib * 1024) as $memory_used |
    ($swap_total_kib * 1024) as $swap_total |
    ($swap_used_kib * 1024) as $swap_used |
    (($disk_read_delta * 512 * 1000 / $elapsed_ms) | round) as $disk_read_bps |
    (($disk_write_delta * 512 * 1000 / $elapsed_ms) | round) as $disk_write_bps |
    (($network_rx_delta * 1000 / $elapsed_ms) | round) as $network_rx_bps |
    (($network_tx_delta * 1000 / $elapsed_ms) | round) as $network_tx_bps |

    {
      schema_version: 1,
      ok: true,
      source: "procfs+sysfs",
      observed_at: $observed_at,
      data: {
        cpu: {
          percent: (percent($cpu_busy_delta; $cpu_total_delta) | clamp(0; 100)),
          sample_seconds: (($elapsed_ms / 1000 * 100 | round) / 100),
          logical_cpus: $logical_cpus,
          cores: $cores,
          breakdown: {
            user_percent: (percent(($cpu_user_delta + $cpu_nice_delta); $cpu_total_delta)),
            system_percent: (percent($cpu_system_delta; $cpu_total_delta)),
            iowait_percent: (percent($cpu_iowait_delta; $cpu_total_delta)),
            irq_percent: (percent(($cpu_irq_delta + $cpu_softirq_delta); $cpu_total_delta)),
            steal_percent: (percent($cpu_steal_delta; $cpu_total_delta)),
            idle_percent: (percent($cpu_idle_delta; $cpu_total_delta))
          },
          frequency: {
            available: $frequency_available,
            current_mhz: (if $frequency_available then ($frequency_current_khz / 1000 | round) else null end),
            min_mhz: (if $frequency_min_khz > 0 then ($frequency_min_khz / 1000 | round) else null end),
            max_mhz: (if $frequency_max_khz > 0 then ($frequency_max_khz / 1000 | round) else null end),
            base_mhz: (if $frequency_base_khz > 0 then ($frequency_base_khz / 1000 | round) else null end),
            governor: (if $frequency_governor == "" then null else $frequency_governor end),
            driver: (if $frequency_driver == "" then null else $frequency_driver end),
            preference: (if $frequency_preference == "" then null else $frequency_preference end),
            policy_count: $frequency_policy_count
          },
          scheduler: {
            context_switches_per_second: per_second($context_switch_delta),
            interrupts_per_second: per_second($interrupt_delta),
            forks_per_second: per_second($fork_delta),
            running: $processes_running,
            blocked: $processes_blocked,
            tasks_total: $tasks_total
          }
        },
        memory: {
          total_bytes: $memory_total,
          used_bytes: $memory_used,
          available_bytes: ($mem_available_kib * 1024),
          free_bytes: ($mem_free_kib * 1024),
          percent: (percent($memory_used; $memory_total)),
          buffers_bytes: ($mem_buffers_kib * 1024),
          cache_bytes: (($mem_cached_kib + $mem_reclaimable_kib) * 1024),
          anonymous_bytes: ($mem_anon_kib * 1024),
          slab_bytes: ($mem_slab_kib * 1024),
          shared_bytes: ($mem_shared_kib * 1024),
          dirty_bytes: ($mem_dirty_kib * 1024),
          writeback_bytes: ($mem_writeback_kib * 1024),
          page_tables_bytes: ($mem_page_tables_kib * 1024),
          kernel_stack_bytes: ($mem_kernel_stack_kib * 1024),
          swap: {
            available: ($swap_total > 0),
            total_bytes: $swap_total,
            used_bytes: $swap_used,
            percent: (percent($swap_used; $swap_total))
          },
          commit: {
            available: ($commit_limit_kib > 0),
            limit_bytes: ($commit_limit_kib * 1024),
            committed_bytes: ($committed_kib * 1024),
            percent: (percent($committed_kib; $commit_limit_kib))
          }
        },
        disk: {
          available: $disk_available,
          source: (if $disk_source == "" then null else $disk_source end),
          device: (if $disk_device == "" then null else $disk_device end),
          read_bytes_per_second: $disk_read_bps,
          write_bytes_per_second: $disk_write_bps,
          read_iops: per_second($disk_reads_delta),
          write_iops: per_second($disk_writes_delta),
          busy_percent: (($disk_io_ms_delta * 100 / $elapsed_ms) | clamp(0; 100) | . * 10 | round / 10),
          in_flight: $disk_in_flight,
          total_read_bytes: $disk_read_total,
          total_written_bytes: $disk_write_total
        },
        network: {
          available: $network_available,
          interface: (if $network_interface == "" then null else $network_interface end),
          state: $network_state,
          kind: $network_kind,
          mtu: $network_mtu,
          link_speed_mbps: $network_speed_mbps,
          signal_dbm: $network_signal_dbm,
          receive_bytes_per_second: $network_rx_bps,
          transmit_bytes_per_second: $network_tx_bps,
          receive_packets_per_second: per_second($network_rx_packets_delta),
          transmit_packets_per_second: per_second($network_tx_packets_delta),
          total_received_bytes: $network_rx_total,
          total_transmitted_bytes: $network_tx_total,
          receive_errors: $network_rx_errors,
          transmit_errors: $network_tx_errors,
          receive_drops: $network_rx_drops,
          transmit_drops: $network_tx_drops
        },
        pressure: {
          available: (
            $pressure_cpu_some != null
            or $pressure_memory_some != null
            or $pressure_io_some != null
          ),
          cpu: {some_avg10: $pressure_cpu_some},
          memory: {
            some_avg10: $pressure_memory_some,
            full_avg10: $pressure_memory_full
          },
          io: {
            some_avg10: $pressure_io_some,
            full_avg10: $pressure_io_full
          },
          irq: {full_avg10: $pressure_irq_full}
        },
        thermal: {
          cpu: {
            available: $temperature_available,
            celsius: (
              if $temperature_available
              then (($temperature_millicelsius / 100 | round) / 10)
              else null
              end
            ),
            source: (if $temperature_source == "" then null else $temperature_source end)
          },
          fan: {
            available: $fan_available,
            rpm: (if $fan_available then $fan_rpm else null end)
          }
        },
        graphics: {
          available: $graphics_available,
          card: (if $graphics_card == "" then null else $graphics_card end),
          driver: (if $graphics_driver == "" then null else $graphics_driver end),
          busy_percent: $graphics_busy_percent,
          current_mhz: $graphics_current_mhz,
          min_mhz: $graphics_min_mhz,
          max_mhz: $graphics_max_mhz
        },
        uptime: {
          seconds: $uptime_seconds,
          human: $uptime_human
        },
        load: {
          one: $load_one,
          five: $load_five,
          fifteen: $load_fifteen,
          normalized_one_percent: (
            if $logical_cpus > 0
            then (($load_one * 1000 / $logical_cpus | round) / 10)
            else 0
            end
          )
        }
      },
      error: null
    }
  '
