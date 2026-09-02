#!/usr/bin/env bash

# Validate the deterministic Thunar UCA merge and its fixed action helper under
# a temporary root. No live Thunar file, process, clipboard, or notification is
# touched.

set -euo pipefail
export LC_ALL=C

readonly CONFIG_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/senomy-thunar-test.XXXXXX")"
trap 'rm -rf -- "$TEST_ROOT"' EXIT

readonly BASE="$TEST_ROOT/uca.xml"
readonly FIRST="$TEST_ROOT/first.xml"
readonly SECOND="$TEST_ROOT/second.xml"
readonly REPORT="$TEST_ROOT/report.json"
readonly LIMITED="$TEST_ROOT/limited.xml"
readonly LIMITED_REPORT="$TEST_ROOT/limited-report.json"
readonly HELPER_TARGET="$TEST_ROOT/home/.local/bin/senomy-thunar-action"
readonly WORKSPACE="$CONFIG_DIR/components/file-manager/thunar/scripts/senomy-file-workspace"
readonly DESKTOP_ENTRY="$CONFIG_DIR/components/file-manager/thunar/thunar.desktop"
readonly TEST_BIN="$TEST_ROOT/bin"
readonly CLIPBOARD_CAPTURE="$TEST_ROOT/clipboard"

mkdir -p "$TEST_BIN" "$(dirname -- "$HELPER_TARGET")" "$TEST_ROOT/files"

desktop-file-validate "$DESKTOP_ENTRY"
grep -qF 'Exec=/usr/bin/env sh -c "exec ~/.local/bin/senomy-file-workspace"' "$DESKTOP_ENTRY"
grep -qF 'Exec=/usr/bin/env sh -c "SENOMY_FILE_DENSITY=touch exec ~/.local/bin/senomy-file-workspace"' "$DESKTOP_ENTRY"
! grep -q '^TryExec=' "$DESKTOP_ENTRY"

mkdir -p "$TEST_ROOT/desktop-data/applications"
cp -- "$DESKTOP_ENTRY" "$TEST_ROOT/desktop-data/applications/thunar.desktop"
XDG_DATA_HOME="$TEST_ROOT/desktop-data" PATH=/usr/bin python3 - <<'PY'
import gi

gi.require_version("GioUnix", "2.0")
from gi.repository import GioUnix

entry = GioUnix.DesktopAppInfo.new("thunar.desktop")
assert entry is not None
assert entry.get_filename().endswith("/desktop-data/applications/thunar.desktop")
assert "~/.local/bin/senomy-file-workspace" in entry.get_commandline()
PY

printf '%s\n' \
  '<?xml version="1.0" encoding="UTF-8"?>' \
  '<actions>' \
  '  <!-- user-owned action must survive -->' \
  '  <action>' \
  '    <icon>utilities-terminal</icon>' \
  '    <name>Open Terminal Here</name>' \
  '    <unique-id>1752824457083670-1</unique-id>' \
  '    <command>exo-open --working-directory %f --launch TerminalEmulator</command>' \
  '    <description>Open a terminal in this directory</description>' \
  '    <patterns>*</patterns>' \
  '    <directories />' \
  '  </action>' \
  '  <action>' \
  '    <name>Stale managed action</name>' \
  '    <unique-id>1893456000000001-1</unique-id>' \
  '    <command>false</command>' \
  '    <patterns>*</patterns>' \
  '    <other-files />' \
  '  </action>' \
  '</actions>' >"$BASE"

printf '%s\n' \
  '#!/usr/bin/env bash' \
  'set -euo pipefail' \
  'dest="${SENOMY_TEST_CLIPBOARD:?}"' \
  'cp -- /dev/stdin "$dest"' >"$TEST_BIN/wl-copy"
