#!/usr/bin/env bash

# Manual SenomyOS shell doctor and kill switch. The restart action validates the
# tree, captures an incident report, terminates only exact config-matched Eww
# daemons, then restores one daemon and one main bar.
set -euo pipefail
export LC_ALL=C
umask 077

readonly ACTION="${1:-doctor}"
readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly CONFIG_DIR="${SENOMY_EWW_CONFIG:-$(cd -- "$SCRIPT_DIR/.." && pwd)}"
readonly EWW_BIN="${EWW_BIN:-/usr/bin/eww}"
readonly TIMEOUT_BIN="${SENOMY_TIMEOUT_BIN:-/usr/bin/timeout}"
readonly INCIDENT_ROOT="${XDG_STATE_HOME:-$HOME/.local/state}/senomyos/recovery/incidents"
readonly RUNTIME_ROOT="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/senomyos"

fail() {
  printf 'SenomyOS shell control: %s\n' "$*" >&2
  exit 1
}

config_eww_pids() {
  local proc pid owner index matched
  local -a arguments=()

  for proc in /proc/[0-9]*; do
    pid="${proc##*/}"
    [[ "$pid" != "$$" ]] || continue
    owner="$(stat -c %u "$proc" 2>/dev/null || true)"
    [[ "$owner" == "$(id -u)" ]] || continue
    arguments=()
    mapfile -d '' -t arguments <"$proc/cmdline" 2>/dev/null || true
    [[ "${arguments[0]:-}" == "$EWW_BIN" ]] || continue
    matched=false
    for ((index = 1; index + 1 < ${#arguments[@]}; index++)); do
      if [[ "${arguments[index]}" == --config && "${arguments[index + 1]}" == "$CONFIG_DIR" ]]; then
        matched=true
      fi
    done
    [[ "$matched" == true ]] && printf '%s\n' "$pid"
  done
}

eww_query() {
  "$TIMEOUT_BIN" --foreground --kill-after=1s 3s \
    "$EWW_BIN" --no-daemonize --config "$CONFIG_DIR" "$@"
}

daemon_reachable() {
  eww_query ping >/dev/null 2>&1
}

active_windows() {
  if daemon_reachable; then
    eww_query active-windows 2>/dev/null || printf 'Eww active-window query failed\n'
  else
    printf 'Eww daemon is unreachable\n'
  fi
}

collect_incident() {
  local reason="$1" stamp report daemon_log
  mkdir -p -m 700 "$INCIDENT_ROOT"
  stamp="$(date +%Y%m%d-%H%M%S)"
  report="$INCIDENT_ROOT/shell-$stamp.txt"
  daemon_log="$RUNTIME_ROOT/eww-daemon.log"
  {
    printf 'SENOMYOS SHELL INCIDENT\n'
    printf 'captured=%s\nreason=%s\nconfig=%s\n\n' "$(date --iso-8601=seconds)" "$reason" "$CONFIG_DIR"
    printf '%s\n' '--- Eww version ---'
    "$EWW_BIN" --version 2>&1 || true
    printf '%s\n' '--- Config-matched daemon PIDs ---'
    config_eww_pids || true
    printf '%s\n' '--- Process snapshot ---'
    ps -eo pid,ppid,etimes,stat,%cpu,%mem,rss,args | grep -E '[e]ww|[w]orkspaces\.sh|bar-(audio|network)-listener' || true
    printf '%s\n' '--- Active windows ---'
    active_windows
    printf '%s\n' '--- Surface state ---'
    for variable in active_surface active_flyout control_section insights_section performance_section dismiss_armed; do
      printf '%s=' "$variable"
      eww_query get "$variable" 2>/dev/null || printf 'unavailable\n'
    done
    printf '%s\n' '--- Hyprland version and config errors ---'
    hyprctl version 2>&1 || true
    hyprctl configerrors 2>&1 || true
    printf '%s\n' '--- Workspace service ---'
    systemctl --user --no-pager --full status workspaces.service 2>&1 || true
    printf '%s\n' '--- Recent workspace journal ---'
    journalctl --user -u workspaces.service -n 40 --no-pager 2>&1 || true
    printf '%s\n' '--- Detached Eww daemon log ---'
    [[ -r "$daemon_log" ]] && tail -n 120 "$daemon_log" || printf 'No detached daemon log is available.\n'
  } >"$report"
  chmod 600 "$report"
  printf '%s\n' "$report"
}

preflight() {
  local compiled
  command -v sassc >/dev/null 2>&1 || fail "sassc is required"
  command -v jq >/dev/null 2>&1 || fail "jq is required"
  compiled="$(mktemp "${TMPDIR:-/tmp}/senomy-shellctl.XXXXXX.css")"
  trap 'rm -f "${compiled:-}"' RETURN
  sassc -t compressed "$CONFIG_DIR/eww.scss" "$compiled" ||
    fail "SCSS validation failed; the running shell was left untouched"
  for script in "$CONFIG_DIR"/scripts/*.sh; do
    bash -n "$script" || fail "Bash validation failed: $script"
  done
  for json in "$CONFIG_DIR"/data/*.json; do
    jq -e . "$json" >/dev/null || fail "JSON validation failed: $json"
  done
  "$CONFIG_DIR/scripts/senomy-avatar.sh" catalog | jq -e '.ok == true' >/dev/null ||
    fail "avatar catalog validation failed"
  "$CONFIG_DIR/scripts/validate-eww-config.sh" >/dev/null ||
    fail "isolated Eww/Yuck validation failed"
  rm -f "$compiled"
  trap - RETURN
  printf 'Preflight passed: shell, SCSS, JSON, avatar and isolated Eww contracts are readable.\n'
}

doctor() {
  local pids windows count bar_count=0 status="HEALTHY"
  pids="$(config_eww_pids || true)"
  count="$(sed '/^$/d' <<<"$pids" | wc -l)"
  windows="$(active_windows)"
  if daemon_reachable; then
    bar_count="$(grep -cE '^[^:]+: main-bar$' <<<"$windows" || true)"
  fi
  ((count == 1)) || status="DEGRADED"
  ((bar_count == 1)) || status="DEGRADED"
  printf 'SENOMYOS SHELL DOCTOR // %s\n' "$status"
  printf 'config: %s\n' "$CONFIG_DIR"
  printf 'daemon reachable: %s\n' "$(daemon_reachable && printf yes || printf no)"
  printf 'config-matched Eww processes: %s\n' "$count"
  printf 'active main bars: %s\n' "$bar_count"
  printf '%s\n' 'active windows:' "$windows"
  printf 'workspace service: %s\n' "$(systemctl --user is-active workspaces.service 2>/dev/null || printf unavailable)"
  printf 'hyprland config errors: '
  errors="$(hyprctl configerrors 2>/dev/null || printf unavailable)"
  [[ -n "$errors" ]] && printf '%s\n' "$errors" || printf 'none\n'
  [[ "$status" == HEALTHY ]]
}

stop_exact_daemons() {
  local pids pid attempt
  eww_query close-all >/dev/null 2>&1 || true
  eww_query kill >/dev/null 2>&1 || true
  pids="$(config_eww_pids || true)"
  for pid in $pids; do kill -TERM "$pid" 2>/dev/null || true; done

  for attempt in {1..30}; do
    pids="$(config_eww_pids || true)"
    [[ -z "$pids" ]] && ! daemon_reachable && return 0
    sleep 0.10
  done

  pids="$(config_eww_pids || true)"
  if [[ -n "$pids" ]]; then
    printf 'Graceful stop timed out; force-stopping exact Eww daemon PID(s): %s\n' "$(tr '\n' ' ' <<<"$pids")" >&2
    for pid in $pids; do kill -KILL "$pid" 2>/dev/null || true; done
  fi
  for attempt in {1..20}; do
    [[ -z "$(config_eww_pids || true)" ]] && ! daemon_reachable && return 0
    sleep 0.10
  done
  return 1
}

restart_shell() {
  local incident pids windows count bar_count
  preflight
  incident="$(collect_incident manual-restart)"
  printf 'Incident evidence saved: %s\n' "$incident"
  stop_exact_daemons || fail "unable to stop every exact config-matched Eww daemon"
  "$CONFIG_DIR/scripts/start-eww.sh" || fail "Eww restart did not restore the main bar"

  systemctl --user import-environment XDG_RUNTIME_DIR HYPRLAND_INSTANCE_SIGNATURE WAYLAND_DISPLAY DISPLAY >/dev/null 2>&1 || true
  systemctl --user restart workspaces.service >/dev/null 2>&1 ||
    "$CONFIG_DIR/scripts/workspaces.sh" --publish-once >/dev/null 2>&1 || true

  pids="$(config_eww_pids || true)"
  count="$(sed '/^$/d' <<<"$pids" | wc -l)"
  windows="$(eww_query active-windows 2>/dev/null || true)"
  bar_count="$(grep -cE '^[^:]+: main-bar$' <<<"$windows" || true)"
  ((count == 1 && bar_count == 1)) ||
    fail "restart finished without the one-daemon/one-bar invariant"
  printf 'SenomyOS shell restored: one daemon, one main bar, workspace listener restarted.\n'
}

case "$ACTION" in
  doctor | status) doctor ;;
  preflight) preflight ;;
  incident) collect_incident manual-diagnostic ;;
  restart | reset) restart_shell ;;
  *)
    printf 'Usage: %s [doctor|preflight|incident|restart]\n' "$0" >&2
    exit 2
    ;;
esac
