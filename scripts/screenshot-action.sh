#!/usr/bin/env bash
set -euo pipefail
SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
exec "$(dirname "$SCRIPT_PATH")/senomy-screenshot" "$@"
