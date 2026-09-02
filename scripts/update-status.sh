#!/usr/bin/env bash

# Maintain a bounded, read-only package availability cache for Senomy Insights.
# Official and AUR checks are separate so network disclosure is always explicit.

set -u

export LC_ALL=C

readonly ACTION="${1:-read}"
readonly USER_HOME="${HOME:-/nonexistent}"
readonly CACHE_FILE="${SENOMY_UPDATES_CACHE:-${XDG_CACHE_HOME:-"$USER_HOME/.cache"}/senomyos/updates.json}"
readonly CACHE_DIR="$(dirname "$CACHE_FILE")"
readonly LOCK_FILE="${CACHE_FILE}.lock"
readonly CHECK_TIMEOUT="${SENOMY_UPDATES_TIMEOUT:-30}"
readonly PACKAGE_LIMIT="${SENOMY_UPDATES_LIMIT:-100}"
readonly PACMAN_SYNC_ROOT="${SENOMY_PACMAN_SYNC_ROOT:-/var/lib/pacman/sync}"

now_epoch() {
  printf '%(%s)T' -1
}

epoch_label() {
  local epoch="$1"

  if ((epoch > 0)); then
    date -d "@$epoch" '+%Y-%m-%d %H:%M' 2>/dev/null || printf 'UNKNOWN'
  else
    printf 'NEVER'
  fi
}

emit_dependency_error() {
  local observed_at
  observed_at="$(now_epoch)"

  printf \
    '{"schema_version":1,"ok":false,"source":"senomy-updates-cache","observed_at":%s,"data":{"state":"error","active_check":"none","known_total_count":0,"successful_source_count":0,"last_attempt_at":0,"last_attempt_label":"NEVER","official":{"state":"unavailable","state_label":"UNAVAILABLE","ok":false,"source":"none","freshness":"unknown","checked_at":0,"checked_at_label":"NEVER","count":0,"shown_count":0,"truncated":false,"packages":[],"warning":null,"error":{"code":"dependency_missing","message":"Required command jq is unavailable"}},"aur":{"state":"unavailable","state_label":"UNAVAILABLE","ok":false,"source":"none","freshness":"unknown","checked_at":0,"checked_at_label":"NEVER","count":0,"shown_count":0,"truncated":false,"packages":[],"warning":"An AUR check queries aur.archlinux.org with installed foreign package names.","error":{"code":"dependency_missing","message":"Required command jq is unavailable"}}},"error":{"code":"dependency_missing","message":"Required command jq is unavailable"}}\n' \
    "$observed_at"
  exit 0
}

command -v jq >/dev/null 2>&1 || emit_dependency_error

initial_payload() {
  local observed_at
  observed_at="$(now_epoch)"

  jq -nc \
    --argjson observed_at "$observed_at" \
    '{
      schema_version: 1,
      ok: true,
      source: "senomy-updates-cache",
      observed_at: $observed_at,
      data: {
        state: "never_checked",
        active_check: "none",
        known_total_count: 0,
        successful_source_count: 0,
        last_attempt_at: 0,
        last_attempt_label: "NEVER",
        official: {
          state: "never_checked",
          state_label: "NOT CHECKED",
          ok: false,
          source: "none",
          freshness: "unknown",
          checked_at: 0,
          checked_at_label: "NEVER",
          count: 0,
          shown_count: 0,
          truncated: false,
          packages: [],
          warning: "Without checkupdates, the fallback reads pacman local databases and may be stale.",
          error: null
        },
        aur: {
          state: "never_checked",
          state_label: "NOT CHECKED",
          ok: false,
          source: "none",
          freshness: "unknown",
          checked_at: 0,
          checked_at_label: "NEVER",
          count: 0,
          shown_count: 0,
          truncated: false,
          packages: [],
          warning: "An AUR check queries aur.archlinux.org with installed foreign package names.",
          error: null
        }
      },
      error: null
    }'
}

