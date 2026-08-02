#!/usr/bin/env bash

# Senomy Console cockpit. In-panel tasks are fixed and bounded; unrestricted
# shells are launched only inside a real terminal emulator with a PTY.
set -u
export LC_ALL=C

readonly ACTION="${1:-read}"
readonly VALUE="${2:-none}"
readonly HOME_DIR="${HOME:-/nonexistent}"
readonly CONFIG_DIR="${EWW_CONFIG:-${XDG_CONFIG_HOME:-$HOME_DIR/.config}/eww}"
readonly CACHE_FILE="${SENOMY_CONSOLE_CACHE:-${XDG_CACHE_HOME:-$HOME_DIR/.cache}/senomyos/console.json}"
readonly CACHE_DIR="$(dirname "$CACHE_FILE")"
readonly LOCK_FILE="$CACHE_FILE.lock"
readonly TIMEOUT_SECONDS="${SENOMY_CONSOLE_TIMEOUT:-8}"
readonly LINE_LIMIT="${SENOMY_CONSOLE_LINE_LIMIT:-80}"
readonly EWW_BIN="${SENOMY_EWW_BIN:-/usr/bin/eww}"
readonly HYPRCTL_BIN="${SENOMY_HYPRCTL_BIN:-/usr/bin/hyprctl}"
LAUNCHED_PID=0

now() { date +%s; }
available() { command -v "$1" >/dev/null 2>&1 && printf true || printf false; }
path_of() { command -v "$1" 2>/dev/null || true; }

catalog() {
  jq -nc --argjson at "$(now)" \
    --arg bash_path "$(path_of bash)" --arg zsh_path "$(path_of zsh)" \
    --arg fish_path "$(path_of fish)" --arg pwsh_path "$(path_of pwsh)" \
    --arg kitty_path "$(path_of kitty)" --arg tmux_path "$(path_of tmux)" \
    --argjson bash_available "$(available bash)" --argjson zsh_available "$(available zsh)" \
    --argjson fish_available "$(available fish)" --argjson pwsh_available "$(available pwsh)" \
    --argjson kitty_available "$(available kitty)" --argjson tmux_available "$(available tmux)" '
    {schema_version:1,ok:true,source:"senomy-console-catalog",observed_at:$at,
      data:{terminal:{id:"kitty",available:$kitty_available,path:$kitty_path,pty:true},
        multiplexer:{id:"tmux",available:$tmux_available,path:$tmux_path},
        shells:[
          {id:"bash",name:"Bash",code:"BASH",available:$bash_available,path:$bash_path,installed_by_default:true,summary:"Arch default-compatible Bourne shell."},
          {id:"zsh",name:"Zsh",code:"ZSH",available:$zsh_available,path:$zsh_path,installed_by_default:false,summary:"Interactive shell with advanced completion and customization."},
          {id:"fish",name:"Fish",code:"FISH",available:$fish_available,path:$fish_path,installed_by_default:false,summary:"Interactive shell with autosuggestions and syntax highlighting."},
          {id:"pwsh",name:"PowerShell",code:"PWSH",available:$pwsh_available,path:$pwsh_path,installed_by_default:false,summary:"Cross-platform object-oriented PowerShell 7 session."}],
        tasks:[
          {id:"identity",code:"WHO",title:"Session identity",summary:"User, groups, shell and working directory.",preview:"id; groups; printenv SHELL; pwd"},
          {id:"platform",code:"OS",title:"Platform fingerprint",summary:"Kernel, architecture and release metadata.",preview:"uname -a; /etc/os-release"},
          {id:"resources",code:"RES",title:"Resource snapshot",summary:"Load, memory, filesystems and pressure counters.",preview:"uptime; free -h; df; /proc/pressure/*"},
          {id:"network",code:"NET",title:"Network path",summary:"Interfaces, addresses, routes and NetworkManager state.",preview:"ip -brief; ip route; nmcli general"},
          {id:"services",code:"SVC",title:"User services",summary:"Failed user units and Senomy service state.",preview:"systemctl --user --failed; status workspaces"},
          {id:"hardware",code:"HW",title:"Hardware topology",summary:"PCI, USB and block-device inventory.",preview:"lspci -k; lsusb; lsblk"},
          {id:"bluetooth",code:"BT",title:"Bluetooth evidence",summary:"BlueZ controller and known device state.",preview:"bluetoothctl show; bluetoothctl devices"},
          {id:"warnings",code:"LOG",title:"Recent warnings",summary:"Bounded warning-level user journal.",preview:"journalctl --user -p warning -n 40"},
          {id:"packages",code:"PKG",title:"Package state",summary:"Explicit packages and foreign-package inventory.",preview:"pacman -Qe; pacman -Qm"},
          {id:"eww-state",code:"EWW",title:"Eww state",summary:"Active windows and public Eww variables.",preview:"eww active-windows; surface-state status"}]},error:null}'
}

