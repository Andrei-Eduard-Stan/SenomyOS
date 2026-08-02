#!/usr/bin/env bash

# Validate the central avatar manifest and update Senomy's ambient visual state.

set -u

export LC_ALL=C

readonly ACTION="${1:-catalog}"
readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly CONFIG_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
readonly MANIFEST="${SENOMY_AVATAR_MANIFEST:-$CONFIG_DIR/data/senomy-avatars.json}"
readonly EWW_BIN="${EWW_BIN:-/usr/bin/eww}"
readonly EWW_CONFIG="${EWW_CONFIG:-$CONFIG_DIR}"
readonly JQ_BIN="${JQ_BIN:-/usr/bin/jq}"

fail() {
  printf 'SenomyOS avatar: %s\n' "$1" >&2
  exit 1
}

emit_error() {
  local code="$1"
  local message="$2"
  local observed_at

  observed_at="$(date +%s)"
  "$JQ_BIN" -cn \
    --arg code "$code" \
    --arg message "$message" \
    --argjson observed_at "$observed_at" \
    '{
      schema_version: 1,
      ok: false,
      source: "senomy-avatar-manifest",
      observed_at: $observed_at,
      data: {default_state: "idle", states: []},
      error: {code: $code, message: $message}
    }'
}

validate_manifest() {
  local relative
  local state_id

  [[ -x "$JQ_BIN" ]] || fail "jq is unavailable"
  [[ -r "$MANIFEST" ]] || return 1

  "$JQ_BIN" -e '
    . as $manifest
    | .schema_version == 1
      and (.default_state | type == "string")
      and (.states | type == "array" and length > 0)
      and all(.states[];
        (.id | type == "string"
          and test("^[a-z0-9][a-z0-9_-]{0,31}$"))
        and (.label | type == "string" and length > 0 and length <= 64)
        and (.emotion | type == "string" and length <= 64)
        and (.activity | type == "string" and length <= 64)
        and (.chibi | type == "string"
          and startswith("assets/senomy/")
          and (contains("..") | not))
        and (.portrait | type == "string"
          and startswith("assets/senomy/")
          and (contains("..") | not)))
      and ([.states[].id] | length == (unique | length))
      and ([.states[].id] | index($manifest.default_state) != null)
  ' "$MANIFEST" >/dev/null 2>&1 || return 1

  while IFS=$'\t' read -r state_id relative; do
    [[ -r "$CONFIG_DIR/$relative" ]] || {
      printf 'Missing %s avatar asset: %s\n' "$state_id" "$relative" >&2
      return 1
    }
  done < <(
    "$JQ_BIN" -r '.states[] | [.id, .chibi, .id, .portrait] | @tsv' "$MANIFEST" |
      while IFS=$'\t' read -r chibi_id chibi portrait_id portrait; do
        printf '%s\t%s\n%s\t%s\n' "$chibi_id" "$chibi" "$portrait_id" "$portrait"
      done
  )
}

emit_catalog() {
  local observed_at

  if ! validate_manifest; then
    emit_error "invalid_manifest" \
      "The avatar manifest or one of its referenced assets is invalid."
    return
  fi

  observed_at="$(date +%s)"
  "$JQ_BIN" -c \
    --arg root "$CONFIG_DIR" \
    --argjson observed_at "$observed_at" '
      {
        schema_version: 1,
        ok: true,
        source: "senomy-avatar-manifest",
        observed_at: $observed_at,
        data: {
          default_state: .default_state,
          states: [
            .states[] | {
              id,
              label,
              emotion,
              activity,
              chibi_path: ($root + "/" + .chibi),
              portrait_path: ($root + "/" + .portrait)
            }
          ]
        },
        error: null
      }
    ' "$MANIFEST"
}

set_state() {
  local state="${1:-}"

  [[ -n "$state" ]] || fail "Usage: senomy-avatar.sh set STATE"
  validate_manifest || fail "Avatar manifest validation failed"
  "$JQ_BIN" -e --arg state "$state" \
    'any(.states[]; .id == $state)' "$MANIFEST" >/dev/null ||
    fail "Unknown avatar state: $state"
  [[ -x "$EWW_BIN" ]] || fail "Eww is unavailable"

  "$EWW_BIN" \
    --config "$EWW_CONFIG" \
    update "chibi_state=$state"
}

case "$ACTION" in
  catalog)
    [[ $# -eq 1 ]] || fail "Usage: senomy-avatar.sh catalog"
    emit_catalog
    ;;
  list)
    [[ $# -eq 1 ]] || fail "Usage: senomy-avatar.sh list"
    validate_manifest || fail "Avatar manifest validation failed"
    "$JQ_BIN" -r '.states[] | "\(.id)\t\(.label)\t\(.emotion)\t\(.activity)"' \
      "$MANIFEST"
    ;;
  set)
    [[ $# -eq 2 ]] || fail "Usage: senomy-avatar.sh set STATE"
    set_state "$2"
    ;;
  reset)
    [[ $# -eq 1 ]] || fail "Usage: senomy-avatar.sh reset"
    validate_manifest || fail "Avatar manifest validation failed"
    set_state "$("$JQ_BIN" -r '.default_state' "$MANIFEST")"
    ;;
  show)
    [[ $# -eq 1 ]] || fail "Usage: senomy-avatar.sh show"
    [[ -x "$EWW_BIN" ]] || fail "Eww is unavailable"
    "$EWW_BIN" --config "$EWW_CONFIG" get chibi_state
    ;;
  *)
    fail "Usage: senomy-avatar.sh {catalog|list|set STATE|reset|show}"
    ;;
esac