printf '%s\n' '#!/usr/bin/env bash' 'exit 0' >"$TEST_BIN/notify-send"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'set -euo pipefail' \
  'printf "%s\n" "${GTK_THEME:-}" >"$SENOMY_TEST_THEME_LOG"' \
  'printf "%s\0" "$@" >"$SENOMY_TEST_THUNAR_LOG"' >"$TEST_BIN/thunar"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  '[[ "${SENOMY_TEST_THUNAR_RUNNING:-0}" == 1 ]]' >"$TEST_BIN/pgrep"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'printf "uri: %s\n" "${SENOMY_TEST_URI:?}"' >"$TEST_BIN/gio"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'set -euo pipefail' \
  'if [[ "$*" == "--user list --no-legend" ]]; then' \
  '  printf "org.xfce.Thunar 4321 thunar fixture :1.1 fixture.scope - -\n"' \
  'else' \
  '  printf "%s\0" "$@" >"$SENOMY_TEST_BUSCTL_LOG"' \
  'fi' >"$TEST_BIN/busctl"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'set -euo pipefail' \
  'case "$*" in' \
  '  "-c thunar -p /last-separator-position") printf "%s\n" "${SENOMY_TEST_XFCONF_CURRENT:-447}" ;;' \
  '  "-c thunar -p /last-side-pane") printf "%s\n" "${SENOMY_TEST_XFCONF_SIDEPANE:-THUNAR_SIDEPANE_TYPE_TREE}" ;;' \
  '  "-c thunar -p /misc-image-preview-mode") exit 1 ;;' \
  '  *) printf "%s\0" "$@" >>"$SENOMY_TEST_XFCONF_LOG"; printf "\0" >>"$SENOMY_TEST_XFCONF_LOG" ;;' \
  'esac' >"$TEST_BIN/xfconf-query"
chmod 755 "$TEST_BIN/wl-copy" "$TEST_BIN/notify-send" "$TEST_BIN/thunar" "$TEST_BIN/pgrep" \
  "$TEST_BIN/gio" "$TEST_BIN/busctl" "$TEST_BIN/xfconf-query"

PATH="$TEST_BIN:$PATH" "$CONFIG_DIR/scripts/thunar-uca-merge.py" \
  --base "$BASE" \
  --registry "$CONFIG_DIR/components/file-manager/thunar/actions.json" \
  --helper-target "$HELPER_TARGET" \
  --output "$FIRST" \
  --report "$REPORT"
PATH="$TEST_BIN:$PATH" "$CONFIG_DIR/scripts/thunar-uca-merge.py" \
  --base "$FIRST" \
  --registry "$CONFIG_DIR/components/file-manager/thunar/actions.json" \
  --helper-target "$HELPER_TARGET" \
  --output "$SECOND" >/dev/null

xmllint --noout "$FIRST" "$SECOND"
cmp -s "$FIRST" "$SECOND"
[[ "$(stat -c %a "$FIRST")" == 600 ]]

jq -e '
  .base_exists == true and
  .preserved_user_actions == 1 and
  .replaced_managed_unique_ids == ["1893456000000001-1"] and
  .enabled_actions == ["copy-path", "copy-sha256"] and
  .unavailable_actions == [] and
  .result_actions == 3
' "$REPORT" >/dev/null

jq '.actions[0].requirements = ["senomy-missing-provider"]' \
  "$CONFIG_DIR/components/file-manager/thunar/actions.json" >"$TEST_ROOT/limited-actions.json"
PATH="$TEST_BIN:$PATH" "$CONFIG_DIR/scripts/thunar-uca-merge.py" \
  --base "$BASE" \
  --registry "$TEST_ROOT/limited-actions.json" \
  --helper-target "$HELPER_TARGET" \
  --output "$LIMITED" \
  --report "$LIMITED_REPORT"
xmllint --noout "$LIMITED"
jq -e '
  .preserved_user_actions == 1 and
  .enabled_actions == ["copy-sha256"] and
  .unavailable_actions == [{"id":"copy-path","missing":["senomy-missing-provider"]}] and
  .result_actions == 2
' "$LIMITED_REPORT" >/dev/null
! grep -q '<name>Copy Path</name>' "$LIMITED"
grep -q '<name>Copy SHA-256</name>' "$LIMITED"

python3 - "$FIRST" "$HELPER_TARGET" <<'PY'
from pathlib import Path
import sys
import xml.etree.ElementTree as ET

root = ET.parse(sys.argv[1]).getroot()
helper = sys.argv[2]
actions = {item.findtext("unique-id"): item for item in root.findall("action")}
assert len(actions) == 3
user = actions["1752824457083670-1"]
assert user.findtext("name") == "Open Terminal Here"
assert user.findtext("command") == "exo-open --working-directory %f --launch TerminalEmulator"
for unique_id, verb in (
    ("1893456000000001-1", "copy-path"),
    ("1893456000000002-1", "copy-sha256"),
):
    managed = actions[unique_id]
    assert managed.findtext("submenu") == "SenomyOS"
    assert managed.findtext("command") == f"{helper} {verb} %F"
