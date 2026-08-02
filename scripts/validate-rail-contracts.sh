#!/usr/bin/env bash

# Isolated rail behavior checks for moving dialogue and bounded history.
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

history="$(SENOMY_HISTORY_RUNTIME_DIR="$TEST_ROOT/history" "$CONFIG_DIR/scripts/performance-history.sh" read)"
jq -e '.ok == true and .window_seconds == 300 and .sample_interval_seconds == 10 and (.data.samples | type == "array")' >/dev/null <<<"$history"
printf 'PASS  Performance history contract remains bounded to five minutes\n'
