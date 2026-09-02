#!/usr/bin/env bash

# Exercise the companion controller against a stateful fake Eww client. No
# live daemon or compositor window is touched.

set -euo pipefail

readonly CONFIG_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly TEST_ROOT="$(mktemp -d /tmp/senomy-companion-contract.XXXXXX)"
trap 'rm -rf -- "$TEST_ROOT"' EXIT INT TERM HUP

cat >"$TEST_ROOT/eww" <<'MOCK'
#!/usr/bin/env bash
set -eu
root="${SENOMY_COMPANION_MOCK_ROOT:?}"
while (($#)); do
  case "$1" in
    --no-daemonize) shift ;;
    --config) shift 2 ;;
    *) break ;;
  esac
done
command="${1:-}"
shift || true
case "$command" in
  get)
    file="$root/var-${1:?}"
    [[ -f "$file" ]] && cat "$file" || exit 1
    ;;
  update)
    for assignment in "$@"; do
      name="${assignment%%=*}"
      value="${assignment#*=}"
      printf '%s\n' "$value" >"$root/var-$name"
    done
    ;;
  active-windows)
    [[ -f "$root/window" ]] && printf 'companion: companion\n'
    ;;
  open)
    touch "$root/window"
    ;;
  close)
    rm -f "$root/window"
    ;;
  *) exit 2 ;;
esac
MOCK

cat >"$TEST_ROOT/hyprctl" <<'MOCK'
#!/usr/bin/env bash
printf '[{"id":2,"focused":true,"width":1920,"height":1080,"scale":1}]\n'
MOCK

chmod 0755 "$TEST_ROOT/eww" "$TEST_ROOT/hyprctl"
printf 'closed\n' >"$TEST_ROOT/var-companion_mode"
printf 'right\n' >"$TEST_ROOT/var-companion_dock"
printf 'false\n' >"$TEST_ROOT/var-companion_pinned"

run_controller() {
  env \
    EWW_BIN="$TEST_ROOT/eww" \
    EWW_CONFIG="$CONFIG_DIR" \
    SENOMY_HYPRCTL_BIN="$TEST_ROOT/hyprctl" \
    SENOMY_COMPANION_MOCK_ROOT="$TEST_ROOT" \
    SENOMY_COMPANION_RUNTIME_DIR="$TEST_ROOT/runtime" \
    SENOMY_COMPANION_EXPANDED_SECONDS=600 \
    "$CONFIG_DIR/scripts/companion-state.sh" "$@"
}

run_controller open
[[ "$(cat "$TEST_ROOT/var-companion_mode")" == expanded && -f "$TEST_ROOT/window" ]]

run_controller collapse
[[ "$(cat "$TEST_ROOT/var-companion_mode")" == compact && -f "$TEST_ROOT/window" ]]

run_controller dock
[[ "$(cat "$TEST_ROOT/var-companion_dock")" == left && -f "$TEST_ROOT/window" ]]

run_controller pin
[[ "$(cat "$TEST_ROOT/var-companion_pinned")" == true ]]

run_controller toggle
[[ "$(cat "$TEST_ROOT/var-companion_mode")" == closed && ! -f "$TEST_ROOT/window" ]]

printf 'SenomyOS companion controller: open, collapse, dock, pin and close passed.\n'
