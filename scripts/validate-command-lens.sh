#!/usr/bin/env bash

# Isolated Command Lens contract checks. This does not open Rofi, launch a real
# application, deploy user configuration, or touch the live Hyprland binding.
set -euo pipefail
export LC_ALL=C
export SENOMY_LENS_NATIVE=0

readonly CONFIG_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly APPEARANCE_DIR="$CONFIG_DIR/appearance/launcher/rofi"
readonly SCRIPT_DIR="$CONFIG_DIR/components/launcher/rofi/scripts"
readonly WRAPPER="$SCRIPT_DIR/senomy-command-lens"

fixture_dir="$(mktemp -d)"
trap 'rm -rf -- "$fixture_dir"' EXIT

# Copy the changed providers and substitute only their shared app boundary.
# This test must never reach the real manager or a GUI application.
provider_root="$fixture_dir/source/components/launcher/rofi/scripts"
mkdir -p "$provider_root" "$fixture_dir/source/scripts"
cp -- "$SCRIPT_DIR/senomy-rofi-files" "$SCRIPT_DIR/senomy-rofi-actions" "$provider_root/"
readonly FILES_MODE="$provider_root/senomy-rofi-files"
readonly ACTIONS_MODE="$provider_root/senomy-rofi-actions"
cat >"$fixture_dir/source/scripts/senomy-app-launch" <<'APPSTUB'
#!/usr/bin/env bash
set -euo pipefail
case "$1:$2" in
 --quiet:open) printf '%s\0' "$@" >"$SENOMY_TEST_GIO_LOG" ;;
 --quiet:tool) [[ "$3" == files ]]; printf '%s\0' "$@" >"$SENOMY_TEST_THUNAR_LOG" ;;
 *) exit 1 ;;
esac
APPSTUB
chmod 755 "$fixture_dir/source/scripts/senomy-app-launch"

home_dir="$fixture_dir/home"
root_dir="$home_dir/Test Files"
outside_dir="$fixture_dir/outside"
mock_dir="$fixture_dir/mock-bin"
fake_native="$fixture_dir/native-sentinel"
mkdir -p "$root_dir/folder" "$outside_dir" "$mock_dir" "$fake_native/scripts"

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
  'printf "%s\0" "$@" >"$SENOMY_TEST_SURFACE_LOG"' >"$fake_native/scripts/senomy-surface"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'set -euo pipefail' \
  'printf "%s\0" "$@" >"$SENOMY_TEST_SCREENSHOT_LOG"' >"$fake_native/scripts/senomy-screenshot"
chmod 755 "$mock_dir/setsid" "$mock_dir/gio" "$mock_dir/thunar" "$mock_dir/rofi" \
  "$fake_native/scripts/senomy-surface" "$fake_native/scripts/senomy-screenshot"

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
[[ "${gio_args[*]}" == "--quiet open $selected" && "${#gio_args[@]}" == 3 ]]

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
[[ "${thunar_args[*]}" == "--quiet tool files --select $selected" && "${#thunar_args[@]}" == 5 ]]

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
SENOMY_SURFACE_BIN="$fake_native/scripts/senomy-surface" \
SENOMY_SCREENSHOT_BIN="$fake_native/scripts/senomy-screenshot" \
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
  'appearance|show-settings|appearance' \
  'settings|show-settings|overview'; do
  IFS='|' read -r action_id expected_verb expected_route <<<"$action_spec"
  rm -f -- "$surface_log"
  HOME="$home_dir" \
  XDG_CONFIG_HOME="$home_dir/.config" \
  SENOMY_SURFACE_BIN="$fake_native/scripts/senomy-surface" \
SENOMY_SCREENSHOT_BIN="$fake_native/scripts/senomy-screenshot" \
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
SENOMY_SURFACE_BIN="$fake_native/scripts/senomy-surface" \
SENOMY_SCREENSHOT_BIN="$fake_native/scripts/senomy-screenshot" \
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
SENOMY_ROFI_MONITOR_HEIGHT=1080 \
SENOMY_TEST_ROFI_LOG="$rofi_log" \
"$WRAPPER" --mode files
mapfile -d '' -t rofi_args <"$rofi_log"
[[ "${rofi_args[0]:-}" == -config ]]
[[ "${rofi_args[1]:-}" == "$APPEARANCE_DIR/config.rasi" ]]
[[ "${rofi_args[2]:-}" == -modes ]]
[[ "${rofi_args[3]:-}" == "drun,files:$FILES_MODE --cached,window,actions:$ACTIONS_MODE" ]]
[[ "${rofi_args[4]:-}" == -show && "${rofi_args[5]:-}" == files ]]
[[ "${rofi_args[6]:-}" == -m && "${rofi_args[7]:-}" == -4 ]]
[[ "${rofi_args[8]:-}" == -theme-str ]]
[[ "${rofi_args[9]:-}" == *'width: 800px;'* && "${rofi_args[9]:-}" == *'height: 650px;'* ]]

