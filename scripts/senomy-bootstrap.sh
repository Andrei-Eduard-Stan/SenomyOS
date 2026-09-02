#!/usr/bin/env bash

# Reproducible Arch bootstrap orchestration for an already installed base system.
# Package installation, service activation, and recovery provisioning remain
# separate visible trust boundaries even when this script coordinates them.

set -euo pipefail
export LC_ALL=C
umask 077

readonly ACTION="${1:-help}"
readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
readonly PACKAGE_MANIFEST="$REPO_ROOT/deploy/packages.json"
readonly SERVICE_MANIFEST="$REPO_ROOT/deploy/services.json"
readonly PACMAN_BIN="${SENOMY_PACMAN_BIN:-/usr/bin/pacman}"
readonly SYSTEMCTL_BIN="${SENOMY_SYSTEMCTL_BIN:-/usr/bin/systemctl}"
readonly USER_DEPLOY="${SENOMY_USER_DEPLOY:-$SCRIPT_DIR/senomy-deploy.sh}"
readonly SYSTEM_DEPLOY="${SENOMY_SYSTEM_DEPLOY:-$SCRIPT_DIR/senomy-system-deploy.sh}"
readonly RECOVERYCTL="${SENOMY_RECOVERYCTL:-/usr/local/sbin/senomy-recoveryctl}"

fail() { printf 'SenomyOS bootstrap: %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
Usage:
  senomy-bootstrap.sh audit
  senomy-bootstrap.sh plan {automatic|desktop|touch|narrow}
  senomy-bootstrap.sh install-packages [--with-external]
  senomy-bootstrap.sh apply {automatic|desktop|touch|narrow} TARGET_USER

audit and plan are read-only. install-packages uses pacman and optionally the
already-installed paru helper. apply deploys reviewed user/system files,
enables the workspace unit, and enters interactive recovery provisioning. It
does not restart SDDM, reload Hyprland, regenerate initramfs/GRUB, log out, or
reboot.
EOF
}

validate_manifests() {
  jq -e '
    .schema_version == 1 and .distribution == "arch" and
    (.official | type == "array" and length > 0) and
    (.external | type == "array") and
    ([.official[].package, .external[].package] | length == (unique | length)) and
    all(.official[];
      (.package | test("^[a-z0-9@._+-]+$")) and
      (.tier | IN("runtime", "feature", "optional", "development", "system")) and
      (.required | type == "boolean") and (.reason | length > 0)) and
    all(.external[];
      (.package | test("^[a-z0-9@._+-]+$")) and .provider == "aur" and
      (.required | type == "boolean") and (.reason | length > 0) and (.review | length > 0))
  ' "$PACKAGE_MANIFEST" >/dev/null || fail 'package manifest is invalid'
  jq -e '
    .schema_version == 1 and
    ([.system[].unit, .user[].unit] | length == (unique | length)) and
    all(.system[];
      (.unit | test("^[A-Za-z0-9@_.-]+\\.service$")) and
      (.policy | IN("enable", "optional")) and (.required | type == "boolean")) and
    all(.user[];
      (.unit | test("^[A-Za-z0-9@_.-]+\\.(service|socket)$")) and
      (.policy | IN("enable", "preset")) and (.required | type == "boolean") and
      (.managed | type == "boolean"))
  ' "$SERVICE_MANIFEST" >/dev/null || fail 'service manifest is invalid'
}

validate_profile_id() {
  case "$1" in automatic | desktop | touch | narrow) ;; *) fail 'profile must be automatic, desktop, touch, or narrow' ;; esac
}

package_status() {
  local item package installed provider
  while IFS= read -r item; do
    package="$(jq -r .package <<<"$item")"
    provider="$(jq -r '.provider // "official"' <<<"$item")"
    installed=false
    "$PACMAN_BIN" -Q -- "$package" >/dev/null 2>&1 && installed=true
    jq -nc --argjson item "$item" --arg provider "$provider" --argjson installed "$installed" \
      '$item + {provider:$provider,installed:$installed}'
  done < <(jq -c '.official[] + {provider:"official"}, .external[]' "$PACKAGE_MANIFEST") | jq -s .
}

service_status() {
  local scope item unit state
  for scope in system user; do
    while IFS= read -r item; do
      unit="$(jq -r .unit <<<"$item")"
      if [[ "$scope" == user ]]; then
        state="$($SYSTEMCTL_BIN --user is-enabled "$unit" 2>/dev/null || true)"
      else
        state="$($SYSTEMCTL_BIN is-enabled "$unit" 2>/dev/null || true)"
      fi
      [[ -n "$state" ]] || state=unavailable
      jq -nc --argjson item "$item" --arg scope "$scope" --arg state "$state" \
        '$item + {scope:$scope,state:$state}'
    done < <(jq -c ".${scope}[]" "$SERVICE_MANIFEST")
  done | jq -s .
}

