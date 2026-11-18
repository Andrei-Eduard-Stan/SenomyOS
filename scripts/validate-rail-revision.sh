#!/usr/bin/env bash
# Isolated visual/behavior fixtures. No live workspace or service is changed.
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
output="${1:-$root/docs/qa/rail-revision-2026-09-06}"
mkdir -p -- "$output"
output="$(realpath -- "$output")"
env -u WAYLAND_DISPLAY QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
  SENOMY_QA_OUT="$output" timeout 15s qs --path "$root/shell/quickshell/rail-revision-test.qml" --no-color
