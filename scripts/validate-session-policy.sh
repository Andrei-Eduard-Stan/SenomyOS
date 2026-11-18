#!/usr/bin/env bash
# Uses an isolated configuration root; never reloads Hypridle or changes the live session.
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
python3 "$root/shell/quickshell/tests/test_session_policy.py"
python3 -m py_compile "$root/shell/quickshell/scripts/session-policy.py" \
  "$root/shell/quickshell/tests/test_session_policy.py"
/usr/lib/qt6/bin/qmllint "$root/shell/quickshell/services/SessionPolicy.qml" \
  "$root/shell/quickshell/components/ControlCentre.qml" >/dev/null
env -u WAYLAND_DISPLAY QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
  /usr/lib/qt6/bin/qmltestrunner -input "$root/shell/quickshell/tests/tst_SessionPolicy.qml"
