#!/usr/bin/env bash

# Exercise the Quickshell notification server on a private session bus. The
# live org.freedesktop.Notifications owner is never contacted or displaced.

set -euo pipefail

readonly SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SOURCE_ROOT="${SENOMY_SOURCE_ROOT:-$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd -P)}"
readonly HARNESS_FILE="$SOURCE_ROOT/shell/quickshell/notification-test.qml"

fail() {
  printf 'Quickshell notification validation: %s\n' "$*" >&2
  exit 1
}

ipc() {
  /usr/bin/qs --path "$HARNESS_FILE" ipc call notification-test "$@"
}

notify() {
  /usr/bin/gdbus call --session \
    --dest org.freedesktop.Notifications \
    --object-path /org/freedesktop/Notifications \
    --method org.freedesktop.Notifications.Notify "$@"
}

wait_ready() {
  for _attempt in {1..80}; do
    if /usr/bin/busctl --user call org.freedesktop.DBus /org/freedesktop/DBus \
      org.freedesktop.DBus GetNameOwner s org.freedesktop.Notifications >/dev/null 2>&1 &&
      ipc state >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.1
  done
  return 1
}

start_harness() {
  SENOMY_NOTIFICATION_OWNER=quickshell \
    SENOMY_NOTIFICATION_STORE="$test_root/history.json" \
    QT_QPA_PLATFORM=offscreen \
    /usr/bin/qs --path "$HARNESS_FILE" --no-color >"$test_root/quickshell.log" 2>&1 &
  harness_pid=$!
  if ! wait_ready; then
    /usr/bin/tail -n 80 "$test_root/quickshell.log" >&2 || true
    fail "isolated server did not become ready"
  fi
}

stop_harness() {
  if [[ -n "${harness_pid:-}" ]] && kill -0 "$harness_pid" 2>/dev/null; then
    kill "$harness_pid"
    wait "$harness_pid" 2>/dev/null || true
  fi
  harness_pid=""
}

