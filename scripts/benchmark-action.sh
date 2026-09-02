#!/usr/bin/env bash

# Bounded SenomyOS confidence/stress benchmark. Workloads are local, finite,
# unprivileged and temperature-watched. Results are comparative evidence, not
# laboratory certification or a guarantee of hardware health.
set -euo pipefail
export LC_ALL=C
umask 077

readonly ACTION="${1:-status}"
readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly ROOT="${SENOMY_BENCHMARK_ROOT:-${XDG_STATE_HOME:-$HOME/.local/state}/senomyos/benchmarks}"
readonly STATUS_FILE="$ROOT/status.json"
readonly LOG_FILE="$ROOT/current.log"
readonly PID_FILE="$ROOT/runner.pid"
readonly TELEMETRY_FILE="$ROOT/current-telemetry.jsonl"
readonly MAX_TEMP_C="${SENOMY_BENCHMARK_MAX_TEMP_C:-95}"

mkdir -p -m 700 "$ROOT"

STARTED_AT=0
ACTIVE_WORKLOAD_PID=0
SCRATCH_FILE=""
WORK_ROOT=""
PROFILE="none"

valid_profile() { case "$1" in quick | standard) return 0 ;; *) return 1 ;; esac; }
profile_estimate() { [[ "$1" == quick ]] && printf '70' || printf '210'; }

profile_plan() {
  local requested_profile="${1:-standard}" cpu_single cpu_multi memory compression storage processes
  valid_profile "$requested_profile" || { printf 'Unknown benchmark profile: %s\n' "$requested_profile" >&2; return 2; }
  if [[ "$requested_profile" == quick ]]; then
    cpu_single=8; cpu_multi=20; memory=10; compression=10; storage=256; processes=200
  else
    cpu_single=15; cpu_multi=60; memory=30; compression=30; storage=512; processes=500
  fi
  jq -nc --arg profile "$requested_profile" --argjson estimate "$(profile_estimate "$requested_profile")" \
    --argjson thermal_limit "$MAX_TEMP_C" --argjson cpu_single "$cpu_single" --argjson cpu_multi "$cpu_multi" \
    --argjson memory "$memory" --argjson compression "$compression" --argjson storage "$storage" \
    --argjson processes "$processes" \
    '{schema_version:1,ok:true,source:"senomy-benchmark-plan",data:{profile:$profile,estimated_seconds:$estimate,
      thermal_limit_c:$thermal_limit,network:false,root:false,package_install:false,
      workloads:{cpu_single_seconds:$cpu_single,cpu_multi_seconds:$cpu_multi,memory_seconds:$memory,
        compression_seconds:$compression,storage_mib:$storage,process_launches:$processes}},error:null}'
}

write_status() {
  local state="$1" progress="$2" stage="$3" message="$4"
  local markdown="${5:-}" pdf="${6:-}" results="${7:-{}}" temporary finished=0
  case "$state" in succeeded | failed | cancelled | thermal-abort) finished="$(date +%s)" ;; esac
  temporary="$(mktemp "$ROOT/.status.XXXXXX")"
  jq -nc --arg state "$state" --argjson progress "$progress" \
    --arg stage "$stage" --arg message "$message" --arg profile "$PROFILE" \
    --arg markdown "$markdown" --arg pdf "$pdf" --argjson results "$results" \
    --argjson observed_at "$(date +%s)" --argjson started_at "$STARTED_AT" \
    --argjson finished_at "$finished" --argjson thermal_limit "$MAX_TEMP_C" '
      {schema_version:2,ok:true,source:"senomy-benchmark",observed_at:$observed_at,
       data:{state:$state,state_label:($state|ascii_upcase|gsub("-";" ")),progress:$progress,
         stage:$stage,message:$message,profile:$profile,
         estimated_seconds:(if $profile=="quick" then 70 elif $profile=="standard" then 210 else 0 end),
         thermal_limit_c:$thermal_limit,started_at:$started_at,finished_at:$finished_at,
         markdown_path:$markdown,pdf_path:$pdf,results:$results},error:null}
    ' >"$temporary"
  chmod 600 "$temporary"
  mv -f "$temporary" "$STATUS_FILE"
}

