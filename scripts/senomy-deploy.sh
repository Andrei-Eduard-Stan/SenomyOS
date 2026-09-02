#!/usr/bin/env bash

# Transactional deployment for SenomyOS-owned user files and explicitly
# supported deterministic merges. This command never reloads Eww, restarts
# applications, or writes privileged paths.

set -euo pipefail
export LC_ALL=C
umask 077

readonly ACTION="${1:-help}"
readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
readonly MANIFEST="${SENOMY_DEPLOY_MANIFEST:-$REPO_ROOT/deploy/manifest.json}"
readonly USER_HOME="${HOME:-/nonexistent}"
readonly XDG_CONFIG_ROOT="${XDG_CONFIG_HOME:-$USER_HOME/.config}"
readonly XDG_DATA_ROOT="${XDG_DATA_HOME:-$USER_HOME/.local/share}"
readonly USER_BIN_ROOT="$USER_HOME/.local/bin"
readonly RUNTIME_ROOT="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/senomyos"
readonly LOCK_FILE="$RUNTIME_ROOT/deployment.lock"
declare -a PREPARE_ROOTS=()
PREPARE_ROOT_RESULT=''

cleanup_prepare_roots() {
  local path
  for path in "${PREPARE_ROOTS[@]}"; do
    [[ -z "$path" ]] || rm -rf -- "$path"
  done
}
trap cleanup_prepare_roots EXIT

usage() {
  cat <<'EOF'
Usage:
  senomy-deploy.sh list
  senomy-deploy.sh plan COMPONENT
  senomy-deploy.sh apply COMPONENT [--yes]
  senomy-deploy.sh history
  senomy-deploy.sh rollback DEPLOYMENT_ID [--yes]

list, plan, and history are read-only. apply and rollback require confirmation.
EOF
}

fail() {
  printf 'SenomyOS deployment: %s\n' "$*" >&2
  exit 1
}

require_commands() {
  local command_name
  for command_name in jq sha256sum realpath stat cmp install mktemp flock; do
    command -v "$command_name" >/dev/null 2>&1 ||
      fail "required command is unavailable: $command_name"
  done
}

