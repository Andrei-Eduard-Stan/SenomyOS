#!/usr/bin/env bash

# Wrap the global system summary and retain a bounded runtime-only metric history.

set -uo pipefail

umask 077

export LC_ALL=C

readonly ACTION="${1:-read}"
readonly JQ_BIN="${SENOMY_JQ_BIN:-/usr/bin/jq}"
readonly PERFORMANCE_LIVE_BIN="${SENOMY_PERFORMANCE_LIVE_BIN:-${SENOMY_SYSTEM_STATUS_BIN:-${XDG_CONFIG_HOME:-"$HOME/.config"}/eww/scripts/performance-live.sh}}"
readonly RUNTIME_ROOT="${SENOMY_HISTORY_RUNTIME_DIR:-${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/senomyos}"
readonly HISTORY_FILE="${SENOMY_HISTORY_FILE:-$RUNTIME_ROOT/performance-history.json}"
readonly LOCK_FILE="${SENOMY_HISTORY_LOCK_FILE:-$RUNTIME_ROOT/performance-history.lock}"
readonly WINDOW_SECONDS="${SENOMY_HISTORY_WINDOW_SECONDS:-300}"
readonly SAMPLE_INTERVAL_SECONDS="${SENOMY_HISTORY_SAMPLE_SECONDS:-10}"

fail() {
  printf 'SenomyOS performance history: %s\n' "$1" >&2
  exit 1
}

validate_configuration() {
  [[ "$WINDOW_SECONDS" =~ ^[1-9][0-9]*$ ]] ||
    fail "history window must be a positive integer"
  [[ "$SAMPLE_INTERVAL_SECONDS" =~ ^[1-9][0-9]*$ ]] ||
    fail "sample interval must be a positive integer"
  ((SAMPLE_INTERVAL_SECONDS <= WINDOW_SECONDS)) ||
    fail "sample interval cannot exceed the history window"
}

empty_history() {
  "$JQ_BIN" -nc \
    --argjson window_seconds "$WINDOW_SECONDS" \
    --argjson sample_seconds "$SAMPLE_INTERVAL_SECONDS" \
    '{
      schema_version: 1,
      ok: true,
      source: "runtime-cache",
      observed_at: 0,
      window_seconds: $window_seconds,
      sample_interval_seconds: $sample_seconds,
      data: {
        samples: [],
        scales: {
          disk_bytes_per_second: 1048576,
          network_bytes_per_second: 131072
        }
      },
      error: null
    }'
}

read_history() {
  local history

  if [[ -r "$HISTORY_FILE" ]]; then
    history="$(< "$HISTORY_FILE")"
    if "$JQ_BIN" -e '
      .schema_version == 1
      and .ok == true
      and (.data.samples | type) == "array"
    ' >/dev/null 2>&1 <<< "$history"; then
      "$JQ_BIN" \
        --argjson window_seconds "$WINDOW_SECONDS" \
        --argjson sample_seconds "$SAMPLE_INTERVAL_SECONDS" \
        '.window_seconds = $window_seconds | .sample_interval_seconds = $sample_seconds' \
        <<<"$history"
      return
    fi
  fi

  empty_history
}

