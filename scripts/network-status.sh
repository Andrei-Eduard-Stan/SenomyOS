#!/usr/bin/env bash

# Emit detailed NetworkManager telemetry. This collector never scans or mutates.

set -u
export LC_ALL=C
printf -v observed_at '%(%s)T' -1

emit_error() {
  jq -nc --argjson at "$observed_at" --arg code "$1" --arg message "$2" \
    '{schema_version:2,ok:false,source:"NetworkManager/nmcli",observed_at:$at,
      data:null,error:{code:$code,message:$message}}'
  exit 0
}

command -v jq >/dev/null 2>&1 || {
  printf '{"schema_version":2,"ok":false,"source":"NetworkManager/nmcli","observed_at":%s,"data":null,"error":{"code":"dependency_missing","message":"Required command jq is unavailable"}}\n' "$observed_at"
  exit 0
}
command -v nmcli >/dev/null 2>&1 ||
  emit_error "dependency_missing" "Required command nmcli is unavailable"

state="$(nmcli -g STATE general 2>/dev/null)" ||
  emit_error "network_manager_unavailable" "NetworkManager is not reachable"
connectivity="$(nmcli -g CONNECTIVITY general 2>/dev/null || printf unknown)"
networking="$(nmcli networking 2>/dev/null || printf disabled)"
wifi_radio="$(nmcli radio wifi 2>/dev/null || printf disabled)"
devices="$(nmcli -t --escape no -f DEVICE,TYPE,STATE device status 2>/dev/null)" ||
  emit_error "network_manager_unavailable" "Unable to read network devices"
active_ap="$(nmcli -t --escape no -f IN-USE,BSSID,SSID,CHAN,FREQ,RATE,SIGNAL,SECURITY device wifi list --rescan no 2>/dev/null | awk -F: '$1=="*" {print; exit}')"
saved_count="$(nmcli -t -f TYPE connection show 2>/dev/null | awk '$0=="802-11-wireless"{n++} END{print n+0}')"

saved_profiles_json='[]'
while IFS=: read -r uuid type; do
  [[ "$type" == "802-11-wireless" || "$type" == "wifi" ]] || continue
  [[ "$uuid" =~ ^[[:xdigit:]]{8}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{12}$ ]] || continue

  mapfile -t profile_fields < <(
    nmcli -g connection.id,802-11-wireless.ssid,connection.autoconnect,connection.timestamp \
      connection show uuid "$uuid" 2>/dev/null
  )
  profile_name="${profile_fields[0]:-Unknown profile}"
  profile_ssid="${profile_fields[1]:-${profile_fields[0]:-}}"
  profile_autoconnect=false
  [[ "${profile_fields[2]:-no}" == "yes" ]] && profile_autoconnect=true
  profile_timestamp="${profile_fields[3]:-0}"
  [[ "$profile_timestamp" =~ ^[0-9]+$ ]] || profile_timestamp=0

  profile_json="$(jq -nc \
    --arg uuid "$uuid" \
    --arg name "$profile_name" \
    --arg ssid "$profile_ssid" \
    --argjson autoconnect "$profile_autoconnect" \
    --argjson timestamp "$profile_timestamp" \
    '{
      uuid: $uuid,
      name: $name,
      ssid: $ssid,
      autoconnect: $autoconnect,
      last_used_at: $timestamp
    }')"
  saved_profiles_json="$(
    jq -nc --argjson list "$saved_profiles_json" --argjson item "$profile_json" '$list + [$item]'
  )"
done < <(nmcli -t --escape no -f UUID,TYPE connection show 2>/dev/null)

nearby_raw_json='[]'
ap_in_use=""
ap_bssid=""
ap_ssid=""
ap_mode=""
ap_channel=""
ap_frequency=""
ap_rate=""
ap_signal=""
ap_security=""

append_access_point() {
  local hidden=false
  local frequency_mhz=0
  local signal=0
  local channel=0
  local item

  [[ -n "$ap_bssid" ]] || return 0
  [[ "$ap_bssid" =~ ^([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}$ ]] || return 0
  [[ "$ap_ssid" == "--" || -z "$ap_ssid" ]] && hidden=true
  [[ "$ap_frequency" =~ ([0-9]+) ]] && frequency_mhz="${BASH_REMATCH[1]}"
  [[ "$ap_signal" =~ ^[0-9]+$ ]] && signal="$ap_signal"
  [[ "$ap_channel" =~ ^[0-9]+$ ]] && channel="$ap_channel"

  item="$(jq -nc \
    --arg bssid "$ap_bssid" \
    --arg ssid "$ap_ssid" \
    --arg mode "$ap_mode" \
    --arg rate "$ap_rate" \
    --arg security "$ap_security" \
    --argjson active "$([[ "$ap_in_use" == "*" ]] && printf true || printf false)" \
    --argjson hidden "$hidden" \
    --argjson channel "$channel" \
    --argjson frequency "$frequency_mhz" \
    --argjson signal "$signal" \
    '{
      bssid: $bssid,
      ssid: (if $hidden then "" else $ssid end),
      hidden: $hidden,
      active: $active,
      mode: $mode,
      channel: $channel,
      frequency_mhz: $frequency,
      band: (
        if $frequency >= 5925 then "6 GHz"
        elif $frequency >= 4900 then "5 GHz"
        else "2.4 GHz"
        end
      ),
      rate: $rate,
      signal_percent: $signal,
      security: (
        if $security == "" or $security == "--" then "OPEN" else $security end
      ),
      secured: ($security != "" and $security != "--")
    }')"
  nearby_raw_json="$(
    jq -nc --argjson list "$nearby_raw_json" --argjson item "$item" '$list + [$item]'
  )"
}

