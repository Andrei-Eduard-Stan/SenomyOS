#!/usr/bin/env bash

# Exercise launcher readiness without touching the live Eww daemon.
set -euo pipefail
export LC_ALL=C

readonly CONFIG_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly TEST_ROOT="$(mktemp -d /tmp/senomy-startup-contract.XXXXXX)"
trap 'rm -rf "$TEST_ROOT"' EXIT

cat >"$TEST_ROOT/eww" <<'EOF'
#!/usr/bin/env bash
set -eu
root="${SENOMY_MOCK_ROOT:?}"
command_name=""
for argument in "$@"; do
  case "$argument" in daemon | ping | list-windows | active-windows | open) command_name="$argument"; break ;; esac
done
case "$command_name" in
  daemon) : >"$root/daemon" ;;
  ping) [[ -f "$root/daemon" ]] ;;
  list-windows) [[ "${SENOMY_MOCK_EMPTY:-false}" == false ]] && printf 'main-bar\n' ;;
  active-windows) [[ -f "$root/active" ]] && printf 'main-bar: main-bar\n' ;;
  open) : >"$root/active" ;;
  *) exit 2 ;;
esac
EOF
chmod 755 "$TEST_ROOT/eww"

export SENOMY_MOCK_ROOT="$TEST_ROOT"
export EWW_BIN="$TEST_ROOT/eww"
export EWW_CONFIG="$CONFIG_DIR"
export SENOMY_HYPRCTL_BIN=/nonexistent
export EWW_READY_ATTEMPTS=3
export EWW_READY_DELAY=0.01

"$CONFIG_DIR/scripts/start-eww.sh"
[[ -f "$TEST_ROOT/active" ]] || { printf 'Launcher did not open main-bar\n' >&2; exit 1; }
printf 'PASS  healthy cold start reaches active main-bar\n'

rm -f "$TEST_ROOT/active"
export SENOMY_MOCK_EMPTY=true
if "$CONFIG_DIR/scripts/start-eww.sh" >"$TEST_ROOT/empty.out" 2>&1; then
  printf 'Launcher accepted an empty daemon\n' >&2
  exit 1
fi
grep -Eq 'did not load the main-bar definition|Unable to replace an empty Eww daemon' "$TEST_ROOT/empty.out"
printf 'PASS  empty daemon is rejected when safe replacement is unavailable\n'
