#!/usr/bin/env bash
# Isolated input tests only. Never inherits a live compositor or session bus.
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -x "$root/shell/quickshell/scripts/input-settings.py" ]] || { echo "Input helper is not executable" >&2; exit 1; }
export PYTHONDONTWRITEBYTECODE=1
unset HYPRLAND_INSTANCE_SIGNATURE WAYLAND_DISPLAY DISPLAY DBUS_SESSION_BUS_ADDRESS
export QT_QPA_PLATFORM=offscreen
python3 "$root/shell/quickshell/tests/test_input_settings.py"
python3 "$root/shell/quickshell/tests/test_input_transport.py"
python3 "$root/shell/quickshell/tests/test_input_page.py"
/usr/lib/qt6/bin/qmltestrunner -input "$root/shell/quickshell/tests/tst_InputPreferences.qml"
/usr/lib/qt6/bin/qmllint -I "$root/shell/quickshell" \
    "$root/shell/quickshell/services/InputPreferences.qml" \
    "$root/shell/quickshell/services/InputSettings.qml" \
    "$root/shell/quickshell/components/control/ControlInputPage.qml"
luac -p "$root/hyprland.lua"
