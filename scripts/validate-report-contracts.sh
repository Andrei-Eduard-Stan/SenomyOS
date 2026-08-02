#!/usr/bin/env bash

# Generate every report profile in temporary private storage and validate its
# artifact, manifest, policy, and deletion lifecycle.
set -euo pipefail
export LC_ALL=C

readonly CONFIG_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly TEST_ROOT="$(mktemp -d /tmp/senomy-report-contracts.XXXXXX)"
trap 'rm -rf "$TEST_ROOT"' EXIT

pass=0
for profile in overview performance network power full; do
  payload="$(SENOMY_REPORT_ROOT="$TEST_ROOT" "$CONFIG_DIR/scripts/performance-report.sh" generate-json "$profile" 2>/dev/null)"
  path="$(jq -r '.data.latest.path' <<<"$payload")"
  id="$(jq -r '.data.latest.id' <<<"$payload")"
  manifest="$TEST_ROOT/report-$id.json"

  jq -e --arg profile "$profile" --arg root "$TEST_ROOT" '
    .ok == true
    and .data.exists == true
    and .data.latest.profile == $profile
    and (.data.latest.path | startswith($root + "/report-"))
    and (.data.latest.sections | type == "array" and length > 0)
    and .data.latest.privacy.mode == "0600"
    and .data.latest.privacy.uploaded == false
    and .data.latest.privacy.credentials_included == false
  ' >/dev/null <<<"$payload"
  [[ -s "$path" && -s "$manifest" ]]
  [[ "$(stat -c %a "$path")" == 600 && "$(stat -c %a "$manifest")" == 600 ]]

  SENOMY_REPORT_ROOT="$TEST_ROOT" "$CONFIG_DIR/scripts/performance-report.sh" delete-latest "$profile" >/dev/null
  [[ ! -e "$path" && ! -e "$manifest" ]]
  pass=$((pass + 1))
done

printf 'SenomyOS report contracts: %d profiles generated and deleted safely.\n' "$pass"
