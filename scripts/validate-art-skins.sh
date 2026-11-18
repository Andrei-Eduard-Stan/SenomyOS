#!/usr/bin/env bash
# Offscreen fixtures only: never changes the live shell, services or workspaces.
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
output="${1:-$(mktemp -d -t senomy-art-qa.XXXXXX)}"
mkdir -p -- "$output"
output="$(realpath -- "$output")"
python3 "$root/scripts/validate-art-skins.py" "$root"
for scale in 1 1.25 1.5 2; do
  mkdir -p "$output/$scale"
  env -u WAYLAND_DISPLAY QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
    QT_SCALE_FACTOR="$scale" SENOMY_QA_OUT="$output/$scale" \
    timeout 15s qs --path "$root/shell/quickshell/skin-test.qml" --no-color \
    > "$output/$scale/test.log" 2>&1
  rg -q 'PASS: sliced frames' "$output/$scale/test.log"
  if rg -q 'FAIL:|ERROR|Binding loop|ReferenceError|TypeError' "$output/$scale/test.log"; then
    cat "$output/$scale/test.log"
    exit 1
  fi
  printf 'PASS art frames and native input at scale %s\n' "$scale"
done
bash "$root/scripts/validate-rail-revision.sh" "$output/workspaces" > "$output/workspaces.log" 2>&1
rg -q 'PASS: borders' "$output/workspaces.log"
if rg -q 'FAIL:|ERROR|Binding loop|ReferenceError|TypeError' "$output/workspaces.log"; then
  cat "$output/workspaces.log"
  exit 1
fi
printf 'PASS workspace carousel regression; captures: %s\n' "$output"