note() { printf '[%(%H:%M:%S)T] %s\n' -1 "$1" | tee -a "$LOG_FILE" >/dev/null; }
rate_mib() { awk -v mib="$1" -v seconds="$2" 'BEGIN {if(seconds>0)printf "%.1f",mib/seconds;else printf "0.0"}'; }

sample_telemetry() {
  local stage="$1" sample
  sample="$($SCRIPT_DIR/performance-live.sh 2>/dev/null || printf '{}')"
  if jq -e '.ok == true' >/dev/null 2>&1 <<<"$sample"; then
    jq -c --arg stage "$stage" '. + {benchmark_stage:$stage}' <<<"$sample" >>"$TELEMETRY_FILE"
  else
    jq -nc --arg stage "$stage" --argjson at "$(date +%s)" \
      '{schema_version:1,ok:false,observed_at:$at,benchmark_stage:$stage,data:null,error:{code:"telemetry_unavailable",message:"Performance sample unavailable"}}' >>"$TELEMETRY_FILE"
  fi
}

monitor_workload() {
  local pid="$1" stage="$2" sample temperature status=0
  while kill -0 "$pid" 2>/dev/null; do
    sample_telemetry "$stage"
    sample="$(tail -n 1 "$TELEMETRY_FILE")"
    temperature="$(jq -r '.data.thermal.cpu.celsius // empty' <<<"$sample" 2>/dev/null || true)"
    if [[ "$temperature" =~ ^[0-9]+([.][0-9]+)?$ ]] &&
      awk -v value="$temperature" -v limit="$MAX_TEMP_C" 'BEGIN {exit !(value >= limit)}'; then
      note "Thermal safety stop: ${temperature} C reached the ${MAX_TEMP_C} C limit during $stage"
      kill -TERM -- "-$pid" 2>/dev/null || kill -TERM "$pid" 2>/dev/null || true
      sleep 1
      kill -KILL -- "-$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
      ACTIVE_WORKLOAD_PID=0
      return 75
    fi
    sleep 2
  done
  if wait "$pid"; then status=0; else status=$?; fi
  ACTIVE_WORKLOAD_PID=0
  return "$status"
}

launch_monitored() {
  local stage="$1"
  shift
  setsid "$@" &
  ACTIVE_WORKLOAD_PID=$!
  monitor_workload "$ACTIVE_WORKLOAD_PID" "$stage"
}

workload_cpu() {
  local workers="$1" seconds="$2" result_dir="$3" worker deadline count
  mkdir -p -m 700 "$result_dir"
  deadline=$((SECONDS + seconds))
  for ((worker = 0; worker < workers; worker++)); do
    (
      count=0
      while ((SECONDS < deadline)); do
        dd if=/dev/zero bs=8M count=1 status=none | sha256sum >/dev/null
        count=$((count + 1))
      done
      printf '%s\n' "$count" >"$result_dir/worker-$worker"
    ) &
  done
  wait
}

workload_compression() {
  local seconds="$1" result_file="$2" deadline count=0
  deadline=$((SECONDS + seconds))
  while ((SECONDS < deadline)); do
    dd if=/dev/zero bs=8M count=1 status=none | gzip -1 >/dev/null
    count=$((count + 1))
  done
  printf '%s\n' "$count" >"$result_file"
}

sum_worker_blocks() {
  local directory="$1" total=0 value file
  for file in "$directory"/worker-*; do
    [[ -r "$file" ]] || continue
    value="$(<"$file")"
    [[ "$value" =~ ^[0-9]+$ ]] && total=$((total + value))
  done
  printf '%s\n' "$total"
}

telemetry_summary() {
  if [[ ! -s "$TELEMETRY_FILE" ]]; then
    printf '{"sample_count":0,"temperature":{"available":false,"min_c":null,"average_c":null,"max_c":null},"frequency":{"available":false,"min_mhz":null,"average_mhz":null,"max_mhz":null},"pressure":{"cpu_max":null,"memory_max":null,"io_max":null}}\n'
    return
  fi
  jq -sc '
    [.[]|select(.ok==true)] as $s
    | [$s[]?.data.thermal.cpu.celsius|select(type=="number")] as $t
    | [$s[]?.data.cpu.frequency.current_mhz|select(type=="number")] as $f
    | {sample_count:($s|length),
       temperature:{available:($t|length>0),min_c:(if($t|length)>0 then($t|min)else null end),average_c:(if($t|length)>0 then(($t|add)/($t|length)*10|round/10)else null end),max_c:(if($t|length)>0 then($t|max)else null end)},
       frequency:{available:($f|length>0),min_mhz:(if($f|length)>0 then($f|min)else null end),average_mhz:(if($f|length)>0 then(($f|add)/($f|length)|round)else null end),max_mhz:(if($f|length)>0 then($f|max)else null end)},
       pressure:{cpu_max:([$s[]?.data.pressure.cpu.some_avg10|select(type=="number")]|if length>0 then max else null end),memory_max:([$s[]?.data.pressure.memory.some_avg10|select(type=="number")]|if length>0 then max else null end),io_max:([$s[]?.data.pressure.io.some_avg10|select(type=="number")]|if length>0 then max else null end)}}
  ' "$TELEMETRY_FILE"
}

