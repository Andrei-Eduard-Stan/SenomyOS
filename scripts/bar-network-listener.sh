#!/usr/bin/env bash

# Stream NetworkManager changes to Eww without running the detailed AP collector.

set -u
export LC_ALL=C

emit() {
  local observed_at available=false networking=false wifi=false connected=false
  local connectivity="unknown" connection="Offline" signal=0
  printf -v observed_at '%(%s)T' -1

  if command -v nmcli >/dev/null 2>&1; then
    available=true
    [[ "$(nmcli networking 2>/dev/null || true)" == enabled ]] && networking=true
    [[ "$(nmcli radio wifi 2>/dev/null || true)" == enabled ]] && wifi=true
    connectivity="$(nmcli -g CONNECTIVITY general 2>/dev/null || printf unknown)"
    connection="$(nmcli -t --escape no -f TYPE,STATE,CONNECTION device status 2>/dev/null |
      awk -F: '$2 ~ /^connected/ && $1 != "loopback" {print $3; exit}')"
    if [[ -n "$connection" ]]; then connected=true; else connection="Offline"; fi
    signal="$(nmcli -t --escape no -f IN-USE,SIGNAL device wifi list --rescan no 2>/dev/null |
      awk -F: '$1=="*" {print $2; exit}')"
    [[ "$signal" =~ ^[0-9]+$ ]] || signal=0
  fi

  jq -nc --argjson at "$observed_at" --argjson available "$available" \
    --argjson networking "$networking" --argjson wifi "$wifi" \
    --argjson connected "$connected" --arg connectivity "$connectivity" \
    --arg connection "$connection" --argjson signal "$signal" \
    '{schema_version:1,ok:true,source:"NetworkManager event",observed_at:$at,
      data:{available:$available,networking_enabled:$networking,wifi_enabled:$wifi,
        connected:$connected,connectivity:$connectivity,connection_name:$connection,
        signal_percent:$signal},error:null}'
}

emit
command -v nmcli >/dev/null 2>&1 || exit 0

nmcli monitor 2>/dev/null | while IFS= read -r _event; do emit; done
