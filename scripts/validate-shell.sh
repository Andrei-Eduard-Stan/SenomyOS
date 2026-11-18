#!/usr/bin/env bash
# Native Quickshell validation. All default checks are read-only or isolated.
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
case "${1:-static}" in static|--live) ;; *) printf 'usage: validate-shell.sh [--live]\n' >&2;exit 64;;esac
qmllint -I "$root/shell/quickshell" "$root/shell/quickshell/shell.qml"
"$root/scripts/generate-appearance.py" check
python3 "$root/scripts/generate-settings-search.py" --check
python3 -m unittest discover -s "$root/shell/quickshell/tests" -p 'test_account*.py'
python3 "$root/scripts/validate-control-directory.py"
python3 "$root/scripts/validate-interactions.py"
python3 "$root/scripts/validate-native-command-lens.py"
python3 "$root/scripts/validate-command-lens-quality.py"
python3 "$root/scripts/validate-settings-host.py"
python3 "$root/scripts/validate-motion.py"
python3 "$root/scripts/validate-decoration.py"
python3 "$root/scripts/validate-desktop-quality.py"
python3 "$root/scripts/validate-account-page.py"
python3 "$root/scripts/validate-session-telemetry.py"
python3 "$root/scripts/validate-native-entrypoints.py"
python3 "$root/scripts/validate-notification-ownership.py"
python3 "$root/scripts/validate-notification-selection.py"
python3 "$root/scripts/validate-rail-control-anchors.py"
bash "$root/scripts/validate-selector-readonly.sh"
env -u WAYLAND_DISPLAY QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software timeout 15s qs --path "$root/shell/quickshell/battery-service-test.qml" --no-color
if [[ "${1:-static}" == --live ]]; then "$root/scripts/senomy-shell" doctor;fi
printf 'PASS: native Quickshell shell checks\n'
