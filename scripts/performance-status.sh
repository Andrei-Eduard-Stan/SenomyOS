#!/usr/bin/env bash

# Emit slower-changing system inventory for the Performance Dashboard.

set -uo pipefail

export LC_ALL=C

readonly PROC_ROOT="${SENOMY_PROC_ROOT:-/proc}"
readonly SYS_ROOT="${SENOMY_SYS_ROOT:-/sys}"
readonly DF_BIN="${SENOMY_DF_BIN:-/usr/bin/df}"
readonly FINDMNT_BIN="${SENOMY_FINDMNT_BIN:-/usr/bin/findmnt}"
readonly IP_BIN="${SENOMY_IP_BIN:-/usr/bin/ip}"
readonly JQ_BIN="${SENOMY_JQ_BIN:-/usr/bin/jq}"
readonly LSBLK_BIN="${SENOMY_LSBLK_BIN:-/usr/bin/lsblk}"
readonly LSCPU_BIN="${SENOMY_LSCPU_BIN:-/usr/bin/lscpu}"
readonly LSPCI_BIN="${SENOMY_LSPCI_BIN:-/usr/bin/lspci}"
readonly NMCLI_BIN="${SENOMY_NMCLI_BIN:-/usr/bin/nmcli}"
readonly PACMAN_BIN="${SENOMY_PACMAN_BIN:-/usr/bin/pacman}"
readonly READLINK_BIN="${SENOMY_READLINK_BIN:-/usr/bin/readlink}"
readonly SS_BIN="${SENOMY_SS_BIN:-/usr/bin/ss}"
readonly SYSTEMCTL_BIN="${SENOMY_SYSTEMCTL_BIN:-/usr/bin/systemctl}"
readonly TIMEOUT_BIN="${SENOMY_TIMEOUT_BIN:-/usr/bin/timeout}"
readonly UNAME_BIN="${SENOMY_UNAME_BIN:-/usr/bin/uname}"
readonly OS_RELEASE="${SENOMY_OS_RELEASE:-/etc/os-release}"

printf -v observed_at '%(%s)T' -1

emit_error() {
  local code="$1"
  local message="$2"

  "$JQ_BIN" -nc \
    --argjson observed_at "$observed_at" \
    --arg code "$code" \
    --arg message "$message" \
    '{
      schema_version: 1,
      ok: false,
      source: "procfs+sysfs+system",
      observed_at: $observed_at,
      data: null,
      error: {code: $code, message: $message}
    }'
  exit 0
}

is_uint() {
  [[ "${1:-}" =~ ^[0-9]+$ ]]
}

json_or_default() {
  local candidate="$1"
  local fallback="$2"

  if "$JQ_BIN" -e . >/dev/null 2>&1 <<< "$candidate"; then
    printf '%s\n' "$candidate"
  else
    printf '%s\n' "$fallback"
  fi
}

for command_path in "$DF_BIN" "$JQ_BIN" "$UNAME_BIN"; do
  [[ -x "$command_path" ]] || {
    printf \
      '{"schema_version":1,"ok":false,"source":"procfs+sysfs+system","observed_at":%s,"data":null,"error":{"code":"dependency_missing","message":"A required performance command is unavailable"}}\n' \
      "$observed_at"
    exit 0
  }
done

read -r storage_total storage_used storage_available storage_percent storage_mount < <(
  "$DF_BIN" -B1 --output=size,used,avail,pcent,target / 2>/dev/null |
    awk '
      NR == 2 {
        gsub(/%/, "", $4)
        print $1, $2, $3, $4, $5
      }
    '
)

for value in "$storage_total" "$storage_used" "$storage_available" "$storage_percent"; do
  is_uint "$value" ||
    emit_error "storage_source_unavailable" "Unable to read root filesystem usage"
done

hostname="$("$UNAME_BIN" -n 2>/dev/null || true)"
kernel="$("$UNAME_BIN" -r 2>/dev/null || true)"
architecture="$("$UNAME_BIN" -m 2>/dev/null || true)"
os_name="Linux"

if [[ -r "$OS_RELEASE" ]]; then
  while IFS='=' read -r key value; do
    if [[ "$key" == "PRETTY_NAME" ]]; then
      os_name="${value%\"}"
      os_name="${os_name#\"}"
      break
    fi
  done < "$OS_RELEASE"
fi

package_count="null"
if [[ -x "$PACMAN_BIN" ]]; then
  candidate_count="$("$PACMAN_BIN" -Qq 2>/dev/null | awk 'END {print NR}')"
  is_uint "$candidate_count" && package_count="$candidate_count"