narrow_rofi_log="$fixture_dir/rofi-narrow.log"
HOME="$home_dir" \
XDG_CONFIG_HOME="$home_dir/.config" \
SENOMY_ROFI_BIN="$mock_dir/rofi" \
SENOMY_ROFI_CONFIG="$APPEARANCE_DIR/config.rasi" \
SENOMY_ROFI_FILES_MODE="$FILES_MODE" \
SENOMY_ROFI_ACTIONS_MODE="$ACTIONS_MODE" \
SENOMY_ROFI_MONITOR_WIDTH=390 \
SENOMY_ROFI_MONITOR_HEIGHT=844 \
SENOMY_TEST_ROFI_LOG="$narrow_rofi_log" \
"$WRAPPER" --mode actions
mapfile -d '' -t narrow_rofi_args <"$narrow_rofi_log"
[[ "${narrow_rofi_args[5]:-}" == actions ]]
[[ "${narrow_rofi_args[9]:-}" == *'width: 366px;'* && "${narrow_rofi_args[9]:-}" == *'height: 650px;'* ]]
[[ "${narrow_rofi_args[9]:-}" == *'textbox-query-label { enabled: false;'* ]]
[[ "${narrow_rofi_args[9]:-}" == *'num-rows { enabled: false;'* ]]
[[ "${narrow_rofi_args[9]:-}" == *'padding: 12px 2px;'* ]]

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

HOME="$home_dir" SENOMY_ROFI_CONFIG="$APPEARANCE_DIR/config.rasi" \
SENOMY_ROFI_FILES_MODE="$fixture_dir/missing-files" SENOMY_ROFI_ACTIONS_MODE="$fixture_dir/missing-actions" \
SENOMY_ROFI_BIN="$mock_dir/rofi" SENOMY_TEST_ROFI_LOG="$rofi_log" \
SENOMY_ROFI_MONITOR_WIDTH=320 SENOMY_ROFI_MONITOR_HEIGHT=360 "$WRAPPER" --mode files
mapfile -d '' -t fallback_args <"$rofi_log"
[[ "${fallback_args[3]}" == drun,window ]]
[[ "${fallback_args[5]}" == drun ]]
[[ "${fallback_args[9]}" == *'width: 296px;'* && "${fallback_args[9]}" == *'height: 312px;'* ]]
[[ "${fallback_args[10]}" == -mesg && "${fallback_args[11]}" == *'unavailable'* ]]
# Read actual compositor-shaped data through the adapter, including rotation,
# fractional geometry and all four work-area reservations.
cat >"$mock_dir/hyprctl" <<'MOCKMONITOR'
#!/usr/bin/env bash
printf '%s\n' '[{"width":1200,"height":1800,"scale":2,"transform":1,"reserved":[8,10,12,72],"focused":true}]'
MOCKMONITOR
chmod 755 "$mock_dir/hyprctl"
env -u SENOMY_ROFI_MONITOR_WIDTH -u SENOMY_ROFI_MONITOR_HEIGHT \
HOME="$home_dir" PATH="$mock_dir:$PATH" SENOMY_ROFI_CONFIG="$APPEARANCE_DIR/config.rasi" \
SENOMY_ROFI_FILES_MODE="$FILES_MODE" SENOMY_ROFI_ACTIONS_MODE="$ACTIONS_MODE" \
SENOMY_ROFI_BIN="$mock_dir/rofi" SENOMY_TEST_ROFI_LOG="$rofi_log" "$WRAPPER"
mapfile -d '' -t rotated_args <"$rofi_log"
[[ "${rotated_args[9]}" == *'width: 800px;'* && "${rotated_args[9]}" == *'height: 470px;'* ]]
printf 'Command Lens contract validation passed.\n'
