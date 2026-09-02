#!/usr/bin/env bash

# Transactional deployment for the narrow SenomyOS system appearance allowlist.
# It never restarts SDDM, logs out, reboots, or regenerates GRUB/initramfs.

set -euo pipefail
export LC_ALL=C
umask 077

readonly ACTION="${1:-help}"
readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
readonly MANIFEST="${SENOMY_SYSTEM_MANIFEST:-$REPO_ROOT/deploy/system-manifest.json}"
readonly LOCK_FILE=/run/lock/senomyos-system-deployment.lock

fail() {
  printf 'SenomyOS system deployment: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage:
  senomy-system-deploy.sh list
  senomy-system-deploy.sh plan COMPONENT
  sudo senomy-system-deploy.sh apply COMPONENT [--yes]
  sudo senomy-system-deploy.sh history
  sudo senomy-system-deploy.sh rollback DEPLOYMENT_ID [--yes]

plan and list are read-only. apply and rollback require root and confirmation.
No command restarts SDDM or the current graphical session.
EOF
}

require_commands() {
  local command_name
  for command_name in jq sha256sum realpath stat cmp install mktemp flock; do
    command -v "$command_name" >/dev/null 2>&1 || fail "required command is unavailable: $command_name"
  done
}

validate_relative_path() {
  local path="$1" label="$2"
  [[ -n "$path" && "$path" != /* && "$path" != . ]] || fail "$label must be a relative path"
  [[ ! "$path" =~ (^|/)\.\.(/|$) ]] || fail "$label contains parent traversal: $path"
}

system_root() {
  case "$1" in
    sddm_config) printf '/etc/sddm.conf.d\n' ;;
    sddm_themes) printf '/usr/share/sddm/themes\n' ;;
    wayland_sessions) printf '/usr/share/wayland-sessions\n' ;;
    local_libexec) printf '/usr/local/libexec\n' ;;
    local_sbin) printf '/usr/local/sbin\n' ;;
    senomy_etc) printf '/etc/senomyos\n' ;;
    sudoers) printf '/etc/sudoers.d\n' ;;
    plymouth_themes) printf '/usr/share/plymouth/themes\n' ;;
    grub_themes) printf '/usr/share/grub/themes\n' ;;
    *) fail "unsupported system root: $1" ;;
  esac
}

system_root_mode() {
  case "$1" in
    sudoers) printf '0750\n' ;;
    *) printf '0755\n' ;;
  esac
}

resolve_target() {
  local root_id="$1" relative="$2" root target
  validate_relative_path "$relative" 'target path'
  root="$(realpath -m -- "$(system_root "$root_id")")"
  target="$(realpath -m -- "$root/$relative")"
  [[ "$root" != / && "$target" == "$root/"* ]] || fail "unsafe system target: $root_id/$relative"
  printf '%s\n' "$target"
}

resolve_source() {
  local relative="$1" source
  validate_relative_path "$relative" 'source path'
  source="$(realpath -e -- "$REPO_ROOT/$relative" 2>/dev/null || true)"
  [[ -n "$source" && "$source" == "$REPO_ROOT/"* ]] || fail "source is missing or outside the repository: $relative"
  [[ -f "$source" && ! -L "$source" ]] || fail "source must be a regular non-symlink file: $relative"
  printf '%s\n' "$source"
}

ensure_system_root() {
  local root_id="$1" root root_mode directory mode
  local -a directories=()
  root="$(system_root "$root_id")"
  root_mode="$(system_root_mode "$root_id")"
  case "$root_id" in
    sddm_themes) directories=(/usr/share/sddm "$root") ;;
    plymouth_themes) directories=(/usr/share/plymouth "$root") ;;
    grub_themes) directories=(/usr/share/grub "$root") ;;
    *) directories=("$root") ;;
  esac
  for directory in "${directories[@]}"; do
    mode=0755
    [[ "$directory" != "$root" ]] || mode="$root_mode"
    install -d -o root -g root -m "$mode" -- "$directory"
    [[ "$(stat -c %a "$directory")" == "${mode#0}" &&
       "$(stat -c %U:%G "$directory")" == root:root ]] || return 1
  done
}

validate_manifest() {
  [[ -f "$MANIFEST" && ! -L "$MANIFEST" ]] || fail "manifest is unavailable: $MANIFEST"
  jq -e '
    .schema_version == 1 and
    (.backup_root | type == "string" and startswith("/var/lib/senomyos/")) and
    (.components | type == "array" and length > 0) and
    ([.components[].id] | length == (unique | length)) and
    all(.components[];
      (.id | type == "string" and test("^[a-z0-9][a-z0-9-]*$")) and
      (.description | type == "string" and length > 0) and
      (.scope == "system") and
      (.readiness | IN("ready", "planned")) and
      (.reason | type == "string" and length > 0) and
      ((.warning // "") | type == "string") and
      (.post_apply | type == "array") and
      all(.post_apply[]; IN("sddm-theme", "recovery-runtime")) and
      (.entries | type == "array") and
      ([.entries[].id] | length == (unique | length)) and
      all(.entries[];
        (.id | type == "string" and test("^[a-z0-9][a-z0-9-]*$")) and
        (.source | type == "string" and length > 0) and
        (.target.root | IN("sddm_config", "sddm_themes", "wayland_sessions", "local_libexec", "local_sbin", "senomy_etc", "sudoers", "plymouth_themes", "grub_themes")) and
        (.target.path | type == "string" and length > 0) and
        (.mode | type == "string" and test("^0[0-7]{3}$"))
      )
    )
  ' "$MANIFEST" >/dev/null || fail 'manifest schema validation failed'
}

component_json() {
  local component="$1" payload
  payload="$(jq -ce --arg component "$component" '.components[] | select(.id == $component)' "$MANIFEST" 2>/dev/null || true)"
  [[ -n "$payload" ]] || fail "unknown component: $component"
  printf '%s\n' "$payload"
}

file_hash() {
  sha256sum -- "$1" | awk '{print $1}'
}

entry_state() {
  local source="$1" target="$2" expected_mode="$3" probe
  probe="$(dirname -- "$target")"
  while [[ "$probe" != / && ! -e "$probe" ]]; do
    probe="$(dirname -- "$probe")"
  done
  if [[ -d "$probe" && ! -x "$probe" ]]; then
    printf 'INACCESSIBLE\n'
    return
  fi
  if [[ ! -e "$target" && ! -L "$target" ]]; then
    printf 'CREATE\n'
    return
  fi
  [[ -f "$target" && ! -L "$target" ]] || fail "target is not a regular non-symlink file: $target"
  if cmp -s -- "$source" "$target" &&
     [[ "$(stat -c %a "$target")" == "${expected_mode#0}" ]] &&
     [[ "$(stat -c %U:%G "$target")" == root:root ]]; then
    printf 'UNCHANGED\n'
  else
    printf 'UPDATE\n'
  fi
}

print_plan() {
  local component="$1" payload entry source target state
  local -a entries=()
  payload="$(component_json "$component")"
  printf 'SENOMYOS SYSTEM PLAN // %s\n' "$component"
  printf 'status: %s\n' "$(jq -r .readiness <<<"$payload")"
  printf 'description: %s\n' "$(jq -r .description <<<"$payload")"
  [[ -z "$(jq -r '.warning // empty' <<<"$payload")" ]] || printf 'warning: %s\n' "$(jq -r .warning <<<"$payload")"
  if [[ "$(jq -r .readiness <<<"$payload")" != ready ]]; then
    printf 'reason: %s\n' "$(jq -r .reason <<<"$payload")"
    return
  fi
  mapfile -t entries < <(jq -c '.entries[]' <<<"$payload")
  for entry in "${entries[@]}"; do
    source="$(resolve_source "$(jq -r .source <<<"$entry")")"
    target="$(resolve_target "$(jq -r .target.root <<<"$entry")" "$(jq -r .target.path <<<"$entry")")"
    state="$(entry_state "$source" "$target" "$(jq -r .mode <<<"$entry")")"
    printf '%-10s %-22s %s -> %s (mode %s)\n' "$state" "$(jq -r .id <<<"$entry")" "$(jq -r .source <<<"$entry")" "$target" "$(jq -r .mode <<<"$entry")"
  done
}

require_root() {
  [[ "$EUID" -eq 0 ]] || fail 'this action must run as root (use sudo)'
}

confirmation() {
  local phrase="$1" assume_yes="$2" reply
  [[ "$assume_yes" == true ]] && return
  [[ -t 0 ]] || fail 'confirmation requires an interactive terminal or --yes'
  printf 'Type %s to continue: ' "$phrase" >&2
  IFS= read -r reply
  [[ "$reply" == "$phrase" ]] || fail 'confirmation did not match; no changes were made'
}

backup_root() {
  local root
  root="$(jq -r .backup_root "$MANIFEST")"
  [[ "$root" == /var/lib/senomyos/* && "$root" != /var/lib/senomyos ]] || fail "unsafe backup root: $root"
  printf '%s\n' "$root"
}

write_json_atomic() {
  local target="$1" payload="$2" temporary
  temporary="$(mktemp "$(dirname -- "$target")/.receipt.XXXXXX")"
  printf '%s\n' "$payload" >"$temporary"
  chmod 600 "$temporary"
  mv -fT -- "$temporary" "$target"
}

run_post_checks() {
  local payload="$1" check verify_runtime verify_status
  local -a checks=()
  mapfile -t checks < <(jq -r '.post_apply[]' <<<"$payload")
  for check in "${checks[@]}"; do
    case "$check" in
      sddm-theme)
        grep -qx 'Current=senomyos' /etc/sddm.conf.d/20-senomyos-theme.conf || return 1
        grep -qx 'SessionCommand=/usr/local/libexec/senomy-sddm-wayland-session' /etc/sddm.conf.d/20-senomyos-theme.conf || return 1
        grep -qx 'SessionCommand=/usr/local/libexec/senomy-sddm-x11-session' /etc/sddm.conf.d/20-senomyos-theme.conf || return 1
        [[ -f /usr/share/sddm/themes/senomyos/Main.qml && -f /usr/share/sddm/themes/senomyos/metadata.desktop ]] || return 1
        bash -n /usr/local/libexec/senomy-sddm-wayland-session /usr/local/libexec/senomy-sddm-x11-session || return 1
        ;;
      recovery-runtime)
        /usr/bin/visudo -cf /etc/sudoers.d/senomy-recovery >/dev/null || {
          printf 'Recovery post-check failed: sudoers validation.\n' >&2; return 1;
        }
        bash -n /usr/local/libexec/senomy-recovery-session /usr/local/libexec/senomy-password-reset-helper || {
          printf 'Recovery post-check failed: launcher/helper shell syntax.\n' >&2; return 1;
        }
        /usr/bin/python3 -c 'compile(open("/usr/local/libexec/senomy-recovery-ui", encoding="utf-8").read(), "/usr/local/libexec/senomy-recovery-ui", "exec")' || {
          printf 'Recovery post-check failed: UI Python syntax.\n' >&2; return 1;
        }
        verify_runtime="$(mktemp -d /run/senomyos-hyprland-verify.XXXXXX)" || return 1
        chmod 0700 "$verify_runtime"
        verify_status=0
        XDG_RUNTIME_DIR="$verify_runtime" /usr/bin/Hyprland --i-am-really-stupid --verify-config --config /etc/senomyos/recovery-hyprland.lua 2>&1 |
          grep -qF 'config ok' || verify_status=$?
        rm -rf -- "$verify_runtime"
        if [[ "$verify_status" -ne 0 ]]; then
          printf 'Recovery post-check failed: Hyprland Lua validation.\n' >&2
          return 1
        fi
        if command -v desktop-file-validate >/dev/null 2>&1; then
          desktop-file-validate /usr/share/wayland-sessions/senomy-recovery.desktop || {
            printf 'Recovery post-check failed: desktop entry validation.\n' >&2; return 1;
          }
        fi
        ;;
      *) return 1 ;;
    esac
  done
}

restore_receipt() {
  local receipt="$1" drift_guard="$2" deployment_dir item target root_id root_path parent parent_mode existed backup before_hash source_hash before_mode current_hash stage
  local index
  local -a items=()
  deployment_dir="$(dirname -- "$receipt")"
  mapfile -t items < <(jq -c '.entries[]' "$receipt")

  if [[ "$drift_guard" == true ]]; then
    for item in "${items[@]}"; do
      root_id="$(jq -r .target.root <<<"$item")"
      target="$(resolve_target "$root_id" "$(jq -r .target.path <<<"$item")")"
      existed="$(jq -r .existed <<<"$item")"
      before_hash="$(jq -r '.before_hash // empty' <<<"$item")"
      source_hash="$(jq -r .source_hash <<<"$item")"
      if [[ -e "$target" || -L "$target" ]]; then
        [[ -f "$target" && ! -L "$target" ]] || fail "rollback target changed type: $target"
        current_hash="$(file_hash "$target")"
        [[ "$current_hash" == "$source_hash" || ( "$existed" == true && "$current_hash" == "$before_hash" ) ]] ||
          fail "rollback refused because target drifted: $target"
      else
        [[ "$existed" == false ]] || fail "rollback refused because an original target is missing: $target"
      fi
    done
  fi

  for ((index=${#items[@]}-1; index>=0; index--)); do
    item="${items[index]}"
    root_id="$(jq -r .target.root <<<"$item")"
    target="$(resolve_target "$root_id" "$(jq -r .target.path <<<"$item")")"
    existed="$(jq -r .existed <<<"$item")"
    if [[ "$existed" == true ]]; then
      backup="$(realpath -e -- "$deployment_dir/$(jq -r .backup <<<"$item")" 2>/dev/null || true)"
      [[ -f "$backup" && ! -L "$backup" && "$backup" == "$deployment_dir/"* ]] || return 1
      [[ "$(file_hash "$backup")" == "$(jq -r .before_hash <<<"$item")" ]] || return 1
      before_mode="$(jq -r .before_mode <<<"$item")"
      ensure_system_root "$root_id"
      root_path="$(system_root "$root_id")"
      parent="$(dirname -- "$target")"
      parent_mode=0755
      [[ "$parent" != "$root_path" ]] || parent_mode="$(system_root_mode "$root_id")"
      install -d -o root -g root -m "$parent_mode" -- "$parent"
      stage="$(mktemp "$(dirname -- "$target")/.senomy-restore.XXXXXX")"
      install -o root -g root -m "$before_mode" -- "$backup" "$stage" || return 1
      mv -fT -- "$stage" "$target" || return 1
    elif [[ -e "$target" || -L "$target" ]]; then
      [[ -f "$target" && ! -L "$target" ]] || return 1
      rm -f -- "$target" || return 1
    fi
  done
}

update_receipt_status() {
  local receipt="$1" status="$2" temporary
  temporary="$(mktemp "$(dirname -- "$receipt")/.receipt.XXXXXX")"
  jq --arg status "$status" --arg at "$(date --iso-8601=seconds)" '.status=$status | .status_at=$at' "$receipt" >"$temporary"
  chmod 600 "$temporary"
  mv -fT -- "$temporary" "$receipt"
}

install_from_receipt() {
  local receipt="$1" item source target mode root_id root_path parent parent_mode stage
  local -a items=()
  mapfile -t items < <(jq -c '.entries[]' "$receipt")
  for item in "${items[@]}"; do
    source="$(resolve_source "$(jq -r .source <<<"$item")")"
    root_id="$(jq -r .target.root <<<"$item")"
    target="$(resolve_target "$root_id" "$(jq -r .target.path <<<"$item")")"
    mode="$(jq -r .mode <<<"$item")"
    ensure_system_root "$root_id"
    root_path="$(system_root "$root_id")"
    parent="$(dirname -- "$target")"
    parent_mode=0755
    [[ "$parent" != "$root_path" ]] || parent_mode="$(system_root_mode "$root_id")"
    install -d -o root -g root -m "$parent_mode" -- "$parent"
    [[ "$(stat -c %a "$parent")" == "${parent_mode#0}" &&
       "$(stat -c %U:%G "$parent")" == root:root ]] || return 1
    [[ ! -L "$target" ]] || return 1
    stage="$(mktemp "$(dirname -- "$target")/.senomy-install.XXXXXX")"
    if ! install -o root -g root -m "$mode" -- "$source" "$stage" || ! mv -fT -- "$stage" "$target"; then
      rm -f -- "$stage"
      return 1
    fi
    [[ "$(file_hash "$target")" == "$(jq -r .source_hash <<<"$item")" ]] || return 1
    [[ "$(stat -c %a "$target")" == "${mode#0}" && "$(stat -c %U:%G "$target")" == root:root ]] || return 1
  done
}

apply_component() {
  local component="$1" assume_yes="$2" payload root_dir deployment_id deployment_dir receipt entries_json entry source target existed before_hash before_mode backup_rel
  local -a entries=()
  payload="$(component_json "$component")"
  [[ "$(jq -r .readiness <<<"$payload")" == ready ]] || fail "component is not ready: $(jq -r .reason <<<"$payload")"
  print_plan "$component"
  confirmation "APPLY SYSTEM $component" "$assume_yes"
  require_root
  exec 9>"$LOCK_FILE"
  flock -w 5 9 || fail 'another system deployment is active'

  root_dir="$(backup_root)"
  install -d -o root -g root -m 700 -- "$root_dir"
  deployment_id="$(date +%Y%m%d-%H%M%S)-$component-$$"
  deployment_dir="$root_dir/$deployment_id"
  install -d -o root -g root -m 700 -- "$deployment_dir" "$deployment_dir/backups"
  receipt="$deployment_dir/receipt.json"
  entries_json='[]'

  mapfile -t entries < <(jq -c '.entries[]' <<<"$payload")
  for entry in "${entries[@]}"; do
    source="$(resolve_source "$(jq -r .source <<<"$entry")")"
    target="$(resolve_target "$(jq -r .target.root <<<"$entry")" "$(jq -r .target.path <<<"$entry")")"
    [[ ! -L "$target" ]] || fail "refusing symbolic-link target: $target"
    existed=false
    before_hash=''
    before_mode=''
    backup_rel=''
    if [[ -e "$target" ]]; then
      [[ -f "$target" ]] || fail "target is not a regular file: $target"
      existed=true
      before_hash="$(file_hash "$target")"
      before_mode="$(stat -c %a "$target")"
      backup_rel="backups/$(jq -r .id <<<"$entry")"
      cp --preserve=mode,ownership,timestamps -- "$target" "$deployment_dir/$backup_rel"
    fi
    entries_json="$(jq -c \
      --argjson entries "$entries_json" \
      --arg id "$(jq -r .id <<<"$entry")" \
      --arg source "$(jq -r .source <<<"$entry")" \
      --arg root "$(jq -r .target.root <<<"$entry")" \
      --arg path "$(jq -r .target.path <<<"$entry")" \
      --arg mode "$(jq -r .mode <<<"$entry")" \
      --arg source_hash "$(file_hash "$source")" \
      --argjson existed "$existed" \
      --arg before_hash "$before_hash" \
      --arg before_mode "$before_mode" \
      --arg backup "$backup_rel" \
      '$entries + [{id:$id,source:$source,target:{root:$root,path:$path},mode:$mode,source_hash:$source_hash,existed:$existed,before_hash:(if $before_hash=="" then null else $before_hash end),before_mode:(if $before_mode=="" then null else $before_mode end),backup:(if $backup=="" then null else $backup end)}]' <<<"{}")"
  done

  write_json_atomic "$receipt" "$(jq -n \
    --arg id "$deployment_id" --arg component "$component" --arg status prepared \
    --arg created_at "$(date --iso-8601=seconds)" --argjson entries "$entries_json" \
    '{schema_version:1,id:$id,component:$component,status:$status,created_at:$created_at,entries:$entries}')"

  if ! install_from_receipt "$receipt" || ! run_post_checks "$payload"; then
    update_receipt_status "$receipt" failed
    if restore_receipt "$receipt" false; then
      update_receipt_status "$receipt" auto-rolled-back
      fail "deployment failed validation and the previous files were restored; receipt: $receipt"
    fi
    fail "deployment failed and automatic restoration also failed; receipt: $receipt"
  fi
  update_receipt_status "$receipt" applied
  printf 'System deployment applied: %s\n' "$deployment_id"
  printf 'Receipt: %s\n' "$receipt"
  printf 'No SDDM restart, logout, reboot, or compositor reload was run.\n'
}

rollback_component() {
  local id="$1" assume_yes="$2" root_dir deployment_dir receipt status receipt_component recovery_status
  require_root
  [[ "$id" =~ ^[0-9]{8}-[0-9]{6}-[a-z0-9-]+-[0-9]+$ ]] || fail 'invalid deployment ID'
  root_dir="$(backup_root)"
  deployment_dir="$(realpath -m -- "$root_dir/$id")"
  [[ "$deployment_dir" == "$root_dir/"* ]] || fail 'unsafe deployment path'
  receipt="$deployment_dir/receipt.json"
  [[ -f "$receipt" && ! -L "$receipt" ]] || fail "receipt is unavailable: $id"
  status="$(jq -r .status "$receipt")"
  [[ "$status" == applied || "$status" == prepared || "$status" == failed ]] || fail "receipt cannot be rolled back from status: $status"
  receipt_component="$(jq -r .component "$receipt")"
  if [[ "$receipt_component" == sddm || "$receipt_component" == recovery ]] &&
     getent passwd senomy-recovery >/dev/null 2>&1; then
    recovery_status="$(passwd -S senomy-recovery 2>/dev/null | awk '{print $2}')"
    case "$recovery_status" in
      L|LK) ;;
      P) fail 'disable Senomy recovery before rolling back its SDDM guards or runtime' ;;
      *) fail 'cannot prove that the Senomy recovery account is locked; rollback refused' ;;
    esac
  fi
  confirmation "ROLL BACK SYSTEM $id" "$assume_yes"
  exec 9>"$LOCK_FILE"
  flock -w 5 9 || fail 'another system deployment is active'
  restore_receipt "$receipt" true || fail "rollback failed; inspect $receipt"
  update_receipt_status "$receipt" rolled-back
  printf 'System deployment rolled back: %s\n' "$id"
  printf 'No SDDM restart, logout, reboot, or compositor reload was run.\n'
}

list_components() {
  jq -r '.components[] | [.id,.readiness,.description] | @tsv' "$MANIFEST"
}

history() {
  local root_dir receipt
  require_root
  root_dir="$(backup_root)"
  [[ -d "$root_dir" ]] || return 0
  while IFS= read -r -d '' receipt; do
    jq -r '[.id,.component,.status,.created_at] | @tsv' "$receipt"
  done < <(find "$root_dir" -mindepth 2 -maxdepth 2 -type f -name receipt.json -print0 | sort -z)
}

require_commands
validate_manifest

case "$ACTION" in
  list) list_components ;;
  plan) [[ $# -eq 2 ]] || fail 'plan requires COMPONENT'; print_plan "$2" ;;
  apply)
    [[ $# -eq 2 || ( $# -eq 3 && "$3" == --yes ) ]] || fail 'apply requires COMPONENT [--yes]'
    apply_component "$2" "$( [[ "${3:-}" == --yes ]] && printf true || printf false )"
    ;;
  history) [[ $# -eq 1 ]] || fail 'history takes no arguments'; history ;;
  rollback)
    [[ $# -eq 2 || ( $# -eq 3 && "$3" == --yes ) ]] || fail 'rollback requires DEPLOYMENT_ID [--yes]'
    rollback_component "$2" "$( [[ "${3:-}" == --yes ]] && printf true || printf false )"
    ;;
  help|-h|--help) usage ;;
  *) usage >&2; exit 2 ;;
esac
