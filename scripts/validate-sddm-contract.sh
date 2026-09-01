#!/usr/bin/env bash

# Static and parser-level checks for login, lock, and authenticated recovery.
# This does not install files, reload SDDM, log out, or start a real session.

set -euo pipefail
export LC_ALL=C

readonly REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly THEME="$REPO_ROOT/appearance/login/sddm/senomyos"
readonly MAIN_QML="$THEME/Main.qml"
readonly FRAME_QML="$THEME/FrameSurface.qml"
readonly SHARED_FRAMES="$REPO_ROOT/appearance/shared/frames/generated"
readonly SDDM_CONFIG="$REPO_ROOT/appearance/login/sddm/sddm.conf"
readonly HYPRLOCK="$REPO_ROOT/appearance/lock/hyprlock.conf"
readonly RECOVERY="$REPO_ROOT/components/recovery"
readonly LOGIN_RUNTIME="$REPO_ROOT/components/login/sddm"

"$REPO_ROOT/scripts/generate-appearance.py" check
jq -e . "$REPO_ROOT/deploy/system-manifest.json" >/dev/null

qmllint -I /usr/lib/qt6/qml "$MAIN_QML" "$FRAME_QML"
grep -qxF '[SddmGreeterTheme]' "$THEME/metadata.desktop"
grep -qxF 'Type=sddm-theme' "$THEME/metadata.desktop"
grep -qxF 'MainScript=Main.qml' "$THEME/metadata.desktop"
grep -qxF 'QtVersion=6' "$THEME/metadata.desktop"
grep -qxF '[Desktop Entry]' "$RECOVERY/senomy-recovery.desktop"
grep -qxF 'Exec=/usr/local/libexec/senomy-recovery-session' "$RECOVERY/senomy-recovery.desktop"
grep -qxF 'TryExec=/usr/local/libexec/senomy-recovery-session' "$RECOVERY/senomy-recovery.desktop"
grep -qxF 'Type=Application' "$RECOVERY/senomy-recovery.desktop"

bash -n \
  "$LOGIN_RUNTIME/senomy-sddm-wayland-session" \
  "$LOGIN_RUNTIME/senomy-sddm-x11-session" \
  "$RECOVERY/senomy-recovery-session" \
  "$RECOVERY/senomy-password-reset-helper" \
  "$REPO_ROOT/components/lock/scripts/senomy-lock" \
  "$REPO_ROOT/scripts/senomy-recoveryctl" \
  "$REPO_ROOT/scripts/senomy-system-deploy.sh" \
  "$REPO_ROOT/scripts/senomy-appearance.sh"

python3 -c 'compile(open("'"$RECOVERY/senomy-recovery-ui"'", encoding="utf-8").read(), "senomy-recovery-ui", "exec")'
visudo -cf "$RECOVERY/senomy-recovery.sudoers" >/dev/null
Hyprland --verify-config --config "$RECOVERY/recovery-hyprland.lua" 2>&1 | grep -qF 'config ok'

grep -qF 'sddm.login(currentUser(), passwordItem.text, selectedSessionIndex)' "$MAIN_QML"
grep -qF 'function sessionIsRecovery(index)' "$MAIN_QML"
grep -qF 'function preferredNormalSessionIndex()' "$MAIN_QML"
grep -qF 'function nextNormalSessionIndex(current)' "$MAIN_QML"
grep -qF 'if (selectedSessionIndex < 0 || sessionIsRecovery(selectedSessionIndex))' "$MAIN_QML"
grep -qF 'onClicked: root.selectNextNormalSession()' "$MAIN_QML"
! grep -qF '(root.selectedSessionIndex + 1) % root.sessionCount()' "$MAIN_QML"
grep -qF 'sddm.powerOff()' "$MAIN_QML"
grep -qF 'sddm.reboot()' "$MAIN_QML"
grep -qF 'keyboard.currentLayout = index' "$MAIN_QML"
grep -qF '{ "code": "gb", "label": "UK" }' "$MAIN_QML"
grep -qF '{ "code": "us", "label": "US" }' "$MAIN_QML"
grep -qF 'RECOVERY RUNTIME NOT INSTALLED' "$MAIN_QML"
grep -qF 'var value = sessionModel.data(modelIndex, 260)' "$MAIN_QML"
grep -qxF 'PreviewUser=' "$THEME/theme.conf"
! grep -Eq 'Qt\.openUrlExternally|DesktopServices|QProcess|Process\s*\{' "$MAIN_QML"

for asset in corner-tl corner-tr corner-bl corner-br edge-top edge-bottom edge-left edge-right; do
  cmp -s \
    "$SHARED_FRAMES/compact/${asset}.svg" \
    "$THEME/assets/frames/compact/${asset}.svg"
done
for asset in controls identity junction diagnostic-tick clock-notification; do
  cmp -s \
    "$SHARED_FRAMES/motifs/${asset}.svg" \
    "$THEME/assets/frames/motifs/${asset}.svg"
done
grep -qF 'source: "assets/frames/compact/corner-tl.svg"' "$FRAME_QML"
grep -qF 'source: "assets/frames/motifs/" + frame.motif + ".svg"' "$FRAME_QML"
jq -e '[.components[] | select(.id == "sddm") | .entries[] | .source] |
  index("appearance/login/sddm/senomyos/FrameSurface.qml") != null' \
  "$REPO_ROOT/deploy/system-manifest.json" >/dev/null

