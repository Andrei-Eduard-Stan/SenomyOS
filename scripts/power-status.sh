#!/usr/bin/env bash

# Emit detailed, capability-detected battery and power-policy status.

set -uo pipefail

export LC_ALL=C

readonly SYS_POWER_ROOT="${SENOMY_SYS_POWER_ROOT:-/sys/class/power_supply}"
readonly CPU_ROOT="${SENOMY_CPU_ROOT:-/sys/devices/system/cpu}"
readonly TLP_RUN_CONF="${SENOMY_TLP_RUN_CONF:-/run/tlp/run.conf}"
readonly TLP_LAST_PWR="${SENOMY_TLP_LAST_PWR:-/run/tlp/last_pwr}"
readonly JQ_BIN="${SENOMY_JQ_BIN:-/usr/bin/jq}"
readonly UPOWER_BIN="${SENOMY_UPOWER_BIN:-/usr/bin/upower}"
readonly SYSTEMCTL_BIN="${SENOMY_SYSTEMCTL_BIN:-/usr/bin/systemctl}"
readonly TLP_BIN="${SENOMY_TLP_BIN:-/usr/bin/tlp}"
readonly PKEXEC_BIN="${SENOMY_PKEXEC_BIN:-/usr/bin/pkexec}"

printf -v observed_at '%(%s)T' -1

emit_error() {
  local code="$1"
  local message="$2"

  "$JQ_BIN" -cn \
    --argjson observed_at "$observed_at" \
    --arg code "$code" \
    --arg message "$message" '
      {
        schema_version: 1,
        ok: false,
        source: "upower+sysfs+tlp",
        observed_at: $observed_at,
        data: null,
        error: {code: $code, message: $message}
      }
    '
  exit 0
}

[[ -x "$JQ_BIN" ]] ||
  printf '{"schema_version":1,"ok":false,"source":"upower+sysfs+tlp","observed_at":%s,"data":null,"error":{"code":"dependency_missing","message":"jq is unavailable"}}\n' "$observed_at"
[[ -x "$JQ_BIN" ]] || exit 0
[[ -x "$UPOWER_BIN" ]] ||
  emit_error "dependency_missing" "UPower is unavailable"
[[ -d "$SYS_POWER_ROOT" ]] ||
  emit_error "source_unavailable" "The kernel power-supply interface is unavailable"

read_value() {
  local path="$1"
  [[ -r "$path" ]] && head -n 1 "$path" 2>/dev/null || true
}

trim() {
  awk '{$1=$1; print}'
}

micro_to_unit() {
  local value="${1:-}"
  [[ "$value" =~ ^-?[0-9]+$ ]] ||
    return 1
  awk -v value="$value" 'BEGIN {printf "%.3f", value / 1000000}'
}

ratio_percent() {
  local current="${1:-}"
  local design="${2:-}"
  [[ "$current" =~ ^[0-9]+$ && "$design" =~ ^[1-9][0-9]*$ ]] ||
    return 1
  awk -v current="$current" -v design="$design" \
    'BEGIN {printf "%.1f", (current / design) * 100}'
}

upower_field() {
  local content="$1"
  local key="$2"
  awk -F: -v key="$key" '
    $1 ~ "^[[:space:]]*" key "[[:space:]]*$" {
      sub(/^[[:space:]]+/, "", $2)
      sub(/[[:space:]]+$/, "", $2)
      print $2
      exit
    }
  ' <<<"$content"
}

number_or_null() {
  local value="${1:-}"
  if [[ "$value" =~ ^-?[0-9]+([.][0-9]+)?$ ]]; then
    printf '%s' "$value"
  else
    printf 'null'
  fi
}

bool_json() {
  [[ "${1:-}" == "1" || "${1:-}" == "yes" || "${1:-}" == "true" ]] &&
    printf 'true' ||
    printf 'false'
}