markdown_command() {
  local title="$1"
  shift
  printf '\n### %s\n\n```text\n' "$title"
  "$@" 2>&1 || printf 'Unavailable or command returned non-zero.\n'
  printf '```\n'
}

hardware_report() {
  local field value
  printf '\n## Machine specification\n\n| Field | Value |\n|---|---|\n'
  for field in sys_vendor product_name product_version board_vendor board_name bios_vendor bios_version bios_date; do
    value="$(tr -d '\n' <"/sys/class/dmi/id/$field" 2>/dev/null || printf unavailable)"
    printf '| %s | %s |\n' "$field" "${value//|/ }"
  done
  markdown_command "CPU topology and capabilities" lscpu
  printf '\n### CPU vulnerability status\n\n```text\n'
  for field in /sys/devices/system/cpu/vulnerabilities/*; do [[ -r "$field" ]] && printf '%s: %s\n' "$(basename "$field")" "$(<"$field")"; done
  printf '```\n'
  markdown_command "Memory" free -h
  markdown_command "Graphics and PCI devices" lspci -nnk
  markdown_command "USB devices" lsusb
  markdown_command "Block devices" lsblk -e 7 -o NAME,TYPE,SIZE,FSTYPE,FSUSE%,MOUNTPOINTS,MODEL,ROTA,TRAN
  markdown_command "Filesystem capacity" df -hT -x tmpfs -x devtmpfs -x squashfs -x efivarfs
  markdown_command "Thermal sensors" sensors
  command -v hyprctl >/dev/null 2>&1 && markdown_command "Display topology" hyprctl monitors
  printf '\n### Software platform\n\n```text\n'
  uname -a || true; sed -n '1,24p' /etc/os-release || true
  printf 'Hyprland: '; hyprctl version 2>/dev/null | head -n 1 || printf 'unavailable\n'
  printf 'Eww: '; /usr/bin/eww --version 2>/dev/null || printf 'unavailable\n'
  printf 'Installed native packages: '; pacman -Qnq 2>/dev/null | wc -l || true
  printf 'Installed foreign/AUR packages: '; pacman -Qmq 2>/dev/null | wc -l || true
  printf '```\n\n### Optional evidence availability\n\n'
  for field in stress-ng fio smartctl nvme dmidecode vainfo vulkaninfo; do
    if command -v "$field" >/dev/null 2>&1; then value=available; else value='not installed'; fi
    printf -- '- `%s`: %s\n' "$field" "$value"
  done
  printf '\nSerial numbers, MAC addresses, IP addresses, credentials and unrestricted logs are deliberately excluded.\n'
}

cleanup_workload() {
  if [[ "$ACTIVE_WORKLOAD_PID" =~ ^[1-9][0-9]*$ ]] && ((ACTIVE_WORKLOAD_PID > 0)); then
    kill -TERM -- "-$ACTIVE_WORKLOAD_PID" 2>/dev/null || kill -TERM "$ACTIVE_WORKLOAD_PID" 2>/dev/null || true
  fi
  [[ -n "$SCRATCH_FILE" ]] && rm -f -- "$SCRATCH_FILE"
  [[ -n "$WORK_ROOT" && "$WORK_ROOT" == "$ROOT"/.work-* ]] && rm -rf -- "$WORK_ROOT"
  rm -f "$PID_FILE"
}

on_signal() {
  trap - ERR INT TERM HUP
  note "Benchmark cancelled; active bounded workload is being stopped."
  write_status cancelled 0 interrupted "Benchmark cancelled safely. Partial measurements were not published."
  cleanup_workload
  exit 130
}

on_error() {
  local code="$1" line="$2"
  trap - ERR INT TERM HUP
  note "Benchmark failed at line $line with exit code $code."
  write_status failed 0 failed "Benchmark failed safely. Review the retained execution log."
  cleanup_workload
  exit "$code"
}

handle_monitored_failure() {
  local status="$1" progress="$2" stage="$3"
  if ((status == 75)); then
    write_status thermal-abort "$progress" "$stage" "Thermal safety limit reached; the workload was stopped."
    cleanup_workload
    trap - ERR INT TERM HUP
    exit 75
  fi
  on_error "$status" "$LINENO"
}

run_suite() {
  local requested_profile="${1:-standard}" workers cpu_single_seconds cpu_multi_seconds memory_seconds compression_seconds
  local storage_mib memory_mib available_mib stamp markdown pdf checksum status i
  local load_before load_after battery_before battery_after single_dir multi_dir memory_result compression_result
  local start_ns end_ns elapsed single_blocks multi_blocks compression_blocks
  local cpu_single_rate cpu_multi_rate memory_rate compression_rate write_seconds read_seconds write_rate read_rate storage_mode process_count launch_ms
  local summary results generated_at

  valid_profile "$requested_profile" || { printf 'Unknown benchmark profile: %s\n' "$requested_profile" >&2; exit 2; }
  [[ "$MAX_TEMP_C" =~ ^[0-9]+([.][0-9]+)?$ ]] || { printf 'Invalid thermal limit\n' >&2; exit 2; }
  awk -v value="$MAX_TEMP_C" 'BEGIN {exit !(value>=70&&value<=110)}' || { printf 'Thermal limit must be 70-110 C\n' >&2; exit 2; }
  PROFILE="$requested_profile"; STARTED_AT="$(date +%s)"
  trap 'on_error $? $LINENO' ERR; trap on_signal INT TERM HUP
  : >"$LOG_FILE"; : >"$TELEMETRY_FILE"; chmod 600 "$LOG_FILE" "$TELEMETRY_FILE"
  printf '%s\n' "$$" >"$PID_FILE"; chmod 600 "$PID_FILE"
  WORK_ROOT="$(mktemp -d "$ROOT/.work-XXXXXX")"
  stamp="$(date +%Y%m%d-%H%M%S)"; markdown="$ROOT/benchmark-$stamp.md"; pdf="$ROOT/benchmark-$stamp.pdf"; checksum="$ROOT/benchmark-$stamp.sha256"; SCRATCH_FILE="$ROOT/.storage-$stamp.bin"
  workers="$(nproc)"
  if ((workers > 8)); then workers=8; fi
  if [[ "$PROFILE" == quick ]]; then cpu_single_seconds=8; cpu_multi_seconds=20; memory_seconds=10; compression_seconds=10; storage_mib=256; process_count=200
  else cpu_single_seconds=15; cpu_multi_seconds=60; memory_seconds=30; compression_seconds=30; storage_mib=512; process_count=500; fi
  available_mib="$(awk '/MemAvailable:/ {print int($2/1024)}' /proc/meminfo)"
  if ((available_mib < 256)); then
    write_status failed 0 memory-check "Less than 256 MiB is available. Close applications before running the benchmark."
    note "Run refused: insufficient available memory."
    cleanup_workload
    trap - ERR INT TERM HUP
    return 4
  fi
  memory_mib=$((available_mib / 4))
  if ((memory_mib > 1024)); then memory_mib=1024; fi
  if [[ "$PROFILE" == quick ]] && ((memory_mib > 512)); then memory_mib=512; fi
  if ((memory_mib < 64)); then memory_mib=64; fi
  battery_before="$($SCRIPT_DIR/battery.sh 2>/dev/null || printf '{}')"
  if jq -e '.available==true and .state=="discharging" and .percent_total<25' >/dev/null 2>&1 <<<"$battery_before"; then
    write_status failed 0 power-check "Battery is below 25% while discharging. Connect power before running a sustained benchmark."
    note "Run refused: low battery while discharging."; cleanup_workload; trap - ERR INT TERM HUP; return 3
  fi

  load_before="$(cut -d' ' -f1-3 /proc/loadavg)"; write_status running 5 baseline "Capturing baseline telemetry before load."
  note "Profile $PROFILE; estimated $(profile_estimate "$PROFILE") seconds; thermal abort ${MAX_TEMP_C} C"
  note "Baseline load: $load_before; workers: $workers; memory allocation: $memory_mib MiB"; sample_telemetry baseline; sleep 3

  single_dir="$WORK_ROOT/cpu-single"; write_status running 15 cpu-single "Running sustained single-worker SHA-256 confidence load."; note "Single-worker SHA-256 load for ${cpu_single_seconds}s"
  start_ns="$(date +%s%N)"
  if launch_monitored cpu-single "$0" workload-cpu 1 "$cpu_single_seconds" "$single_dir"; then :; else status=$?; handle_monitored_failure "$status" 15 cpu-single; fi
  end_ns="$(date +%s%N)"; elapsed="$(awk -v ns="$((end_ns-start_ns))" 'BEGIN{printf "%.3f",ns/1000000000}')"; single_blocks="$(sum_worker_blocks "$single_dir")"; cpu_single_rate="$(rate_mib "$((single_blocks*8))" "$elapsed")"; note "Single-worker SHA-256: $cpu_single_rate MiB/s"

  multi_dir="$WORK_ROOT/cpu-multi"; write_status running 32 cpu-multi "Running sustained all-thread SHA-256 load under thermal watch."; note "Multi-worker SHA-256: $workers workers for ${cpu_multi_seconds}s"
  start_ns="$(date +%s%N)"
  if launch_monitored cpu-multi "$0" workload-cpu "$workers" "$cpu_multi_seconds" "$multi_dir"; then :; else status=$?; handle_monitored_failure "$status" 32 cpu-multi; fi
  end_ns="$(date +%s%N)"; elapsed="$(awk -v ns="$((end_ns-start_ns))" 'BEGIN{printf "%.3f",ns/1000000000}')"; multi_blocks="$(sum_worker_blocks "$multi_dir")"; cpu_multi_rate="$(rate_mib "$((multi_blocks*8))" "$elapsed")"; note "Multi-worker SHA-256: $cpu_multi_rate MiB/s"

  memory_result="$WORK_ROOT/memory.json"; write_status running 52 memory "Writing a bounded native memory buffer repeatedly."; note "Memory-write load: $memory_mib MiB for ${memory_seconds}s"
  if launch_monitored memory "$SCRIPT_DIR/benchmark-memory.py" --mib "$memory_mib" --seconds "$memory_seconds" --result "$memory_result"; then :; else status=$?; handle_monitored_failure "$status" 52 memory; fi
  memory_rate="$(jq -r '.write_mib_per_second' "$memory_result")"; note "Native memory write: $memory_rate MiB/s"

  compression_result="$WORK_ROOT/compression-count"; write_status running 67 compression "Running sustained gzip level-1 compression load."; note "Compression load for ${compression_seconds}s"
  start_ns="$(date +%s%N)"
  if launch_monitored compression "$0" workload-compression "$compression_seconds" "$compression_result"; then :; else status=$?; handle_monitored_failure "$status" 67 compression; fi
  end_ns="$(date +%s%N)"
  elapsed="$(awk -v ns="$((end_ns-start_ns))" 'BEGIN{printf "%.3f",ns/1000000000}')"; compression_blocks="$(<"$compression_result")"; compression_rate="$(rate_mib "$((compression_blocks*8))" "$elapsed")"; note "gzip level 1: $compression_rate MiB/s"

  write_status running 79 storage "Measuring bounded direct storage write and read where supported."; note "Storage workload: $storage_mib MiB private scratch file"; storage_mode=direct; start_ns="$(date +%s%N)"
  if ! dd if=/dev/zero of="$SCRATCH_FILE" bs=8M count="$((storage_mib/8))" oflag=direct conv=fdatasync status=none; then storage_mode=buffered; dd if=/dev/zero of="$SCRATCH_FILE" bs=8M count="$((storage_mib/8))" conv=fdatasync status=none; fi
  end_ns="$(date +%s%N)"; write_seconds="$(awk -v ns="$((end_ns-start_ns))" 'BEGIN{printf "%.3f",ns/1000000000}')"; write_rate="$(rate_mib "$storage_mib" "$write_seconds")"; start_ns="$(date +%s%N)"
  if [[ "$storage_mode" == direct ]] && dd if="$SCRATCH_FILE" of=/dev/null bs=8M iflag=direct status=none; then :; else storage_mode="${storage_mode}+cached-read"; dd if="$SCRATCH_FILE" of=/dev/null bs=8M status=none; fi
  end_ns="$(date +%s%N)"; read_seconds="$(awk -v ns="$((end_ns-start_ns))" 'BEGIN{printf "%.3f",ns/1000000000}')"; read_rate="$(rate_mib "$storage_mib" "$read_seconds")"; rm -f "$SCRATCH_FILE"; SCRATCH_FILE=""; note "Storage $storage_mode: write $write_rate MiB/s; read $read_rate MiB/s"

  write_status running 88 responsiveness "Measuring repeated process-launch latency."; start_ns="$(date +%s%N)"; for ((i=0;i<process_count;i++)); do /usr/bin/true; done; end_ns="$(date +%s%N)"
  launch_ms="$(awk -v ns="$((end_ns-start_ns))" -v count="$process_count" 'BEGIN{printf "%.3f",(ns/1000000)/count}')"; note "Average process launch: $launch_ms ms over $process_count launches"

  write_status running 93 cooldown "Capturing post-load thermals, frequency and pressure."; sample_telemetry cooldown; sleep 5; sample_telemetry cooldown
  load_after="$(cut -d' ' -f1-3 /proc/loadavg)"; battery_after="$($SCRIPT_DIR/battery.sh 2>/dev/null || printf '{}')"; summary="$(telemetry_summary)"; generated_at="$(date --iso-8601=seconds)"
  results="$(jq -nc --arg profile "$PROFILE" --argjson workers "$workers" --argjson single "$cpu_single_rate" --argjson multi "$cpu_multi_rate" --argjson memory "$memory_rate" --argjson compression "$compression_rate" --argjson write "$write_rate" --argjson read "$read_rate" --arg storage_mode "$storage_mode" --argjson launch "$launch_ms" --argjson telemetry "$summary" '{profile:$profile,workers:$workers,cpu:{single_sha256_mib_s:$single,multi_sha256_mib_s:$multi},memory:{native_write_mib_s:$memory},compression:{gzip_level1_mib_s:$compression},storage:{write_mib_s:$write,read_mib_s:$read,mode:$storage_mode},responsiveness:{process_launch_ms:$launch},telemetry:$telemetry}')"
  write_status running 97 report "Building rich Markdown and PDF evidence reports." "" "" "$results"
  {
    printf '# SenomyOS Benchmark Report\n\n- Generated: %s\n- Profile: %s\n- Duration target: approximately %s seconds\n- Worker count: %s\n- Thermal abort limit: %s C\n' "$generated_at" "$PROFILE" "$(profile_estimate "$PROFILE")" "$workers" "$MAX_TEMP_C"
    printf '%s\n' '- Scope: bounded local confidence/stress suite; comparative evidence, not laboratory certification'
    printf '\n## Executive results\n\n| Test | Result | Method |\n|---|---:|---|\n'
    printf '| Single-worker SHA-256 | %s MiB/s | repeated 8 MiB blocks |\n| Multi-worker SHA-256 | %s MiB/s | %s workers under thermal watch |\n| Native memory write | %s MiB/s | %s MiB bounded buffer |\n| gzip level 1 | %s MiB/s | deterministic zero-data stream |\n| Storage write | %s MiB/s | %s MiB, %s |\n| Storage read | %s MiB/s | %s MiB, %s |\n| Process launch | %s ms average | %s launches |\n' "$cpu_single_rate" "$cpu_multi_rate" "$workers" "$memory_rate" "$memory_mib" "$compression_rate" "$write_rate" "$storage_mib" "$storage_mode" "$read_rate" "$storage_mib" "$storage_mode" "$launch_ms" "$process_count"
    printf '\n## Reliability and telemetry\n\n```json\n%s\n```\n\n- Load before: %s\n- Load after: %s\n' "$(jq . <<<"$summary")" "$load_before" "$load_after"
    printf -- '- Battery before: %s%%, %s\n- Battery after: %s%%, %s\n' "$(jq -r '.percent_total // "N/A"' <<<"$battery_before")" "$(jq -r '.state // "unavailable"' <<<"$battery_before")" "$(jq -r '.percent_total // "N/A"' <<<"$battery_after")" "$(jq -r '.state // "unavailable"' <<<"$battery_after")"
    hardware_report
    printf '\n## Methodology and limits\n\n%s\n%s\n%s\n%s\n%s\n%s\n' '- No network traffic, root access, package installation, indefinite stress or unrestricted logs are used.' '- CPU and compression inputs are deterministic synthetic streams; scores compare this machine across cooling, power and software changes.' '- The memory result measures repeated native writes to one bounded allocated buffer, not full application performance.' '- Direct storage I/O is attempted first. The report labels any buffered or potentially cached fallback.' '- Missing sensors or optional inventory tools remain explicit. No unavailable value is fabricated.' '- A passing run cannot prove that hardware is healthy; it provides bounded evidence for comparison and troubleshooting.'
  } >"$markdown"
  chmod 600 "$markdown"; "$SCRIPT_DIR/markdown-to-pdf.py" "$markdown" "$pdf"; chmod 600 "$pdf"; (cd "$ROOT" && sha256sum "$(basename "$markdown")" "$(basename "$pdf")") >"$checksum"; chmod 600 "$checksum"
  note "Report complete: $(basename "$markdown"), $(basename "$pdf"), and checksums"; write_status succeeded 100 complete "Benchmark complete. Rich private Markdown/PDF evidence is retained." "$markdown" "$pdf" "$results"; cleanup_workload; trap - ERR INT TERM HUP
}

start_suite() {
  local requested_profile="${1:-standard}" battery pid
  valid_profile "$requested_profile" || { printf 'Unknown benchmark profile: %s\n' "$requested_profile" >&2; exit 2; }
  if [[ -r "$PID_FILE" ]]; then pid="$(<"$PID_FILE")"; [[ "$pid" =~ ^[1-9][0-9]*$ ]] && kill -0 "$pid" 2>/dev/null && { printf 'Benchmark is already running.\n' >&2; exit 1; }; rm -f "$PID_FILE"; fi
  battery="$($SCRIPT_DIR/battery.sh 2>/dev/null || printf '{}')"
  if jq -e '.available==true and .state=="discharging" and .percent_total<25' >/dev/null 2>&1 <<<"$battery"; then PROFILE="$requested_profile"; STARTED_AT="$(date +%s)"; write_status failed 0 power-check "Battery is below 25% while discharging. Connect power first."; exit 3; fi
  nohup setsid "$0" run "$requested_profile" >"$ROOT/runner.out" 2>&1 </dev/null &
}

cancel_suite() {
  local pid command_line group
  [[ -r "$PID_FILE" ]] || exit 0; pid="$(<"$PID_FILE")"; [[ "$pid" =~ ^[1-9][0-9]*$ ]] || exit 1
  command_line="$(tr '\0' ' ' <"/proc/$pid/cmdline" 2>/dev/null || true)"; [[ "$command_line" == *"benchmark-action.sh run"* ]] || { printf 'Refusing to signal an unverified PID.\n' >&2; exit 1; }
  group="$(ps -o pgid= -p "$pid" | tr -d ' ')"; if [[ "$group" == "$pid" ]]; then kill -TERM -- "-$pid"; else kill -TERM "$pid"; fi
}

open_latest() {
  local path
  path="$(jq -r '.data.markdown_path // empty' "$STATUS_FILE" 2>/dev/null || true)"; [[ "$path" == "$ROOT"/benchmark-*.md && -r "$path" ]] || exit 4
  if command -v code >/dev/null 2>&1; then
    nohup code --reuse-window "$path" >/dev/null 2>&1 &
  elif command -v xdg-open >/dev/null 2>&1; then
    nohup xdg-open "$path" >/dev/null 2>&1 &
  else
    exit 3
  fi
}

case "$ACTION" in
  status) exec "$SCRIPT_DIR/benchmark-status.sh" ;;
  plan) profile_plan "${2:-standard}" ;;
  start) start_suite "${2:-standard}" ;;
  run) run_suite "${2:-standard}" ;;
  cancel) cancel_suite ;;
  open-latest) open_latest ;;
  workload-cpu) workload_cpu "$2" "$3" "$4" ;;
  workload-compression) workload_compression "$2" "$3" ;;
  *) printf 'Usage: %s [status|plan quick|plan standard|start quick|start standard|cancel|open-latest]\n' "$0" >&2; exit 2 ;;
esac