inner() {
  command -v qs >/dev/null 2>&1 || fail "qs is unavailable"
  command -v gdbus >/dev/null 2>&1 || fail "gdbus is unavailable"
  command -v busctl >/dev/null 2>&1 || fail "busctl is unavailable"
  command -v jq >/dev/null 2>&1 || fail "jq is unavailable"

  test_root="$(mktemp -d "${TMPDIR:-/tmp}/senomy-notification-test.XXXXXX")"
  readonly test_root
  harness_pid=""
  trap 'stop_harness; rm -rf -- "$test_root"' EXIT
  printf '{"schemaVersion":1,"dnd":false,"history":[]}\n' >"$test_root/history.json"
  chmod 600 "$test_root/history.json"

  start_harness

  owner_pid="$(
    /usr/bin/busctl --user call org.freedesktop.DBus /org/freedesktop/DBus \
      org.freedesktop.DBus GetConnectionUnixProcessID s \
      "$(/usr/bin/busctl --user call org.freedesktop.DBus /org/freedesktop/DBus \
        org.freedesktop.DBus GetNameOwner s org.freedesktop.Notifications |
        /usr/bin/sed -n 's/^s "\(.*\)"$/\1/p')" |
      /usr/bin/awk '{print $2}'
  )"
  [[ "$owner_pid" == "$harness_pid" ]] || fail "notification owner PID does not match the harness"

  first_reply="$(
    notify 'Contract App' 0 'dialog-information' 'Original summary' 'Original body' \
      "['open', 'Open']" "{'urgency': <byte 1>, 'resident': <true>}" 0
  )"
  notification_id="$(/usr/bin/sed -n 's/^(uint32 \([0-9][0-9]*\),)$/\1/p' <<<"$first_reply")"
  [[ "$notification_id" =~ ^[1-9][0-9]*$ ]] || fail "Notify did not return a valid ID"

  [[ "$(ipc holdLatestAction)" == held ]] || fail "could not hold original fixture action"
  capabilities="$(/usr/bin/gdbus call --session --dest org.freedesktop.Notifications --object-path /org/freedesktop/Notifications --method org.freedesktop.Notifications.GetCapabilities)"
  [[ "$capabilities" != *"body-images"* && "$capabilities" != *"action-icons"* ]] || fail "unsupported presentation capability advertised"
  monitor_file="$test_root/signals.log"
  /usr/bin/gdbus monitor --session --dest org.freedesktop.Notifications >"$monitor_file" 2>&1 &
  monitor_pid=$!
  sleep 0.2

  notify 'Contract App' "$notification_id" 'dialog-information' 'Replacement summary' 'Replacement body' \
    "['open', 'Open replacement']" "{'urgency': <byte 2>, 'resident': <true>}" 0 >/dev/null
  sleep 0.2
  state="$(ipc state)"
  /usr/bin/jq -e --argjson id "$notification_id" '
    .serverEnabled == true
    and (.history | length) == 1
    and .history[0].id == $id
    and .history[0].summary == "Replacement summary"
    and .history[0].urgency == "Critical"
    and .history[0].resident == true
    and .history[0].actionCount == 1
  ' <<<"$state" >/dev/null || {
    /usr/bin/jq . <<<"$state" >&2
    fail "replacement metadata contract failed"
  }

  [[ "$(ipc invokeHeld)" == missing ]] || fail "stale replacement action was invoked"
  [[ "$(ipc holdLatestAction)" == held ]] || fail "could not hold current action"
  [[ "$(ipc invokeLatest open)" == invoked ]] || fail "notification action was not invoked"
  sleep 0.2
  /usr/bin/grep -q "ActionInvoked.*uint32 $notification_id.*'open'" "$monitor_file" ||
    fail "ActionInvoked signal was not observed"

  /usr/bin/gdbus call --session --dest org.freedesktop.Notifications --object-path /org/freedesktop/Notifications --method org.freedesktop.Notifications.CloseNotification "$notification_id" >/dev/null
  sleep 0.2
  [[ "$(ipc invokeHeld)" == missing ]] || fail "closed notification action was invoked"

  before_generation="$(/usr/bin/jq -r '.toastGeneration' <<<"$(ipc state)")"
  [[ "$(ipc setDnd true)" == true ]] || fail "DND did not enable"
  notify 'Quiet App' 0 '' 'DND summary' 'Recorded without a toast' '[]' "{'urgency': <byte 0>}" 0 >/dev/null
  sleep 0.2
  state="$(ipc state)"
  /usr/bin/jq -e --argjson generation "$before_generation" '
    .dnd == true and .toastGeneration == $generation
    and (.history | any(.summary == "DND summary"))
  ' <<<"$state" >/dev/null || fail "DND retention/toast suppression contract failed"

  retained_before_read="$(/usr/bin/jq -r '.history | length' <<<"$(ipc state)")"
  [[ "$(ipc readLatest)" == read ]] || fail "single-record read failed"
  /usr/bin/jq -e --argjson id "$notification_id" --argjson count "$retained_before_read" '.unreadCount == 1 and (.history | length) == $count and (.history | any(.id == $id and .unread == true))' <<<"$(ipc state)" >/dev/null || fail "single read changed another record or deleted history"
  [[ "$(ipc readLatest)" == unchanged ]] || fail "repeated read was not idempotent"
  [[ "$(ipc readAll)" == read ]] || fail "explicit read all failed"
  /usr/bin/jq -e --argjson count "$retained_before_read" '.unreadCount == 0 and (.history | length) == $count' <<<"$(ipc state)" >/dev/null || fail "read all deleted history"

  notify 'Transient App'  0 '' 'Transient summary' 'Do not persist' '[]' \
    "{'transient': <true>, 'urgency': <byte 1>}" 0 >/dev/null
  sleep 0.2
  state="$(ipc state)"
  /usr/bin/jq -e '
    .latest.summary == "Transient summary" and .latest.transient == true
    and (.history | all(.summary != "Transient summary"))
  ' <<<"$state" >/dev/null || fail "transient retention contract failed"

  [[ "$(ipc setDnd false)" == false ]] || fail "DND did not disable"
  timeout_reply="$(notify 'Timeout App' 0 '' 'Timeout summary' 'Expires' '[]' "{'urgency': <byte 1>}" 250)"
  timeout_id="$(/usr/bin/sed -n 's/^(uint32 \([0-9][0-9]*\),)$/\1/p' <<<"$timeout_reply")"
  sleep 1.4
  state="$(ipc state)"
  /usr/bin/jq -e --argjson id "$timeout_id" '
    .history | any(.id == $id and .closeReason == "Expired")
  ' <<<"$state" >/dev/null || fail "expiry/close-reason contract failed"
  /usr/bin/grep -q "NotificationClosed.*uint32 $timeout_id.*uint32 1" "$monitor_file" ||
    fail "NotificationClosed expiry signal was not observed"

  persisted_count="$(/usr/bin/jq -r '.history | length' <<<"$state")"
  stop_harness
  start_harness
  state="$(ipc state)"
  /usr/bin/jq -e --argjson count "$persisted_count" '
    (.history | length) == $count and .dnd == false
  ' <<<"$state" >/dev/null || fail "private persistence contract failed"

  notify 'Dismiss App' 0 '' 'Dismiss summary' 'Dismiss me' '[]' "{'urgency': <byte 1>}" 0 >/dev/null
  sleep 0.2
  [[ "$(ipc dismissLatest)" == dismissed ]] || fail "per-notification dismissal failed"
  before_clear="$(/usr/bin/jq -r '.history | length' <<<"$(ipc state)")"
  [[ "$(ipc confirmClear)" == rejected ]] || fail "confirmation without request was accepted"
  [[ "$(ipc requestClear)" == pending ]] || fail "clear preview failed"
  [[ "$(ipc cancelClear)" == cancelled ]] || fail "clear cancellation failed"
  /usr/bin/jq -e --argjson count "$before_clear" '.history | length == $count' <<<"$(ipc state)" >/dev/null || fail "cancel changed history"
  [[ "$(ipc requestClear)" == pending ]] || fail "second clear preview failed"
  notify 'Race App' 0 '' 'New after preview' 'Retain until reviewed' '[]' "{'urgency': <byte 1>}" 0 >/dev/null
  sleep 0.2
  [[ "$(ipc confirmClear)" == rejected ]] || fail "stale preview cleared new notifications"
  /usr/bin/jq -e '.history | any(.summary == "New after preview")' <<<"$(ipc state)" >/dev/null || fail "new notification was lost"

  # Simulate an unwritable destination using only the private fixture store.
  mv "$test_root/history.json" "$test_root/history-before.json"
  mkdir "$test_root/history.json"
  [[ "$(ipc requestClear)" == pending ]] || fail "failure preview failed"
  ipc confirmClear >/dev/null
  sleep 0.2
  /usr/bin/jq -e '.clearState == "failed" and (.clearMessage | contains("saving failed"))' <<<"$(ipc state)" >/dev/null || fail "save failure was not reported"
  rmdir "$test_root/history.json"
  mv "$test_root/history-before.json" "$test_root/history.json"

  notify 'Clear App' 0 '' 'Clear summary' 'Clear with confirmation' '[]' "{'urgency': <byte 1>}" 0 >/dev/null
  sleep 0.2
  [[ "$(ipc requestClear)" == pending ]] || fail "final preview failed"
  [[ "$(ipc confirmClear)" == confirmed ]] || fail "clear confirmation failed"
  sleep 0.2
  /usr/bin/jq -e '.clearState == "succeeded" and .activeCount == 0 and (.history | length == 0)' <<<"$(ipc state)" >/dev/null || fail "clear result was not verified"
  /usr/bin/jq -e '.history | length == 0' "$test_root/history.json" >/dev/null || fail "cleared history was not persisted"
  stop_harness
  start_harness
  /usr/bin/jq -e '.history | length == 0' <<<"$(ipc state)" >/dev/null || fail "history returned after restart"

  kill "$monitor_pid" 2>/dev/null || true
  wait "$monitor_pid" 2>/dev/null || true
  printf 'PASS  isolated Quickshell notification ownership and behavior\n'
}

if [[ "${1:-}" == --inner ]]; then
  inner
else
  exec /usr/bin/dbus-run-session -- "$SCRIPT_PATH" --inner
fi
