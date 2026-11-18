#!/usr/bin/env bash
# Fake settings provider and screen state only; does not change live settings or hardware.
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
lint="$(mktemp -t senomy-settings-lint.XXXXXX)"
trap 'rm -f -- "$lint"' EXIT
/usr/lib/qt6/bin/qmllint "$root/shell/quickshell/components/AppearanceSettings.qml" \
    "$root/shell/quickshell/components/ControlCentre.qml" "$root/shell/quickshell/config/Skin.qml" >"$lint" 2>&1
env -u WAYLAND_DISPLAY QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
    /usr/lib/qt6/bin/qmltestrunner -input "$root/shell/quickshell/tests/tst_SkinPreferences.qml"
env -u WAYLAND_DISPLAY QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
    /usr/lib/qt6/bin/qmltestrunner -input "$root/shell/quickshell/tests/tst_ScreenLifecycle.qml"
focus_log="$(mktemp -t senomy-control-focus.XXXXXX)"
focus_runtime="$(mktemp -d -t senomy-control-runtime.XXXXXX)"
chmod 700 "$focus_runtime"
trap 'rm -f -- "$lint" "$focus_log"; rm -rf -- "$focus_runtime"' EXIT
env -u WAYLAND_DISPLAY XDG_RUNTIME_DIR="$focus_runtime" \
    QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
    timeout 12s qs --path "$root/shell/quickshell/control-style-test.qml" --no-color \
    >"$focus_log" 2>&1
if rg -q 'FAIL:|Binding loop|ReferenceError|TypeError|Cannot open' "$focus_log"; then
    cat "$focus_log"
    exit 1
fi
rg 'PASS: styled controls support pointer, ordered keyboard focus, activation, and disabled gates' "$focus_log"