empty_status() {
  jq -nc --argjson at "$(now)" '{schema_version:1,ok:true,source:"senomy-console",observed_at:$at,
    data:{state:"idle",state_label:"READY",task_id:"none",code:"RUN",title:"Console standing by",summary:"Choose a bounded command or launch a real shell.",command_preview:"select <task>",started_at:0,finished_at:0,duration_ms:0,exit_code:null,line_count:0,truncated:false,output:[]},error:null}'
}

write_running_status() {
  local id="$1" tmp
  mkdir -p -m 700 "$CACHE_DIR" || exit 1
  tmp="$(mktemp "$CACHE_DIR/.console.XXXXXX")" || exit 1
  jq -nc --argjson at "$(now)" --arg id "$id" '{schema_version:1,ok:true,source:"senomy-console",observed_at:$at,
    data:{state:"running",state_label:"RUNNING",task_id:$id,code:"RUN",title:"Command in progress",summary:"The bounded task is executing.",command_preview:$id,started_at:$at,finished_at:0,duration_ms:0,exit_code:null,line_count:0,truncated:false,output:[]},error:null}' >"$tmp"
  chmod 600 "$tmp"; mv "$tmp" "$CACHE_FILE"
  publish_status
}

run_async() {
  case "$1" in identity | platform | resources | network | services | hardware | bluetooth | warnings | packages | eww-state) ;; *) exit 2 ;; esac
  write_running_status "$1"
  nohup "$0" run "$1" >/dev/null 2>&1 &
}

read_status() { [[ -r "$CACHE_FILE" ]] && cat "$CACHE_FILE" || empty_status; }

publish_status() {
  [[ -x "$EWW_BIN" ]] || return 0
  local payload
  payload="$(read_status)"
  "$EWW_BIN" --config "$CONFIG_DIR" update "console_status=$payload" >/dev/null 2>&1 || true
}

sanitize_output() {
  jq -Rsc --arg home "$HOME_DIR" --argjson limit "$LINE_LIMIT" '
    split("\n") | map(select(length > 0)) | map(
      gsub($home; "$HOME") | gsub("[[:cntrl:]]"; " ") |
      if test("(?i)(password|passwd|secret|token|authorization|cookie)") then "[redacted potentially sensitive line]" else .[0:260] end
    ) as $all | {line_count:($all|length),truncated:(($all|length)>$limit),lines:($all[0:$limit] | to_entries | map({line_no:(.key+1),text:.value}))}'
}

