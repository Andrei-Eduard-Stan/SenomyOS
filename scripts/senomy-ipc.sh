#!/usr/bin/env bash
# Shared CLI transport. The production service owns the target, not pgrep or
# whichever preview of the same configuration was launched first.

senomy_ipc_init() {
  SENOMY_IPC_SYSTEMCTL="${SENOMY_SYSTEMCTL_BIN:-/usr/bin/systemctl}"
  SENOMY_IPC_QS="${SENOMY_QS_BIN:-/usr/bin/qs}"
  SENOMY_IPC_PID="$(timeout 2s "$SENOMY_IPC_SYSTEMCTL" --user show senomy-quickshell.service --property=MainPID --value 2>/dev/null)" || {
    printf 'SenomyOS: production service ownership is unavailable. No preview was targeted.\n' >&2; return 1;
  }
  [[ "$SENOMY_IPC_PID" =~ ^[1-9][0-9]*$ ]] || {
    printf 'SenomyOS: production shell is not running. Inspect senomy-shell status/logs.\n' >&2; return 1;
  }
}

senomy_ipc_call() {
  local current_pid
  current_pid="$(timeout 2s "$SENOMY_IPC_SYSTEMCTL" --user show senomy-quickshell.service --property=MainPID --value 2>/dev/null)" || return 1
  [[ "$current_pid" == "$SENOMY_IPC_PID" ]] || {
    printf 'SenomyOS: service ownership changed; request was not sent.\n' >&2; return 1;
  }
  # Qt can emit a C-locale startup warning into stdout before the IPC reply.
  # Protocol clients require deterministic UTF-8 replies, independent of their terminal.
  LC_ALL=C.UTF-8 LANG=C.UTF-8 timeout 3s "$SENOMY_IPC_QS" ipc --pid "$SENOMY_IPC_PID" call shell "$@"
}