PY

printf 'first file\n' >"$TEST_ROOT/files/alpha beta.txt"
printf 'second file\n' >"$TEST_ROOT/files/-leading.txt"
SENOMY_TEST_CLIPBOARD="$CLIPBOARD_CAPTURE" PATH="$TEST_BIN:$PATH" \
  "$CONFIG_DIR/components/file-manager/thunar/scripts/senomy-thunar-action" copy-path \
  "$TEST_ROOT/files/alpha beta.txt" "$TEST_ROOT/files/-leading.txt"
printf '%s\n' "$TEST_ROOT/files/alpha beta.txt" "$TEST_ROOT/files/-leading.txt" >"$TEST_ROOT/expected-paths"
cmp -s "$CLIPBOARD_CAPTURE" "$TEST_ROOT/expected-paths"

SENOMY_TEST_CLIPBOARD="$CLIPBOARD_CAPTURE" PATH="$TEST_BIN:$PATH" \
  "$CONFIG_DIR/components/file-manager/thunar/scripts/senomy-thunar-action" copy-sha256 \
  "$TEST_ROOT/files/alpha beta.txt"
sha256sum -- "$TEST_ROOT/files/alpha beta.txt" >"$TEST_ROOT/expected-sha256"
cmp -s "$CLIPBOARD_CAPTURE" "$TEST_ROOT/expected-sha256"

if SENOMY_TEST_CLIPBOARD="$CLIPBOARD_CAPTURE" PATH="$TEST_BIN:$PATH" \
  "$CONFIG_DIR/components/file-manager/thunar/scripts/senomy-thunar-action" unknown \
  "$TEST_ROOT/files/alpha beta.txt" >/dev/null 2>&1; then
  printf 'Unknown Thunar action unexpectedly ran.\n' >&2
  exit 1
fi
if SENOMY_TEST_CLIPBOARD="$CLIPBOARD_CAPTURE" PATH="$TEST_BIN:$PATH" \
  "$CONFIG_DIR/components/file-manager/thunar/scripts/senomy-thunar-action" copy-path relative.txt \
  >/dev/null 2>&1; then
  printf 'Relative Thunar action path unexpectedly passed validation.\n' >&2
  exit 1
fi

! grep -qE '(^|[^[:alnum:]_])(eval|bash[[:space:]]+-c|sh[[:space:]]+-c)([^[:alnum:]_]|$)' \
  "$CONFIG_DIR/components/file-manager/thunar/scripts/senomy-thunar-action"

mkdir -p "$TEST_ROOT/data/themes/SenomyOS/gtk-3.0" \
  "$TEST_ROOT/data/themes/SenomyOS-Touch/gtk-3.0" \
  "$TEST_ROOT/workspace-home" \
  "$TEST_ROOT/workspace-config/senomyos"
printf '/* fixture */\n' >"$TEST_ROOT/data/themes/SenomyOS/gtk-3.0/gtk.css"
printf '/* touch fixture */\n' >"$TEST_ROOT/data/themes/SenomyOS-Touch/gtk-3.0/gtk.css"
workspace_theme_log="$TEST_ROOT/workspace-theme.log"
workspace_thunar_log="$TEST_ROOT/workspace-thunar.log"
workspace_busctl_log="$TEST_ROOT/workspace-busctl.log"
workspace_systemd_run_log="$TEST_ROOT/workspace-systemd-run.log"
workspace_xfconf_log="$TEST_ROOT/workspace-xfconf.log"

printf '%s\n' \
  '#!/usr/bin/env bash' \
  'set -euo pipefail' \
  'printf "%s\0" "$@" >"$SENOMY_TEST_SYSTEMD_RUN_LOG"' >"$TEST_BIN/systemd-run"
chmod 755 "$TEST_BIN/systemd-run"

