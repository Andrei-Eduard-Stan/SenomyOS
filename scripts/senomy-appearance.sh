#!/usr/bin/env bash

# One repository entry point for building, validating, previewing, deploying,
# and rolling back SenomyOS visual sources.

set -euo pipefail
export LC_ALL=C

readonly ACTION="${1:-help}"
readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
readonly USER_DEPLOY="$SCRIPT_DIR/senomy-deploy.sh"
readonly SYSTEM_DEPLOY="$SCRIPT_DIR/senomy-system-deploy.sh"
readonly GENERATOR="$SCRIPT_DIR/generate-appearance.py"

fail() {
  printf 'SenomyOS appearance: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage:
  senomy-appearance.sh build
  senomy-appearance.sh check
  senomy-appearance.sh plan [all|shell|launcher|file-manager|lock|login|recovery|boot]
  senomy-appearance.sh apply {shell|launcher|file-manager|lock|login|boot}
  senomy-appearance.sh apply recovery TARGET_USER
  senomy-appearance.sh preview login
  senomy-appearance.sh rollback user DEPLOYMENT_ID
  senomy-appearance.sh rollback system DEPLOYMENT_ID

All editable appearance sources live under appearance/. Generated projections
are refreshed before apply. System operations use the privileged transactional
deployer and never restart SDDM, log out, or reboot.
EOF
}

ensure_user_context() {
  [[ "$EUID" -ne 0 ]] || fail 'run this entry point as the desktop user; it invokes sudo only for system components'
}

build() {
  "$GENERATOR" build
}

check() {
  "$GENERATOR" check
  "$SCRIPT_DIR/validate-theme-contract.sh"
  "$SCRIPT_DIR/validate-command-lens.sh"
  "$SCRIPT_DIR/validate-thunar-contract.sh"
  "$SCRIPT_DIR/validate-sddm-contract.sh"
  "$SCRIPT_DIR/validate-boot-themes.sh"
  git -C "$REPO_ROOT" diff --check
  printf 'SenomyOS appearance validation passed.\n'
}

plan_one() {
  case "$1" in
    shell)
      printf 'LIVE       shell                  appearance/shell/eww.scss -> %s/eww.scss import\n' "$REPO_ROOT"
      printf '           Applying shell rebuilds projections and explicitly reloads Eww.\n'
      ;;
    launcher) "$USER_DEPLOY" plan rofi ;;
    file-manager)
      "$USER_DEPLOY" plan gtk3
      "$USER_DEPLOY" plan thunar
      ;;
    lock) "$USER_DEPLOY" plan hyprlock ;;
    login) "$SYSTEM_DEPLOY" plan sddm ;;
    recovery) "$SYSTEM_DEPLOY" plan recovery ;;
    boot)
      "$SCRIPT_DIR/senomy-bootctl" status
      "$SYSTEM_DEPLOY" plan grub-staged
      "$SYSTEM_DEPLOY" plan plymouth-staged
      ;;
    *) fail "unknown appearance component: $1" ;;
  esac
}

plan_all() {
  local component
  for component in shell launcher file-manager lock login recovery boot; do
    printf '\n// %s\n' "$component"
    plan_one "$component"
  done
}

confirm_shell_reload() {
  local reply
  [[ -t 0 ]] || fail 'shell reload confirmation requires an interactive terminal'
  printf 'Eww will reload; the rail and open Eww panels may briefly disappear.\n' >&2
  printf 'Type RELOAD SHELL to continue: ' >&2
  IFS= read -r reply
  [[ "$reply" == 'RELOAD SHELL' ]] || fail 'confirmation did not match; Eww was not reloaded'
}

apply_one() {
  local component="$1" target_user="${2:-}"
  if [[ "$component" == file-manager ]] && pgrep -i -x thunar >/dev/null 2>&1; then
    fail 'close every Thunar window before applying the file-manager bundle'
  fi
  build
  check
  case "$component" in
    shell)
      confirm_shell_reload
      "$SCRIPT_DIR/reload-eww.sh"
      eww --no-daemonize --config "$REPO_ROOT" ping >/dev/null
      printf 'SenomyOS shell appearance reloaded.\n'
      ;;
    launcher) "$USER_DEPLOY" apply rofi ;;
    file-manager)
      "$USER_DEPLOY" apply gtk3
      "$USER_DEPLOY" apply thunar
      ;;
    lock) "$USER_DEPLOY" apply hyprlock ;;
    login) sudo "$SYSTEM_DEPLOY" apply sddm ;;
    boot)
      sudo "$SYSTEM_DEPLOY" apply grub-staged
      sudo "$SYSTEM_DEPLOY" apply plymouth-staged
      printf 'SenomyOS boot appearance staged only; no boot path was activated.\n'
      ;;
    recovery)
      [[ -n "$target_user" ]] || fail 'recovery apply requires TARGET_USER'
      sudo "$SYSTEM_DEPLOY" apply recovery
      sudo /usr/local/sbin/senomy-recoveryctl provision "$target_user"
      ;;
    *) fail "unknown or non-applicable appearance component: $component" ;;
  esac
}

ensure_user_context

case "$ACTION" in
  build)
    [[ $# -eq 1 ]] || fail 'build takes no arguments'
    build
    ;;
  check)
    [[ $# -eq 1 ]] || fail 'check takes no arguments'
    check
    ;;
  plan)
    [[ $# -eq 1 || $# -eq 2 ]] || fail 'plan takes at most one component'
    if [[ "${2:-all}" == all ]]; then plan_all; else plan_one "$2"; fi
    ;;
  apply)
    [[ $# -ge 2 && $# -le 3 ]] || fail 'apply requires a component and optional recovery TARGET_USER'
    apply_one "$2" "${3:-}"
    ;;
  preview)
    [[ $# -eq 2 && "$2" == login ]] || fail 'preview currently supports only login'
    command -v sddm-greeter-qt6 >/dev/null 2>&1 || fail 'sddm-greeter-qt6 is not installed'
    exec sddm-greeter-qt6 --test-mode --theme "$REPO_ROOT/appearance/login/sddm/senomyos"
    ;;
  rollback)
    [[ $# -eq 3 ]] || fail 'rollback requires user|system and DEPLOYMENT_ID'
    case "$2" in
      user) "$USER_DEPLOY" rollback "$3" ;;
      system) sudo "$SYSTEM_DEPLOY" rollback "$3" ;;
      *) fail 'rollback scope must be user or system' ;;
    esac
    ;;
  help|-h|--help) usage ;;
  *) usage >&2; exit 2 ;;
esac
