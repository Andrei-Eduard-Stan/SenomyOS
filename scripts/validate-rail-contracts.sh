#!/usr/bin/env bash

# Isolated Rail behavior checks for moving dialogue, workspace normalization,
# bounded history, and truthful notification state.
set -euo pipefail
export LC_ALL=C

readonly CONFIG_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly TEST_ROOT="$(mktemp -d /tmp/senomy-rail-contracts.XXXXXX)"
trap 'rm -rf "$TEST_ROOT"' EXIT

cat >"$TEST_ROOT/battery" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' '{"available":false}'
EOF
cat >"$TEST_ROOT/dialogue" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' '{"data":{"text":"Long diagnostics remain useful when the message viewport moves calmly across the complete observation."}}'
EOF
chmod 755 "$TEST_ROOT/battery" "$TEST_ROOT/dialogue"

timeout 1s env \
  SENOMY_BATTERY_BIN="$TEST_ROOT/battery" \
  SENOMY_DIALOGUE_BIN="$TEST_ROOT/dialogue" \
  SENOMY_EWW_BIN=/usr/bin/false \
  SENOMY_RAIL_MESSAGE_WIDTH=24 \
  SENOMY_RAIL_MESSAGE_HOLD_STEPS=1 \
  SENOMY_RAIL_MESSAGE_STEP_DELAY=0.01 \
  "$CONFIG_DIR/scripts/senomy-rail-message.sh" >"$TEST_ROOT/frames" || true

[[ "$(wc -l <"$TEST_ROOT/frames")" -gt 3 ]]
awk 'length($0) > 24 { exit 1 }' "$TEST_ROOT/frames"
[[ "$(sort -u "$TEST_ROOT/frames" | wc -l)" -gt 2 ]]
printf 'PASS  Senomy long-message viewport emits moving bounded frames\n'

workspace_fixture='{
  "workspaces": [{"id": 2}, {"id": 6}, {"id": -98}],
  "active_workspace": {"id": 6},
  "clients": [
    {"mapped": true, "hidden": false, "workspace": {"id": 6}, "initialClass": "firefox"},
    {"mapped": true, "hidden": false, "workspace": {"id": 6}, "initialClass": "kitty"},
    {"mapped": true, "hidden": false, "workspace": {"id": 6}, "initialClass": "thunar"},
    {"mapped": true, "hidden": false, "workspace": {"id": 6}, "initialClass": "code"},
    {"mapped": true, "hidden": false, "workspace": {"id": 6}, "initialClass": "org.gnome.Calculator"},
    {"mapped": true, "hidden": false, "workspace": {"id": 2}, "initialClass": "firefox"},
    {"mapped": true, "hidden": false, "workspace": {"id": 2}, "initialClass": "kitty"},
    {"mapped": true, "hidden": false, "workspace": {"id": 2}, "initialClass": "thunar"}
  ]
}'
workspace_state="$(
  SENOMY_WORKSPACE_SNAPSHOT_JSON="$workspace_fixture" \
    "$CONFIG_DIR/scripts/workspaces.sh" --print-once
)"
jq -e '
  [.data.workspaces[].id] == [2, 6]
  and .data.active_id == 6
  and (
    .data.workspaces[]
    | select(.id == 2)
    | .app_count == 3
      and .overflow_count == 2
      and (.grid_rows | map(length)) == [2]
      and .grid_rows[0][1].kind == "overflow"
  )
  and (
    .data.workspaces[]
    | select(.id == 6)
    | .app_count == 5
      and .overflow_count == 2
      and (.grid_rows | map(length)) == [2, 2]
      and .grid_rows[1][1].kind == "overflow"
  )
' >/dev/null <<<"$workspace_state"

special_active_fixture='{
  "workspaces": [{"id": 2}, {"id": -98}],
  "active_workspace": {"id": -98},
  "clients": []
}'
special_active_state="$(
  SENOMY_WORKSPACE_SNAPSHOT_JSON="$special_active_fixture" \
    "$CONFIG_DIR/scripts/workspaces.sh" --print-once
)"
jq -e '
  .data.active_id == 2
  and [.data.workspaces[].id] == [2]
' >/dev/null <<<"$special_active_state"
printf 'PASS  Workspace state follows real IDs and bounded active/inactive grids\n'
"$CONFIG_DIR/scripts/validate-workspace-carousel.sh"

history="$(SENOMY_HISTORY_RUNTIME_DIR="$TEST_ROOT/history" "$CONFIG_DIR/scripts/performance-history.sh" read)"
jq -e '.ok == true and .window_seconds == 300 and .sample_interval_seconds == 10 and (.data.samples | type == "array")' >/dev/null <<<"$history"
printf 'PASS  Performance history contract remains bounded to five minutes\n'

cat >"$TEST_ROOT/swaync-client" <<'EOF'
#!/usr/bin/env bash
[[ "${1:-}" == --subscribe ]] || exit 2
printf '%s\n' '{ "count": 3, "dnd": false, "visible": false, "inhibited": false }'
sleep 2
EOF
chmod 755 "$TEST_ROOT/swaync-client"

timeout 0.2s env \
  SENOMY_SWAYNC_CLIENT_BIN="$TEST_ROOT/swaync-client" \
  "$CONFIG_DIR/scripts/bar-notification-listener.sh" >"$TEST_ROOT/notification-frames" || true
jq -e 'select(.ok == true) | .data.available == true and .data.count == 3 and .data.dnd == false' \
  "$TEST_ROOT/notification-frames" >/dev/null
printf 'PASS  Rail notification listener preserves truthful event state\n'