while IFS= read -r line; do
  key="${line%%:*}"
  value="${line#*:}"
  value="${value#"${value%%[![:space:]]*}"}"

  if [[ "$key" == "IN-USE" && -n "$ap_bssid" ]]; then
    append_access_point
    ap_bssid=""
  fi

  case "$key" in
    IN-USE) ap_in_use="$value" ;;
    BSSID) ap_bssid="$value" ;;
    SSID) ap_ssid="$value" ;;
    MODE) ap_mode="$value" ;;
    CHAN) ap_channel="$value" ;;
    FREQ) ap_frequency="$value" ;;
    RATE) ap_rate="$value" ;;
    SIGNAL) ap_signal="$value" ;;
    SECURITY) ap_security="$value" ;;
  esac
done < <(
  nmcli -m multiline -f IN-USE,BSSID,SSID,MODE,CHAN,FREQ,RATE,SIGNAL,SECURITY \
    device wifi list --rescan no 2>/dev/null
)
append_access_point

nearby_json="$(
  jq -nc \
    --argjson access_points "$nearby_raw_json" \
    --argjson profiles "$saved_profiles_json" '
    [
      $access_points[]
      | select(.hidden == false)
    ]
    | sort_by(.ssid, -.signal_percent)
    | group_by(.ssid)
    | map(
        sort_by(-.signal_percent) as $radios
        | (
            ([$radios[] | select(.active)] | first) // $radios[0]
          ) as $selected
        | $selected
        | .radio_count = ($radios | length)
        | .bands = ($radios | map(.band) | unique)
        | .band_summary = (.bands | join(" + "))
        | .profile = (
            [$profiles[] | select(.ssid == $radios[0].ssid)]
            | sort_by(-.last_used_at)
            | first // null
          )
        | .saved = (.profile != null)
      )
    | sort_by((if .active then 0 else 1 end), -.signal_percent, .ssid)
    | .[:16]
  '
)"
hidden_network_count="$(jq '[.[] | select(.hidden)] | length' <<<"$nearby_raw_json")"

