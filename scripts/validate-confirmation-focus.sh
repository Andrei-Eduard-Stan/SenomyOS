#!/usr/bin/env bash
# Uses only fake action objects; never invokes a real device operation.
set -euo pipefail
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
shell_root="${1:-$repo_root/shell/quickshell}"
runtime="$(mktemp -d -t senomy-confirmation-focus.XXXXXX)"
trap 'rm -rf -- "$runtime"' EXIT
chmod 700 "$runtime"
/usr/lib/qt6/bin/qmllint "$shell_root/components/ConfirmationFocus.qml" \
    "$shell_root/components/SelectionActionReview.qml" \
    "$shell_root/components/NetworkActionReview.qml" > "$runtime/lint.log" 2>&1 || {
    cat "$runtime/lint.log" >&2
    exit 1
}
env -u WAYLAND_DISPLAY XDG_RUNTIME_DIR="$runtime" \
    QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
    timeout 15s qs --path "$shell_root/confirmation-focus-test.qml" --no-color \
    > "$runtime/test.log" 2>&1
if rg -q 'FAIL:|ERROR|Binding loop|ReferenceError|TypeError' "$runtime/test.log"; then
    cat "$runtime/test.log" >&2
    exit 1
fi
rg 'PASS: selection, network/Bluetooth, notification and display confirmation' "$runtime/test.log"
if rg -q 'WARN|Warning:' "$runtime/test.log" "$runtime/lint.log"; then
    printf 'Passed with diagnostics; Qt activeFocusOnTab/lint warnings are not treated as absent.\n'
fi
