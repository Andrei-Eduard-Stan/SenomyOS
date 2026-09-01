#!/usr/bin/env bash

# Isolated Command Lens contract checks. This does not open Rofi, launch a real
# application, deploy user configuration, or touch the live Hyprland binding.
set -euo pipefail
export LC_ALL=C

readonly CONFIG_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly APPEARANCE_DIR="$CONFIG_DIR/appearance/launcher/rofi"
readonly SCRIPT_DIR="$CONFIG_DIR/components/launcher/rofi/scripts"
readonly WRAPPER="$SCRIPT_DIR/senomy-command-lens"
readonly FILES_MODE="$SCRIPT_DIR/senomy-rofi-files"
readonly ACTIONS_MODE="$SCRIPT_DIR/senomy-rofi-actions"

fixture_dir="$(mktemp -d)"
trap 'rm -rf -- "$fixture_dir"' EXIT

home_dir="$fixture_dir/home"
root_dir="$home_dir/Test Files"
outside_dir="$fixture_dir/outside"
mock_dir="$fixture_dir/mock-bin"
fake_eww="$fixture_dir/eww"
mkdir -p "$root_dir/folder" "$outside_dir" "$mock_dir" "$fake_eww/scripts"

grep -qF "\$menu = /usr/bin/env sh -c '\$HOME/.local/bin/senomy-command-lens'" \
  "$CONFIG_DIR/hyprland.conf"
grep -qF "\$fileManager = /usr/bin/env sh -c '\$HOME/.local/bin/senomy-file-workspace'" \
  "$CONFIG_DIR/hyprland.conf"

touch -- \
  "$root_dir/a file.txt" \
  "$root_dir/quote'file.md" \
  "$root_dir/--leading-dash" \
  "$root_dir/日本語.txt" \
  "$root_dir/.hidden-file" \
  "$outside_dir/not-allowed.txt"

search_config="$fixture_dir/file-search.json"
jq -n '{
  schema_version: 1,
  roots: ["Test Files"],
  max_depth: 3,
  max_results: 50,
  timeout_seconds: 2
}' >"$search_config"

printf '%s\n' \
  '#!/usr/bin/env bash' \
  'set -euo pipefail' \
  '[[ "${1:-}" == --fork ]] && shift' \
  '"$@"' >"$mock_dir/setsid"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'set -euo pipefail' \
  'printf "%s\0" "$@" >"$SENOMY_TEST_GIO_LOG"' >"$mock_dir/gio"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'set -euo pipefail' \
  'printf "%s\0" "$@" >"$SENOMY_TEST_THUNAR_LOG"' >"$mock_dir/thunar"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'set -euo pipefail' \
  'printf "%s\0" "$@" >"$SENOMY_TEST_ROFI_LOG"' >"$mock_dir/rofi"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'set -euo pipefail' \
  'printf "%s\0" "$@" >"$SENOMY_TEST_SURFACE_LOG"' >"$fake_eww/scripts/surface-state.sh"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'set -euo pipefail' \
  'printf "%s\0" "$@" >"$SENOMY_TEST_SCREENSHOT_LOG"' >"$fake_eww/scripts/screenshot-action.sh"
chmod 755 "$mock_dir/setsid" "$mock_dir/gio" "$mock_dir/thunar" "$mock_dir/rofi" \
  "$fake_eww/scripts/surface-state.sh" "$fake_eww/scripts/screenshot-action.sh"

catalog="$fixture_dir/files.catalog"
HOME="$home_dir" \
XDG_CONFIG_HOME="$home_dir/.config" \
SENOMY_FILE_SEARCH_CONFIG="$search_config" \
"$FILES_MODE" >"$catalog"

grep -aFq 'a file.txt' "$catalog"
grep -aFq "quote'file.md" "$catalog"
grep -aFq -- '--leading-dash' "$catalog"
grep -aFq '日本語.txt' "$catalog"
grep -aFq 'folder' "$catalog"
grep -aFq '~/Test Files' "$catalog"
! grep -aFq '.hidden-file' "$catalog"
grep -aFq '<span weight="bold">' "$catalog"

