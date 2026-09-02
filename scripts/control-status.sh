#!/usr/bin/env bash

# Emit bounded Control Centre inventory without changing system state.

set -u
export LC_ALL=C
printf -v observed_at '%(%s)T' -1

emit_error() {
  jq -nc --argjson at "$observed_at" --arg code "$1" --arg message "$2" \
    '{schema_version:1,ok:false,source:"hyprland+system",observed_at:$at,data:null,error:{code:$code,message:$message}}'
  exit 0
}

command -v jq >/dev/null 2>&1 || { printf '{"schema_version":1,"ok":false,"source":"hyprland+system","observed_at":%s,"data":null,"error":{"code":"dependency_missing","message":"jq is unavailable"}}\n' "$observed_at"; exit 0; }
command -v hyprctl >/dev/null 2>&1 || emit_error "dependency_missing" "hyprctl is unavailable"

monitors="$(hyprctl -j monitors 2>/dev/null)" || emit_error "hyprland_unavailable" "Unable to read monitors"
devices="$(hyprctl -j devices 2>/dev/null)" || emit_error "hyprland_unavailable" "Unable to read input devices"
workspace="$(hyprctl -j activeworkspace 2>/dev/null || printf '{}')"

timezone="$(timedatectl show -p Timezone --value 2>/dev/null || date +%Z)"
ntp_capable="$(timedatectl show -p CanNTP --value 2>/dev/null || printf no)"
ntp_enabled="$(timedatectl show -p NTP --value 2>/dev/null || printf no)"
ntp_synced="$(timedatectl show -p NTPSynchronized --value 2>/dev/null || printf no)"
locale="$(localectl status 2>/dev/null | sed -n 's/.*System Locale: LANG=//p' | head -n1)"
now_iso="$(date --iso-8601=seconds)"
month="$(date '+%B %Y')"
day_name="$(date '+%A')"
day_number="$(date '+%d')"
week_number="$(date '+%V')"
calendar="$(cal -m 2>/dev/null || true)"

bluetooth_available=false bluetooth_active=false bluetooth_powered=false bluetooth_name="Unavailable"
if command -v bluetoothctl >/dev/null 2>&1; then
  bluetooth_available=true
  systemctl is-active --quiet bluetooth.service 2>/dev/null && bluetooth_active=true
  bt_show="$(timeout 2 bluetoothctl show 2>/dev/null || true)"
  grep -q $'\tPowered: yes' <<<"$bt_show" && bluetooth_powered=true
  bluetooth_name="$(sed -n 's/^\tAlias: //p' <<<"$bt_show" | head -n1)"
  [[ -n "$bluetooth_name" ]] || bluetooth_name="Controller"
fi

brightness_available=false brightness_percent=null
if command -v brightnessctl >/dev/null 2>&1; then
  brightness_raw="$(brightnessctl -m 2>/dev/null | awk -F, 'NR==1 {gsub(/%/,"",$4); print $4}')"
  if [[ "$brightness_raw" =~ ^[0-9]+$ ]]; then brightness_available=true; brightness_percent="$brightness_raw"; fi
fi

jq -nc --argjson at "$observed_at" --argjson monitors "$monitors" --argjson devices "$devices" --argjson workspace "$workspace" \
  --arg timezone "$timezone" --arg locale "$locale" --arg now "$now_iso" --arg month "$month" --arg day_name "$day_name" \
  --arg day_number "$day_number" --arg week "$week_number" --arg calendar "$calendar" \
  --argjson ntp_capable "$([[ "$ntp_capable" == yes ]] && printf true || printf false)" \
  --argjson ntp_enabled "$([[ "$ntp_enabled" == yes ]] && printf true || printf false)" \
  --argjson ntp_synced "$([[ "$ntp_synced" == yes ]] && printf true || printf false)" \
  --argjson bt_available "$bluetooth_available" --argjson bt_active "$bluetooth_active" --argjson bt_powered "$bluetooth_powered" --arg bt_name "$bluetooth_name" \
  --argjson brightness_available "$brightness_available" --argjson brightness "$brightness_percent" '
  {
    schema_version:1,ok:true,source:"hyprland+system",observed_at:$at,
    data:{
      session:{workspace:($workspace.id//0),workspace_name:($workspace.name//"--"),window_count:($workspace.windows//0),layout:($workspace.tiledLayout//"unknown")},
      clock:{now_iso:$now,timezone:$timezone,locale:($locale|select(length>0)//"Unavailable"),month:$month,day_name:$day_name,day_number:$day_number,week_number:$week,calendar:$calendar,ntp_capable:$ntp_capable,ntp_enabled:$ntp_enabled,ntp_synchronized:$ntp_synced},
      monitors:[$monitors[]|{id,name,description,make,model,width,height,refresh_hz:.refreshRate,x,y,scale,transform,focused,dpms:.dpmsStatus,vrr,workspace:(.activeWorkspace.id//0),physical_width_mm:.physicalWidth,physical_height_mm:.physicalHeight}],
      inputs:{
        keyboards:[($devices.keyboards//[])[]|{name,main,keymap:.active_keymap,layout,caps_lock:.capsLock,num_lock:.numLock}],
        pointers:[($devices.mice//[])[]|{name,default_speed:.defaultSpeed,scroll_factor:.scrollFactor}],
        touch:[($devices.touch//[])[]|{name}],tablets:[($devices.tablets//[])[]|{name}],switches:[($devices.switches//[])[]|{name}]
      },
      bluetooth:{available:$bt_available,service_active:$bt_active,powered:$bt_powered,name:$bt_name},
      brightness:{available:$brightness_available,percent:$brightness},
      counts:{monitors:($monitors|length),keyboards:(($devices.keyboards//[])|length),pointers:(($devices.mice//[])|length),touch:(($devices.touch//[])|length),tablets:(($devices.tablets//[])|length),switches:(($devices.switches//[])|length)}
    },error:null
  }'
