#!/usr/bin/env bash
# Isolated fixture; does not control real media or the live shell.
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
output="${1:-$(mktemp -d -t senomy-expanded-qa.XXXXXX)}"
mkdir -p -- "$output"
output="$(realpath -- "$output")"
qmllint -I "$root/shell/quickshell" "$root"/shell/quickshell/components/Expanded*.qml
# Set QT_QUICK_BACKEND=rhi and QSG_RHI_BACKEND=opengl to exercise the shader.
env -u WAYLAND_DISPLAY QT_QPA_PLATFORM=offscreen \
    QT_QUICK_BACKEND="${QT_QUICK_BACKEND:-software}" SENOMY_QA_OUT="$output" \
    timeout 18s qs --path "$root/shell/quickshell/expanded-panel-test.qml" --no-color \
    > "$output/test.log" 2>&1
if rg -q 'FAIL:|ERROR|Binding loop|ReferenceError|TypeError|Cannot open' "$output/test.log"; then
    cat "$output/test.log"
    exit 1
fi
rg 'PASS:' "$output/test.log"
