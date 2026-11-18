#!/usr/bin/env bash
# Fake providers and mocked subprocesses only; never changes a real display.
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
python3 -B "$root/shell/quickshell/tests/test_display_action.py"
python3 -B "$root/scripts/validate-display-canvas.py"
env -u WAYLAND_DISPLAY QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
    /usr/lib/qt6/bin/qmltestrunner -input "$root/shell/quickshell/tests/tst_DisplayActions.qml"
/usr/lib/qt6/bin/qmllint "$root/shell/quickshell/components/DisplaySettings.qml" \
    "$root/shell/quickshell/services/DisplayActions.qml" "$root/shell/quickshell/services/DeviceInventory.qml" >/dev/null
