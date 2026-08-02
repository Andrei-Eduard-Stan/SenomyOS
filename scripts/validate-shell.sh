#!/usr/bin/env bash

# Non-destructive SenomyOS validation. Use --live to add daemon/window checks;
# neither mode reloads Eww, restarts services, or changes system state.
set -euo pipefail
export LC_ALL=C

readonly MODE="${1:-static}"
readonly CONFIG_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

case "$MODE" in static | --live) ;; *) printf 'Usage: %s [--live]\n' "$0" >&2; exit 2 ;; esac

pass=0
check() {
  local label="$1"
  shift
  printf 'CHECK  %-34s' "$label"
  if "$@"; then
    printf ' PASS\n'
    pass=$((pass + 1))
  else
    printf ' FAIL\n' >&2
    return 1
  fi
}

check "Bash syntax" bash -c 'for file in "$1"/scripts/*.sh; do bash -n "$file" || exit; done' _ "$CONFIG_DIR"
check "SCSS compilation" sassc -t compressed "$CONFIG_DIR/eww.scss" /tmp/senomyos-eww-validation.css
check "Tracked JSON syntax" bash -c 'for file in "$1"/data/*.json; do jq -e . "$file" >/dev/null || exit; done' _ "$CONFIG_DIR"
check "Wiki catalog contract" bash -c '"$1/scripts/wiki-status.py" catalog | jq -e ".schema_version >= 1 and (.ok|type == \"boolean\") and (.data.articles|type == \"array\")" >/dev/null' _ "$CONFIG_DIR"
check "Appearance contract" bash -c '"$1/scripts/appearance-status.sh" | jq -e ".ok == true and (.data.title_px|type == \"number\") and (.data.accent|IN(\"cyan\",\"violet\",\"amber\"))" >/dev/null' _ "$CONFIG_DIR"
check "Responsive layout fixtures" bash -c '
  check_layout() {
    local width="$1" height="$2" scale="$3" expected="$4" logical="$5" phone="$6" payload
    payload="$(SENOMY_PREFERENCES=/dev/null SENOMY_MONITORS_JSON="[{\"id\":0,\"name\":\"fixture\",\"focused\":true,\"width\":$width,\"height\":$height,\"scale\":$scale}]" "$7/scripts/bar-layout.sh")"
    jq -e --arg expected "$expected" --argjson logical "$logical" --argjson phone "$phone" ".ok == true and .data.density == \$expected and .data.width == \$logical and .data.phone == \$phone" >/dev/null <<<"$payload"
  }
  check_layout 1920 1080 1 standard 1920 false "$1" &&
  check_layout 1366 768 1 compact 1366 false "$1" &&
  check_layout 720 1280 1 narrow 720 false "$1" &&
  check_layout 390 844 1 narrow 390 true "$1" &&
  check_layout 2560 1600 2 compact 1280 false "$1"
' _ "$CONFIG_DIR"
check "Console catalog contract" bash -c '"$1/scripts/console-status.sh" catalog | jq -e ".ok == true and (.data.tasks|length > 0) and (.data.shells|length > 0)" >/dev/null' _ "$CONFIG_DIR"
check "Diagnostics catalog contract" bash -c '"$1/scripts/diagnostics-status.sh" catalog | jq -e ".ok == true and (.data.tasks|length > 0)" >/dev/null' _ "$CONFIG_DIR"
check "Tracked Escape dispatcher" grep -qF "bindn = , Escape, exec, /usr/bin/env sh -c '\$HOME/.config/eww/scripts/surface-state.sh dismiss'" "$CONFIG_DIR/hyprland.conf"
check "Workspace event contract" bash -c '
  grep -q "^readonly FULL_RESYNC_SECONDS=300$" "$1/scripts/workspaces.sh" &&
    grep -q "openwindow>>" "$1/scripts/workspaces.sh" &&
    grep -q "movewindowv2>>" "$1/scripts/workspaces.sh" &&
    grep -q -- "--publish-once" "$1/scripts/start-eww.sh" &&
    [[ "$(stat -c %a "$1/systemd/workspaces.service")" == 644 ]]
' _ "$CONFIG_DIR"
check "GTK stylesheet contract" bash -c '
  ! grep -qF "var(--" "$1/eww.scss" &&
    ! grep -R -nE "data\\?\\.phone[[:space:]]+\\?[[:space:]]+\"" "$1/windows" "$1/widgets" "$1/sections" >/dev/null
' _ "$CONFIG_DIR"
check "Session startup contract" "$CONFIG_DIR/scripts/validate-startup-contract.sh"
check "Rail behavior contracts" "$CONFIG_DIR/scripts/validate-rail-contracts.sh"
check "Action failure contracts" "$CONFIG_DIR/scripts/validate-action-contracts.sh"
check "Surface data contracts" "$CONFIG_DIR/scripts/validate-data-contracts.sh"
check "Insights action contracts" "$CONFIG_DIR/scripts/validate-insights-actions.sh"
check "Report lifecycle contracts" "$CONFIG_DIR/scripts/validate-report-contracts.sh"
check "Appearance action contracts" "$CONFIG_DIR/scripts/validate-appearance-actions.sh"
check "Git whitespace" git -C "$CONFIG_DIR" diff --check

if [[ "$MODE" == --live ]]; then
  check "Eww daemon" eww --config "$CONFIG_DIR" ping
  check "Single main bar" bash -c '
    windows="$(eww --config "$1" active-windows)"
    [[ "$(grep -cE "^[^:]+: main-bar$" <<<"$windows")" -eq 1 ]]
  ' _ "$CONFIG_DIR"
  check "Surface state contract" bash -c '
    payload="$("$1/scripts/surface-state.sh" status)"
    grep -qE "^active_surface=(none|control|performance|insights)$" <<<"$payload" &&
      grep -qE "^active_flyout=(none|volume|tray)$" <<<"$payload"
  ' _ "$CONFIG_DIR"
fi

printf '\nSenomyOS validation: %d checks passed (%s mode).\n' "$pass" "$MODE"
