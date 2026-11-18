#!/usr/bin/env bash
# Uses current informational providers only; never switches or restarts shells.
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
fixture="$(mktemp -d -t senomy-selector-readonly.XXXXXX)"
trap 'rm -rf -- "$fixture"' EXIT

for verb in status doctor logs; do
  # A regular file cannot contain a runtime directory. A read-only command
  # should still work, while the old mkdir/lock path necessarily fails.
  printf 'sentinel\n' > "$fixture/runtime"
  result=0
  XDG_RUNTIME_DIR="$fixture/runtime" "$root/scripts/senomy-shell" "$verb" 1 \
    > "$fixture/$verb.out" 2> "$fixture/$verb.err" || result=$?
  # doctor can correctly reject missing providers in this isolated environment.
  if [[ "$verb" != doctor && "$result" -ne 0 ]]; then
    cat "$fixture/$verb.err" >&2
    exit 1
  fi
  [[ "$(cat "$fixture/runtime")" == sentinel ]]
  ! rg -q 'mkdir:|shell-selector.lock|another selector operation' "$fixture/$verb.err"
  if [[ "$verb" == status ]]; then
    jq -e '.services and .layers and .notifications' "$fixture/$verb.out" >/dev/null
  fi
done
printf 'PASS: status, doctor and logs do not create selector state or acquire its lock\n'
