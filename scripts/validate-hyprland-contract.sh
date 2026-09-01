#!/usr/bin/env bash

# Validate the legacy-to-Lua migration and both workspace dispatch paths
# without changing the running compositor or a real workspace.

set -euo pipefail
export LC_ALL=C

readonly REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly DESKTOP_CONFIG="$REPO_ROOT/hyprland.lua"
readonly RECOVERY_CONFIG="$REPO_ROOT/components/recovery/recovery-hyprland.lua"
[[ ! -e "$REPO_ROOT/components/recovery/recovery-hyprland.conf" ]]
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/senomy-hyprland-contract.XXXXXX")"
trap 'rm -rf -- "$TEST_ROOT"' EXIT

Hyprland --verify-config --config "$DESKTOP_CONFIG" 2>&1 | grep -qF 'config ok'
Hyprland --verify-config --config "$RECOVERY_CONFIG" 2>&1 | grep -qF 'config ok'

grep -qF 'source": "hyprland.lua"' "$REPO_ROOT/deploy/manifest.json"
grep -qF 'path": "hypr/hyprland.lua"' "$REPO_ROOT/deploy/manifest.json"
grep -qF 'readonly HYPRLAND_CONFIG="/etc/senomyos/recovery-hyprland.lua"' \
  "$REPO_ROOT/components/recovery/senomy-recovery-session"
grep -qF 'hl.bind(mainMod .. " + L"' "$DESKTOP_CONFIG"
grep -qF 'hl.bind(mainMod .. " + R"' "$DESKTOP_CONFIG"
grep -qF 'hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))' "$DESKTOP_CONFIG"
grep -qF 'hl.bind(mainMod .. " + F", hl.dsp.exec_cmd("/usr/bin/env sh -c '\''$HOME/.local/bin/senomy-fullscreen'\''"))' "$DESKTOP_CONFIG"
grep -qF 'hl.bind(mainMod .. " + SHIFT + F", hl.dsp.exec_cmd("/usr/bin/env sh -c '\''$HOME/.local/bin/senomy-fullscreen immersive'\''"))' "$DESKTOP_CONFIG"
grep -qF 'source": "components/desktop/scripts/senomy-fullscreen"' "$REPO_ROOT/deploy/manifest.json"
grep -qF 'SENOMY_NESTED_QA' "$DESKTOP_CONFIG"
grep -qF 'home .. "/.local/bin/senomy-wallpaper"' "$DESKTOP_CONFIG"
grep -qF 'scale = selected_display_scale()' "$DESKTOP_CONFIG"
grep -qF 'kb_layout = "gb,us"' "$DESKTOP_CONFIG"
grep -qF 'hyprctl switchxkblayout all next' "$DESKTOP_CONFIG"
! grep -Eq '/home/[^/]+|output[[:space:]]*=[[:space:]]*"eDP-' "$DESKTOP_CONFIG"
! grep -Eqi 'hyprpaper|swww|/Downloads/' "$DESKTOP_CONFIG"
! grep -qF 'hl.bind' "$RECOVERY_CONFIG"

printf '%s\n' \
  '#!/usr/bin/env bash' \
  'set -euo pipefail' \
  'if [[ "$1" == binds && "$2" == -j ]]; then' \
  '  if [[ "${SENOMY_TEST_CONFIG_STYLE:-legacy}" == lua ]]; then' \
  '    printf '\''[{"dispatcher":"__lua"}]\n'\''' \
  '  else' \
  '    printf '\''[{"dispatcher":"workspace"}]\n'\''' \
  '  fi' \
  '  exit 0' \
  'fi' \
  'if [[ "$1" == monitors && "$2" == -j ]]; then' \
  '  if [[ "${SENOMY_TEST_SPECIAL_VISIBLE:-false}" == true ]]; then' \
  '    printf '\''[{"focused":true,"specialWorkspace":{"id":-98,"name":"special:magic"}}]\n'\''' \
  '  else' \
  '    printf '\''[{"focused":true,"specialWorkspace":{"id":0,"name":""}}]\n'\''' \
  '  fi' \
  '  exit 0' \
  'fi' \
  'printf '\''%s\n'\'' "$*" >>"$SENOMY_TEST_DISPATCH_LOG"' \
  >"$TEST_ROOT/hyprctl"
chmod 755 "$TEST_ROOT/hyprctl"

SENOMY_TEST_CONFIG_STYLE=legacy \
SENOMY_TEST_DISPATCH_LOG="$TEST_ROOT/legacy.log" \
SENOMY_HYPRCTL_BIN="$TEST_ROOT/hyprctl" \
  "$REPO_ROOT/scripts/workspace-action.sh" switch 7
grep -qxF 'dispatch workspace 7' "$TEST_ROOT/legacy.log"

SENOMY_TEST_CONFIG_STYLE=lua \
SENOMY_TEST_DISPATCH_LOG="$TEST_ROOT/lua.log" \
SENOMY_HYPRCTL_BIN="$TEST_ROOT/hyprctl" \
  "$REPO_ROOT/scripts/workspace-action.sh" switch 7
grep -qxF 'dispatch hl.dsp.focus({workspace=7})' "$TEST_ROOT/lua.log"

SENOMY_TEST_CONFIG_STYLE=lua \
SENOMY_TEST_SPECIAL_VISIBLE=true \
SENOMY_TEST_DISPATCH_LOG="$TEST_ROOT/lua-special.log" \
SENOMY_HYPRCTL_BIN="$TEST_ROOT/hyprctl" \
  "$REPO_ROOT/scripts/workspace-action.sh" switch 7
diff -u <(printf '%s\n' \
  'dispatch hl.dsp.workspace.toggle_special("magic")' \
  'dispatch hl.dsp.focus({workspace=7})') \
  "$TEST_ROOT/lua-special.log"

if SENOMY_TEST_CONFIG_STYLE=lua \
  SENOMY_TEST_DISPATCH_LOG="$TEST_ROOT/rejected.log" \
  SENOMY_HYPRCTL_BIN="$TEST_ROOT/hyprctl" \
    "$REPO_ROOT/scripts/workspace-action.sh" switch '7);os.execute("bad")' >/dev/null 2>&1; then
  printf 'Workspace injection fixture was unexpectedly accepted.\n' >&2
  exit 1
fi

printf 'SenomyOS Hyprland: desktop/recovery Lua and legacy/Lua workspace dispatch contracts passed.\n'