present_history() {
  read_history |
    "$JQ_BIN" '
      def clamp($low; $high):
        if . < $low then $low elif . > $high then $high else . end;

      (.data.samples // []) as $samples |
      ([
        1048576,
        ($samples[]?.disk_read_bytes_per_second // 0),
        ($samples[]?.disk_write_bytes_per_second // 0)
      ] | max) as $disk_scale |
      ([
        131072,
        ($samples[]?.network_receive_bytes_per_second // 0),
        ($samples[]?.network_transmit_bytes_per_second // 0)
      ] | max) as $network_scale |
      .data.scales = {
        disk_bytes_per_second: $disk_scale,
        network_bytes_per_second: $network_scale
      } |
      .data.samples |= map(
        . + {
          disk_read_chart_percent: (
            ((.disk_read_bytes_per_second // 0) * 100 / $disk_scale)
            | clamp(0; 100)
          ),
          disk_write_chart_percent: (
            ((.disk_write_bytes_per_second // 0) * 100 / $disk_scale)
            | clamp(0; 100)
          ),
          network_receive_chart_percent: (
            ((.network_receive_bytes_per_second // 0) * 100 / $network_scale)
            | clamp(0; 100)
          ),
          network_transmit_chart_percent: (
            ((.network_transmit_bytes_per_second // 0) * 100 / $network_scale)
            | clamp(0; 100)
          ),
          temperature_chart_percent: (
            (.temperature_celsius // 0) | clamp(0; 100)
          ),
          load_chart_percent: (
            (.normalized_load_percent // 0) | clamp(0; 100)
          )
        }
      )
    '
}

sample_status() {
  local status
  local history
  local sample
  local updated
  local temporary
  local observed_at
  local last_observed_at
  local max_samples

  [[ -x "$PERFORMANCE_LIVE_BIN" ]] ||
    fail "live performance collector is unavailable"

  status="$("$PERFORMANCE_LIVE_BIN")" ||
    fail "live performance collector failed"

  if ! "$JQ_BIN" -e '
    .schema_version == 1
    and .ok == true
    and (.observed_at | type) == "number"
    and (.data.cpu.percent | type) == "number"
    and (.data.memory.percent | type) == "number"
  ' >/dev/null 2>&1 <<< "$status"; then
    printf '%s\n' "$status"
    return
  fi

  mkdir -p "$RUNTIME_ROOT" 2>/dev/null || {
    printf '%s\n' "$status"
    return
  }
  chmod 700 "$RUNTIME_ROOT" 2>/dev/null || true

  command -v flock >/dev/null 2>&1 || {
    printf '%s\n' "$status"
    return
  }

  if ! { exec 9>"$LOCK_FILE"; } 2>/dev/null; then
    printf '%s\n' "$status"
    return
  fi
  chmod 600 "$LOCK_FILE" 2>/dev/null || true

  if ! flock -w 1 9; then
    printf '%s\n' "$status"
    return
  fi

  history="$(read_history)"
  observed_at="$("$JQ_BIN" -r '.observed_at' <<< "$status")"
  last_observed_at="$("$JQ_BIN" -r '.data.samples[-1].observed_at // 0' <<< "$history")"

  if ((observed_at - last_observed_at < SAMPLE_INTERVAL_SECONDS)); then
    printf '%s\n' "$status"
    return
  fi

  sample="$(
    "$JQ_BIN" -c '
      {
        observed_at: .observed_at,
        cpu_percent: .data.cpu.percent,
        memory_percent: .data.memory.percent,
        temperature_celsius: (.data.thermal.cpu.celsius // null),
        normalized_load_percent: (.data.load.normalized_one_percent // 0),
        cpu_pressure_percent: (.data.pressure.cpu.some_avg10 // 0),
        memory_pressure_percent: (.data.pressure.memory.full_avg10 // 0),
        io_pressure_percent: (.data.pressure.io.full_avg10 // 0),
        disk_read_bytes_per_second: (.data.disk.read_bytes_per_second // 0),
        disk_write_bytes_per_second: (.data.disk.write_bytes_per_second // 0),
        disk_busy_percent: (.data.disk.busy_percent // 0),
        network_receive_bytes_per_second: (
          .data.network.receive_bytes_per_second // 0
        ),
        network_transmit_bytes_per_second: (
          .data.network.transmit_bytes_per_second // 0
        ),
        graphics_busy_percent: (.data.graphics.busy_percent // null)
      }
    ' <<< "$status"
  )"

  max_samples=$((WINDOW_SECONDS / SAMPLE_INTERVAL_SECONDS + 1))
  updated="$(
    "$JQ_BIN" -nc \
      --argjson history "$history" \
      --argjson sample "$sample" \
      --argjson observed_at "$observed_at" \
      --argjson window_seconds "$WINDOW_SECONDS" \
      --argjson max_samples "$max_samples" '
        $history
        | .observed_at = $observed_at
        | .data.samples = (
            ((.data.samples // []) + [$sample])
            | map(select(.observed_at >= ($observed_at - $window_seconds)))
            | if length > $max_samples then
                .[(length - $max_samples):]
              else
                .
              end
          )
      '
  )" || {
    printf '%s\n' "$status"
    return
  }

  temporary="$(mktemp "$RUNTIME_ROOT/.performance-history.XXXXXX")" || {
    printf '%s\n' "$status"
    return
  }

  if printf '%s\n' "$updated" > "$temporary" &&
      chmod 600 "$temporary" &&
      mv -f "$temporary" "$HISTORY_FILE"; then
    :
  else
    rm -f "$temporary"
  fi

  printf '%s\n' "$status"
}

validate_configuration

[[ -x "$JQ_BIN" ]] ||
  fail "jq is unavailable"

case "$ACTION" in
  read)
    [[ $# -le 1 ]] ||
      fail "read accepts no value"
    present_history
    ;;
  sample)
    [[ $# -eq 1 ]] ||
      fail "sample accepts no value"
    sample_status
    ;;
  *)
    fail "unknown action: $ACTION"
    ;;
esac
