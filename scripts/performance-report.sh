#!/usr/bin/env bash

# Generate private, profile-based SenomyOS evidence bundles. Sources are fixed,
# read-only and bounded; unrestricted journals and environment dumps are excluded.
set -euo pipefail
export LC_ALL=C

readonly ACTION="${1:-read-json}"
readonly PROFILE="${2:-overview}"
readonly HOME_DIR="${HOME:-/nonexistent}"
readonly STATE_ROOT="${SENOMY_REPORT_ROOT:-${XDG_STATE_HOME:-$HOME_DIR/.local/state}/senomyos/reports}"
readonly LATEST_FILE="$STATE_ROOT/latest.json"
readonly HISTORY_LIMIT="${SENOMY_REPORT_HISTORY_LIMIT:-10}"

valid_profile() { case "$1" in overview | performance | network | power | full) return 0 ;; *) return 1 ;; esac; }
valid_profile "$PROFILE" || { printf 'Unknown report profile: %s\n' "$PROFILE" >&2; exit 2; }

profile_sections() {
  case "$1" in
    overview) printf '%s\n' identity platform uptime memory storage services ;;
    performance) printf '%s\n' platform uptime memory pressure storage processes ;;
    network) printf '%s\n' platform network interfaces routes resolver ;;
    power) printf '%s\n' platform power batteries profiles thermal ;;
    full) printf '%s\n' identity platform uptime memory pressure storage processes services network interfaces routes resolver power batteries profiles thermal ;;
  esac
}

section_title() { printf '%s' "$1" | tr '[:lower:]' '[:upper:]'; }

collect_section() {
  local section="$1"
  printf '\n================================================================================\n%s\n================================================================================\n' "$(section_title "$section")"
  case "$section" in
    identity) id; printf 'groups='; groups ;;
    platform) uname -a; printf '\n'; sed -n '1,24p' /etc/os-release ;;
    uptime) uptime; cat /proc/loadavg ;;
    memory) free -h; printf '\n'; sed -n '1,28p' /proc/meminfo ;;
    pressure) for file in /proc/pressure/cpu /proc/pressure/memory /proc/pressure/io; do printf '\n[%s]\n' "$file"; cat "$file"; done ;;
    storage) df -hT -x tmpfs -x devtmpfs -x squashfs -x efivarfs; command -v lsblk >/dev/null && { printf '\n'; lsblk -e 7 -o NAME,TYPE,SIZE,FSTYPE,FSUSE%,MOUNTPOINTS,MODEL; } ;;
    processes) ps -eo pid,ppid,user,stat,%cpu,%mem,rss,etimes,comm --sort=-%cpu | head -n 26 ;;
    services) systemctl --user --failed --no-pager --plain || true; printf '\nWORKSPACES SERVICE\n'; systemctl --user status workspaces.service --no-pager --lines=16 || true ;;
    network) command -v nmcli >/dev/null && nmcli general || printf 'NetworkManager CLI unavailable\n' ;;
    interfaces) ip -details -statistics -brief address 2>/dev/null || ip -brief address ;;
    routes) ip route; printf '\nIPV6\n'; ip -6 route 2>/dev/null || true ;;
    resolver) command -v resolvectl >/dev/null && resolvectl status || sed -n '1,80p' /etc/resolv.conf ;;
    power) command -v upower >/dev/null && upower -e || printf 'UPower unavailable\n' ;;
    batteries)
      if command -v upower >/dev/null; then
        while IFS= read -r device; do case "$device" in *battery*) upower -i "$device" ;; esac; done < <(upower -e)
      else printf 'UPower unavailable\n'; fi ;;
    profiles) command -v powerprofilesctl >/dev/null && { powerprofilesctl get; powerprofilesctl list; } || printf 'power-profiles-daemon unavailable\n' ;;
    thermal) for zone in /sys/class/thermal/thermal_zone*; do [[ -r "$zone/temp" ]] || continue; printf '%s type=%s temp_mC=%s\n' "$(basename "$zone")" "$(cat "$zone/type" 2>/dev/null || printf unknown)" "$(cat "$zone/temp")"; done ;;
  esac
}