cache_is_valid() {
  jq -e '
    .schema_version == 1
    and (.data | type == "object")
    and (.data.official | type == "object")
    and (.data.aur | type == "object")
    and (.data.official.packages | type == "array")
    and (.data.aur.packages | type == "array")
  ' "$CACHE_FILE" >/dev/null 2>&1
}

emit_invalid_cache() {
  local observed_at
  observed_at="$(now_epoch)"

  initial_payload |
    jq -c \
      --argjson observed_at "$observed_at" \
      '
        .ok = false
        | .observed_at = $observed_at
        | .data.state = "error"
        | .error = {
            code: "cache_invalid",
            message: "The cached update record is invalid. Run a new source check to replace it."
          }
      '
}

emit_collector_error() {
  local code="$1"
  local message="$2"
  local observed_at
  observed_at="$(now_epoch)"

  initial_payload |
    jq -c \
      --argjson observed_at "$observed_at" \
      --arg code "$code" \
      --arg message "$message" \
      '
        .ok = false
        | .observed_at = $observed_at
        | .data.state = "error"
        | .error = {
            code: $code,
            message: $message
          }
      '
}

read_cache() {
  if [[ ! -e "$CACHE_FILE" ]]; then
    initial_payload
  elif [[ -r "$CACHE_FILE" ]] && cache_is_valid; then
    jq -c . "$CACHE_FILE"
  else
    emit_invalid_cache
  fi
}

load_for_update() {
  if [[ -r "$CACHE_FILE" ]] && cache_is_valid; then
    jq -c . "$CACHE_FILE"
  else
    initial_payload
  fi
}

write_cache() {
  local payload="$1"
  local temporary

  mkdir -p "$CACHE_DIR" 2>/dev/null || return 1
  temporary="$(mktemp "$CACHE_DIR/.updates.json.XXXXXX")" || return 1

  if ! printf '%s\n' "$payload" > "$temporary" ||
    ! jq -e . "$temporary" >/dev/null 2>&1; then
    rm -f -- "$temporary"
    return 1
  fi

  chmod 600 "$temporary"
  mv -f -- "$temporary" "$CACHE_FILE"
}

resolve_command() {
  local override="$1"
  local name="$2"

  if [[ -n "$override" ]]; then
    [[ -x "$override" ]] || return 1
    printf '%s\n' "$override"
    return 0
  fi

  command -v "$name" 2>/dev/null
}

parse_packages() {
  local output_file="$1"
  local source="$2"

  jq -Rsc \
    --arg source "$source" \
    --argjson limit "$PACKAGE_LIMIT" \
    '
      (split("\n") | map(select(length > 0))) as $lines
      | (
          $lines
          | map(
              capture(
                "^(?<name>[^[:space:]]+)[[:space:]]+(?<current>[^[:space:]]+)[[:space:]]+->[[:space:]]+(?<available>[^[:space:]]+)$"
              )?
            )
        ) as $parsed
      | if ($parsed | length) != ($lines | length) then
          error("Package source returned an unexpected line format")
        else
          {
            count: ($parsed | length),
            shown_count: ([($parsed | length), $limit] | min),
            truncated: (($parsed | length) > $limit),
            packages: (
              $parsed[0:$limit]
              | map({
                  name: (.name[0:96]),
                  current: (.current[0:96]),
                  available: (.available[0:96]),
                  source: $source
                })
            )
          }
        end
    ' "$output_file"
}

source_error() {
  local state="$1"
  local source="$2"
  local freshness="$3"
  local checked_at="$4"
  local warning="$5"
  local code="$6"
  local message="$7"
  local state_label

  case "$state" in
    unavailable)
      state_label="UNAVAILABLE"
      ;;
    *)
      state_label="CHECK FAILED"
      ;;
  esac

  jq -nc \
    --arg state "$state" \
    --arg state_label "$state_label" \
    --arg source "$source" \
    --arg freshness "$freshness" \
    --argjson checked_at "$checked_at" \
    --arg checked_at_label "$(epoch_label "$checked_at")" \
    --arg warning "$warning" \
    --arg code "$code" \
    --arg message "$message" \
    '{
      state: $state,
      state_label: $state_label,
      ok: false,
      source: $source,
      freshness: $freshness,
      checked_at: $checked_at,
      checked_at_label: $checked_at_label,
      count: 0,
      shown_count: 0,
      truncated: false,
      packages: [],
      warning: (if $warning == "" then null else $warning end),
      error: {
        code: $code,
        message: $message
      }
    }'
}