HOME="$TEST_ROOT/workspace-home" \
XDG_DATA_HOME="$TEST_ROOT/data" \
SENOMY_THUNAR_BIN="$TEST_BIN/thunar" \
SENOMY_PGREP_BIN="$TEST_BIN/pgrep" \
SENOMY_GIO_BIN="$TEST_BIN/gio" \
SENOMY_BUSCTL_BIN="$TEST_BIN/busctl" \
SENOMY_SYSTEMD_RUN_BIN="$TEST_BIN/systemd-run" \
SENOMY_XFCONF_BIN="$TEST_BIN/xfconf-query" \
SENOMY_TEST_URI='file:///fixture/alpha%20beta.txt' \
SENOMY_TEST_THEME_LOG="$workspace_theme_log" \
SENOMY_TEST_THUNAR_LOG="$workspace_thunar_log" \
SENOMY_TEST_BUSCTL_LOG="$workspace_busctl_log" \
SENOMY_TEST_SYSTEMD_RUN_LOG="$workspace_systemd_run_log" \
SENOMY_TEST_XFCONF_LOG="$workspace_xfconf_log" \
"$WORKSPACE" --select "$TEST_ROOT/files/alpha beta.txt"
python3 - "$workspace_xfconf_log" 220 <<'PY'
from pathlib import Path
import sys

items = Path(sys.argv[1]).read_bytes().split(b"\0")
calls = []
current = []
for item in items:
    if item:
        current.append(item.decode())
    elif current:
        calls.append(current)
        current = []
assert calls == [
    ["-c", "thunar", "-p", "/last-separator-position", "-s", sys.argv[2]],
    ["-c", "thunar", "-p", "/last-side-pane", "-s", "THUNAR_SIDEPANE_TYPE_SHORTCUTS"],
    ["-c", "thunar", "-p", "/misc-image-preview-mode", "-n", "-t", "string", "-s", "THUNAR_IMAGE_PREVIEW_MODE_STANDALONE"],
]
PY
mapfile -d '' -t workspace_systemd_run_args <"$workspace_systemd_run_log"
[[ "${workspace_systemd_run_args[0]:-}" == --user ]]
[[ "${workspace_systemd_run_args[1]:-}" == --quiet ]]
[[ "${workspace_systemd_run_args[2]:-}" == --collect ]]
[[ "${workspace_systemd_run_args[3]:-}" == --setenv=GTK_THEME=SenomyOS ]]
[[ "${workspace_systemd_run_args[4]:-}" == "$TEST_BIN/thunar" ]]
[[ "${workspace_systemd_run_args[5]:-}" == --daemon ]]
[[ "${#workspace_systemd_run_args[@]}" == 6 ]]
mapfile -d '' -t workspace_busctl_args <"$workspace_busctl_log"
[[ "${workspace_busctl_args[0]:-}" == --user ]]
[[ "${workspace_busctl_args[1]:-}" == call ]]
[[ "${workspace_busctl_args[2]:-}" == org.xfce.Thunar ]]
[[ "${workspace_busctl_args[3]:-}" == /org/freedesktop/FileManager1 ]]
[[ "${workspace_busctl_args[4]:-}" == org.freedesktop.FileManager1 ]]
[[ "${workspace_busctl_args[5]:-}" == ShowItems ]]
[[ "${workspace_busctl_args[6]:-}" == ass ]]
[[ "${workspace_busctl_args[7]:-}" == 1 ]]
[[ "${workspace_busctl_args[8]:-}" == 'file:///fixture/alpha%20beta.txt' ]]

rm -f -- "$workspace_thunar_log" "$workspace_systemd_run_log" "$workspace_xfconf_log"
env -u GTK_THEME \
  HOME="$TEST_ROOT/workspace-home" \
  XDG_DATA_HOME="$TEST_ROOT/data" \
  SENOMY_TEST_THUNAR_RUNNING=1 \
  SENOMY_THUNAR_BIN="$TEST_BIN/thunar" \
  SENOMY_PGREP_BIN="$TEST_BIN/pgrep" \
  SENOMY_SYSTEMD_RUN_BIN="$TEST_BIN/systemd-run" \
  SENOMY_XFCONF_BIN="$TEST_BIN/xfconf-query" \
  SENOMY_TEST_THEME_LOG="$workspace_theme_log" \
  SENOMY_TEST_THUNAR_LOG="$workspace_thunar_log" \
  SENOMY_TEST_SYSTEMD_RUN_LOG="$workspace_systemd_run_log" \
  SENOMY_TEST_XFCONF_LOG="$workspace_xfconf_log" \
  "$WORKSPACE" -- "$TEST_ROOT/files"
