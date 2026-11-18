#!/usr/bin/env bash
# Isolated fake-provider tests. Never starts the normal shell or NetworkManager.
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
command -v qs >/dev/null || { printf 'Quickshell is required for the isolated control fixture.\n' >&2; exit 1; }
env -u WAYLAND_DISPLAY QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
    timeout 30s "$runner" -input "$root/shell/quickshell/tests/tst_NetworkActions.qml"
log="$(mktemp -t senomy-network-controls.XXXXXX)"
trap 'rm -f -- "$log"' EXIT
env -u WAYLAND_DISPLAY QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
    timeout 15s qs --path "$root/shell/quickshell/network-confirmation-test.qml" --no-color >"$log" 2>&1
if rg -q 'FAIL|ERROR|Binding loop|ReferenceError|TypeError' "$log"; then
    cat "$log"
    exit 1
fi
rg 'PASS:' "$log"