history_json() {
  local manifests=()
  while IFS= read -r path; do manifests+=("$path"); done < <(find "$STATE_ROOT" -maxdepth 1 -type f -name 'report-*.json' -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -n "$HISTORY_LIMIT" | cut -d' ' -f2-)
  if ((${#manifests[@]})); then jq -sc 'map({id,profile,profile_label,generated_at,generated_label,size_bytes,line_count,path,section_count:(.sections|length)})' "${manifests[@]}"; else printf '[]'; fi
}

emit_status() {
  local latest='{}' history preview='[]' exists=false
  [[ -r "$LATEST_FILE" ]] && latest="$(cat "$LATEST_FILE")" && exists=true
  history="$(history_json)"
  if [[ "$exists" == true ]]; then
    path="$(jq -r '.path // empty' <<<"$latest")"
    [[ -r "$path" ]] && preview="$(head -n 100 "$path" | jq -Rsc 'split("\n") | map(select(length>0)) | to_entries | map({line_no:(.key+1),text:.value})')"
  fi
  jq -nc --argjson at "$(date +%s)" --argjson exists "$exists" --argjson latest "$latest" --argjson history "$history" --argjson preview "$preview" '
    {schema_version:2,ok:true,source:"senomy-evidence-reports",observed_at:$at,
      data:{exists:$exists,latest:$latest,history:$history,history_count:($history|length),preview:$preview,
        policy:{private_mode:"0600",automatic_upload:false,unrestricted_logs:false,environment_dump:false,credentials:false}},error:null}'
}

generate() {
  local timestamp id report manifest tmp_report tmp_manifest sections_json size lines label
  mkdir -p -m 700 "$STATE_ROOT"
  timestamp="$(date '+%Y%m%d-%H%M%S')"; id="${timestamp}-${PROFILE}"
  report="$STATE_ROOT/report-$id.txt"; manifest="$STATE_ROOT/report-$id.json"
  tmp_report="$(mktemp "$STATE_ROOT/.report.XXXXXX")"; tmp_manifest="$(mktemp "$STATE_ROOT/.manifest.XXXXXX")"
  trap 'rm -f "$tmp_report" "$tmp_manifest"' EXIT
  label="$(tr '[:lower:]' '[:upper:]' <<<"$PROFILE")"
  {
    printf 'SENOMYOS EVIDENCE REPORT\nID: %s\nPROFILE: %s\nGENERATED: %s\nHOST: %s\nKERNEL: %s\nPOLICY: local-only, mode-0600, fixed read-only collectors, no unrestricted logs\n' "$id" "$label" "$(date --iso-8601=seconds)" "$(uname -n)" "$(uname -r)"
    while IFS= read -r section; do collect_section "$section" || printf 'COLLECTOR WARNING: %s returned non-zero\n' "$section"; done < <(profile_sections "$PROFILE")
  } >"$tmp_report"
  chmod 600 "$tmp_report"; mv "$tmp_report" "$report"
  size="$(stat -c %s "$report")"; lines="$(wc -l <"$report")"
  sections_json="$(profile_sections "$PROFILE" | jq -Rsc 'split("\n")|map(select(length>0))')"
  sections_label="$(profile_sections "$PROFILE" | paste -sd '|' - | sed 's/|/ \/\/ /g')"
  jq -nc --arg id "$id" --arg profile "$PROFILE" --arg profile_label "$label" --arg path "$report" --arg sections_label "$sections_label" \
    --argjson generated_at "$(date +%s)" --arg generated_label "$(date '+%Y-%m-%d %H:%M:%S %Z')" \
    --argjson size "$size" --argjson lines "$lines" --argjson sections "$sections_json" \
    '{id:$id,profile:$profile,profile_label:$profile_label,path:$path,generated_at:$generated_at,generated_label:$generated_label,size_bytes:$size,line_count:$lines,sections:$sections,sections_label:$sections_label,privacy:{mode:"0600",uploaded:false,credentials_included:false,unrestricted_logs_included:false}}' >"$tmp_manifest"
  chmod 600 "$tmp_manifest"; mv "$tmp_manifest" "$manifest"; cp "$manifest" "$LATEST_FILE"; chmod 600 "$LATEST_FILE"
  trap - EXIT
  emit_status
}

delete_latest() {
  [[ -r "$LATEST_FILE" ]] || { emit_status; return; }
  report="$(jq -r '.path // empty' "$LATEST_FILE")"; id="$(jq -r '.id // empty' "$LATEST_FILE")"
  [[ "$report" == "$STATE_ROOT"/report-*.txt ]] && rm -f "$report"
  [[ "$id" =~ ^[0-9]{8}-[0-9]{6}-(overview|performance|network|power|full)$ ]] && rm -f "$STATE_ROOT/report-$id.json"
  rm -f "$LATEST_FILE"; emit_status
}

latest_path() {
  [[ -r "$LATEST_FILE" ]] || exit 4
  local path
  path="$(jq -r '.path // empty' "$LATEST_FILE")"
  [[ "$path" == "$STATE_ROOT"/report-*.txt && -r "$path" ]] || exit 4
  printf '%s\n' "$path"
}

open_latest() {
  local path
  path="$(latest_path)"
  command -v kitty >/dev/null 2>&1 || exit 3
  command -v less >/dev/null 2>&1 || exit 3
  nohup kitty --class senomy-report --title "Senomy Evidence Report" less -- "$path" >/dev/null 2>&1 &
}

copy_latest_path() {
  local path
  path="$(latest_path)"
  command -v wl-copy >/dev/null 2>&1 || exit 3
  printf '%s' "$path" | wl-copy
}

case "$ACTION" in
  generate | generate-json) generate ;;
  generate-path) generate >/dev/null; jq -r '.path' "$LATEST_FILE" ;;
  read-json) emit_status ;;
  delete-latest) delete_latest ;;
  open-latest) open_latest ;;
  copy-latest-path) copy_latest_path ;;
  *) printf 'Usage: %s [generate-json|generate-path|read-json|delete-latest|open-latest|copy-latest-path] [profile]\n' "$0" >&2; exit 2 ;;
esac
