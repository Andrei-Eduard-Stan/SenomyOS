#!/usr/bin/env bash
# Pure model, private D-Bus and offscreen Qt only; no real device mutations.
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
python3 -B "$root/scripts/validate-bluetooth.py" "${1:-$root/shell/quickshell}" "${2:-$root/docs/qa/bluetooth-20261025/isolated}"
