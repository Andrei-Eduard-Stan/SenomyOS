#!/usr/bin/env bash

# Isolated screenshot lifecycle contract. No real Eww, Hyprland, systemd, or
# Flameshot process is contacted.
set -euo pipefail
export LC_ALL=C

readonly REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/senomy-screenshot-contract.XXXXXX")"
trap 'rm -rf -- "$fixture"' EXIT

mkdir -p "$fixture/bin" "$fixture/runtime" "$fixture/eww/scripts"
state_file="$fixture/client-state"
surface_log="$fixture/surface.log"
companion_log="$fixture/companion.log"
printf 'closed\n' >"$state_file"

printf '%s\n' \
  '#!/usr/bin/env bash' \
  "if [[ \"\$(cat '$state_file')\" == open ]]; then" \
  "  printf '[{\"class\":\"flameshot\",\"initialTitle\":\"flameshot\"}]\\n'" \
  'else' \
  "  printf '[]\\n'" \
  'fi' >"$fixture/bin/hyprctl"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  '[[ "${1:-}" == gui ]] || exit 2' \
  "printf 'open\\n' >'$state_file'" \
  'sleep 0.30' \
  "printf 'closed\\n' >'$state_file'" >"$fixture/bin/flameshot"
printf '%s\n' '#!/usr/bin/env bash' 'exit 0' >"$fixture/bin/systemctl"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  '[[ "${*: -1}" == ping ]]' >"$fixture/bin/eww"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  "printf '%s\\n' \"\${1:-}\" >>'$surface_log'" >"$fixture/eww/scripts/surface-state.sh"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  "printf '%s\\n' \"\${1:-}\" >>'$companion_log'" >"$fixture/eww/scripts/companion-state.sh"
chmod +x "$fixture/bin/"* "$fixture/eww/scripts/"*

XDG_RUNTIME_DIR="$fixture/runtime" \
EWW_CONFIG="$fixture/eww" \
SENOMY_EWW_BIN="$fixture/bin/eww" \
SENOMY_FLAMESHOT_BIN="$fixture/bin/flameshot" \
SENOMY_SYSTEMCTL_BIN="$fixture/bin/systemctl" \
SENOMY_HYPRCTL_BIN="$fixture/bin/hyprctl" \
SENOMY_JQ_BIN="$(command -v jq)" \
SENOMY_SURFACE_STATE_BIN="$fixture/eww/scripts/surface-state.sh" \
SENOMY_COMPANION_STATE_BIN="$fixture/eww/scripts/companion-state.sh" \
SENOMY_SCREENSHOT_FREEZE_SECONDS=0.01 \
SENOMY_SCREENSHOT_POLL_SECONDS=0.01 \
"$REPO_ROOT/scripts/screenshot-action.sh" capture

mapfile -t surface_actions <"$surface_log"
mapfile -t companion_actions <"$companion_log"
[[ "${surface_actions[*]}" == "capture-suspend capture-restore" ]]
[[ "${companion_actions[*]}" == "capture-suspend capture-restore" ]]
! grep -qx dismiss "$surface_log"

printf 'SenomyOS screenshot: frozen-frame suspend/restore lifecycle passed.\n'
