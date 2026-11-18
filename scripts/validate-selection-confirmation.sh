#!/usr/bin/env bash
# Fake providers only: no native audio route or power-profile mutation.
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
runner="${SENOMY_QMLTESTRUNNER:-}"
if [[ -z "$runner" ]]; then
    if [[ -x /usr/lib/qt6/bin/qmltestrunner ]]; then
        runner=/usr/lib/qt6/bin/qmltestrunner
    else
        runner="$(command -v qmltestrunner || true)"
    fi
fi
[[ -n "$runner" && -x "$runner" ]] || { printf 'Qt 6 qmltestrunner is required.\n' >&2; exit 1; }
command -v qs >/dev/null || { printf 'Quickshell is required.\n' >&2; exit 1; }
env -u WAYLAND_DISPLAY QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
    timeout 30s "$runner" -input "$root/shell/quickshell/tests/tst_SelectionActions.qml"
log="$(mktemp -t senomy-selection-controls.XXXXXX)"
trap 'rm -f -- "$log"' EXIT
env -u WAYLAND_DISPLAY QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
    timeout 15s qs --path "$root/shell/quickshell/selection-confirmation-test.qml" --no-color >"$log" 2>&1
if rg -q 'FAIL|ERROR|Binding loop|ReferenceError|TypeError' "$log"; then
    cat "$log"
    exit 1
fi
rg 'PASS:' "$log"
