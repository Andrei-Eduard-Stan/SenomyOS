#!/usr/bin/env bash

# Execute validated actions from the SenomyOS workspace strip.

set -euo pipefail

readonly HYPRCTL_BIN="${SENOMY_HYPRCTL_BIN:-/usr/bin/hyprctl}"
readonly JQ_BIN="${SENOMY_JQ_BIN:-/usr/bin/jq}"

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

[[ -x "$HYPRCTL_BIN" ]] ||
  fail "hyprctl is unavailable"
[[ -x "$JQ_BIN" ]] ||
  fail "jq is unavailable"

lua_dispatch=false
if "$HYPRCTL_BIN" binds -j 2>/dev/null |
  "$JQ_BIN" -e 'any(.[]; .dispatcher == "__lua")' >/dev/null; then
  lua_dispatch=true
fi

visible_special="$(
  "$HYPRCTL_BIN" monitors -j 2>/dev/null |
    "$JQ_BIN" -r '
      [
        .[]
        | select(.focused == true)
        | .specialWorkspace.name
        | select(type == "string" and startswith("special:"))
      ][0] // ""
    ' 2>/dev/null
)" || visible_special=""

special_name="${visible_special#special:}"
if [[ -n "$visible_special" &&
      ! "$special_name" =~ ^[A-Za-z0-9._-]+$ ]]; then
  fail "Visible special workspace name is unsafe"
fi

case "$action" in
  switch)
    # A visible special workspace is an overlay. Close it first so a Rail
    # workspace click changes what the user actually sees, not only the
    # regular workspace underneath the scratchpad.
    if [[ -n "$visible_special" ]]; then
      if [[ "$lua_dispatch" == true ]]; then
        "$HYPRCTL_BIN" dispatch \
          "hl.dsp.workspace.toggle_special(\"$special_name\")" >/dev/null ||
          fail "Unable to close the visible special workspace"
      else
        "$HYPRCTL_BIN" dispatch togglespecialworkspace "$special_name" >/dev/null ||
          fail "Unable to close the visible special workspace"
      fi
    fi

    if [[ "$lua_dispatch" == true ]]; then
      exec "$HYPRCTL_BIN" dispatch "hl.dsp.focus({workspace=$workspace_id})"
    fi
    exec "$HYPRCTL_BIN" dispatch workspace "$workspace_id"
    ;;
  *)
    usage
    ;;
esac