run_task() {
  local id="$1" code title summary preview started finished exit_code output parsed tmp
  case "$id" in
    identity) code=WHO; title="Session identity"; summary="Identity and shell context."; preview="id + groups + shell + pwd" ;;
    platform) code=OS; title="Platform fingerprint"; summary="Kernel and release metadata."; preview="uname + os-release" ;;
    resources) code=RES; title="Resource snapshot"; summary="Current resource and pressure evidence."; preview="uptime + free + df + PSI" ;;
    network) code=NET; title="Network path"; summary="Current interface, route and NetworkManager evidence."; preview="ip + nmcli" ;;
    services) code=SVC; title="User services"; summary="Failed units and workspace publisher state."; preview="systemctl --user" ;;
    hardware) code=HW; title="Hardware topology"; summary="PCI, USB and block-device inventory."; preview="lspci + lsusb + lsblk" ;;
    bluetooth) code=BT; title="Bluetooth evidence"; summary="BlueZ controller and known-device evidence."; preview="bluetoothctl show + devices" ;;
    warnings) code=LOG; title="Recent warnings"; summary="Bounded warning-level user journal."; preview="journalctl --user warning" ;;
    packages) code=PKG; title="Package state"; summary="Explicit and foreign package inventory."; preview="pacman -Qe + pacman -Qm" ;;
    eww-state) code=EWW; title="Eww state"; summary="Current Senomy/Eww surface state."; preview="eww + surface-state" ;;
    *) exit 2 ;;
  esac

  mkdir -p -m 700 "$CACHE_DIR" || exit 1
  exec 9>"$LOCK_FILE"; flock -w 1 9 || exit 1
  tmp="$(mktemp "$CACHE_DIR/.console.XXXXXX")" || exit 1
  started="$(now)"
  set +e
  case "$id" in
    identity) output="$(timeout "$TIMEOUT_SECONDS" bash -c 'id; groups; printf "SHELL=%s\n" "${SHELL:-unknown}"; pwd' 2>&1)"; exit_code=$? ;;
    platform) output="$(timeout "$TIMEOUT_SECONDS" bash -c 'uname -a; printf "\n"; sed -n "1,20p" /etc/os-release' 2>&1)"; exit_code=$? ;;
    resources) output="$(timeout "$TIMEOUT_SECONDS" bash -c 'uptime; free -h; df -hT / "$HOME"; for f in /proc/pressure/cpu /proc/pressure/memory /proc/pressure/io; do printf "\n[%s]\n" "$f"; cat "$f"; done' 2>&1)"; exit_code=$? ;;
    network) output="$(timeout "$TIMEOUT_SECONDS" bash -c 'ip -brief address; printf "\nROUTES\n"; ip route; if command -v nmcli >/dev/null; then printf "\nNETWORKMANAGER\n"; nmcli general; fi' 2>&1)"; exit_code=$? ;;
    services) output="$(timeout "$TIMEOUT_SECONDS" bash -c 'systemctl --user --failed --no-pager --plain; printf "\nWORKSPACES\n"; systemctl --user status workspaces.service --no-pager --lines=12' 2>&1)"; exit_code=$? ;;
    hardware) output="$(timeout "$TIMEOUT_SECONDS" bash -c 'command -v lspci >/dev/null && lspci -k; printf "\nUSB\n"; command -v lsusb >/dev/null && lsusb; printf "\nBLOCK\n"; lsblk -e 7 -o NAME,TYPE,SIZE,FSTYPE,MOUNTPOINTS,MODEL' 2>&1)"; exit_code=$? ;;
    bluetooth) output="$(timeout "$TIMEOUT_SECONDS" bash -c 'if command -v bluetoothctl >/dev/null; then bluetoothctl show; printf "\nKNOWN DEVICES\n"; bluetoothctl devices; else printf "bluetoothctl unavailable\n"; exit 3; fi' 2>&1)"; exit_code=$? ;;
    warnings) output="$(timeout "$TIMEOUT_SECONDS" journalctl --user -p warning -n 40 --no-pager --output=short-iso 2>&1)"; exit_code=$? ;;
    packages) output="$(timeout "$TIMEOUT_SECONDS" bash -c 'printf "EXPLICIT PACKAGES\n"; pacman -Qe; printf "\nFOREIGN PACKAGES\n"; pacman -Qm' 2>&1)"; exit_code=$? ;;
    eww-state) output="$(timeout "$TIMEOUT_SECONDS" "$CONFIG_DIR/scripts/surface-state.sh" status 2>&1)"; exit_code=$? ;;
  esac
  set -e
  finished="$(now)"; parsed="$(printf '%s' "$output" | sanitize_output)"
  jq -nc --argjson at "$finished" --arg id "$id" --arg code "$code" --arg title "$title" --arg summary "$summary" --arg preview "$preview" \
    --argjson started "$started" --argjson finished "$finished" --argjson exit_code "$exit_code" --argjson parsed "$parsed" '
    {schema_version:1,ok:($exit_code==0),source:"senomy-console",observed_at:$at,
      data:{state:(if $exit_code==0 then "ready" else "failed" end),state_label:(if $exit_code==0 then "COMPLETE" else "FAILED" end),task_id:$id,code:$code,title:$title,summary:$summary,command_preview:$preview,started_at:$started,finished_at:$finished,duration_ms:(($finished-$started)*1000),exit_code:$exit_code,line_count:$parsed.line_count,truncated:$parsed.truncated,output:$parsed.lines},
      error:(if $exit_code==0 then null else {code:"task_failed",message:"The bounded command returned a non-zero status."} end)}' >"$tmp"
  chmod 600 "$tmp"; mv "$tmp" "$CACHE_FILE"
  publish_status
}