[[ -z "$(cat "$workspace_theme_log")" ]]
mapfile -d '' -t workspace_args <"$workspace_thunar_log"
[[ "${workspace_args[0]:-}" == --window ]]
[[ "${workspace_args[1]:-}" == -- ]]
[[ "${workspace_args[2]:-}" == "$TEST_ROOT/files" ]]
[[ ! -e "$workspace_systemd_run_log" ]]
[[ ! -e "$workspace_xfconf_log" ]]

printf '{"schema_version":3,"font_scale":"touch"}\n' >"$TEST_ROOT/workspace-config/senomyos/preferences.json"
rm -f -- "$workspace_theme_log" "$workspace_thunar_log" "$workspace_systemd_run_log"
HOME="$TEST_ROOT/workspace-home" \
XDG_CONFIG_HOME="$TEST_ROOT/workspace-config" \
XDG_DATA_HOME="$TEST_ROOT/data" \
SENOMY_THUNAR_BIN="$TEST_BIN/thunar" \
SENOMY_PGREP_BIN="$TEST_BIN/pgrep" \
SENOMY_BUSCTL_BIN="$TEST_BIN/busctl" \
SENOMY_SYSTEMD_RUN_BIN="$TEST_BIN/systemd-run" \
SENOMY_XFCONF_BIN="$TEST_BIN/xfconf-query" \
SENOMY_TEST_THEME_LOG="$workspace_theme_log" \
SENOMY_TEST_THUNAR_LOG="$workspace_thunar_log" \
SENOMY_TEST_SYSTEMD_RUN_LOG="$workspace_systemd_run_log" \
SENOMY_TEST_XFCONF_LOG="$workspace_xfconf_log" \
"$WORKSPACE" -- "$TEST_ROOT/files"
python3 - "$workspace_xfconf_log" 260 <<'PY'
from pathlib import Path
import sys

items = Path(sys.argv[1]).read_bytes().split(b"\0")
calls = []
current = []
for item in items:
    if item:
        current.append(item.decode())
    elif current:
        calls.append(current)
        current = []
assert calls == [
    ["-c", "thunar", "-p", "/last-separator-position", "-s", sys.argv[2]],
    ["-c", "thunar", "-p", "/last-side-pane", "-s", "THUNAR_SIDEPANE_TYPE_SHORTCUTS"],
    ["-c", "thunar", "-p", "/misc-image-preview-mode", "-n", "-t", "string", "-s", "THUNAR_IMAGE_PREVIEW_MODE_STANDALONE"],
]
PY
mapfile -d '' -t workspace_systemd_run_args <"$workspace_systemd_run_log"
[[ "${workspace_systemd_run_args[3]:-}" == --setenv=GTK_THEME=SenomyOS-Touch ]]
mapfile -d '' -t workspace_args <"$workspace_thunar_log"
[[ "${workspace_args[0]:-}" == --window ]]
[[ "${workspace_args[1]:-}" == -- ]]
[[ "${workspace_args[2]:-}" == "$TEST_ROOT/files" ]]

if SENOMY_FILE_DENSITY=oversized \
  HOME="$TEST_ROOT/workspace-home" \
  XDG_DATA_HOME="$TEST_ROOT/data" \
  SENOMY_THUNAR_BIN="$TEST_BIN/thunar" \
  "$WORKSPACE" >/dev/null 2>&1; then
  printf 'Invalid file-workspace density unexpectedly passed validation.\n' >&2
  exit 1
fi

rm -f -- "$workspace_thunar_log"
if HOME="$TEST_ROOT/workspace-home" \
  XDG_DATA_HOME="$TEST_ROOT/data" \
  SENOMY_THUNAR_BIN="$TEST_BIN/thunar" \
  SENOMY_PGREP_BIN="$TEST_BIN/pgrep" \
  SENOMY_TEST_THEME_LOG="$workspace_theme_log" \
  SENOMY_TEST_THUNAR_LOG="$workspace_thunar_log" \
  "$WORKSPACE" --select relative.txt >/dev/null 2>&1; then
  printf 'Relative file-workspace path unexpectedly passed validation.\n' >&2
  exit 1
fi
[[ ! -e "$workspace_thunar_log" ]]

! grep -qE '(^|[^[:alnum:]_])(eval|bash[[:space:]]+-c|sh[[:space:]]+-c)([^[:alnum:]_]|$)' "$WORKSPACE"

printf 'SenomyOS Thunar: deterministic merge, system-PATH desktop resolution, standard/touch workspace handoff, native Shortcuts/preview layout, fixed verbs, path validation, and clipboard fixtures passed.\n'
