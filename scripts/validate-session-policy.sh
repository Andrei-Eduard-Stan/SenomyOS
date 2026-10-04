#!/usr/bin/env bash
# Uses an isolated configuration root; never reloads Hypridle or changes the live session.
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
python3 "$root/shell/quickshell/tests/test_session_policy.py"
python3 -m py_compile "$root/shell/quickshell/scripts/session-policy.py" \
  "$root/shell/quickshell/tests/test_session_policy.py"