gio_log="$fixture_dir/gio.log"
selected="$root_dir/quote'file.md"
HOME="$home_dir" \
XDG_CONFIG_HOME="$home_dir/.config" \
SENOMY_FILE_SEARCH_CONFIG="$search_config" \
SENOMY_SETSID_BIN="$mock_dir/setsid" \
SENOMY_GIO_BIN="$mock_dir/gio" \
SENOMY_TEST_GIO_LOG="$gio_log" \
ROFI_RETV=1 ROFI_INFO="$selected" \
"$FILES_MODE"
mapfile -d '' -t gio_args <"$gio_log"
[[ "${gio_args[0]:-}" == open && "${gio_args[1]:-}" == -- && "${gio_args[2]:-}" == "$selected" ]]

thunar_log="$fixture_dir/thunar.log"
HOME="$home_dir" \
XDG_CONFIG_HOME="$home_dir/.config" \
SENOMY_FILE_SEARCH_CONFIG="$search_config" \
SENOMY_SETSID_BIN="$mock_dir/setsid" \
SENOMY_THUNAR_BIN="$mock_dir/thunar" \
SENOMY_TEST_THUNAR_LOG="$thunar_log" \
ROFI_RETV=10 ROFI_INFO="$selected" \
"$FILES_MODE"
mapfile -d '' -t thunar_args <"$thunar_log"
[[ "${thunar_args[0]:-}" == --select && "${thunar_args[1]:-}" == "$selected" ]]

refused="$fixture_dir/refused.catalog"
rm -f -- "$gio_log"
HOME="$home_dir" \
XDG_CONFIG_HOME="$home_dir/.config" \
SENOMY_FILE_SEARCH_CONFIG="$search_config" \
SENOMY_SETSID_BIN="$mock_dir/setsid" \
SENOMY_GIO_BIN="$mock_dir/gio" \
SENOMY_TEST_GIO_LOG="$gio_log" \
ROFI_RETV=1 ROFI_INFO="$outside_dir/not-allowed.txt" \
"$FILES_MODE" >"$refused"
[[ ! -e "$gio_log" ]]
grep -aFq 'Selection refused' "$refused"

actions_catalog="$fixture_dir/actions.catalog"
HOME="$home_dir" \
XDG_CONFIG_HOME="$home_dir/.config" \
SENOMY_EWW_CONFIG="$fake_eww" \
SENOMY_THUNAR_BIN="$mock_dir/thunar" \
"$ACTIONS_MODE" >"$actions_catalog"
grep -aFq 'Control Centre' "$actions_catalog"
grep -aFq 'Performance Dashboard' "$actions_catalog"
grep -aFq 'Senomy Insights' "$actions_catalog"
grep -aFq 'Appearance' "$actions_catalog"
grep -aFq 'Settings' "$actions_catalog"
grep -aFq 'Capture Screenshot' "$actions_catalog"
grep -aFq 'Open File Workspace' "$actions_catalog"
! grep -aiEq 'shutdown|reboot|logout|arbitrary shell' "$actions_catalog"

surface_log="$fixture_dir/surface.log"
for action_spec in \
  'control|show-control|overview' \
  'performance|show-performance|' \
  'insights|show-insights|briefing' \
  'diagnostics|show-insights|diagnostics' \
  'appearance|show-control|appearance' \
  'settings|show-control|settings'; do
  IFS='|' read -r action_id expected_verb expected_route <<<"$action_spec"
  rm -f -- "$surface_log"
  HOME="$home_dir" \
  XDG_CONFIG_HOME="$home_dir/.config" \
  SENOMY_EWW_CONFIG="$fake_eww" \
  SENOMY_TEST_SURFACE_LOG="$surface_log" \
  ROFI_RETV=1 ROFI_INFO="$action_id" \
  "$ACTIONS_MODE"
  mapfile -d '' -t surface_args <"$surface_log"
  [[ "${surface_args[0]:-}" == "$expected_verb" ]]
  [[ "${surface_args[1]:-}" == "$expected_route" ]]
done

screenshot_log="$fixture_dir/screenshot.log"
HOME="$home_dir" \
XDG_CONFIG_HOME="$home_dir/.config" \
SENOMY_EWW_CONFIG="$fake_eww" \
SENOMY_SETSID_BIN="$mock_dir/setsid" \
SENOMY_TEST_SCREENSHOT_LOG="$screenshot_log" \
ROFI_RETV=1 ROFI_INFO=screenshot \
"$ACTIONS_MODE"
mapfile -d '' -t screenshot_args <"$screenshot_log"
[[ "${screenshot_args[0]:-}" == capture ]]