validate_manifest() {
  [[ -f "$MANIFEST" && ! -L "$MANIFEST" ]] ||
    fail "manifest is unavailable or is a symbolic link: $MANIFEST"

  jq -e '
    .schema_version == 1 and
    (.backup_namespace | type == "string" and length > 0) and
    (.backup_namespace | test("^/|(^|/)\\.\\.(/|$)") | not) and
    (.components | type == "array" and length > 0) and
    ([.components[].id] | length == (unique | length)) and
    all(.components[];
      (.id | type == "string" and test("^[a-z0-9][a-z0-9-]*$")) and
      (.description | type == "string" and length > 0) and
      (.scope | IN("user", "system")) and
      (.readiness | IN("ready", "planned", "in-place")) and
      (.reason | type == "string" and length > 0) and
      ((.warning // "") | type == "string") and
      ((.pre_apply // []) | type == "array") and
      all((.pre_apply // [])[]; IN("thunar-not-running", "hyprlock-installed", "hyprland-lua-valid", "swaybg-installed", "workspaces-unit-valid")) and
      (.post_apply | type == "array") and
      all(.post_apply[]; IN("hyprland-configerrors", "thunar-uca-xml")) and
      (.entries | type == "array") and
      ([.entries[].id] | length == (unique | length)) and
      all(.entries[];
        (.id | type == "string" and test("^[a-z0-9][a-z0-9-]*$")) and
        (.source | type == "string" and length > 0) and
        (.target.root | IN("xdg_config", "xdg_data", "user_bin")) and
        (.target.path | type == "string" and length > 0) and
        (.kind == "file") and
        (.strategy | IN("replace", "thunar-uca-merge")) and
        (if .strategy == "thunar-uca-merge" then
          (.helper_target.root | IN("xdg_config", "xdg_data", "user_bin")) and
          (.helper_target.path | type == "string" and length > 0)
         else
          .helper_target? == null
         end) and
        (.mode | type == "string" and test("^0[0-7]{3}$"))
      )
    )
  ' "$MANIFEST" >/dev/null || fail "manifest schema validation failed"
}

component_json() {
  local component="$1" payload
  payload="$(jq -ce --arg component "$component" '.components[] | select(.id == $component)' "$MANIFEST" 2>/dev/null || true)"
  [[ -n "$payload" ]] || fail "unknown component: $component"
  printf '%s\n' "$payload"
}

validate_relative_path() {
  local path="$1" label="$2"
  [[ -n "$path" && "$path" != /* && "$path" != "." ]] ||
    fail "$label must be a non-empty relative path"
  [[ ! "$path" =~ (^|/)\.\.(/|$) ]] ||
    fail "$label contains parent traversal: $path"
}

canonical_root() {
  local root_id="$1" root home_root
  case "$root_id" in
    xdg_config) root="$XDG_CONFIG_ROOT" ;;
    xdg_data) root="$XDG_DATA_ROOT" ;;
    user_bin) root="$USER_BIN_ROOT" ;;
    *) fail "unsupported target root: $root_id" ;;
  esac

  home_root="$(realpath -m -- "$USER_HOME")"
  root="$(realpath -m -- "$root")"
  [[ -n "$root" && "$root" != / && "$root" != "$home_root" ]] ||
    fail "unsafe target root resolved for $root_id: $root"
  [[ "$root" == "$home_root/"* ]] ||
    fail "user target root resolves outside the home directory: $root"
  printf '%s\n' "$root"
}

resolve_target() {
  local root_id="$1" relative="$2" root target
  validate_relative_path "$relative" "target path"
  root="$(canonical_root "$root_id")"
  target="$(realpath -m -- "$root/$relative")"
  [[ "$target" == "$root/"* ]] ||
    fail "target resolves outside $root_id: $relative"
  printf '%s\n' "$target"
}

resolve_source() {
  local relative="$1" source
  validate_relative_path "$relative" "source path"
  source="$(realpath -e -- "$REPO_ROOT/$relative" 2>/dev/null || true)"
  [[ -n "$source" && "$source" == "$REPO_ROOT/"* ]] ||
    fail "source is missing or resolves outside the repository: $relative"
  [[ -f "$source" && ! -L "$source" ]] ||
    fail "source must be a regular non-symlink file: $relative"
  printf '%s\n' "$source"
}

prepare_entry_source() {
  local entry="$1" target="$2" prepare_root="$3"
  local strategy manifest_source helper_root helper_relative helper_target output generator
  strategy="$(jq -r '.strategy' <<<"$entry")"
  manifest_source="$(resolve_source "$(jq -r '.source' <<<"$entry")")"
  case "$strategy" in
    replace)
      printf '%s\n' "$manifest_source"
      ;;
    thunar-uca-merge)
      command -v python3 >/dev/null 2>&1 || fail "Thunar merge requires python3"
      command -v xmllint >/dev/null 2>&1 || fail "Thunar merge requires xmllint"
      generator="$REPO_ROOT/scripts/thunar-uca-merge.py"
      [[ -f "$generator" && ! -L "$generator" && -x "$generator" ]] ||
        fail "Thunar merge generator is unavailable: $generator"
      helper_root="$(jq -r '.helper_target.root' <<<"$entry")"
      helper_relative="$(jq -r '.helper_target.path' <<<"$entry")"
      helper_target="$(resolve_target "$helper_root" "$helper_relative")"
      output="$(mktemp "$prepare_root/$(jq -r '.id' <<<"$entry").XXXXXX")"
      "$generator" \
        --base "$target" \
        --registry "$manifest_source" \
        --helper-target "$helper_target" \
        --output "$output" >/dev/null || fail "unable to build merged Thunar custom actions"
      xmllint --noout "$output" || fail "generated Thunar custom actions are invalid XML"
      printf '%s\n' "$output"
      ;;
    *) fail "unsupported deployment strategy: $strategy" ;;
  esac
}

new_prepare_root() {
  PREPARE_ROOT_RESULT="$(mktemp -d "${TMPDIR:-/tmp}/senomy-deploy-prepare.XXXXXX")" ||
    fail "unable to create deployment preparation directory"
  chmod 700 "$PREPARE_ROOT_RESULT"
  PREPARE_ROOTS+=("$PREPARE_ROOT_RESULT")
}

normalize_mode() {
  printf '%s\n' "${1#0}"
}

file_hash() {
  sha256sum -- "$1" | awk '{print $1}'
}

entry_state() {
  local source="$1" target="$2" expected_mode="$3" actual_mode
  if [[ ! -e "$target" && ! -L "$target" ]]; then
    printf 'CREATE\n'
    return
  fi
  [[ -f "$target" && ! -L "$target" ]] ||
    fail "target is not a regular non-symlink file: $target"
  actual_mode="$(stat -c %a -- "$target")"
  if cmp -s -- "$source" "$target" && [[ "$actual_mode" == "$(normalize_mode "$expected_mode")" ]]; then
    printf 'UNCHANGED\n'
  else
    printf 'UPDATE\n'
  fi
}

target_fingerprint() {
  local target="$1"
  if [[ ! -e "$target" && ! -L "$target" ]]; then
    printf 'missing\n'
    return
  fi
  [[ -f "$target" && ! -L "$target" ]] ||
    fail "target is not a regular non-symlink file: $target"
  printf '%s:%s\n' "$(file_hash "$target")" "$(stat -c %a -- "$target")"
}

backup_root() {
  local namespace home_root state_root root
  namespace="$(jq -r '.backup_namespace' "$MANIFEST")"
  validate_relative_path "$namespace" "backup namespace"
  home_root="$(realpath -m -- "$USER_HOME")"
  state_root="$(realpath -m -- "${XDG_STATE_HOME:-$USER_HOME/.local/state}")"
  root="$(realpath -m -- "$state_root/$namespace")"
  [[ -n "$state_root" && "$state_root" != / && "$state_root" != "$home_root" ]] ||
    fail "unsafe user state root: $state_root"
  [[ "$state_root" == "$home_root/"* ]] ||
    fail "user state root resolves outside the home directory: $state_root"
  [[ -n "$root" && "$root" == "$state_root/"* ]] ||
    fail "unsafe deployment backup root: $root"
  printf '%s\n' "$root"
}

component_is_ready() {
  local payload="$1" readiness scope reason
  readiness="$(jq -r '.readiness' <<<"$payload")"
  scope="$(jq -r '.scope' <<<"$payload")"
  reason="$(jq -r '.reason' <<<"$payload")"
  [[ "$scope" == user ]] || fail "component requires a separate privileged deployer: $(jq -r '.id' <<<"$payload")"
  [[ "$readiness" == ready ]] || fail "component is $readiness: $reason"
  [[ "$(jq '.entries | length' <<<"$payload")" -gt 0 ]] || fail "ready component has no deployment entries"
}

run_pre_apply_checks() {
  local payload="$1" check_name
  local -a checks=()
  mapfile -t checks < <(jq -r '(.pre_apply // [])[]' <<<"$payload")
  for check_name in "${checks[@]}"; do
    case "$check_name" in
      thunar-not-running)
        command -v pgrep >/dev/null 2>&1 || {
          printf 'Pre-apply validation failed: pgrep is unavailable.\n' >&2
          return 1
        }
        if pgrep -i -x thunar >/dev/null 2>&1; then
          printf 'Pre-apply validation failed: Thunar is running and may overwrite uca.xml on exit.\n' >&2
          return 1
        fi
        ;;
      hyprlock-installed)
        if ! command -v hyprlock >/dev/null 2>&1; then
          printf 'Pre-apply validation failed: hyprlock is not installed.\n' >&2
          return 1
        fi
        ;;
      hyprland-lua-valid)
        if ! command -v Hyprland >/dev/null 2>&1; then
          printf 'Pre-apply validation failed: Hyprland is unavailable.\n' >&2
          return 1
        fi
        if ! Hyprland --verify-config --config "$REPO_ROOT/hyprland.lua" 2>&1 | grep -qF 'config ok'; then
          printf 'Pre-apply validation failed: the tracked Hyprland Lua config is invalid.\n' >&2
          return 1
        fi
        ;;
      swaybg-installed)
        if ! command -v swaybg >/dev/null 2>&1; then
          printf 'Pre-apply validation failed: swaybg is not installed.\n' >&2
          return 1
        fi
        ;;
      workspaces-unit-valid)
        if ! command -v systemd-analyze >/dev/null 2>&1 ||
          ! systemd-analyze --user verify "$REPO_ROOT/systemd/workspaces.service" >/dev/null 2>&1; then
          printf 'Pre-apply validation failed: the workspace user unit is invalid.\n' >&2
          return 1
        fi
        ;;
      *)
        printf 'Pre-apply validation failed: unsupported check %s.\n' "$check_name" >&2
        return 1
        ;;
    esac
  done
}

print_pre_apply_status() {
  local payload="$1" check_name
  local -a checks=()
  mapfile -t checks < <(jq -r '(.pre_apply // [])[]' <<<"$payload")
  for check_name in "${checks[@]}"; do
    case "$check_name" in
      thunar-not-running)
        if command -v pgrep >/dev/null 2>&1 && pgrep -i -x thunar >/dev/null 2>&1; then
          printf 'precondition: BLOCKED while Thunar is running; close it before apply or rollback.\n'
        else
          printf 'precondition: ready; no Thunar process detected.\n'
        fi
        ;;
      hyprlock-installed)
        if command -v hyprlock >/dev/null 2>&1; then
          printf 'precondition: ready; hyprlock is installed.\n'
        else
          printf 'precondition: BLOCKED; install the official hyprlock package first.\n'
        fi
        ;;
      hyprland-lua-valid)
        if command -v Hyprland >/dev/null 2>&1 &&
          Hyprland --verify-config --config "$REPO_ROOT/hyprland.lua" 2>&1 | grep -qF 'config ok'; then
          printf 'precondition: ready; Hyprland accepts the tracked Lua configuration.\n'
        else
          printf 'precondition: BLOCKED; the tracked Hyprland Lua configuration is invalid.\n'
        fi
        ;;
      swaybg-installed)
        if command -v swaybg >/dev/null 2>&1; then
          printf 'precondition: ready; swaybg is installed.\n'
        else
          printf 'precondition: BLOCKED; install the official swaybg package first.\n'
        fi
        ;;
      workspaces-unit-valid)
        if command -v systemd-analyze >/dev/null 2>&1 &&
          systemd-analyze --user verify "$REPO_ROOT/systemd/workspaces.service" >/dev/null 2>&1; then
          printf 'precondition: ready; the workspace user unit is valid.\n'
        else
          printf 'precondition: BLOCKED; the workspace user unit is invalid.\n'
        fi
        ;;
    esac
  done
}

print_component_plan() {
  local component="$1" payload readiness description reason warning
  local entry source target root_id relative mode state prepare_root
  local -a entries=()

  payload="$(component_json "$component")"
  readiness="$(jq -r '.readiness' <<<"$payload")"
  description="$(jq -r '.description' <<<"$payload")"
  reason="$(jq -r '.reason' <<<"$payload")"
  warning="$(jq -r '.warning // empty' <<<"$payload")"

  printf 'SENOMYOS DEPLOYMENT PLAN // %s\n' "$component"
  printf 'status: %s\n' "$readiness"
  printf 'scope: %s\n' "$(jq -r '.scope' <<<"$payload")"
  printf 'description: %s\n' "$description"
  [[ -z "$warning" ]] || printf 'warning: %s\n' "$warning"
  print_pre_apply_status "$payload"

  if [[ "$readiness" != ready ]]; then
    printf 'reason: %s\n' "$reason"
    return 0
  fi

  component_is_ready "$payload"
  new_prepare_root
  prepare_root="$PREPARE_ROOT_RESULT"
  mapfile -t entries < <(jq -c '.entries[]' <<<"$payload")
  for entry in "${entries[@]}"; do
    root_id="$(jq -r '.target.root' <<<"$entry")"
    relative="$(jq -r '.target.path' <<<"$entry")"
    target="$(resolve_target "$root_id" "$relative")"
    source="$(prepare_entry_source "$entry" "$target" "$prepare_root")"
    mode="$(jq -r '.mode' <<<"$entry")"
    state="$(entry_state "$source" "$target" "$mode")"
    printf '%-10s %-18s %s -> %s (mode %s)\n' \
      "$state" "$(jq -r '.id' <<<"$entry")" "$(jq -r '.source' <<<"$entry")" "$target" "$mode"
  done
}

run_post_apply_checks() {
  local payload="$1" check_name errors attempt check_passed entry root_id relative target
  local -a checks=()
  mapfile -t checks < <(jq -r '.post_apply[]' <<<"$payload")
  for check_name in "${checks[@]}"; do
    case "$check_name" in
      hyprland-configerrors)
        command -v hyprctl >/dev/null 2>&1 || {
          printf 'Post-apply validation failed: hyprctl is unavailable.\n' >&2
          return 1
        }
        errors=''
        check_passed=false
        for attempt in {1..10}; do
          sleep 0.1
          if errors="$(hyprctl configerrors 2>&1)" && [[ -z "$errors" ]]; then
            check_passed=true
            break
          fi
        done
        if [[ "$check_passed" != true ]]; then
          printf 'Post-apply validation failed: Hyprland reported configuration errors or was unreachable.\n%s\n' "$errors" >&2
          return 1
        fi
        ;;
      thunar-uca-xml)
        command -v xmllint >/dev/null 2>&1 || {
          printf 'Post-apply validation failed: xmllint is unavailable.\n' >&2
          return 1
        }
        entry="$(jq -ce '.entries[] | select(.strategy == "thunar-uca-merge" or .id == "uca")' <<<"$payload" 2>/dev/null | head -n 1 || true)"
        [[ -n "$entry" ]] || {
          printf 'Post-apply validation failed: Thunar UCA target is missing from the component.\n' >&2
          return 1
        }
        root_id="$(jq -r '.target.root' <<<"$entry")"
        relative="$(jq -r '.target.path' <<<"$entry")"
        target="$(resolve_target "$root_id" "$relative")"
        [[ -f "$target" && ! -L "$target" ]] && xmllint --noout "$target" || {
          printf 'Post-apply validation failed: generated Thunar uca.xml is invalid.\n' >&2
          return 1
        }
        ;;
      *)
        printf 'Post-apply validation failed: unsupported check %s.\n' "$check_name" >&2
        return 1
        ;;
    esac
  done
}

list_components() {
  printf 'COMPONENT          SCOPE   STATUS     DESCRIPTION\n'
  jq -r '.components[] | [.id, .scope, .readiness, .description] | @tsv' "$MANIFEST" |
    while IFS=$'\t' read -r id scope readiness description; do
      printf '%-18s %-7s %-10s %s\n' "$id" "$scope" "$readiness" "$description"
    done
}

confirmation() {
  local phrase="$1" assume_yes="$2" reply
  [[ "$assume_yes" == true ]] && return 0
  [[ -t 0 ]] || fail "confirmation requires an interactive terminal or --yes"
  printf 'Type %s to continue: ' "$phrase" >&2
  IFS= read -r reply
  [[ "$reply" == "$phrase" ]] || fail "confirmation did not match; no changes were made"
}

acquire_lock() {
  mkdir -p -m 700 -- "$RUNTIME_ROOT" || fail "unable to create deployment runtime directory"
  exec 9>"$LOCK_FILE" || fail "unable to open deployment lock"
  flock -w 3 9 || fail "another SenomyOS deployment operation is active"
}

write_receipt_status() {
  local receipt="$1" status="$2" field="$3" value="$4" temporary
  temporary="$(mktemp "${receipt}.XXXXXX")"
  jq --arg status "$status" --arg field "$field" --arg value "$value" \
    '.status = $status | .[$field] = $value' "$receipt" >"$temporary" || {
      rm -f -- "$temporary"
      return 1
    }
  chmod 600 "$temporary"
  mv -fT -- "$temporary" "$receipt"
}

restore_receipt() {
  local receipt="$1" check_drift="$2" deployment_dir status
  local item target root_id relative existed before_hash source_hash before_mode backup_rel backup_file current_hash stage
  local index
  local -a items=()

  deployment_dir="$(dirname -- "$receipt")"
  status="$(jq -r '.status' "$receipt")"
  mapfile -t items < <(jq -c '.entries[]' "$receipt")

  if [[ "$check_drift" == true ]]; then
    for item in "${items[@]}"; do
      root_id="$(jq -r '.target.root' <<<"$item")"
      relative="$(jq -r '.target.path' <<<"$item")"
      target="$(resolve_target "$root_id" "$relative")"
      existed="$(jq -r '.existed' <<<"$item")"
      before_hash="$(jq -r '.before_hash // empty' <<<"$item")"
      source_hash="$(jq -r '.source_hash' <<<"$item")"

      if [[ -e "$target" || -L "$target" ]]; then
        [[ -f "$target" && ! -L "$target" ]] || fail "rollback target changed type: $target"
        current_hash="$(file_hash "$target")"
        [[ "$current_hash" == "$source_hash" || ( "$existed" == true && "$current_hash" == "$before_hash" ) ]] ||
          fail "rollback refused because target drifted after deployment: $target"
      else
        [[ "$existed" == false ]] || fail "rollback refused because an original target is now missing: $target"
      fi
    done
  fi

  for ((index=${#items[@]}-1; index>=0; index--)); do
    item="${items[index]}"
    root_id="$(jq -r '.target.root' <<<"$item")"
    relative="$(jq -r '.target.path' <<<"$item")"
    target="$(resolve_target "$root_id" "$relative")"
    existed="$(jq -r '.existed' <<<"$item")"
    before_hash="$(jq -r '.before_hash // empty' <<<"$item")"
    before_mode="$(jq -r '.before_mode // empty' <<<"$item")"

    if [[ "$existed" == true ]]; then
      backup_rel="$(jq -r '.backup' <<<"$item")"
      validate_relative_path "$backup_rel" "receipt backup path"
      [[ ! -L "$deployment_dir/$backup_rel" ]] || fail "deployment backup is a symbolic link"
      backup_file="$(realpath -e -- "$deployment_dir/$backup_rel" 2>/dev/null || true)"
      [[ -n "$backup_file" && "$backup_file" == "$deployment_dir/"* ]] ||
        fail "deployment backup resolves outside its receipt directory"
      [[ -f "$backup_file" && ! -L "$backup_file" ]] || fail "deployment backup is unavailable: $backup_file"
      [[ "$(file_hash "$backup_file")" == "$before_hash" ]] || fail "deployment backup checksum failed: $backup_file"
      mkdir -p -m 700 -- "$(dirname -- "$target")"
      stage="$(mktemp "$(dirname -- "$target")/.senomy-restore.XXXXXX")"
      if ! install -m "$before_mode" -- "$backup_file" "$stage" || ! mv -fT -- "$stage" "$target"; then
        rm -f -- "$stage"
        return 1
      fi
      [[ "$(file_hash "$target")" == "$before_hash" ]] || return 1
      [[ "$(stat -c %a -- "$target")" == "$before_mode" ]] || return 1
    else
      if [[ -e "$target" || -L "$target" ]]; then
        [[ -f "$target" && ! -L "$target" ]] || fail "refusing to remove non-file rollback target: $target"
        rm -f -- "$target" || return 1
      fi
      [[ ! -e "$target" && ! -L "$target" ]] || return 1
    fi
  done

  return 0
}

apply_component() {
  local component="$1" assume_yes="$2" payload entry source target root_id relative mode state
  local backup_base deployment_id deployment_dir receipt manifest_hash entries_json item_json
  local existed before_hash before_mode backup_rel backup_file stage failed=false
  local plan_manifest_hash plan_source_hash plan_target_fingerprint prepare_root strategy
  local index
  local -a entries=() changed_entries=()

  payload="$(component_json "$component")"
  component_is_ready "$payload"
  plan_manifest_hash="$(file_hash "$MANIFEST")"
  new_prepare_root
  prepare_root="$PREPARE_ROOT_RESULT"
  mapfile -t entries < <(jq -c '.entries[]' <<<"$payload")

  for entry in "${entries[@]}"; do
    root_id="$(jq -r '.target.root' <<<"$entry")"
    relative="$(jq -r '.target.path' <<<"$entry")"
    target="$(resolve_target "$root_id" "$relative")"
    source="$(prepare_entry_source "$entry" "$target" "$prepare_root")"
    mode="$(jq -r '.mode' <<<"$entry")"
    state="$(entry_state "$source" "$target" "$mode")"
    if [[ "$state" != UNCHANGED ]]; then
      entry="$(jq -c \
        --arg plan_source_hash "$(file_hash "$source")" \
        --arg plan_target_fingerprint "$(target_fingerprint "$target")" \
        '. + {plan_source_hash:$plan_source_hash,plan_target_fingerprint:$plan_target_fingerprint}' <<<"$entry")"
      changed_entries+=("$entry")
    fi
  done

  print_component_plan "$component"
  if ((${#changed_entries[@]} == 0)); then
    printf 'No deployment is required.\n'
    return 0
  fi

  run_pre_apply_checks "$payload" || fail "component pre-apply checks did not pass"
  confirmation "APPLY $component" "$assume_yes"
  acquire_lock
  run_pre_apply_checks "$payload" || fail "component pre-apply checks changed while acquiring the deployment lock"

  [[ "$(file_hash "$MANIFEST")" == "$plan_manifest_hash" ]] ||
    fail "manifest changed after planning; rerun the deployment plan"
  for ((index=0; index<${#changed_entries[@]}; index++)); do
    entry="${changed_entries[index]}"
    root_id="$(jq -r '.target.root' <<<"$entry")"
    relative="$(jq -r '.target.path' <<<"$entry")"
    target="$(resolve_target "$root_id" "$relative")"
    source="$(prepare_entry_source "$entry" "$target" "$prepare_root")"
    plan_source_hash="$(jq -r '.plan_source_hash' <<<"$entry")"
    plan_target_fingerprint="$(jq -r '.plan_target_fingerprint' <<<"$entry")"
    [[ "$(file_hash "$source")" == "$plan_source_hash" ]] ||
      fail "source changed after planning; rerun the deployment plan: $source"
    [[ "$(target_fingerprint "$target")" == "$plan_target_fingerprint" ]] ||
      fail "target changed after planning; rerun the deployment plan: $target"
    changed_entries[index]="$(jq -c --arg prepared_source "$source" '. + {prepared_source:$prepared_source}' <<<"$entry")"
  done

  backup_base="$(backup_root)"
  mkdir -p -m 700 -- "$backup_base"
  deployment_id="$(date +%Y%m%d-%H%M%S)-$component-$$"
  deployment_dir="$backup_base/$deployment_id"
  [[ ! -e "$deployment_dir" ]] || fail "deployment ID collision: $deployment_id"
  mkdir -p -m 700 -- "$deployment_dir/backups"
  receipt="$deployment_dir/receipt.json"
  manifest_hash="$plan_manifest_hash"
  entries_json='[]'

  for entry in "${changed_entries[@]}"; do
    source="$(jq -r '.prepared_source' <<<"$entry")"
    [[ -f "$source" && ! -L "$source" ]] || fail "prepared deployment source is unavailable: $source"
    root_id="$(jq -r '.target.root' <<<"$entry")"
    relative="$(jq -r '.target.path' <<<"$entry")"
    target="$(resolve_target "$root_id" "$relative")"
    mode="$(jq -r '.mode' <<<"$entry")"
    strategy="$(jq -r '.strategy' <<<"$entry")"
    existed=false
    before_hash=''
    before_mode=''
    backup_rel=''

    if [[ -e "$target" || -L "$target" ]]; then
      [[ -f "$target" && ! -L "$target" ]] || fail "target changed type before backup: $target"
      existed=true
      before_hash="$(file_hash "$target")"
      before_mode="$(stat -c %a -- "$target")"
      backup_rel="backups/$(jq -r '.id' <<<"$entry")"
      backup_file="$deployment_dir/$backup_rel"
      cp -a -- "$target" "$backup_file" || fail "unable to back up target: $target"
      [[ "$(file_hash "$backup_file")" == "$before_hash" ]] || fail "backup checksum failed: $target"
    fi

    item_json="$(jq -nc \
      --arg id "$(jq -r '.id' <<<"$entry")" \
      --arg source "$(jq -r '.source' <<<"$entry")" \
      --arg root "$root_id" \
      --arg path "$relative" \
      --arg mode "$(normalize_mode "$mode")" \
      --arg strategy "$strategy" \
      --arg source_hash "$(file_hash "$source")" \
      --arg before_hash "$before_hash" \
      --arg before_mode "$before_mode" \
      --arg backup "$backup_rel" \
      --argjson existed "$existed" \
      '{id:$id,source:$source,strategy:$strategy,target:{root:$root,path:$path},mode:$mode,
        source_hash:$source_hash,existed:$existed,
        before_hash:(if $before_hash=="" then null else $before_hash end),
        before_mode:(if $before_mode=="" then null else $before_mode end),
        backup:(if $backup=="" then null else $backup end)}')"
    entries_json="$(jq -c --argjson item "$item_json" '. + [$item]' <<<"$entries_json")"
  done

  jq -n \
    --arg id "$deployment_id" \
    --arg component "$component" \
    --arg created_at "$(date --iso-8601=seconds)" \
    --arg manifest "$MANIFEST" \
    --arg manifest_hash "$manifest_hash" \
    --argjson pre_apply "$(jq -c '(.pre_apply // [])' <<<"$payload")" \
    --argjson post_apply "$(jq -c '.post_apply' <<<"$payload")" \
    --argjson entries "$entries_json" \
    '{schema_version:1,id:$id,component:$component,status:"prepared",created_at:$created_at,
      manifest:$manifest,manifest_hash:$manifest_hash,pre_apply:$pre_apply,
      post_apply:$post_apply,entries:$entries}' >"$receipt"
  chmod 600 "$receipt"

  for entry in "${changed_entries[@]}"; do
    source="$(jq -r '.prepared_source' <<<"$entry")"
    root_id="$(jq -r '.target.root' <<<"$entry")"
    relative="$(jq -r '.target.path' <<<"$entry")"
    target="$(resolve_target "$root_id" "$relative")"
    mode="$(jq -r '.mode' <<<"$entry")"
    mkdir -p -m 700 -- "$(dirname -- "$target")" || { failed=true; break; }
    stage="$(mktemp "$(dirname -- "$target")/.senomy-deploy.XXXXXX")" || { failed=true; break; }
    if ! install -m "$mode" -- "$source" "$stage" ||
       ! cmp -s -- "$source" "$stage" ||
       ! mv -fT -- "$stage" "$target" ||
       [[ "$(file_hash "$target")" != "$(file_hash "$source")" ]] ||
       [[ "$(stat -c %a -- "$target")" != "$(normalize_mode "$mode")" ]]; then
      rm -f -- "$stage"
      failed=true
      break
    fi
  done

  if [[ "$failed" == false ]] && ! run_post_apply_checks "$payload"; then
    failed=true
  fi

  if [[ "$failed" == true ]]; then
    write_receipt_status "$receipt" failed failed_at "$(date --iso-8601=seconds)" || true
    if restore_receipt "$receipt" false && run_post_apply_checks "$payload"; then
      write_receipt_status "$receipt" auto-rolled-back rolled_back_at "$(date --iso-8601=seconds)" || true
      fail "apply failed; previous files were restored from deployment $deployment_id"
    fi
    fail "apply failed and automatic restoration was incomplete; inspect deployment $deployment_id"
  fi

  write_receipt_status "$receipt" applied applied_at "$(date --iso-8601=seconds)" ||
    fail "files were deployed but the receipt could not be finalized: $deployment_id"
  printf 'Deployment applied: %s\n' "$deployment_id"
  printf 'Receipt: %s\n' "$receipt"
  printf 'No explicit application, service, Eww, or compositor reload command was run.\n'
}

validate_receipt() {
  local receipt="$1" expected_id="$2"
  [[ -f "$receipt" && ! -L "$receipt" ]] || fail "deployment receipt is unavailable: $expected_id"
  jq -e --arg id "$expected_id" '
    .schema_version == 1 and .id == $id and
    (.component | type == "string" and length > 0) and
    (.status | IN("prepared", "failed", "applied", "auto-rolled-back", "rolled-back")) and
    ((.pre_apply // []) | type == "array") and
    all((.pre_apply // [])[]; IN("thunar-not-running", "hyprlock-installed", "hyprland-lua-valid", "swaybg-installed", "workspaces-unit-valid")) and
    (.post_apply | type == "array") and
    all(.post_apply[]; IN("hyprland-configerrors", "thunar-uca-xml")) and
    (.entries | type == "array" and length > 0) and
    all(.entries[];
      (.id | type == "string") and
      (.source | type == "string") and
      ((.strategy // "replace") | IN("replace", "thunar-uca-merge")) and
      (.target.root | IN("xdg_config", "xdg_data", "user_bin")) and
      (.target.path | type == "string" and length > 0) and
      (.mode | test("^[0-7]{3}$")) and
      (.source_hash | test("^[0-9a-f]{64}$")) and
      (.existed | type == "boolean") and
      (if .existed then
        (.before_hash | type == "string" and test("^[0-9a-f]{64}$")) and
        (.before_mode | type == "string" and test("^[0-7]{3}$")) and
        (.backup | type == "string" and test("^backups/[a-z0-9][a-z0-9-]*$"))
       else
        .before_hash == null and .before_mode == null and .backup == null
       end)
    )
  ' "$receipt" >/dev/null || fail "deployment receipt validation failed: $expected_id"
}

rollback_deployment() {
  local deployment_id="$1" assume_yes="$2" backup_base deployment_dir receipt status component payload
  [[ "$deployment_id" =~ ^[0-9]{8}-[0-9]{6}-[a-z0-9-]+-[0-9]+$ ]] ||
    fail "invalid deployment ID: $deployment_id"
  backup_base="$(backup_root)"
  deployment_dir="$(realpath -m -- "$backup_base/$deployment_id")"
  [[ "$deployment_dir" == "$backup_base/"* ]] || fail "deployment resolves outside the backup root"
  receipt="$deployment_dir/receipt.json"
  validate_receipt "$receipt" "$deployment_id"
  status="$(jq -r '.status' "$receipt")"
  component="$(jq -r '.component' "$receipt")"
  case "$status" in
    rolled-back | auto-rolled-back)
      printf 'Deployment %s is already %s.\n' "$deployment_id" "$status"
      return 0
      ;;
    prepared | failed | applied) ;;
    *) fail "deployment cannot be rolled back from status: $status" ;;
  esac

  printf 'SENOMYOS ROLLBACK PLAN // %s\n' "$deployment_id"
  printf 'component: %s\nstatus: %s\nentries: %s\n' "$component" "$status" "$(jq '.entries | length' "$receipt")"
  payload="$(jq -c '{pre_apply:(.pre_apply // []),post_apply:.post_apply,entries:.entries}' "$receipt")"
  print_pre_apply_status "$payload"
  run_pre_apply_checks "$payload" || fail "component pre-rollback checks did not pass"
  confirmation "ROLLBACK $deployment_id" "$assume_yes"
  acquire_lock
  run_pre_apply_checks "$payload" || fail "component pre-rollback checks changed while acquiring the deployment lock"
  restore_receipt "$receipt" true || fail "rollback failed; inspect receipt: $receipt"
  run_post_apply_checks "$payload" ||
    fail "files were restored but component post-rollback validation failed"
  write_receipt_status "$receipt" rolled-back rolled_back_at "$(date --iso-8601=seconds)" ||
    fail "files were restored but the receipt could not be finalized"
  printf 'Deployment rolled back: %s\n' "$deployment_id"
  printf 'No explicit application, service, Eww, or compositor reload command was run.\n'
}

show_history() {
  local root receipt
  root="$(backup_root)"
  printf 'DEPLOYMENT ID                              STATUS             COMPONENT\n'
  [[ -d "$root" ]] || return 0
  while IFS= read -r -d '' receipt; do
    jq -r '[.id, .status, .component] | @tsv' "$receipt" 2>/dev/null ||
      printf 'INVALID\tINVALID\t%s\n' "$receipt"
  done < <(find "$root" -mindepth 2 -maxdepth 2 -type f -name receipt.json -print0 | sort -zr) |
    while IFS=$'\t' read -r id status component; do
      printf '%-42s %-18s %s\n' "$id" "$status" "$component"
    done
}

require_commands
validate_manifest

case "$ACTION" in
  list)
    [[ $# -eq 1 ]] || fail "list takes no additional arguments"
    list_components
    ;;
  plan)
    [[ $# -eq 2 ]] || fail "Usage: senomy-deploy.sh plan COMPONENT"
    print_component_plan "$2"
    ;;
  apply)
    [[ $# -ge 2 && $# -le 3 ]] || fail "Usage: senomy-deploy.sh apply COMPONENT [--yes]"
    [[ $# -eq 2 || "$3" == --yes ]] || fail "unknown apply option: ${3:-}"
    apply_component "$2" "$( [[ ${3:-} == --yes ]] && printf true || printf false )"
    ;;
  history)
    [[ $# -eq 1 ]] || fail "history takes no additional arguments"
    show_history
    ;;
  rollback)
    [[ $# -ge 2 && $# -le 3 ]] || fail "Usage: senomy-deploy.sh rollback DEPLOYMENT_ID [--yes]"
    [[ $# -eq 2 || "$3" == --yes ]] || fail "unknown rollback option: ${3:-}"
    rollback_deployment "$2" "$( [[ ${3:-} == --yes ]] && printf true || printf false )"
    ;;
  help | --help | -h)
    usage
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