battery_object() {
  local dir="$1"
  local id="${dir##*/}"
  local upower_path
  local upower_info=""
  local present status percent capacity_level manufacturer model serial technology
  local cycles energy_now energy_full energy_design power_now voltage_now voltage_design temp
  local health wear current_a
  local threshold_supported="false"
  local threshold_start=""
  local threshold_end=""
  local upower_state warning time_empty time_full

  upower_path="$("$UPOWER_BIN" -e 2>/dev/null |
    awk -v id="$id" '$0 ~ "/battery_" id "$" {print; exit}')"
  [[ -z "$upower_path" ]] ||
    upower_info="$("$UPOWER_BIN" -i "$upower_path" 2>/dev/null || true)"

  present="$(read_value "$dir/present")"
  status="$(read_value "$dir/status")"
  percent="$(read_value "$dir/capacity")"
  capacity_level="$(read_value "$dir/capacity_level")"
  manufacturer="$(read_value "$dir/manufacturer" | trim)"
  model="$(read_value "$dir/model_name" | trim)"
  serial="$(read_value "$dir/serial_number" | trim)"
  technology="$(read_value "$dir/technology")"
  cycles="$(read_value "$dir/cycle_count")"
  energy_now="$(read_value "$dir/energy_now")"
  energy_full="$(read_value "$dir/energy_full")"
  energy_design="$(read_value "$dir/energy_full_design")"
  power_now="$(read_value "$dir/power_now")"
  voltage_now="$(read_value "$dir/voltage_now")"
  voltage_design="$(read_value "$dir/voltage_min_design")"
  temp="$(read_value "$dir/temp")"

  health="$(ratio_percent "$energy_full" "$energy_design" || true)"
  if [[ "$health" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    wear="$(awk -v health="$health" 'BEGIN {wear=100-health; if (wear<0) wear=0; printf "%.1f", wear}')"
  else
    wear=""
  fi
  if [[ "$power_now" =~ ^[0-9]+$ && "$voltage_now" =~ ^[1-9][0-9]*$ ]]; then
    current_a="$(awk -v p="$power_now" -v v="$voltage_now" 'BEGIN {printf "%.3f", p / v}')"
  else
    current_a=""
  fi

  upower_state="$(upower_field "$upower_info" "state")"
  warning="$(upower_field "$upower_info" "warning-level")"
  time_empty="$(upower_field "$upower_info" "time to empty")"
  time_full="$(upower_field "$upower_info" "time to full")"
  threshold_start="$(upower_field "$upower_info" "charge-start-threshold" | tr -d '%')"
  threshold_end="$(upower_field "$upower_info" "charge-end-threshold" | tr -d '%')"
  [[ "$(upower_field "$upower_info" "charge-threshold-supported")" == "yes" ]] &&
    threshold_supported="true"

  "$JQ_BIN" -cn \
    --arg id "$id" \
    --arg path "$dir" \
    --arg upower_path "$upower_path" \
    --arg manufacturer "$manufacturer" \
    --arg model "$model" \
    --arg serial "$serial" \
    --arg technology "$technology" \
    --arg status "${upower_state:-$status}" \
    --arg capacity_level "$capacity_level" \
    --arg warning "${warning:-none}" \
    --arg time_empty "$time_empty" \
    --arg time_full "$time_full" \
    --argjson present "$(bool_json "$present")" \
    --argjson percent "$(number_or_null "$percent")" \
    --argjson cycles "$(number_or_null "$cycles")" \
    --argjson energy_now_wh "$(number_or_null "$(micro_to_unit "$energy_now" || true)")" \
    --argjson energy_full_wh "$(number_or_null "$(micro_to_unit "$energy_full" || true)")" \
    --argjson energy_design_wh "$(number_or_null "$(micro_to_unit "$energy_design" || true)")" \
    --argjson health_percent "$(number_or_null "$health")" \
    --argjson wear_percent "$(number_or_null "$wear")" \
    --argjson power_w "$(number_or_null "$(micro_to_unit "$power_now" || true)")" \
    --argjson voltage_v "$(number_or_null "$(micro_to_unit "$voltage_now" || true)")" \
    --argjson design_voltage_v "$(number_or_null "$(micro_to_unit "$voltage_design" || true)")" \
    --argjson current_a "$(number_or_null "$current_a")" \
    --argjson temperature_c "$(number_or_null "$(
      [[ "$temp" =~ ^-?[0-9]+$ ]] && awk -v value="$temp" 'BEGIN {printf "%.1f", value / 10}' || true
    )")" \
    --argjson threshold_supported "$threshold_supported" \
    --argjson threshold_start "$(number_or_null "$threshold_start")" \
    --argjson threshold_end "$(number_or_null "$threshold_end")" '
      {
        id: $id,
        sysfs_path: $path,
        upower_path: (if ($upower_path | length) > 0 then $upower_path else null end),
        present: $present,
        manufacturer: (if ($manufacturer | length) > 0 then $manufacturer else null end),
        model: (if ($model | length) > 0 then $model else null end),
        serial: (if ($serial | length) > 0 then $serial else null end),
        technology: (if ($technology | length) > 0 then $technology else null end),
        status: ($status | ascii_downcase),
        capacity_level: (if ($capacity_level | length) > 0 then $capacity_level else null end),
        warning_level: $warning,
        percent: $percent,
        cycles: {available: ($cycles != null), count: $cycles},
        energy: {
          now_wh: $energy_now_wh,
          full_wh: $energy_full_wh,
          design_wh: $energy_design_wh
        },
        health: {
          available: ($health_percent != null),
          percent: $health_percent,
          wear_percent: $wear_percent,
          grade: (
            if $health_percent == null then "unknown"
            elif $health_percent >= 90 then "excellent"
            elif $health_percent >= 80 then "good"
            elif $health_percent >= 70 then "worn"
            else "replace-soon"
            end
          )
        },
        electrical: {
          power_w: $power_w,
          voltage_v: $voltage_v,
          design_voltage_v: $design_voltage_v,
          current_a: $current_a,
          temperature_c: $temperature_c
        },
        estimates: {
          time_to_empty: (if ($time_empty | length) > 0 then $time_empty else null end),
          time_to_full: (if ($time_full | length) > 0 then $time_full else null end)
        },
        thresholds: {
          supported: $threshold_supported,
          start_percent: $threshold_start,
          end_percent: $threshold_end
        }
      }
    '
}

mapfile -t battery_dirs < <(
  for dir in "$SYS_POWER_ROOT"/*; do
    [[ -d "$dir" && "$(read_value "$dir/type")" == "Battery" ]] && printf '%s\n' "$dir"
  done
)

((${#battery_dirs[@]} > 0)) ||
  emit_error "no_batteries" "No battery power supplies were detected"

batteries_json="$(
  for dir in "${battery_dirs[@]}"; do
    battery_object "$dir"
  done | "$JQ_BIN" -sc '.'
)"

ac_online="false"
adapter_name=""
for dir in "$SYS_POWER_ROOT"/*; do
  [[ -d "$dir" && "$(read_value "$dir/type")" == "Mains" ]] || continue
  adapter_name="${dir##*/}"
  [[ "$(read_value "$dir/online")" == "1" ]] && ac_online="true"
  break
done

display_info="$("$UPOWER_BIN" -i /org/freedesktop/UPower/devices/DisplayDevice 2>/dev/null || true)"
summary_time_empty="$(upower_field "$display_info" "time to empty")"
summary_time_full="$(upower_field "$display_info" "time to full")"
summary_state="$(upower_field "$display_info" "state")"

tlp_available="false"
tlp_service_active="false"
tlp_version=""
auto_switch=""
profile_ac=""
profile_bat=""
[[ -x "$TLP_BIN" ]] && {
  tlp_available="true"
  tlp_version="$("$TLP_BIN" --version 2>/dev/null | awk 'NR == 1 {print $NF}' || true)"
}
[[ -x "$SYSTEMCTL_BIN" ]] &&
  "$SYSTEMCTL_BIN" is-active --quiet tlp.service 2>/dev/null &&
  tlp_service_active="true"

tlp_config_value() {
  local key="$1"
  [[ -r "$TLP_RUN_CONF" ]] || return 0
  awk -F= -v key="$key" '
    $1 == key {
      value=$2
      gsub(/^"|"$/, "", value)
      print value
      exit
    }
  ' "$TLP_RUN_CONF"
}

auto_switch="$(tlp_config_value TLP_AUTO_SWITCH)"
profile_ac="$(tlp_config_value TLP_PROFILE_AC)"
profile_bat="$(tlp_config_value TLP_PROFILE_BAT)"
epp="$(read_value "$CPU_ROOT/cpu0/cpufreq/energy_performance_preference")"
governor="$(read_value "$CPU_ROOT/cpu0/cpufreq/scaling_governor")"
driver="$(read_value "$CPU_ROOT/cpu0/cpufreq/scaling_driver")"
no_turbo="$(read_value "$CPU_ROOT/intel_pstate/no_turbo")"

case "$epp" in
  performance | balance_performance)
    current_plan="performance"
    ;;
  power)
    current_plan="power-saver"
    ;;
  *)
    current_plan="balanced"
    ;;