fi

cpu_inventory='{}'
if [[ -x "$LSCPU_BIN" ]]; then
  lscpu_output="$("$LSCPU_BIN" -J 2>/dev/null || true)"
  lscpu_output="$(json_or_default "$lscpu_output" '{"lscpu":[]}')"
  cpu_inventory="$(
    "$JQ_BIN" -c '
      def field($name):
        ([.lscpu[]? | select(.field == $name) | .data][0] // null);
      {
        architecture: field("Architecture:"),
        vendor: field("Vendor ID:"),
        model: field("Model name:"),
        logical_cpus: (field("CPU(s):") | tonumber?),
        online_cpus: field("On-line CPU(s) list:"),
        sockets: (field("Socket(s):") | tonumber?),
        physical_cores: (field("Core(s) per socket:") | tonumber?),
        threads_per_core: (field("Thread(s) per core:") | tonumber?),
        virtualization: field("Virtualization:"),
        min_mhz: (field("CPU min MHz:") | tonumber?),
        max_mhz: (field("CPU max MHz:") | tonumber?),
        caches: {
          l1d: field("L1d cache:"),
          l1i: field("L1i cache:"),
          l2: field("L2 cache:"),
          l3: field("L3 cache:")
        }
      }
    ' <<< "$lscpu_output"
  )"
fi

root_source=""
root_fstype=""
root_options=""
root_device=""
root_parent=""
root_resolved=""

if [[ -x "$FINDMNT_BIN" ]]; then
  read -r root_source root_fstype root_options < <(
    "$FINDMNT_BIN" -n -o SOURCE,FSTYPE,OPTIONS / 2>/dev/null
  )
fi

