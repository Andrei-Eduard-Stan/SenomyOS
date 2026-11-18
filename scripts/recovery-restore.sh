#!/usr/bin/env bash

# Inspect or stage the last-known-good shell without modifying live config.
set -euo pipefail
export LC_ALL=C

readonly STATE_ROOT="${SENOMY_RECOVERY_ROOT:-${XDG_STATE_HOME:-$HOME/.local/state}/senomyos/recovery}"
readonly ARCHIVE="$STATE_ROOT/senomyos-shell.tar.gz"
readonly CHECKSUM="$STATE_ROOT/senomyos-shell.sha256"
readonly ACTION="${1:---verify}"

fail() {
  printf 'recovery-restore: %s\n' "$*" >&2
  exit 1
}

verify_archive() {
  [[ -r "$ARCHIVE" ]] || fail "recovery archive is unavailable"
  [[ -r "$CHECKSUM" ]] || fail "recovery checksum is unavailable"
  (cd "$STATE_ROOT" && sha256sum -c "$(basename "$CHECKSUM")" >/dev/null) ||
    fail "recovery checksum does not match"
  tar -tzf "$ARCHIVE" >/dev/null || fail "recovery archive is unreadable"
}

case "$ACTION" in
  --verify)
    [[ $# -eq 1 ]] || fail "--verify accepts no additional arguments"
    verify_archive
    printf 'Recovery archive verified: %s\n' "$ARCHIVE"
    ;;
  --list)
    [[ $# -eq 1 ]] || fail "--list accepts no additional arguments"
    verify_archive
    tar -tzf "$ARCHIVE"
    ;;
  --extract-to)
    [[ $# -eq 2 ]] || fail "--extract-to requires one destination"
    destination="$2"
    [[ "$destination" = /* ]] || fail "destination must be an absolute path"
    [[ ! -e "$destination" ]] || fail "destination already exists"
    verify_archive
    install -d -m 700 "$destination"
    tar -xzf "$ARCHIVE" -C "$destination" --no-same-owner --no-same-permissions
    printf 'Recovery archive staged at: %s\n' "$destination"
    ;;
  *)
    fail "usage: recovery-restore.sh [--verify|--list|--extract-to ABSOLUTE_PATH]"
    ;;
esac
