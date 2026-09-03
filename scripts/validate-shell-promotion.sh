#!/usr/bin/env bash

# Static and isolated acceptance for Quickshell login ownership. This does not
# start, stop, reload, or enable a live user service.

set -euo pipefail
export LC_ALL=C

readonly REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/senomy-shell-promotion.XXXXXX")"
trap 'rm -rf -- "$TEST_ROOT"' EXIT
readonly TEST_HOME="$TEST_ROOT/home/senomy"
readonly TEST_CONFIG="$TEST_HOME/.config"
readonly TEST_BIN="$TEST_ROOT/bin"
mkdir -p "$TEST_CONFIG" "$TEST_HOME/.local/bin" "$TEST_BIN"

grep -qF '/.local/bin/senomy-shell use quickshell' "$REPO_ROOT/hyprland.lua"
grep -qF '$HOME/.local/bin/senomy-shell use quickshell' "$REPO_ROOT/hyprland.conf"
! grep -F 'start-eww.sh' "$REPO_ROOT/hyprland.lua" "$REPO_ROOT/hyprland.conf" >/dev/null
! grep -F 'restart workspaces.service' "$REPO_ROOT/hyprland.lua" "$REPO_ROOT/hyprland.conf" >/dev/null

grep -qxF 'LOGIN_DEFAULT=quickshell' "$REPO_ROOT/scripts/senomy-shell"
jq -e '
  (.official | any(.package == "quickshell" and .required == true)) and
  (.external | any(.package == "eww" and .required == true and (.reason | test("recovery"; "i"))))
' "$REPO_ROOT/deploy/packages.json" >/dev/null
jq -e '
  .user | any(.unit == "workspaces.service" and .policy == "fallback" and .required == false)
' "$REPO_ROOT/deploy/services.json" >/dev/null

printf '%s\n' '#!/usr/bin/env bash' 'exit 0' >"$TEST_BIN/systemctl"
chmod 755 "$TEST_BIN/systemctl"
HOME="$TEST_HOME" XDG_CONFIG_HOME="$TEST_CONFIG" XDG_BIN_HOME="$TEST_HOME/.local/bin" \
  PATH="$TEST_BIN:/usr/bin" "$REPO_ROOT/scripts/senomy-v2-deploy" apply >/dev/null
jq -e '
  .selected_backend == "quickshell" and .login_default == "quickshell" and
  .reason == "initial-deploy"
' "$TEST_CONFIG/senomyos/shell.json" >/dev/null

printf 'Quickshell login ownership: startup, selector, fallback policy, and initial deployment passed.\n'