audit() {
  local packages services profile
  packages="$(package_status)"
  services="$(service_status)"
  profile="$($SCRIPT_DIR/profile-status.sh)"
  jq -nc --argjson packages "$packages" --argjson services "$services" --argjson profile "$profile" '
    ($packages | map(select(.required == true and .installed == false))) as $missing
    | ($services | map(select(.required == true and .policy == "enable" and (.state | IN("enabled", "enabled-runtime", "linked", "linked-runtime") | not)))) as $disabled
    | {
        schema_version:1,
        ok:($missing | length == 0),
        source:"senomy-bootstrap",
        data:{
          packages:$packages,
          missing_required_packages:$missing,
          services:$services,
          required_enablement_gaps:$disabled,
          profile:$profile.data,
          ready_for_configuration:($missing | length == 0)
        },
        error:(if ($missing | length) == 0 then null else {code:"packages_missing",message:"Required packages are not installed"} end)
      }'
}

plan() {
  local profile="$1" report
  validate_profile_id "$profile"
  report="$(audit)"
  printf 'SENOMYOS FIRST-BOOT PLAN // %s\n' "$profile"
  printf 'required packages missing: %s\n' "$(jq '.data.missing_required_packages | length' <<<"$report")"
  jq -r '.data.missing_required_packages[]? | "  MISSING  \(.provider)/\(.package) // \(.reason)"' <<<"$report"
  printf 'required service enablement gaps: %s\n' "$(jq '.data.required_enablement_gaps | length' <<<"$report")"
  jq -r '.data.required_enablement_gaps[]? | "  \(.scope)/\(.unit) // \(.state)"' <<<"$report"
  for component in "profile-$profile" hyprland rofi gtk3 hyprlock workspaces-unit thunar; do
    printf '\n'
    "$USER_DEPLOY" plan "$component"
  done
  printf '\n'
  "$SYSTEM_DEPLOY" plan sddm
  printf '\n'
  "$SYSTEM_DEPLOY" plan recovery
  printf '\nRecovery provisioning remains interactive and targets only: %s\n' "${2:-TARGET_USER}"
}

confirm() {
  local phrase="$1" reply
  [[ -t 0 && -t 1 ]] || fail 'this operation requires an interactive terminal'
  printf 'Type %s to continue: ' "$phrase"
  IFS= read -r reply
  [[ "$reply" == "$phrase" ]] || fail 'confirmation did not match; no operation was started'
}

install_packages() {
  local include_external="$1"
  local -a official=() external=()
  mapfile -t official < <(jq -r '.official[] | select(.required == true) | .package' "$PACKAGE_MANIFEST")
  mapfile -t external < <(jq -r '.external[] | select(.required == true) | .package' "$PACKAGE_MANIFEST")
  printf 'Official required packages: %s\n' "${#official[@]}"
  printf 'External reviewed packages: %s\n' "${#external[@]}"
  [[ "$include_external" == true ]] || printf 'External packages will only be audited, not installed.\n'
  confirm 'INSTALL SENOMYOS PACKAGES'
  sudo "$PACMAN_BIN" -S --needed -- "${official[@]}"
  if [[ "$include_external" == true ]]; then
    command -v paru >/dev/null 2>&1 || fail 'paru is required for the explicitly requested external package step'
    paru -S --needed -- "${external[@]}"
  fi
}

apply_first_boot() {
  local profile="$1" target_user="$2" report component
  validate_profile_id "$profile"
  [[ "$target_user" =~ ^[A-Za-z_][A-Za-z0-9_.-]{0,31}$ ]] || fail 'target user name is invalid'
  [[ "$(id -un)" == "$target_user" ]] || fail 'run first boot as the target desktop user'
  report="$(audit)"
  jq -e '.data.ready_for_configuration == true' <<<"$report" >/dev/null || fail 'install every required package before applying first boot'
  pgrep -i -x thunar >/dev/null 2>&1 && fail 'close every Thunar window before first-boot apply'
  printf 'This installs user/system configuration and enables workspaces.service.\n'
  printf 'It does not restart SDDM, reload Hyprland, regenerate boot files, log out, or reboot.\n'
  confirm "BOOTSTRAP SENOMYOS $profile"
  "$SCRIPT_DIR/generate-appearance.py" build
  "$SCRIPT_DIR/validate-shell.sh"
  for component in "profile-$profile" hyprland rofi gtk3 hyprlock workspaces-unit thunar; do
    "$USER_DEPLOY" apply "$component" --yes
  done
  "$SYSTEMCTL_BIN" --user daemon-reload
  "$SYSTEMCTL_BIN" --user enable --now workspaces.service
  sudo "$SYSTEM_DEPLOY" apply sddm --yes
  sudo "$SYSTEM_DEPLOY" apply recovery --yes
  sudo "$RECOVERYCTL" provision "$target_user"
  printf 'SenomyOS first boot completed. Start a fresh Hyprland session when ready.\n'
}

validate_manifests
case "$ACTION" in
  audit) [[ $# -eq 1 ]] || fail 'audit takes no arguments'; audit ;;
  plan) [[ $# -eq 2 ]] || fail 'plan requires PROFILE'; plan "$2" ;;
  install-packages)
    [[ $# -eq 1 || ( $# -eq 2 && "$2" == --with-external ) ]] || fail 'install-packages accepts only --with-external'
    install_packages "$( [[ "${2:-}" == --with-external ]] && printf true || printf false )"
    ;;
  apply) [[ $# -eq 3 ]] || fail 'apply requires PROFILE TARGET_USER'; apply_first_boot "$2" "$3" ;;
  help|-h|--help) usage ;;
  *) usage >&2; exit 2 ;;
esac