device_json='[]'
while IFS=: read -r id type device_state; do
  [[ -n "$id" && "$type" != "loopback" ]] || continue
  props="$(nmcli -t --escape no -f GENERAL.CONNECTION,GENERAL.CON-UUID,GENERAL.MTU,GENERAL.HWADDR,GENERAL.DRIVER,GENERAL.FIRMWARE-VERSION,IP4.ADDRESS,IP4.GATEWAY,IP4.DNS,IP6.ADDRESS,IP6.GATEWAY,IP6.DNS device show "$id" 2>/dev/null || true)"
  field() { sed -n "s/^$1\\(\\[[0-9][0-9]*\\]\\)\\{0,1\\}://p" <<<"$props"; }
  connection="$(field GENERAL.CONNECTION)"; [[ "$connection" == "--" ]] && connection=""
  connection_uuid="$(field GENERAL.CON-UUID)"; [[ "$connection_uuid" == "--" ]] && connection_uuid=""
  mtu="$(field GENERAL.MTU)"
  hwaddr="$(field GENERAL.HWADDR)"
  driver="$(field GENERAL.DRIVER)"
  firmware="$(field GENERAL.FIRMWARE-VERSION)"
  ip4="$(field IP4.ADDRESS | jq -Rsc 'split("\n")|map(select(length>0))')"; ip4="${ip4:-[]}"
  ip6="$(field IP6.ADDRESS | jq -Rsc 'split("\n")|map(select(length>0))')"; ip6="${ip6:-[]}"
  dns4="$(field IP4.DNS | jq -Rsc 'split("\n")|map(select(length>0))')"; dns4="${dns4:-[]}"
  dns6="$(field IP6.DNS | jq -Rsc 'split("\n")|map(select(length>0))')"; dns6="${dns6:-[]}"
  gateway4="$(field IP4.GATEWAY | head -n1)"
  gateway6="$(field IP6.GATEWAY | head -n1)"
  carrier="unknown"; speed=""
  [[ -r "/sys/class/net/$id/carrier" ]] && carrier="$(<"/sys/class/net/$id/carrier")"
  [[ -r "/sys/class/net/$id/speed" ]] && speed="$(<"/sys/class/net/$id/speed")"
  item="$(jq -nc --arg id "$id" --arg type "$type" --arg state "${device_state,,}" \
    --arg connection "$connection" --arg connection_uuid "$connection_uuid" --arg mtu "$mtu" --arg hwaddr "$hwaddr" \
    --arg driver "$driver" --arg firmware "$firmware" --arg gateway4 "$gateway4" \
    --arg gateway6 "$gateway6" --arg carrier "$carrier" --arg speed "$speed" \
    --argjson ip4 "$ip4" --argjson ip6 "$ip6" --argjson dns4 "$dns4" --argjson dns6 "$dns6" '
    def optional: if length > 0 then . else null end;
    {id:$id,type:$type,state:$state,connected:($state|startswith("connected")),
     connection:($connection|optional),connection_uuid:($connection_uuid|optional),mtu:($mtu|tonumber?),
     hardware_address:($hwaddr|optional),driver:($driver|optional),
     firmware:($firmware|optional),ip4_addresses:$ip4,ip6_addresses:$ip6,
     gateway4:($gateway4|optional),gateway6:($gateway6|optional),
     dns:($dns4+$dns6|unique),carrier:($carrier=="1"),
     speed_mbps:(($speed | try tonumber catch null) as $value |
       if ($value // -1) >= 0 then $value else null end)}')"
  device_json="$(jq -nc --argjson list "$device_json" --argjson item "$item" '$list+[$item]')"
done <<<"$devices"

ap_json='null'
if [[ -n "$active_ap" ]]; then
  IFS=: read -r _ b1 b2 b3 b4 b5 b6 ssid channel frequency rate signal security <<<"$active_ap"
  bssid="$b1:$b2:$b3:$b4:$b5:$b6"
  ap_json="$(jq -nc --arg bssid "$bssid" --arg ssid "$ssid" --arg channel "$channel" \
    --arg frequency "$frequency" --arg rate "$rate" --arg signal "$signal" --arg security "$security" '
    ($frequency | capture("(?<value>[0-9]+)").value | tonumber) as $mhz |
    {bssid:$bssid,ssid:$ssid,channel:($channel|tonumber?),frequency_mhz:$mhz,
     band:(if $mhz>=5925 then "6 GHz" elif $mhz>=4900 then "5 GHz" else "2.4 GHz" end),
     rate:$rate,signal_percent:(($signal|tonumber?)//0),
     security:(if ($security|length)>0 then $security else "OPEN" end)}')"
fi

jq -nc --argjson at "$observed_at" --arg state "${state,,}" \
  --arg connectivity "${connectivity,,}" --arg networking "${networking,,}" \
  --arg wifi "${wifi_radio,,}" --argjson devices "$device_json" \
  --argjson ap "$ap_json" --argjson saved "$saved_count" \
  --argjson profiles "$saved_profiles_json" --argjson nearby "$nearby_json" \
  --argjson hidden "$hidden_network_count" '
  (
    ($devices | map(select(.connected and .gateway4 != null)) | first) //
    ($devices | map(select(.connected)) | first) //
    null
  ) as $primary |
  ($devices|map(select(.type=="wifi"))|first // null) as $wifi_device |
  ($devices|map(select(.type=="ethernet"))|first // null) as $ethernet |
  {schema_version:2,ok:true,source:"NetworkManager/nmcli",observed_at:$at,
   data:{state:$state,connectivity:$connectivity,
    networking_enabled:($networking=="enabled"),connected:($primary!=null),
    internet:{
      online:($connectivity=="full"),
      captive_portal:($connectivity=="portal"),
      limited:($connectivity=="limited" or $connectivity=="portal"),
      label:(
        if $connectivity=="full" then "FULL INTERNET"
        elif $connectivity=="portal" then "CAPTIVE PORTAL"
        elif $connectivity=="limited" then "LIMITED"
        elif $primary!=null then "LINK ONLY"
        else "OFFLINE"
        end
      ),
      detail:(
        if $connectivity=="full" then "NetworkManager verified global connectivity"
        elif $connectivity=="portal" then "Sign-in is required before internet access"
        elif $connectivity=="limited" then "A route exists but global connectivity is unavailable"
        elif $primary!=null then "Associated locally; internet has not been verified"
        else "No active primary route"
        end
      )
    },
    primary:$primary,
    wifi:{enabled:($wifi=="enabled"),connected:($wifi_device.connected//false),
      device:$wifi_device,access_point:$ap,saved_profile_count:$saved,
      saved_profiles:(
        $profiles
        | map(.active = (.uuid == ($wifi_device.connection_uuid // "")))
        | sort_by((if .active then 0 else 1 end), -.last_used_at, .name)
      ),
      nearby:$nearby,
      nearby_count:($nearby|length),
      hidden_network_count:$hidden},
    ethernet:{connected:($ethernet.connected//false),device:$ethernet},
    devices:$devices,device_count:($devices|length)},error:null}'
