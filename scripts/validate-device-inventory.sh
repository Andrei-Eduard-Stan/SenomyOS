#!/usr/bin/env bash
# Read-only native service plus fake inventory rendering; no device changes.
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
python3 "$root/shell/quickshell/tests/test_device_inventory.py"
output="$(mktemp -d -t senomy-inventory.XXXXXX)"
env -u WAYLAND_DISPLAY QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
    SENOMY_QA_OUT="$output" timeout 12s qs --path "$root/shell/quickshell/device-inventory-test.qml" --no-color > "$output/test.log" 2>&1
if rg -q 'FAIL:|ERROR|Binding loop|ReferenceError|TypeError' "$output/test.log"; then
    cat "$output/test.log"
    exit 1
fi
rg 'PASS:' "$output/test.log"
