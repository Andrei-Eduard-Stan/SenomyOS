#!/usr/bin/env bash

# Exercise state-changing action failure paths with inert binaries and private
# runtime directories. No live service or Eww state is modified.
set -euo pipefail
export LC_ALL=C

readonly CONFIG_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly TEST_ROOT="$(mktemp -d /tmp/senomy-action-contracts.XXXXXX)"
trap 'rm -rf "$TEST_ROOT"' EXIT

pass=0
check_failure() {
  local domain="$1" script="$2" action="$3"
  shift 3
  local runtime="$TEST_ROOT/$domain" status exit_code
  mkdir -p "$runtime"

  set +e
  env XDG_RUNTIME_DIR="$runtime" SENOMY_EWW_BIN=/usr/bin/false \
    SENOMY_EWW_CONFIG=/tmp/senomy-no-config "$@" \
    "$CONFIG_DIR/scripts/$script" "$action" >/dev/null 2>&1
  exit_code=$?
  set -e

  ((exit_code != 0)) || return 1
  status="$(env XDG_RUNTIME_DIR="$runtime" SENOMY_EWW_BIN=/usr/bin/false \
    SENOMY_EWW_CONFIG=/tmp/senomy-no-config "$@" \
    "$CONFIG_DIR/scripts/$script" status)"
  jq -e --arg action "$action" --argjson exit_code "$exit_code" '
    .ok == true
    and .data.state == "failed"
    and .data.action == $action
    and .data.exit_code == $exit_code
    and (.data.message | type == "string" and length > 0)
  ' >/dev/null <<<"$status"

  printf 'PASS  %-26s exit=%s\n' "$domain rejection" "$exit_code"
  pass=$((pass + 1))
}

check_failure network network-action.sh wifi-enable \
  SENOMY_NMCLI_BIN=/usr/bin/false
check_failure audio audio-action.sh toggle-input-mute \
  SENOMY_PACTL_BIN=/usr/bin/false
check_failure power power-action.sh performance \
  SENOMY_TLP_BIN=/usr/bin/true SENOMY_PKEXEC_BIN=/usr/bin/false

runtime="$TEST_ROOT/performance"
mkdir -p "$runtime"
set +e
XDG_RUNTIME_DIR="$runtime" SENOMY_EWW_BIN=/usr/bin/false \
  SENOMY_EWW_CONFIG=/tmp/senomy-no-config \
  "$CONFIG_DIR/scripts/performance-action.sh" terminate 999999999 >/dev/null 2>&1
exit_code=$?
set -e
status="$(XDG_RUNTIME_DIR="$runtime" SENOMY_EWW_BIN=/usr/bin/false \
  "$CONFIG_DIR/scripts/performance-action.sh" status)"
((exit_code != 0))
jq -e --argjson exit_code "$exit_code" '
  .data.state == "failed"
  and .data.action == "terminate"
  and .data.exit_code == $exit_code
  and (.data.message | length > 0)
' >/dev/null <<<"$status"
printf 'PASS  %-26s exit=%s\n' "performance rejection" "$exit_code"
pass=$((pass + 1))

runtime="$TEST_ROOT/brightness"
mkdir -p "$runtime"
set +e
XDG_RUNTIME_DIR="$runtime" SENOMY_EWW_BIN=/usr/bin/false \
  SENOMY_EWW_CONFIG=/tmp/senomy-no-config SENOMY_BRIGHTNESSCTL_BIN=/usr/bin/false \
  "$CONFIG_DIR/scripts/brightness-action.sh" set 25 >/dev/null 2>&1
exit_code=$?
set -e
status="$(XDG_RUNTIME_DIR="$runtime" SENOMY_EWW_BIN=/usr/bin/false \
  "$CONFIG_DIR/scripts/brightness-action.sh" status)"
((exit_code != 0))
jq -e --argjson exit_code "$exit_code" '
  .data.state == "failed"
  and .data.action == "set"
  and .data.exit_code == $exit_code
  and (.data.message | length > 0)
' >/dev/null <<<"$status"
printf 'PASS  %-26s exit=%s\n' "brightness rejection" "$exit_code"
pass=$((pass + 1))

ACTION_LOG="$TEST_ROOT/session-actions.log"
cat >"$TEST_ROOT/fake-action" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$SENOMY_TEST_ACTION_LOG"
EOF
chmod 755 "$TEST_ROOT/fake-action"

for action in lock suspend logout reboot poweroff; do
  SENOMY_TEST_ACTION_LOG="$ACTION_LOG" \
  SENOMY_LOCK_BIN="$TEST_ROOT/fake-action" \
  SENOMY_SYSTEMCTL_BIN="$TEST_ROOT/fake-action" \
  SENOMY_HYPRCTL_BIN="$TEST_ROOT/fake-action" \
    "$CONFIG_DIR/scripts/session-action.sh" "$action"
done
diff -u <(printf '%s\n' '' 'suspend' 'dispatch exit' 'reboot' 'poweroff') "$ACTION_LOG"
if SENOMY_TEST_ACTION_LOG="$ACTION_LOG" \
  SENOMY_LOCK_BIN="$TEST_ROOT/fake-action" \
  SENOMY_SYSTEMCTL_BIN="$TEST_ROOT/fake-action" \
  SENOMY_HYPRCTL_BIN="$TEST_ROOT/fake-action" \
    "$CONFIG_DIR/scripts/session-action.sh" shell >/dev/null 2>&1; then
  printf 'Session action allowlist unexpectedly accepted shell.\n' >&2
  exit 1
fi
printf 'PASS  %-26s\n' "session action allowlist"
pass=$((pass + 1))

: >"$ACTION_LOG"
SENOMY_TEST_ACTION_LOG="$ACTION_LOG" SENOMY_SWAYNC_CLIENT_BIN="$TEST_ROOT/fake-action" \
  "$CONFIG_DIR/scripts/notification-action.sh" toggle-dnd
SENOMY_TEST_ACTION_LOG="$ACTION_LOG" SENOMY_SWAYNC_CLIENT_BIN="$TEST_ROOT/fake-action" \
  "$CONFIG_DIR/scripts/notification-action.sh" close-all
diff -u <(printf '%s\n' '--toggle-dnd' '--close-all') "$ACTION_LOG"
if SENOMY_TEST_ACTION_LOG="$ACTION_LOG" SENOMY_SWAYNC_CLIENT_BIN="$TEST_ROOT/fake-action" \
  "$CONFIG_DIR/scripts/notification-action.sh" execute >/dev/null 2>&1; then
  printf 'Notification action allowlist unexpectedly accepted execute.\n' >&2
  exit 1
fi
printf 'PASS  %-26s\n' "notification action allowlist"
pass=$((pass + 1))

printf '\nSenomyOS action contracts: %d rejection paths passed.\n' "$pass"
