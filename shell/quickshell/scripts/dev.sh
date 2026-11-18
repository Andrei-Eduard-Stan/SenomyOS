#!/usr/bin/env bash

set -euo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SHELL_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
readonly ENTRYPOINT="$SHELL_DIR/shell.qml"

resolve_quickshell() {
  if command -v qs >/dev/null 2>&1; then
    command -v qs
  elif command -v quickshell >/dev/null 2>&1; then
    command -v quickshell
  else
    printf 'SenomyOS V2: Quickshell is not installed. Install the Arch quickshell package first.\n' >&2
    return 1
  fi
}

readonly QUICKSHELL_BIN="$(resolve_quickshell)"
readonly ACTION="${1:-run}"

case "$ACTION" in
  run)
    exec "$QUICKSHELL_BIN" -p "$ENTRYPOINT"
    ;;
  kill | log)
    exec "$QUICKSHELL_BIN" -p "$ENTRYPOINT" "$ACTION"
    ;;
  *)
    printf 'Usage: %s [run|kill|log]\n' "$0" >&2
    exit 2
    ;;
esac
