#!/usr/bin/env bash

set -u
export LC_ALL=C
selection_state="${XDG_RUNTIME_DIR:-/tmp}/senomyos/performance-process-selection"
pid="${1:-}"
if [[ -z "$pid" && -r "$selection_state" ]]; then
  read -r pid < "$selection_state"
fi
pid="${pid:-0}"
printf -v observed_at '%(%s)T' -1

emit_error() { jq -nc --argjson at "$observed_at" --arg code "$1" --arg message "$2" '{schema_version:1,ok:false,source:"procfs",observed_at:$at,data:null,error:{code:$code,message:$message}}'; exit 0; }
command -v jq >/dev/null 2>&1 || exit 1
[[ "$pid" =~ ^[1-9][0-9]*$ ]] || emit_error "no_selection" "Select a process to inspect"
[[ -d "/proc/$pid" ]] || emit_error "process_exited" "The selected process no longer exists"

status="$(<"/proc/$pid/status")" || emit_error "unavailable" "Unable to read process status"
cmdline="$(tr '\0' ' ' <"/proc/$pid/cmdline" 2>/dev/null || true)"
exe="$(readlink -f "/proc/$pid/exe" 2>/dev/null || true)"
cwd="$(readlink -f "/proc/$pid/cwd" 2>/dev/null || true)"
field() { awk -F: -v key="$1" '$1==key{sub(/^[[:space:]]+/,"",$2);print $2;exit}' <<<"$status"; }
name="$(field Name)"; state="$(field State)"; uid="$(field Uid | awk '{print $1}')"; threads="$(field Threads)"
vmrss="$(field VmRSS | awk '{print $1}')"; vmsize="$(field VmSize | awk '{print $1}')"; voluntary="$(field voluntary_ctxt_switches)"; involuntary="$(field nonvoluntary_ctxt_switches)"
user="$(getent passwd "$uid" | cut -d: -f1)"; [[ -n "$user" ]] || user="$uid"
fd_count="$(find "/proc/$pid/fd" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l)"
action_allowed=false
[[ "$uid" == "$(id -u)" && "$pid" != "$$" && "$pid" != "$PPID" ]] && action_allowed=true

jq -nc --argjson at "$observed_at" --argjson pid "$pid" --argjson action_allowed "$action_allowed" --arg name "$name" --arg state "$state" --arg user "$user" --arg cmdline "$cmdline" --arg exe "$exe" --arg cwd "$cwd" --arg threads "${threads:-0}" --arg rss "${vmrss:-0}" --arg virtual "${vmsize:-0}" --arg fds "$fd_count" --arg voluntary "${voluntary:-0}" --arg involuntary "${involuntary:-0}" '
 {schema_version:1,ok:true,source:"procfs",observed_at:$at,data:{pid:$pid,name:$name,state:$state,user:$user,action_allowed:$action_allowed,command:($cmdline|if length>0 then . else "Unavailable" end),executable:($exe|if length>0 then . else "Unavailable" end),cwd:($cwd|if length>0 then . else "Unavailable" end),threads:($threads|tonumber?),rss_mib:(($rss|tonumber? // 0)/1024*10|round/10),virtual_mib:(($virtual|tonumber? // 0)/1024*10|round/10),fd_count:($fds|tonumber?),context_switches:{voluntary:($voluntary|tonumber? // 0),involuntary:($involuntary|tonumber? // 0)}},error:null}'
