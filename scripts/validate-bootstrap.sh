#!/usr/bin/env bash

# Clean-home and clean-system-root acceptance for the real deployment manifests.

set -euo pipefail
export LC_ALL=C

readonly REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/senomy-clean-acceptance.XXXXXX")"
trap 'rm -rf -- "$TEST_ROOT"' EXIT
readonly TEST_HOME="$TEST_ROOT/home/senomy"
readonly TEST_CONFIG="$TEST_HOME/.config"
readonly TEST_DATA="$TEST_HOME/.local/share"
readonly TEST_STATE="$TEST_HOME/.local/state"
readonly TEST_RUNTIME="$TEST_ROOT/runtime"
readonly TEST_BIN="$TEST_ROOT/bin"
readonly SYSTEM_ROOT="$TEST_ROOT/system-root"
mkdir -p "$TEST_HOME" "$TEST_CONFIG" "$TEST_DATA" "$TEST_STATE" "$TEST_RUNTIME" "$TEST_BIN" "$SYSTEM_ROOT"
install -D -m 0755 "$REPO_ROOT/scripts/workspaces.sh" "$TEST_CONFIG/eww/scripts/workspaces.sh"

printf '%s\n' \
  '#!/usr/bin/env bash' \
  'if [[ "$1" == -Q && "$3" == "eww" && "${SENOMY_TEST_MISSING_EWW:-0}" == 1 ]]; then exit 1; fi' \
  '[[ "$1" == -Q ]] && exit 0' \
  'exit 0' >"$TEST_BIN/pacman"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'case " $* " in *" is-enabled "*) printf '\''enabled\n'\'';; *) exit 0;; esac' >"$TEST_BIN/systemctl"
printf '%s\n' '#!/usr/bin/env bash' 'exit 1' >"$TEST_BIN/pgrep"
chmod 755 "$TEST_BIN/pacman" "$TEST_BIN/systemctl" "$TEST_BIN/pgrep"

run_bootstrap() {
  HOME="$TEST_HOME" XDG_CONFIG_HOME="$TEST_CONFIG" XDG_DATA_HOME="$TEST_DATA" \
  XDG_STATE_HOME="$TEST_STATE" XDG_RUNTIME_DIR="$TEST_RUNTIME" \
  SENOMY_PACMAN_BIN="$TEST_BIN/pacman" SENOMY_SYSTEMCTL_BIN="$TEST_BIN/systemctl" \
  PATH="$TEST_BIN:/usr/bin" "$REPO_ROOT/scripts/senomy-bootstrap.sh" "$@"
}

run_bootstrap audit | jq -e '.ok == true and (.data.missing_required_packages | length) == 0' >/dev/null
SENOMY_TEST_MISSING_EWW=1 run_bootstrap audit |
  jq -e '.ok == false and (.data.missing_required_packages | map(.package) | index("eww")) != null' >/dev/null

run_user_deploy() {
  HOME="$TEST_HOME" XDG_CONFIG_HOME="$TEST_CONFIG" XDG_DATA_HOME="$TEST_DATA" \
  XDG_STATE_HOME="$TEST_STATE" XDG_RUNTIME_DIR="$TEST_RUNTIME" PATH="$TEST_BIN:/usr/bin" \
    "$REPO_ROOT/scripts/senomy-deploy.sh" "$@"
}

for component in profile-automatic hyprland rofi gtk3 hyprlock workspaces-unit thunar; do
  run_user_deploy apply "$component" --yes >/dev/null
done

cmp -s "$REPO_ROOT/hyprland.lua" "$TEST_CONFIG/hypr/hyprland.lua"
cmp -s "$REPO_ROOT/deploy/profiles/automatic.json" "$TEST_CONFIG/senomyos/profile.json"
cmp -s "$REPO_ROOT/appearance/shared/backgrounds/desktop.png" "$TEST_DATA/senomyos/appearance/backgrounds/desktop.png"
cmp -s "$REPO_ROOT/systemd/workspaces.service" "$TEST_CONFIG/systemd/user/workspaces.service"
[[ -x "$TEST_HOME/.local/bin/senomy-command-lens" && -x "$TEST_HOME/.local/bin/senomy-wallpaper" ]]
xmllint --noout "$TEST_CONFIG/Thunar/uca.xml"

"$REPO_ROOT/scripts/senomy-stage-system-root.sh" "$SYSTEM_ROOT" >/dev/null
jq -e '.kind == "senomyos-system-stage" and (.entries | length > 20)' \
  "$SYSTEM_ROOT/var/lib/senomyos/staged-system.json" >/dev/null
grep -qxF 'Current=senomyos' "$SYSTEM_ROOT/etc/sddm.conf.d/20-senomyos-theme.conf"
[[ -f "$SYSTEM_ROOT/etc/senomyos/recovery-hyprland.lua" ]]
[[ "$(stat -c %a "$SYSTEM_ROOT/etc/senomyos")" == 755 ]]
[[ "$(stat -c %a "$SYSTEM_ROOT/usr/share/plymouth")" == 755 ]]

printf 'SenomyOS clean acceptance: package audit, real user deployment, and system-root staging passed.\n'
