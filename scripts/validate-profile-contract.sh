#!/usr/bin/env bash

# Validate portable profiles and the wallpaper handoff without changing live state.

set -euo pipefail
export LC_ALL=C

readonly REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/senomy-profile-contract.XXXXXX")"
trap 'rm -rf -- "$TEST_ROOT"' EXIT

for profile in automatic desktop touch narrow; do
  file="$REPO_ROOT/deploy/profiles/$profile.json"
  jq -e --arg id "$profile" '
    .schema_version == 1 and .id == $id and
    (.display.scale | IN(1, 1.25, 1.5, 1.75, 2)) and
    (.shell.density | IN("auto", "standard", "compact", "narrow")) and
    (.appearance.font_scale | IN("standard", "large", "touch")) and
    (.file_manager.density | IN("auto", "standard", "touch")) and
    (.wallpaper.asset == "obsidian-default") and
    (.wallpaper.mode | IN("fill", "fit", "stretch", "center", "tile")) and
    (.capabilities.touch_preferred | type == "boolean")
  ' "$file" >/dev/null
  SENOMY_PROFILE="$file" SENOMY_PROFILE_FALLBACK=/dev/null \
    "$REPO_ROOT/scripts/profile-status.sh" |
    jq -e --arg id "$profile" '.ok == true and .data.id == $id and .data.selection_source == "user-selection"' >/dev/null
done

jq -e '.display.scale == 1' "$REPO_ROOT/deploy/profiles/automatic.json" >/dev/null
jq -e '.display.scale == 1' "$REPO_ROOT/deploy/profiles/desktop.json" >/dev/null
jq -e '.display.scale == 1.25' "$REPO_ROOT/deploy/profiles/touch.json" >/dev/null

monitors='[{"id":0,"name":"fixture","focused":true,"width":1920,"height":1080,"scale":1}]'
SENOMY_PROFILE="$REPO_ROOT/deploy/profiles/desktop.json" SENOMY_PREFERENCES=/dev/null \
  SENOMY_MONITORS_JSON="$monitors" "$REPO_ROOT/scripts/bar-layout.sh" |
  jq -e '.data.preferred_density == "standard" and .data.density == "standard"' >/dev/null
SENOMY_PROFILE="$REPO_ROOT/deploy/profiles/narrow.json" SENOMY_PREFERENCES=/dev/null \
  SENOMY_MONITORS_JSON="$monitors" "$REPO_ROOT/scripts/bar-layout.sh" |
  jq -e '.data.preferred_density == "narrow" and .data.density == "narrow"' >/dev/null
printf '{"density":"compact"}\n' >"$TEST_ROOT/preferences.json"
SENOMY_PROFILE="$REPO_ROOT/deploy/profiles/desktop.json" SENOMY_PREFERENCES="$TEST_ROOT/preferences.json" \
  SENOMY_MONITORS_JSON="$monitors" "$REPO_ROOT/scripts/bar-layout.sh" |
  jq -e '.data.preferred_density == "compact" and .data.density == "compact"' >/dev/null
SENOMY_PROFILE="$REPO_ROOT/deploy/profiles/touch.json" SENOMY_PREFERENCES=/dev/null \
  "$REPO_ROOT/scripts/appearance-status.sh" | jq -e '.data.font_scale == "touch"' >/dev/null

printf '%s\n' \
  '#!/usr/bin/env bash' \
  'printf '\''[{"id":0,"name":"fixture","focused":true,"width":%s,"height":%s,"scale":%s}]\n'\'' "${SENOMY_TEST_WIDTH:?}" "${SENOMY_TEST_HEIGHT:?}" "${SENOMY_TEST_SCALE:?}"' \
  >"$TEST_ROOT/hyprctl"
chmod 755 "$TEST_ROOT/hyprctl"
for geometry in \
  '1920 1080 1 actioncenter 960x760' \
  '1920 1080 1 insights 960x760' \
  '1920 1080 1 performance 1480x760' \
  '1920 1080 1 volume-flyout 420x96' \
  '1920 1080 1 tray-flyout 340x150' \
  '1920 1080 1.5 actioncenter 960x590' \
  '1920 1080 1.5 performance 1152x590' \
  '390 844 1 volume-flyout 366x232' \
  '390 844 1 tray-flyout 340x176'; do
  read -r width height scale window expected <<<"$geometry"
  actual="$(SENOMY_HYPRCTL_BIN="$TEST_ROOT/hyprctl" \
    SENOMY_TEST_WIDTH="$width" SENOMY_TEST_HEIGHT="$height" SENOMY_TEST_SCALE="$scale" \
    "$REPO_ROOT/scripts/surface-state.sh" size "$window")"
  [[ "$actual" == "$expected" ]]
done

install -D -m 0644 "$REPO_ROOT/appearance/shared/backgrounds/desktop.png" \
  "$TEST_ROOT/data/senomyos/appearance/backgrounds/desktop.png"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'printf '\''%s\n'\'' "$*" >"$SENOMY_WALLPAPER_LOG"' \
  >"$TEST_ROOT/swaybg"
chmod 755 "$TEST_ROOT/swaybg"
XDG_CONFIG_HOME="$TEST_ROOT/config" XDG_DATA_HOME="$TEST_ROOT/data" \
SENOMY_PROFILE="$REPO_ROOT/deploy/profiles/automatic.json" \
SENOMY_SWAYBG_BIN="$TEST_ROOT/swaybg" SENOMY_WALLPAPER_LOG="$TEST_ROOT/wallpaper.log" \
  "$REPO_ROOT/components/desktop/scripts/senomy-wallpaper"
grep -qxF -- "-c #08090b -m fill -i $TEST_ROOT/data/senomyos/appearance/backgrounds/desktop.png" \
  "$TEST_ROOT/wallpaper.log"

printf 'SenomyOS profiles: schema, display scale, bounded surface geometry, responsive density, and wallpaper handoff passed.\n'
