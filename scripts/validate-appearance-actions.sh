#!/usr/bin/env bash

# Exercise every appearance preference category against a temporary mode-0600
# file. Eww publication is disabled, so live user choices are never changed.
set -euo pipefail
export LC_ALL=C

readonly CONFIG_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly TEST_ROOT="$(mktemp -d /tmp/senomy-appearance-actions.XXXXXX)"
readonly PREFERENCES="$TEST_ROOT/preferences.json"
trap 'rm -rf "$TEST_ROOT"' EXIT

apply() {
  SENOMY_PREFERENCES="$PREFERENCES" SENOMY_SETTINGS_RUNTIME_DIR="$TEST_ROOT/runtime" \
    SENOMY_EWW_CONFIG="$CONFIG_DIR" "$CONFIG_DIR/scripts/settings-action.sh" "$1" "$2"
}

apply set-density narrow
apply set-font-family iosevka
apply set-font-scale touch
apply set-heading-scale large
apply set-body-scale large
apply set-meta-scale large
apply set-title-px 22
apply set-body-px 16
apply set-meta-px 13
apply set-nav-px 15
apply set-rail-px 14
apply set-accent amber
apply set-gradient off

[[ "$(stat -c %a "$PREFERENCES")" == 600 ]]
jq -e '
  .schema_version == 3
  and .density == "narrow"
  and .font_family == "iosevka"
  and .font_scale == "touch"
  and .heading_scale == "large"
  and .body_scale == "large"
  and .meta_scale == "large"
  and .title_px == 22 and .body_px == 16 and .meta_px == 13
  and .nav_px == 15 and .rail_px == 14
  and .accent == "amber" and .gradient == "off"
' >/dev/null "$PREFERENCES"

resolved="$(SENOMY_PREFERENCES="$PREFERENCES" "$CONFIG_DIR/scripts/appearance-status.sh")"
jq -e '
  .ok == true and .data.font_family == "iosevka"
  and .data.title_px == 22 and .data.body_px == 16
  and .data.meta_px == 13 and .data.nav_px == 15 and .data.rail_px == 14
  and .data.accent == "amber" and .data.gradient == "off"
' >/dev/null <<<"$resolved"

SENOMY_SETTINGS_RUNTIME_DIR="$TEST_ROOT/runtime" "$CONFIG_DIR/scripts/settings-action.sh" status |
  jq -e '.ok == true and .data.state == "succeeded" and .data.progress_percent == 100' >/dev/null

if apply set-title-px 99 >/dev/null 2>&1; then
  printf 'Invalid title size was accepted\n' >&2
  exit 1
fi
if apply set-accent chartreuse >/dev/null 2>&1; then
  printf 'Invalid accent was accepted\n' >&2
  exit 1
fi

printf 'SenomyOS appearance actions: all preference categories and rejection bounds passed.\n'
