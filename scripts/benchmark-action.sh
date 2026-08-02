#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C
action="${1:-status}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
root="${XDG_STATE_HOME:-$HOME/.local/state}/senomyos/benchmarks"
status="$root/status.json"; log="$root/current.log"; pidfile="$root/runner.pid"
mkdir -p -m 700 "$root"

write_status() {
  local state="$1" progress="$2" stage="$3" message="$4" md="${5:-}" pdf="${6:-}" tmp
  tmp="$(mktemp "$root/.status.XXXXXX")"
  jq -nc --arg state "$state" --argjson progress "$progress" --arg stage "$stage" --arg message "$message" \
    --arg md "$md" --arg pdf "$pdf" --argjson at "$(date +%s)" --argjson started "${STARTED_AT:-0}" \
    '{schema_version:1,ok:true,source:"benchmark",observed_at:$at,data:{state:$state,state_label:($state|ascii_upcase),progress:$progress,stage:$stage,message:$message,started_at:$started,finished_at:(if ($state=="succeeded" or $state=="failed" or $state=="cancelled") then $at else 0 end),markdown_path:$md,pdf_path:$pdf},error:null}' >"$tmp"
  chmod 600 "$tmp"; mv "$tmp" "$status"
}
note() { printf '[%(%H:%M:%S)T] %s\n' -1 "$1" | tee -a "$log" >/dev/null; }
measure() {
  local start end
  start="$(date +%s%N)"; "$@"; end="$(date +%s%N)"
  awk -v ns="$((end-start))" 'BEGIN {printf "%.3f", ns/1000000000}'
}
metric_rate() { awk -v mib="$1" -v seconds="$2" 'BEGIN {printf "%.1f", mib/seconds}'; }

run_suite() {
  STARTED_AT="$(date +%s)"; export STARTED_AT
  trap 'write_status cancelled 0 interrupted "Benchmark interrupted; partial results were not published."; rm -f "$pidfile" "${scratch:-}"; exit 130' INT TERM HUP
  : >"$log"; chmod 600 "$log"; printf '%s\n' "$$" >"$pidfile"; chmod 600 "$pidfile"
  stamp="$(date +%Y%m%d-%H%M%S)"; md="$root/benchmark-$stamp.md"; pdf="$root/benchmark-$stamp.pdf"; scratch="$root/.io-$stamp.bin"
  load_before="$(cut -d' ' -f1-3 /proc/loadavg)"; temp_before="$(awk '{printf "%.1f",$1/1000}' /sys/class/thermal/thermal_zone0/temp 2>/dev/null || printf unavailable)"
  write_status running 8 baseline "Capturing idle baseline."; note "Baseline load $load_before; temperature ${temp_before} C"
  workers="$(nproc)"; ((workers > 8)) && workers=8
  cpu_mib=$((workers * 128))
  write_status running 18 cpu "Measuring parallel SHA-256 CPU throughput."; note "CPU hash workload: $cpu_mib MiB across $workers workers"
  cpu_s="$(measure bash -c 'workers="$1"; for ((i=0;i<workers;i++)); do (dd if=/dev/zero bs=8M count=16 status=none | sha256sum >/dev/null) & done; wait' _ "$workers")"; cpu_rate="$(metric_rate "$cpu_mib" "$cpu_s")"
  note "CPU SHA-256: $cpu_rate MiB/s in $cpu_s s"
  write_status running 34 memory "Measuring buffered memory throughput."; note "Memory buffer workload: 1024 MiB"
  mem_s="$(measure dd if=/dev/zero of=/dev/null bs=8M count=128 status=none)"; mem_rate="$(metric_rate 1024 "$mem_s")"
  note "Memory buffer: $mem_rate MiB/s in $mem_s s"
  write_status running 50 compression "Measuring gzip throughput."; note "Compression workload: 256 MiB"
  gzip_s="$(measure bash -c 'dd if=/dev/zero bs=8M count=32 status=none | gzip -1 >/dev/null')"; gzip_rate="$(metric_rate 256 "$gzip_s")"
  note "gzip level 1: $gzip_rate MiB/s in $gzip_s s"
  write_status running 65 storage-write "Measuring bounded temporary-file write."; note "Storage write workload: 128 MiB private temporary file"
  write_s="$(measure dd if=/dev/zero of="$scratch" bs=8M count=16 conv=fsync status=none)"; write_rate="$(metric_rate 128 "$write_s")"
  note "Storage write: $write_rate MiB/s in $write_s s"
  write_status running 78 storage-read "Measuring temporary-file read."; read_s="$(measure dd if="$scratch" of=/dev/null bs=8M status=none)"; read_rate="$(metric_rate 128 "$read_s")"
  note "Storage read (cache may contribute): $read_rate MiB/s in $read_s s"; rm -f "$scratch"
  write_status running 88 responsiveness "Measuring process-launch responsiveness."; start="$(date +%s%N)"; for _ in {1..100}; do /usr/bin/true; done; end="$(date +%s%N)"; launch_ms="$(awk -v ns="$((end-start))" 'BEGIN {printf "%.3f",ns/100000000}')"
  note "Average process launch: $launch_ms ms over 100 launches"
  load_after="$(cut -d' ' -f1-3 /proc/loadavg)"; temp_after="$(awk '{printf "%.1f",$1/1000}' /sys/class/thermal/thermal_zone0/temp 2>/dev/null || printf unavailable)"
  write_status running 95 report "Building Markdown and PDF reports."
  cat >"$md" <<EOF
# SenomyOS Benchmark Report

- Generated: $(date --iso-8601=seconds)
- Host: $(hostname)
- Kernel: $(uname -sr)
- Scope: bounded local suite; results are comparative, not laboratory-certified

## Results

| Test | Result | Duration |
|---|---:|---:|
| SHA-256 CPU | $cpu_rate MiB/s | $cpu_s s |
| Memory buffer | $mem_rate MiB/s | $mem_s s |
| gzip level 1 | $gzip_rate MiB/s | $gzip_s s |
| Temporary storage write | $write_rate MiB/s | $write_s s |
| Temporary storage read | $read_rate MiB/s | $read_s s |
| Process launch average | $launch_ms ms | 100 launches |

## Context

- Load before: $load_before
- Load after: $load_after
- Temperature before: $temp_before C
- Temperature after: $temp_after C

## Methodology

The suite uses only local, bounded workloads. Storage uses a private 128 MiB temporary file which is removed after the test. The read result may include filesystem cache. No network traffic, root access, package installation, or indefinite stress is used.
EOF
  chmod 600 "$md"; "$SCRIPT_DIR/markdown-to-pdf.py" "$md" "$pdf"
  note "Report complete: $(basename "$md") and $(basename "$pdf")"
  write_status succeeded 100 complete "Benchmark complete. Markdown and PDF are retained privately." "$md" "$pdf"; rm -f "$pidfile"
}

case "$action" in
  status) exec "$SCRIPT_DIR/benchmark-status.sh" ;;
  start)
    if [[ -r "$pidfile" ]] && kill -0 "$(cat "$pidfile")" 2>/dev/null; then exit 1; fi
    nohup "$0" run >"$root/runner.out" 2>&1 &
    ;;
  run) run_suite ;;
  cancel)
    [[ -r "$pidfile" ]] || exit 0; pid="$(cat "$pidfile")"; [[ "$pid" =~ ^[1-9][0-9]*$ ]] || exit 1
    kill -TERM "$pid" 2>/dev/null || true
    ;;
  *) exit 2 ;;
esac
