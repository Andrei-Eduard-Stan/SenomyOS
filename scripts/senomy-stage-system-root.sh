#!/usr/bin/env bash

# Stage every ready root-owned component into an empty image root. This is for
# package/image/clean-machine QA; it never writes the host root or activates a
# service, display manager, initramfs, or boot loader.

set -euo pipefail
export LC_ALL=C
umask 022

readonly REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly MANIFEST="${SENOMY_SYSTEM_MANIFEST:-$REPO_ROOT/deploy/system-manifest.json}"
readonly REQUESTED_ROOT="${1:-}"

fail() { printf 'SenomyOS system stage: %s\n' "$*" >&2; exit 1; }

[[ $# -eq 1 ]] || fail 'usage: senomy-stage-system-root.sh EMPTY_TARGET_ROOT'
[[ "$REQUESTED_ROOT" == /* && "$REQUESTED_ROOT" != / ]] || fail 'target root must be an explicit absolute non-root path'
[[ -d "$REQUESTED_ROOT" && ! -L "$REQUESTED_ROOT" ]] || fail 'target root must be an existing non-symlink directory'
readonly TARGET_ROOT="$(realpath -e -- "$REQUESTED_ROOT")"
[[ "$TARGET_ROOT" != / && ( "$TARGET_ROOT" == /tmp/* || "$TARGET_ROOT" == /var/tmp/* ) ]] ||
  fail 'staging is restricted to /tmp or /var/tmp roots'
[[ -z "$(find "$TARGET_ROOT" -mindepth 1 -maxdepth 1 -print -quit)" ]] || fail 'target root must be empty'

root_path() {
  case "$1" in
    sddm_config) printf '%s/etc/sddm.conf.d\n' "$TARGET_ROOT" ;;
    sddm_themes) printf '%s/usr/share/sddm/themes\n' "$TARGET_ROOT" ;;
    wayland_sessions) printf '%s/usr/share/wayland-sessions\n' "$TARGET_ROOT" ;;
    local_libexec) printf '%s/usr/local/libexec\n' "$TARGET_ROOT" ;;
    local_sbin) printf '%s/usr/local/sbin\n' "$TARGET_ROOT" ;;
    senomy_etc) printf '%s/etc/senomyos\n' "$TARGET_ROOT" ;;
    sudoers) printf '%s/etc/sudoers.d\n' "$TARGET_ROOT" ;;
    plymouth_themes) printf '%s/usr/share/plymouth/themes\n' "$TARGET_ROOT" ;;
    grub_themes) printf '%s/usr/share/grub/themes\n' "$TARGET_ROOT" ;;
    *) fail "unsupported system root: $1" ;;
  esac
}

jq -e '.schema_version == 1 and (.components | type == "array")' "$MANIFEST" >/dev/null || fail 'system manifest is invalid'
entries='[]'
while IFS= read -r entry; do
  source_relative="$(jq -r .source <<<"$entry")"
  source="$(realpath -e -- "$REPO_ROOT/$source_relative" 2>/dev/null || true)"
  [[ -f "$source" && ! -L "$source" && "$source" == "$REPO_ROOT/"* ]] || fail "invalid source: $source_relative"
  target_root="$(root_path "$(jq -r .target.root <<<"$entry")")"
  relative="$(jq -r .target.path <<<"$entry")"
  [[ -n "$relative" && "$relative" != /* && ! "$relative" =~ (^|/)\.\.(/|$) ]] || fail "invalid target: $relative"
  target="$(realpath -m -- "$target_root/$relative")"
  [[ "$target" == "$target_root/"* ]] || fail "target escaped root: $relative"
  mode="$(jq -r .mode <<<"$entry")"
  install -D -m "$mode" -- "$source" "$target"
  entries="$(jq -nc --argjson entries "$entries" --arg source "$source_relative" \
    --arg path "${target#"$TARGET_ROOT"}" --arg mode "$mode" --arg hash "$(sha256sum "$source" | awk '{print $1}')" \
    '$entries + [{source:$source,path:$path,mode:$mode,sha256:$hash}]')"
done < <(jq -c '.components[] | select(.readiness == "ready") | .entries[]' "$MANIFEST")

receipt="$TARGET_ROOT/var/lib/senomyos/staged-system.json"
install -d -m 0755 -- "$(dirname -- "$receipt")"
jq -n --argjson entries "$entries" '{schema_version:1,kind:"senomyos-system-stage",entries:$entries}' >"$receipt"
chmod 0644 "$receipt"

theme="$TARGET_ROOT/usr/share/sddm/themes/senomyos"
qmllint -I /usr/lib/qt6/qml "$theme/Main.qml" >/dev/null
bash -n \
  "$TARGET_ROOT/usr/local/libexec/senomy-sddm-wayland-session" \
  "$TARGET_ROOT/usr/local/libexec/senomy-sddm-x11-session" \
  "$TARGET_ROOT/usr/local/libexec/senomy-recovery-session" \
  "$TARGET_ROOT/usr/local/libexec/senomy-password-reset-helper" \
  "$TARGET_ROOT/usr/local/sbin/senomy-recoveryctl"
python3 -c 'compile(open("'"$TARGET_ROOT"'/usr/local/libexec/senomy-recovery-ui", encoding="utf-8").read(), "senomy-recovery-ui", "exec")'
visudo -cf "$TARGET_ROOT/etc/sudoers.d/senomy-recovery" >/dev/null
Hyprland --verify-config --config "$TARGET_ROOT/etc/senomyos/recovery-hyprland.lua" 2>&1 | grep -qF 'config ok'
desktop-file-validate "$TARGET_ROOT/usr/share/wayland-sessions/senomy-recovery.desktop"

printf 'SenomyOS system stage complete: %s files beneath %s\n' "$(jq '.entries | length' "$receipt")" "$TARGET_ROOT"
