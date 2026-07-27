#!/usr/bin/env bash

# Execute validated actions from the SenomyOS workspace strip.

set -u

readonly HYPRCTL_BIN="/usr/bin/hyprctl"

fail() {
  printf 'SenomyOS workspace action: %s\n' "$1" >&2
  exit 1
}

usage() {
  printf 'Usage: %s switch WORKSPACE_ID\n' "$0" >&2
  exit 2
}

[[ $# -eq 2 ]] || usage

action="$1"
workspace_id="$2"

[[ "$workspace_id" =~ ^[1-9][0-9]*$ ]] ||
  fail "Workspace ID must be a positive integer"

((workspace_id <= 99)) ||
  fail "Workspace ID is outside the supported range"

[[ -x "$HYPRCTL_BIN" ]] ||
  fail "hyprctl is unavailable"

case "$action" in
  switch)
    exec "$HYPRCTL_BIN" dispatch workspace "$workspace_id"
    ;;
  *)
    usage
    ;;
esac