esac

agent_installed="false"
agent_running="false"
for agent in \
  /usr/lib/hyprpolkitagent/hyprpolkitagent \
  /usr/lib/lxqt-policykit-agent \
  /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 \
  /usr/lib/mate-polkit/polkit-mate-authentication-agent-1 \
  /usr/lib/xfce-polkit/xfce-polkit; do
  [[ -x "$agent" ]] && agent_installed="true"
done
if command -v pgrep >/dev/null 2>&1 &&
  pgrep -f \
    'hyprpolkitagent|lxqt-policykit-agent|polkit-gnome-authentication-agent-1|polkit-mate-authentication-agent-1|xfce-polkit' \
    >/dev/null 2>&1; then
  agent_running="true"
fi
authorization_available="false"
[[ -x "$PKEXEC_BIN" && "$agent_running" == "true" ]] &&
  authorization_available="true"

"$JQ_BIN" -cn \
  --argjson observed_at "$observed_at" \
  --argjson batteries "$batteries_json" \
  --argjson ac_online "$ac_online" \
  --arg adapter_name "$adapter_name" \
  --arg summary_state "${summary_state:-unknown}" \
  --arg time_empty "$summary_time_empty" \
  --arg time_full "$summary_time_full" \
  --argjson tlp_available "$tlp_available" \
  --argjson tlp_service_active "$tlp_service_active" \
  --arg tlp_version "$tlp_version" \
  --arg auto_switch "$auto_switch" \
  --arg profile_ac "$profile_ac" \
  --arg profile_bat "$profile_bat" \
  --arg current_plan "$current_plan" \
  --arg driver "$driver" \
  --arg governor "$governor" \
  --arg epp "$epp" \
  --arg no_turbo "$no_turbo" \
  --argjson agent_installed "$agent_installed" \
  --argjson agent_running "$agent_running" \
  --argjson authorization_available "$authorization_available" '
    ($batteries | map(select(.present))) as $present
    | ($present | map(.energy.now_wh // 0) | add // 0) as $now
    | ($present | map(.energy.full_wh // 0) | add // 0) as $full
    | ($present | map(.energy.design_wh // 0) | add // 0) as $design
    | {
        schema_version: 1,
        ok: true,
        source: "upower+sysfs+tlp",
        observed_at: $observed_at,
        data: {
          summary: {
            battery_count: ($batteries | length),
            present_count: ($present | length),
            dual: (($present | length) > 1),
            state: $summary_state,
            ac_online: $ac_online,
            percent: (if $full > 0 then (($now / $full) * 1000 | round) / 10 else null end),
            health_percent: (if $design > 0 then (($full / $design) * 1000 | round) / 10 else null end),
            energy_now_wh: (($now * 1000 | round) / 1000),
            energy_full_wh: (($full * 1000 | round) / 1000),
            energy_design_wh: (($design * 1000 | round) / 1000),
            power_w: ($present | map(.electrical.power_w // 0) | add // 0),
            time_to_empty: (if ($time_empty | length) > 0 then $time_empty else null end),
            time_to_full: (if ($time_full | length) > 0 then $time_full else null end)
          },
          adapter: {
            available: ($adapter_name | length > 0),
            id: (if ($adapter_name | length) > 0 then $adapter_name else null end),
            online: $ac_online
          },
          batteries: $batteries,
          policy: {
            backend: (if $tlp_available then "tlp" else "none" end),
            available: $tlp_available,
            service_active: $tlp_service_active,
            version: (if ($tlp_version | length) > 0 then $tlp_version else null end),
            current_plan: $current_plan,
            automatic_switching: ($auto_switch != "0" and $auto_switch != ""),
            configured_ac_profile: (
              if $profile_ac == "PRF" then "performance"
              elif $profile_ac == "BAL" then "balanced"
              elif $profile_ac == "SAV" then "power-saver"
              else null end
            ),
            configured_battery_profile: (
              if $profile_bat == "PRF" then "performance"
              elif $profile_bat == "BAL" then "balanced"
              elif $profile_bat == "SAV" then "power-saver"
              else null end
            ),
            authorization: {
              pkexec_available: true,
              agent_installed: $agent_installed,
              agent_running: $agent_running,
              agent_available: $agent_running,
              actions_available: ($tlp_available and $authorization_available)
            },
            effective: {
              cpu_driver: (if ($driver | length) > 0 then $driver else null end),
              governor: (if ($governor | length) > 0 then $governor else null end),
              energy_performance_preference: (if ($epp | length) > 0 then $epp else null end),
              turbo_available: ($no_turbo != "1")
            },
            plans: [
              {
                id: "power-saver",
                name: "Power Saver",
                code: "SAV",
                summary: "Prioritize runtime, lower energy preference and aggressive device savings.",
                available: $tlp_available
              },
              {
                id: "balanced",
                name: "Balanced",
                code: "BAL",
                summary: "Balance responsiveness, thermals and battery endurance for daily work.",
                available: $tlp_available
              },
              {
                id: "performance",
                name: "Performance",
                code: "PRF",
                summary: "Favor responsiveness and throughput with higher energy use and heat.",
                available: $tlp_available
              }
            ]
          }
        },
        error: null
      }
  '
