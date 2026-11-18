#!/usr/bin/env bash
# Offscreen fake route/content fixture; never opens a live panel or device.
set -euo pipefail
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
shell_root="${1:-$repo_root/shell/quickshell}"
runtime="$(mktemp -d -t senomy-navigation.XXXXXX)"
trap 'rm -rf -- "$runtime"' EXIT
chmod 700 "$runtime"
/usr/lib/qt6/bin/qmllint "$shell_root/components/DashboardNavigation.qml" \
    "$shell_root/components/DashboardWindow.qml" > "$runtime/lint.log" 2>&1 || {
    cat "$runtime/lint.log" >&2
    exit 1
}
env -u WAYLAND_DISPLAY XDG_RUNTIME_DIR="$runtime" \
    QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
    timeout 15s qs --path "$shell_root/navigation-test.qml" --no-color \
    > "$runtime/test.log" 2>&1
if rg -q 'FAIL:|ERROR|Binding loop|ReferenceError|TypeError|Cannot open' "$runtime/test.log"; then
    cat "$runtime/test.log" >&2
    exit 1
fi
rg 'PASS: section navigation' "$runtime/test.log"
if [[ -s "$runtime/lint.log" ]]; then
    printf 'QML lint passed with diagnostics; this is not a warning-free result.\n'
fi