grep -qxF 'SessionCommand=/usr/local/libexec/senomy-sddm-wayland-session' "$SDDM_CONFIG"
grep -qxF 'SessionCommand=/usr/local/libexec/senomy-sddm-x11-session' "$SDDM_CONFIG"
grep -qF '[[ $# -eq 1 && "$1" == "$RECOVERY_SESSION" ]]' "$LOGIN_RUNTIME/senomy-sddm-wayland-session"
grep -qF 'ordinary Wayland sessions are denied' "$LOGIN_RUNTIME/senomy-sddm-wayland-session"
grep -qF 'X11 sessions are denied' "$LOGIN_RUNTIME/senomy-sddm-x11-session"

grep -qF 'path = screenshot' "$HYPRLOCK"
grep -qF 'path = $XDG_DATA_HOME/senomyos/appearance/avatar.png' "$HYPRLOCK"
for icon in accessibility keyboard next power recovery restart session; do
  grep -qF "path = \$XDG_DATA_HOME/senomyos/appearance/icons/${icon}.png" "$HYPRLOCK"
  [[ -s "$REPO_ROOT/appearance/lock/assets/icons/${icon}.png" ]]
done
grep -qF 'pam:enabled = true' "$HYPRLOCK"
grep -qF 'text = LAYOUT  $LAYOUT[UK,US]' "$HYPRLOCK"
grep -qF 'SUPER+SPACE TO SWITCH' "$HYPRLOCK"
! grep -Eq '^[[:space:]]*(onclick|cmd\[)' "$HYPRLOCK"
grep -qF 'Exact 1920px Rail grid: 32px outer inset, 22px gaps, 170px optical height.' "$HYPRLOCK"
! grep -qF 'size = 94%, 18.3%' "$HYPRLOCK"
for spec in utility:408x170 identity:284x170 authentication:654x170 session:202x170 clock:220x170; do
  name="${spec%%:*}"
  dimensions="${spec#*:}"
  frame="$REPO_ROOT/appearance/lock/assets/frames/${name}.png"
  [[ -s "$frame" ]]
  [[ "$(identify -format '%wx%h' "$frame")" == "$dimensions" ]]
  grep -qF "path = \$XDG_DATA_HOME/senomyos/appearance/frames/lock-${name}.png" "$HYPRLOCK"
done
jq -e '[.components[] | select(.id == "hyprlock") | .entries[] | select(.id | startswith("frame-"))] |
  length == 5' "$REPO_ROOT/deploy/manifest.json" >/dev/null

grep -qF 'readonly EXPECTED_CALLER=senomy-recovery' "$RECOVERY/senomy-password-reset-helper"
grep -qF '[[ "${SUDO_USER:-}" == "$EXPECTED_CALLER" ]]' "$RECOVERY/senomy-password-reset-helper"
grep -qF '/usr/bin/chpasswd' "$RECOVERY/senomy-password-reset-helper"
grep -qxF 'senomy-recovery ALL=(root) NOPASSWD: /usr/local/libexec/senomy-password-reset-helper ""' "$RECOVERY/senomy-recovery.sudoers"
grep -qF 'readonly NOLOGIN_SHELL=/usr/bin/nologin' "$REPO_ROOT/scripts/senomy-recoveryctl"
grep -qF 'readonly HYPRLAND_CONFIG=/etc/senomyos/recovery-hyprland.lua' "$REPO_ROOT/scripts/senomy-recoveryctl"
grep -qF "recovery configuration directory must be root-owned mode 0755" "$REPO_ROOT/scripts/senomy-recoveryctl"
grep -qF 'SDDM Wayland recovery guard is not active' "$REPO_ROOT/scripts/senomy-recoveryctl"
grep -qF 'SDDM X11 recovery guard is not active' "$REPO_ROOT/scripts/senomy-recoveryctl"
grep -qF 'disable Senomy recovery before rolling back its SDDM guards or runtime' "$REPO_ROOT/scripts/senomy-system-deploy.sh"
! grep -qF 'hl.bind' "$RECOVERY/recovery-hyprland.lua"
grep -qF 'hl.exec_cmd("/usr/local/libexec/senomy-recovery-ui")' "$RECOVERY/recovery-hyprland.lua"
grep -qF '["/usr/bin/sudo", "-n", HELPER]' "$RECOVERY/senomy-recovery-ui"
! grep -Eq 'firefox|kitty|terminal|wofi|rofi' "$RECOVERY/recovery-hyprland.lua"

while IFS= read -r file; do
  case "$file" in
    *.png) expected=644 ;;
    *.sudoers) expected=440 ;;
    */senomy-sddm-*-session|*/senomy-recovery-session|*/senomy-password-reset-helper|*/senomy-recovery-ui|*/senomy-lock) expected=755 ;;
    *) expected=644 ;;
  esac
  [[ "$(stat -c %a "$file")" == "$expected" ]] || {
    printf 'Unexpected source mode %s: %s\n' "$(stat -c %a "$file")" "$file" >&2
    exit 1
  }
done < <(find "$THEME" "$LOGIN_RUNTIME" "$RECOVERY" -type f -not -path '*/__pycache__/*' | sort)

"$REPO_ROOT/scripts/senomy-system-deploy.sh" plan sddm >/dev/null
"$REPO_ROOT/scripts/senomy-system-deploy.sh" plan recovery >/dev/null

printf 'SenomyOS SDDM, Hyprlock, session confinement, and recovery contracts passed.\n'
