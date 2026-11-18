#!/usr/bin/env bash
# Isolated native UI fixture; does not change live controls.
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
output="${1:-$(mktemp -d -t senomy-backgrounds.XXXXXX)}"
mkdir -p -- "$output"
output="$(realpath -- "$output")"
env -u WAYLAND_DISPLAY QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=rhi \
    QSG_RHI_BACKEND=opengl SENOMY_QA_OUT="$output" \
    timeout 15s qs --path "$root/shell/quickshell/background-test.qml" --no-color > "$output/test.log" 2>&1
if rg -q 'FAIL:|ERROR|Binding loop|ReferenceError|TypeError' "$output/test.log"; then
    cat "$output/test.log"
    exit 1
fi
rg 'PASS:' "$output/test.log"