launch_shell() {
  local shell_id="$1" shell_bin title
  command -v kitty >/dev/null 2>&1 || exit 3
  case "$shell_id" in
    bash) shell_bin="$(command -v bash)"; title="Senomy Console // Bash" ;;
    zsh) shell_bin="$(command -v zsh 2>/dev/null)"; title="Senomy Console // Zsh" ;;
    fish) shell_bin="$(command -v fish 2>/dev/null)"; title="Senomy Console // Fish" ;;
    pwsh) shell_bin="$(command -v pwsh 2>/dev/null)"; title="Senomy Console // PowerShell" ;;
    *) exit 2 ;;
  esac
  [[ -n "$shell_bin" ]] || exit 4
  "$CONFIG_DIR/scripts/senomy-event.sh" record console launch "$shell_id" requested >/dev/null 2>&1 || true
  case "$shell_id" in
    bash | zsh | fish) nohup kitty --class senomy-console --title "$title" --directory "$HOME_DIR" "$shell_bin" -l >/dev/null 2>&1 & LAUNCHED_PID=$! ;;
    pwsh) nohup kitty --class senomy-console --title "$title" --directory "$HOME_DIR" "$shell_bin" -Login >/dev/null 2>&1 & LAUNCHED_PID=$! ;;
  esac
}

launch_from_ui() {
  local shell_id="$1" current_surface="${2:-insights}" current_flyout="${3:-none}"
  launch_shell "$shell_id" || exit $?
  if [[ -x "$HYPRCTL_BIN" ]] && command -v jq >/dev/null 2>&1; then
    for _ in {1..30}; do
      "$HYPRCTL_BIN" -j clients 2>/dev/null | jq -e --argjson pid "$LAUNCHED_PID" 'any(.[]?; .pid == $pid and .mapped == true)' >/dev/null 2>&1 && break
      sleep 0.1
    done
  fi
  "$CONFIG_DIR/scripts/surface-state.sh" close insights "$current_surface" "$current_flyout"
}

case "$ACTION" in
  catalog) catalog ;;
  read) read_status ;;
  run) run_task "$VALUE" ;;
  run-async) run_async "$VALUE" ;;
  launch) launch_shell "$VALUE" ;;
  launch-ui) launch_from_ui "$VALUE" "${3:-insights}" "${4:-none}" ;;
  clear) rm -f "$CACHE_FILE"; publish_status ;;
  *) exit 2 ;;
esac