if [[ "$root_source" == /dev/* ]]; then
  root_resolved="$root_source"
  if [[ -x "$READLINK_BIN" ]]; then
    root_resolved="$("$READLINK_BIN" -f "$root_source" 2>/dev/null || printf '%s' "$root_source")"
  fi
  root_device="${root_resolved##*/}"
  if [[ -x "$LSBLK_BIN" ]]; then
    root_parent="$("$LSBLK_BIN" -ndo PKNAME "$root_resolved" 2>/dev/null | head -n 1 || true)"
  fi
fi

block_inventory='{"devices":[],"root":null}'
if [[ -x "$LSBLK_BIN" ]]; then
  lsblk_output="$(
    "$LSBLK_BIN" -J -b \
      -o NAME,KNAME,PKNAME,TYPE,SIZE,FSTYPE,MOUNTPOINTS,MODEL,TRAN,ROTA,RO,RM,PHY-SEC,LOG-SEC \
      2>/dev/null ||
      true
  )"
  lsblk_output="$(json_or_default "$lsblk_output" '{"blockdevices":[]}')"
  block_inventory="$(
    "$JQ_BIN" -c \
      --arg root_device "$root_device" \
      --arg root_parent "$root_parent" '
        def flatten:
          ., (.children[]? | flatten);
        {
          devices: [
            .blockdevices[]?
            | select(.type == "disk")
            | {
                name,
                size_bytes: .size,
                model: (.model // null),
                transport: (.tran // null),
                rotational: .rota,
                removable: (.rm // false),
                read_only: (.ro // false),
                partition_count: ([.children[]? | select(.type == "part")] | length)
              }
          ],
          root: (
            [
              .blockdevices[]?
              | flatten
              | select(.kname == $root_device)
              | {
                  name,
                  parent: (
                    if $root_parent == "" then null else $root_parent end
                  ),
                  type,
                  size_bytes: .size,
                  filesystem: (.fstype // null),
                  logical_sector_bytes: (."log-sec" // null),
                  physical_sector_bytes: (."phy-sec" // null)
                }
            ][0] // null
          ),
          root_parent: (
            [
              .blockdevices[]?
              | flatten
              | select(.kname == $root_parent)
              | {
                  name,
                  model: (.model // null),
                  transport: (.tran // null),
                  rotational: .rota,
                  size_bytes: .size
                }
            ][0] // null
          )
        }
      ' <<< "$lsblk_output"
  )"
fi

sensor_rows=""
fan_rows=""
sensor_count=0
fan_count=0

for hwmon in "$SYS_ROOT"/class/hwmon/hwmon*; do
  [[ -d "$hwmon" ]] || continue
  sensor_name="sensor"
  [[ -r "$hwmon/name" ]] && read -r sensor_name < "$hwmon/name"

  for input in "$hwmon"/temp*_input; do
    [[ -r "$input" ]] || continue
    read -r raw_temperature < "$input" 2>/dev/null || continue
    is_uint "$raw_temperature" || continue
    ((raw_temperature > 0 && raw_temperature <= 150000)) || continue

    sensor_label="${input##*/}"
    sensor_label="${sensor_label%_input}"
    label_file="${input%_input}_label"
    [[ -r "$label_file" ]] && read -r sensor_label < "$label_file"
    sensor_label="${sensor_label//$'\t'/ }"

    critical_temperature="null"
    critical_file="${input%_input}_crit"
    if [[ -r "$critical_file" ]]; then
      read -r critical_temperature < "$critical_file" 2>/dev/null ||
        critical_temperature="null"
      is_uint "$critical_temperature" || critical_temperature="null"
    fi

    sensor_rows+="${sensor_name}"$'\t'"${sensor_label}"$'\t'"${raw_temperature}"$'\t'"${critical_temperature}"$'\n'
    ((sensor_count += 1))
    ((sensor_count >= 20)) && break
  done

  for input in "$hwmon"/fan*_input; do
    [[ -r "$input" ]] || continue
    read -r raw_fan < "$input" 2>/dev/null || continue
    is_uint "$raw_fan" || continue
    fan_label="${input##*/}"
    fan_label="${fan_label%_input}"
    fan_rows+="${sensor_name}"$'\t'"${fan_label}"$'\t'"${raw_fan}"$'\n'
    ((fan_count += 1))
    ((fan_count >= 8)) && break
  done
done

temperatures_json="$(
  "$JQ_BIN" -Rsc '
    split("\n")
    | map(
        select(length > 0)
        | split("\t")
        | {
            source: .[0],
            label: .[1],
            celsius: ((.[2] | tonumber) / 100 | round / 10),
            critical_celsius: (
              if .[3] == "null" then null
              else ((.[3] | tonumber) / 100 | round / 10)
              end
            )
          }
      )
  ' <<< "$sensor_rows"
)"

fans_json="$(
  "$JQ_BIN" -Rsc '
    split("\n")
    | map(
        select(length > 0)
        | split("\t")
        | {
            source: .[0],
            label: .[1],
            rpm: (.[2] | tonumber)
          }
      )
  ' <<< "$fan_rows"
)"

highest_temperature="$(
  "$JQ_BIN" -c '
    if length == 0 then
      {available: false, celsius: null, source: null}
    else
      max_by(.celsius) as $sensor
      | {
          available: true,
          celsius: $sensor.celsius,
          source: ($sensor.source + ":" + $sensor.label)
        }
    end
  ' <<< "$temperatures_json"
)"

graphics_inventory='{"available":false,"card":null,"driver":null,"device":null,"pci_id":null}'
for card in "$SYS_ROOT"/class/drm/card[0-9]*; do
  [[ -d "$card/device" ]] || continue
  graphics_card="${card##*/}"
  graphics_driver=""
  graphics_pci_id=""
  graphics_device=""
  graphics_pci_address=""

  if [[ -L "$card/device/driver" && -x "$READLINK_BIN" ]]; then
    graphics_driver_path="$("$READLINK_BIN" -f "$card/device/driver" 2>/dev/null || true)"
    graphics_driver="${graphics_driver_path##*/}"
  fi
  if [[ -r "$card/device/uevent" ]]; then
    while IFS='=' read -r key value; do
      case "$key" in
        PCI_ID)
          graphics_pci_id="$value"
          ;;
        PCI_SLOT_NAME)
          graphics_pci_address="$value"
          ;;
      esac
    done < "$card/device/uevent"
  fi
  if [[ -x "$LSPCI_BIN" && -n "$graphics_pci_address" ]]; then
    graphics_device="$("$LSPCI_BIN" -D -s "$graphics_pci_address" 2>/dev/null || true)"
    graphics_device="${graphics_device#* }"
  fi

  graphics_inventory="$(
    "$JQ_BIN" -nc \
      --arg card "$graphics_card" \
      --arg driver "$graphics_driver" \
      --arg device "$graphics_device" \
      --arg pci_id "$graphics_pci_id" '
        {
          available: true,
          card: $card,
          driver: (if $driver == "" then null else $driver end),
          device: (if $device == "" then null else $device end),
          pci_id: (if $pci_id == "" then null else $pci_id end)
        }
      '
  )"
  break
done

active_interface=""
if [[ -r "$PROC_ROOT/net/route" ]]; then
  while read -r iface destination gateway flags rest; do
    [[ "$iface" == "Iface" ]] && continue
    if [[ "$destination" == "00000000" && "$iface" != "lo" ]]; then
      active_interface="$iface"
      break
    fi
  done < "$PROC_ROOT/net/route"
fi

network_inventory='{"available":false,"interface":null,"state":"unavailable","kind":"none","mtu":null,"ipv4":null,"ipv6":null,"gateway":null,"connection":null}'
if [[ -n "$active_interface" ]]; then
  address_json='[]'
  route_json='[]'
  if [[ -x "$IP_BIN" ]]; then
    address_output="$("$IP_BIN" -j address show dev "$active_interface" 2>/dev/null || true)"
    route_output="$("$IP_BIN" -j route show default dev "$active_interface" 2>/dev/null || true)"
    address_json="$(json_or_default "$address_output" '[]')"
    route_json="$(json_or_default "$route_output" '[]')"
  fi

  connection_name=""
  if [[ -x "$NMCLI_BIN" ]]; then
    connection_name="$(
      "$NMCLI_BIN" -g GENERAL.CONNECTION device show "$active_interface" 2>/dev/null |
        head -n 1 ||
        true
    )"
  fi

  network_kind="ethernet"
  [[ -d "$SYS_ROOT/class/net/$active_interface/wireless" ]] &&
    network_kind="wireless"

  network_inventory="$(
    "$JQ_BIN" -nc \
      --arg interface "$active_interface" \
      --arg kind "$network_kind" \
      --arg connection "$connection_name" \
      --argjson addresses "$address_json" \
      --argjson routes "$route_json" '
        ($addresses[0] // {}) as $device |
        {
          available: true,
          interface: $interface,
          state: (($device.operstate // "unknown") | ascii_downcase),
          kind: $kind,
          mtu: ($device.mtu // null),
          ipv4: (
            [
              $device.addr_info[]?
              | select(.family == "inet" and .scope == "global")
              | (.local + "/" + (.prefixlen | tostring))
            ][0] // null
          ),
          ipv6: (
            [
              $device.addr_info[]?
              | select(.family == "inet6" and .scope == "global")
              | (.local + "/" + (.prefixlen | tostring))
            ][0] // null
          ),
          gateway: ($routes[0].gateway // null),
          connection: (
            if $connection == "" or $connection == "--"
            then null
            else $connection
            end
          )
        }
      '
  )"
fi

declare -A sockets=()
if [[ -r "$PROC_ROOT/net/sockstat" ]]; then
  while read -r protocol rest; do
    protocol="${protocol%:}"
    read -ra socket_fields <<< "$rest"
    for ((index = 0; index + 1 < ${#socket_fields[@]}; index += 2)); do
      sockets["${protocol}_${socket_fields[index]}"]="${socket_fields[index + 1]}"
    done
  done < "$PROC_ROOT/net/sockstat"
fi

tcp_established=0
tcp_listening=0
if [[ -x "$SS_BIN" ]]; then
  while IFS= read -r socket_line; do
    [[ -n "$socket_line" ]] && ((tcp_established += 1))
  done < <("$SS_BIN" -Htan state established 2>/dev/null || true)
  while IFS= read -r socket_line; do
    [[ -n "$socket_line" ]] && ((tcp_listening += 1))
  done < <("$SS_BIN" -Htan state listening 2>/dev/null || true)
fi

system_state="unavailable"
user_state="unavailable"
services_available=false
failed_service_rows=""
system_failed_count=0
user_failed_count=0

if [[ -x "$SYSTEMCTL_BIN" && -x "$TIMEOUT_BIN" ]]; then
  services_available=true
  system_state="$(
    "$TIMEOUT_BIN" 2s "$SYSTEMCTL_BIN" is-system-running 2>/dev/null ||
      true
  )"
  user_state="$(
    "$TIMEOUT_BIN" 2s "$SYSTEMCTL_BIN" --user is-system-running 2>/dev/null ||
      true
  )"

  while read -r unit load active sub description; do
    [[ -n "$unit" ]] || continue
    failed_service_rows+="system"$'\t'"$unit"$'\t'"${sub:-failed}"$'\n'
    ((system_failed_count += 1))
  done < <(
    "$TIMEOUT_BIN" 2s "$SYSTEMCTL_BIN" \
      --failed --type=service --no-legend --plain --no-pager 2>/dev/null ||
      true
  )

  while read -r unit load active sub description; do
    [[ -n "$unit" ]] || continue
    failed_service_rows+="user"$'\t'"$unit"$'\t'"${sub:-failed}"$'\n'
    ((user_failed_count += 1))
  done < <(
    "$TIMEOUT_BIN" 2s "$SYSTEMCTL_BIN" --user \
      --failed --type=service --no-legend --plain --no-pager 2>/dev/null ||
      true
  )
fi

[[ -n "$system_state" ]] || system_state="unknown"
[[ -n "$user_state" ]] || user_state="unknown"

failed_services_json="$(
  "$JQ_BIN" -Rsc '
    split("\n")
    | map(
        select(length > 0)
        | split("\t")
        | {scope: .[0], unit: .[1], state: .[2]}
      )
    | .[:12]
  ' <<< "$failed_service_rows"
)"

"$JQ_BIN" -nc \
  --argjson observed_at "$observed_at" \
  --arg hostname "${hostname:-unknown}" \
  --arg os_name "$os_name" \
  --arg kernel "${kernel:-unknown}" \
  --arg architecture "${architecture:-unknown}" \
  --argjson package_count "$package_count" \
  --argjson highest_temperature "$highest_temperature" \
  --argjson cpu_inventory "$cpu_inventory" \
  --argjson storage_total "$storage_total" \
  --argjson storage_used "$storage_used" \
  --argjson storage_available "$storage_available" \
  --argjson storage_percent "$storage_percent" \
  --arg storage_mount "${storage_mount:-/}" \
  --arg root_source "$root_source" \
  --arg root_fstype "$root_fstype" \
  --arg root_options "$root_options" \
  --argjson block_inventory "$block_inventory" \
  --argjson temperatures "$temperatures_json" \
  --argjson fans "$fans_json" \
  --argjson graphics "$graphics_inventory" \
  --argjson network "$network_inventory" \
  --argjson services_available "$services_available" \
  --arg system_state "$system_state" \
  --arg user_state "$user_state" \
  --argjson system_failed_count "$system_failed_count" \
  --argjson user_failed_count "$user_failed_count" \
  --argjson failed_services "$failed_services_json" \
  --argjson sockets_used "${sockets[sockets_used]:-0}" \
  --argjson tcp_in_use "${sockets[TCP_inuse]:-0}" \
  --argjson tcp_orphaned "${sockets[TCP_orphan]:-0}" \
  --argjson tcp_time_wait "${sockets[TCP_tw]:-0}" \
  --argjson udp_in_use "${sockets[UDP_inuse]:-0}" \
  --argjson raw_in_use "${sockets[RAW_inuse]:-0}" \
  --argjson tcp_established "$tcp_established" \
  --argjson tcp_listening "$tcp_listening" '
    {
      schema_version: 1,
      ok: true,
      source: "procfs+sysfs+system",
      observed_at: $observed_at,
      data: {
        health: {
          hostname: $hostname,
          os: $os_name,
          kernel: $kernel,
          architecture: $architecture,
          package_count: $package_count,
          temperature: $highest_temperature
        },
        cpu_inventory: $cpu_inventory,
        storage: {
          mount: $storage_mount,
          source: (if $root_source == "" then null else $root_source end),
          filesystem: (if $root_fstype == "" then null else $root_fstype end),
          options: (if $root_options == "" then null else $root_options end),
          total_bytes: $storage_total,
          used_bytes: $storage_used,
          available_bytes: $storage_available,
          percent: $storage_percent,
          root_device: $block_inventory.root,
          root_parent: $block_inventory.root_parent,
          devices: $block_inventory.devices
        },
        sensors: {
          temperatures: $temperatures,
          fans: $fans
        },
        graphics: $graphics,
        network: $network,
        sockets: {
          available: ($sockets_used > 0),
          used: $sockets_used,
          tcp: {
            in_use: $tcp_in_use,
            established: $tcp_established,
            listening: $tcp_listening,
            orphaned: $tcp_orphaned,
            time_wait: $tcp_time_wait
          },
          udp_in_use: $udp_in_use,
          raw_in_use: $raw_in_use
        },
        services: {
          available: $services_available,
          system_state: $system_state,
          user_state: $user_state,
          system_failed_count: $system_failed_count,
          user_failed_count: $user_failed_count,
          failed_total: ($system_failed_count + $user_failed_count),
          failed: $failed_services
        }
      },
      error: null
    }
  '