source_success() {
  local source="$1"
  local freshness="$2"
  local checked_at="$3"
  local warning="$4"
  local parsed="$5"
  local database_updated_at="${6:-0}"

  jq -nc \
    --arg source "$source" \
    --arg freshness "$freshness" \
    --argjson checked_at "$checked_at" \
    --arg checked_at_label "$(epoch_label "$checked_at")" \
    --arg warning "$warning" \
    --argjson parsed "$parsed" \
    --argjson database_updated_at "$database_updated_at" \
    --arg database_updated_label "$(epoch_label "$database_updated_at")" \
    '{
      state: "ready",
      state_label: "READY",
      ok: true,
      source: $source,
      freshness: $freshness,
      checked_at: $checked_at,
      checked_at_label: $checked_at_label,
      database_updated_at: $database_updated_at,
      database_updated_label: $database_updated_label,
      count: $parsed.count,
      shown_count: $parsed.shown_count,
      truncated: $parsed.truncated,
      packages: $parsed.packages,
      warning: (if $warning == "" then null else $warning end),
      error: null
    }'
}

latest_pacman_database_epoch() {
  local latest=0
  local database
  local modified

  shopt -s nullglob
  for database in "$PACMAN_SYNC_ROOT"/*.db; do
    modified="$(stat -c '%Y' "$database" 2>/dev/null || printf '0')"
    [[ "$modified" =~ ^[0-9]+$ ]] || modified=0
    ((modified > latest)) && latest="$modified"
  done
  shopt -u nullglob

  printf '%s\n' "$latest"
}

check_official() {
  local checked_at
  local checkupdates_bin
  local pacman_bin
  local timeout_bin
  local output_file="$1"
  local error_file="$2"
  local status=0
  local parsed
  local database_updated_at

  checked_at="$(now_epoch)"

  if ! timeout_bin="$(resolve_command "${SENOMY_TIMEOUT_BIN:-}" timeout)"; then
    source_error \
      "unavailable" "none" "unknown" "$checked_at" "" \
      "dependency_missing" "Required command timeout is unavailable"
    return
  fi

  if checkupdates_bin="$(resolve_command "${SENOMY_CHECKUPDATES_BIN:-}" checkupdates)"; then
    "$timeout_bin" "${CHECK_TIMEOUT}s" "$checkupdates_bin" >"$output_file" 2>"$error_file" ||
      status=$?

    if ((status == 0 || status == 2)) && [[ ! -s "$error_file" ]]; then
      if parsed="$(parse_packages "$output_file" "checkupdates" 2>/dev/null)"; then
        source_success "checkupdates" "repository-check" "$checked_at" "" "$parsed"
      else
        source_error \
          "error" "checkupdates" "repository-check" "$checked_at" "" \
          "malformed_output" "The official package source returned unexpected output"
      fi
    elif ((status == 124)); then
      source_error \
        "error" "checkupdates" "repository-check" "$checked_at" "" \
        "timed_out" "The official package check timed out"
    else
      source_error \
        "error" "checkupdates" "repository-check" "$checked_at" "" \
        "query_failed" "The official package check failed"
    fi
    return
  fi

  if ! pacman_bin="$(resolve_command "${SENOMY_PACMAN_BIN:-}" pacman)"; then
    source_error \
      "unavailable" "none" "unknown" "$checked_at" "" \
      "dependency_missing" "Neither checkupdates nor pacman is available"
    return
  fi

  status=0
  "$timeout_bin" "${CHECK_TIMEOUT}s" \
    "$pacman_bin" -Qun --color never >"$output_file" 2>"$error_file" ||
    status=$?

  if ((status == 0 || status == 1)) && [[ ! -s "$error_file" ]]; then
    if parsed="$(parse_packages "$output_file" "pacman-local-db" 2>/dev/null)"; then
      database_updated_at="$(latest_pacman_database_epoch)"
      source_success \
        "pacman-local-db" "local-database" "$checked_at" \
        "This result uses local pacman sync databases and may not reflect current repository state." \
        "$parsed" "$database_updated_at"
    else
      source_error \
        "error" "pacman-local-db" "local-database" "$checked_at" \
        "This result uses local pacman sync databases and may not reflect current repository state." \
        "malformed_output" "The local pacman query returned unexpected output"
    fi
  elif ((status == 124)); then
    source_error \
      "error" "pacman-local-db" "local-database" "$checked_at" \
      "This fallback reads local package databases only." \
      "timed_out" "The local pacman query timed out"
  else
    source_error \
      "error" "pacman-local-db" "local-database" "$checked_at" \
      "This fallback reads local package databases only." \
      "query_failed" "The local pacman query failed"
  fi
}

check_aur() {
  local checked_at
  local paru_bin
  local timeout_bin
  local output_file="$1"
  local error_file="$2"
  local status=0
  local parsed
  local privacy_notice
  local privacy_attempted

  checked_at="$(now_epoch)"
  privacy_notice="An AUR check queries aur.archlinux.org with installed foreign package names."
  privacy_attempted="This check may have sent installed foreign package names to aur.archlinux.org."

  if ! timeout_bin="$(resolve_command "${SENOMY_TIMEOUT_BIN:-}" timeout)"; then
    source_error \
      "unavailable" "none" "unknown" "$checked_at" "$privacy_notice" \
      "dependency_missing" "Required command timeout is unavailable"
    return
  fi

  if ! paru_bin="$(resolve_command "${SENOMY_PARU_BIN:-}" paru)"; then
    source_error \
      "unavailable" "none" "unknown" "$checked_at" "$privacy_notice" \
      "dependency_missing" "Required command paru is unavailable"
    return
  fi

  "$timeout_bin" "${CHECK_TIMEOUT}s" \
    "$paru_bin" -Qua --nodevel --color never >"$output_file" 2>"$error_file" ||
    status=$?

  if ((status == 0)) || {
    ((status == 1)) && [[ ! -s "$output_file" && ! -s "$error_file" ]]
  }; then
    if parsed="$(parse_packages "$output_file" "paru-aur" 2>/dev/null)"; then
      source_success \
        "paru-aur" "aur-rpc" "$checked_at" \
        "This query sent installed foreign package names to aur.archlinux.org." \
        "$parsed"
    else
      source_error \
        "error" "paru-aur" "aur-rpc" "$checked_at" "$privacy_attempted" \
        "malformed_output" "The AUR package source returned unexpected output"
    fi
  elif ((status == 124)); then
    source_error \
      "error" "paru-aur" "aur-rpc" "$checked_at" "$privacy_attempted" \
      "timed_out" "The AUR package check timed out"
  else
    source_error \
      "error" "paru-aur" "aur-rpc" "$checked_at" "$privacy_attempted" \
      "query_failed" "The AUR package check failed"
  fi
}

normalize_payload() {
  jq -c '
    [.data.official, .data.aur] as $sources
    | ($sources | map(select(.state == "ready"))) as $ready
    | ($sources | map(select(.state == "error" or .state == "unavailable"))) as $failed
    | ($sources | map(select(.state == "checking"))) as $checking
    | ($sources | map(select(.checked_at > 0)) | sort_by(.checked_at)) as $attempted
    | .data.known_total_count = ($ready | map(.count) | add // 0)
    | .data.successful_source_count = ($ready | length)
    | .data.last_attempt_at = ($attempted[-1].checked_at // 0)
    | .data.last_attempt_label = ($attempted[-1].checked_at_label // "NEVER")
    | .data.active_check = (
        if ($checking | length) == 0 then "none"
        elif .data.official.state == "checking" then "official"
        else "aur"
        end
      )
    | .data.state = (
        if ($checking | length) > 0 then "checking"
        elif ($ready | length) == 0 and ($failed | length) == 0 then "never_checked"
        elif ($ready | length) == 0 then "error"
        elif ($failed | length) > 0 then "partial"
        else "ready"
        end
      )
    | .ok = (.data.state != "error")
    | .error = (
        if .data.state == "error" then
          {
            code: "all_sources_failed",
            message: "No package source returned a successful result"
          }
        else
          null
        end
      )
  '
}

mark_checking() {
  local payload="$1"
  local target="$2"
  local observed_at
  observed_at="$(now_epoch)"

  jq -c \
    --arg target "$target" \
    --argjson observed_at "$observed_at" \
    '
      .observed_at = $observed_at
      | .data[$target].state = "checking"
      | .data[$target].state_label = "CHECKING"
      | .data[$target].ok = false
      | .data[$target].warning = (
          if $target == "aur" then
            "Querying aur.archlinux.org with installed foreign package names."
          else
            "Reading official package availability without installing anything."
          end
        )
      | .data[$target].error = null
    ' <<< "$payload" |
    normalize_payload
}

run_check() {
  local target="$1"
  local payload
  local checking
  local result
  local final
  local work_dir
  local output_file
  local error_file
  local observed_at

  [[ "$CHECK_TIMEOUT" =~ ^[1-9][0-9]*$ ]] && ((CHECK_TIMEOUT <= 120)) || {
    emit_collector_error \
      "invalid_configuration" "Update timeout must be between 1 and 120 seconds"
    return
  }
  [[ "$PACKAGE_LIMIT" =~ ^[1-9][0-9]*$ ]] && ((PACKAGE_LIMIT <= 500)) || {
    emit_collector_error \
      "invalid_configuration" "Update package limit must be between 1 and 500"
    return
  }

  mkdir -p "$CACHE_DIR" 2>/dev/null || {
    emit_collector_error \
      "cache_write_failed" "Unable to create the update cache directory"
    return
  }

  exec 9>"$LOCK_FILE" || {
    emit_collector_error \
      "lock_failed" "Unable to open the update check lock"
    return
  }

  command -v flock >/dev/null 2>&1 || {
    emit_collector_error \
      "dependency_missing" "Required command flock is unavailable"
    return
  }

  if ! flock -n 9; then
    read_cache
    return
  fi

  payload="$(load_for_update)"
  checking="$(mark_checking "$payload" "$target")"
  write_cache "$checking" || {
    emit_collector_error \
      "cache_write_failed" "Unable to write the update check state"
    return
  }

  work_dir="$(mktemp -d "${TMPDIR:-/tmp}/senomy-updates.XXXXXX")" || {
    emit_collector_error \
      "temporary_directory_failed" "Unable to create update check workspace"
    return
  }
  output_file="$work_dir/output"
  error_file="$work_dir/error"
  trap "rm -rf -- '$work_dir'" EXIT

  case "$target" in
    official)
      result="$(check_official "$output_file" "$error_file")"
      ;;
    aur)
      result="$(check_aur "$output_file" "$error_file")"
      ;;
  esac

  observed_at="$(now_epoch)"
  final="$(
    jq -c \
      --arg target "$target" \
      --argjson observed_at "$observed_at" \
      --argjson result "$result" \
      '
        .observed_at = $observed_at
        | .data[$target] = $result
      ' <<< "$checking" |
      normalize_payload
  )"

  write_cache "$final" || {
    emit_collector_error \
      "cache_write_failed" "Unable to save the update result"
    return
  }

  printf '%s\n' "$final"
}

case "$ACTION" in
  read)
    read_cache
    ;;
  check-official)
    run_check "official"
    ;;
  check-aur)
    run_check "aur"
    ;;
  *)
    initial_payload |
      jq -c \
        --arg action "$ACTION" \
        '
          .ok = false
          | .data.state = "error"
          | .error = {
              code: "invalid_action",
              message: ("Unsupported update collector action: " + $action)
            }
        '
    ;;
esac