rofi_log="$fixture_dir/rofi.log"
HOME="$home_dir" \
XDG_CONFIG_HOME="$home_dir/.config" \
SENOMY_ROFI_BIN="$mock_dir/rofi" \
SENOMY_ROFI_CONFIG="$APPEARANCE_DIR/config.rasi" \
SENOMY_ROFI_FILES_MODE="$FILES_MODE" \
SENOMY_ROFI_ACTIONS_MODE="$ACTIONS_MODE" \
SENOMY_ROFI_MONITOR_WIDTH=1920 \
SENOMY_TEST_ROFI_LOG="$rofi_log" \
"$WRAPPER" --mode files
mapfile -d '' -t rofi_args <"$rofi_log"
[[ "${rofi_args[0]:-}" == -config ]]
[[ "${rofi_args[1]:-}" == "$APPEARANCE_DIR/config.rasi" ]]
[[ "${rofi_args[2]:-}" == -modes ]]
[[ "${rofi_args[3]:-}" == "drun,files:$FILES_MODE,window,actions:$ACTIONS_MODE" ]]
[[ "${rofi_args[4]:-}" == -show && "${rofi_args[5]:-}" == files ]]
[[ "${rofi_args[6]:-}" == -m && "${rofi_args[7]:-}" == -4 ]]
[[ "${rofi_args[8]:-}" == -theme-str ]]
[[ "${rofi_args[9]:-}" == 'window { width: 800px; y-offset: 48px; } listview { lines: 7; }' ]]

narrow_rofi_log="$fixture_dir/rofi-narrow.log"
HOME="$home_dir" \
XDG_CONFIG_HOME="$home_dir/.config" \
SENOMY_ROFI_BIN="$mock_dir/rofi" \
SENOMY_ROFI_CONFIG="$APPEARANCE_DIR/config.rasi" \
SENOMY_ROFI_FILES_MODE="$FILES_MODE" \
SENOMY_ROFI_ACTIONS_MODE="$ACTIONS_MODE" \
SENOMY_ROFI_MONITOR_WIDTH=390 \
SENOMY_TEST_ROFI_LOG="$narrow_rofi_log" \
"$WRAPPER" --mode actions
mapfile -d '' -t narrow_rofi_args <"$narrow_rofi_log"
[[ "${narrow_rofi_args[5]:-}" == actions ]]
[[ "${narrow_rofi_args[9]:-}" == 'window { width: 358px; y-offset: 24px; } listview { lines: 7; }'* ]]
[[ "${narrow_rofi_args[9]:-}" == *'textbox-query-label { enabled: false; }'* ]]
[[ "${narrow_rofi_args[9]:-}" == *'num-rows { enabled: false; }'* ]]
[[ "${narrow_rofi_args[9]:-}" == *'button { padding: 8px 5px 7px 5px; }'* ]]

rofi -config "$APPEARANCE_DIR/config.rasi" \
  -modes "drun,files:$FILES_MODE,window,actions:$ACTIONS_MODE" \
  -dump-config >"$fixture_dir/rofi-config.dump" 2>"$fixture_dir/rofi-config.err"
rofi -config "$APPEARANCE_DIR/config.rasi" \
  -modes "drun,files:$FILES_MODE,window,actions:$ACTIONS_MODE" \
  -dump-theme >"$fixture_dir/rofi-theme.dump" 2>"$fixture_dir/rofi-theme.err"
! grep -qF 'Failed to parse' "$fixture_dir/rofi-config.err"
! grep -qF 'Failed to parse' "$fixture_dir/rofi-theme.err"
grep -qF 'display-files: "FILES"' "$fixture_dir/rofi-config.dump"
grep -qF 'display-actions: "ACTIONS"' "$fixture_dir/rofi-config.dump"
grep -qF 'width:            800px' "$fixture_dir/rofi-theme.dump"
grep -qF 'textbox-footer' "$fixture_dir/rofi-theme.dump"
grep -qF 'textbox-query-label' "$fixture_dir/rofi-theme.dump"

printf 'Command Lens contract validation passed.\n'
