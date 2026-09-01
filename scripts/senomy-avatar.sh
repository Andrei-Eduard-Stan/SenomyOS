#!/usr/bin/env bash

# Validate the central avatar manifest and update Senomy's ambient visual state.

set -u

export LC_ALL=C

readonly ACTION="${1:-catalog}"
readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly DEFAULT_CONFIG_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
readonly CONFIG_DIR="${SENOMY_EWW_CONFIG:-$DEFAULT_CONFIG_DIR}"
readonly MANIFEST="${SENOMY_AVATAR_MANIFEST:-$CONFIG_DIR/data/senomy-avatars.json}"
readonly EWW_BIN="${EWW_BIN:-/usr/bin/eww}"
readonly EWW_CONFIG="${EWW_CONFIG:-$CONFIG_DIR}"
readonly JQ_BIN="${JQ_BIN:-/usr/bin/jq}"
readonly CACHE_ROOT="${SENOMY_AVATAR_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/senomyos/avatars}"

fail() {
  printf 'SenomyOS avatar: %s\n' "$1" >&2
  exit 1
}

image_identify() {
  if command -v magick >/dev/null 2>&1; then
    magick identify "$@"
  else
    identify "$@"
  fi
}

image_convert() {
  if command -v magick >/dev/null 2>&1; then
    magick "$@"
  else
    convert "$@"
  fi
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
  local relative state_id extension mime bytes dimensions frames width height

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
        and ((.bar // .chibi) | type == "string"
          and startswith("assets/senomy/")
          and (contains("..") | not)
          and test("^[A-Za-z0-9_./-]+$")
          and test("\\.(svg|png|jpe?g|gif)$"; "i"))
        and (.chibi | type == "string"
          and startswith("assets/senomy/")
          and (contains("..") | not)
          and test("^[A-Za-z0-9_./-]+$")
          and test("\\.(svg|png|jpe?g|gif)$"; "i"))
        and (.portrait | type == "string"
          and startswith("assets/senomy/")
          and (contains("..") | not)
          and test("^[A-Za-z0-9_./-]+$")
          and test("\\.(svg|png|jpe?g|gif)$"; "i")))
      and ([.states[].id] | length == (unique | length))
      and ([.states[].id] | index($manifest.default_state) != null)
  ' "$MANIFEST" >/dev/null 2>&1 || return 1

  while IFS=$'\t' read -r state_id relative; do
    [[ -r "$CONFIG_DIR/$relative" ]] || {
      printf 'Missing %s avatar asset: %s\n' "$state_id" "$relative" >&2
      return 1
    }
    extension="${relative##*.}"
    extension="${extension,,}"
    mime="$(file -b --mime-type "$CONFIG_DIR/$relative" 2>/dev/null || true)"
    case "$extension:$mime" in
      svg:image/svg+xml | svg:text/xml | png:image/png | jpg:image/jpeg | jpeg:image/jpeg | gif:image/gif) ;;
      *)
        printf 'Avatar asset format mismatch for %s: %s reports %s\n' "$state_id" "$relative" "${mime:-unknown}" >&2
        return 1
        ;;
    esac
    if [[ "$extension" == gif ]]; then
      command -v magick >/dev/null 2>&1 ||
        { command -v identify >/dev/null 2>&1 && command -v convert >/dev/null 2>&1; } || {
        printf 'Animated GIF avatars require ImageMagick\n' >&2
        return 1
      }
      bytes="$(stat -c %s "$CONFIG_DIR/$relative" 2>/dev/null || printf 0)"
      [[ "$bytes" =~ ^[0-9]+$ ]] && ((bytes <= 33554432)) || {
        printf 'Animated GIF avatar exceeds the 32 MiB safety limit: %s\n' "$relative" >&2
        return 1
      }
      dimensions="$(image_identify -format '%n %w %h\n' "$CONFIG_DIR/$relative" 2>/dev/null | head -n 1 || true)"
      read -r frames width height <<<"$dimensions"
      [[ "$frames" =~ ^[1-9][0-9]*$ && "$width" =~ ^[1-9][0-9]*$ && "$height" =~ ^[1-9][0-9]*$ ]] || {
        printf 'Unable to inspect animated GIF avatar: %s\n' "$relative" >&2
        return 1
      }
      ((frames <= 300 && width <= 4096 && height <= 4096)) || {
        printf 'Animated GIF avatar exceeds 300 frames or 4096x4096 pixels: %s\n' "$relative" >&2
        return 1
      }
    fi
  done < <("$JQ_BIN" -r '
    .states[]
    | .id as $id
    | ([$id, (.bar // .chibi)], [$id, .chibi], [$id, .portrait])
    | @tsv
  ' "$MANIFEST")
}

render_asset() {
  local relative="$1" size="$2" source extension digest output temporary
  source="$CONFIG_DIR/$relative"
  extension="${relative##*.}"
  extension="${extension,,}"
  if [[ "$extension" != gif ]]; then
    printf '%s\n' "$source"
    return 0
  fi

  mkdir -p -m 700 "$CACHE_ROOT" || return 1
  digest="$(sha256sum "$source" | awk '{print $1}')" || return 1
  output="$CACHE_ROOT/${digest}-${size}.gif"
  if [[ ! -s "$output" ]]; then
    temporary="$(mktemp --suffix=.gif "$CACHE_ROOT/.avatar.XXXXXX")" || return 1
    if ! image_convert "$source" -coalesce -resize "${size}x${size}" -layers Optimize "$temporary"; then
      rm -f "$temporary"
      return 1
    fi
    chmod 600 "$temporary"
    mv -f "$temporary" "$output"
  fi
  printf '%s\n' "$output"
}

emit_catalog() {
  local observed_at render_rows render_path state_id bar chibi portrait context variant size relative
  local renders_json

  if ! validate_manifest; then
    emit_error "invalid_manifest" \
      "The avatar manifest or one of its referenced assets is invalid."
    return
  fi

  render_rows="$(mktemp "${TMPDIR:-/tmp}/senomy-avatar-renders.XXXXXX")" || {
    emit_error "cache_unavailable" "Unable to prepare avatar render paths."
    return
  }
  while IFS=$'\t' read -r state_id bar chibi portrait; do
    while IFS=$'\t' read -r context variant size; do
      if [[ "$variant" == bar ]]; then
        relative="$bar"
      elif [[ "$variant" == chibi ]]; then
        relative="$chibi"
      else
        relative="$portrait"
      fi
      if ! render_path="$(render_asset "$relative" "$size")"; then
        rm -f "$render_rows"
        emit_error "render_failed" "Unable to prepare an animated avatar render."
        return
      fi
      printf '%s\t%s\t%s\n' "$state_id" "$context" "$render_path" >>"$render_rows"
    done <<'EOF'
bar	bar	48
observer	portrait	52
overview	chibi	74
insights-hero	chibi	102
power	chibi	104
companion	chibi	288
companion-compact	chibi	248
EOF
  done < <("$JQ_BIN" -r '.states[] | [.id, (.bar // .chibi), .chibi, .portrait] | @tsv' "$MANIFEST")
  renders_json="$("$JQ_BIN" -Rsc '
    split("\n")
    | map(select(length > 0) | split("\t") | {state:.[0],context:.[1],path:.[2]})
  ' "$render_rows")"
  rm -f "$render_rows"

  observed_at="$(date +%s)"
  "$JQ_BIN" -c \
    --arg root "$CONFIG_DIR" \
    --argjson renders "$renders_json" \
    --argjson observed_at "$observed_at" '
      def asset_format:
        split(".")[-1] | ascii_downcase | if . == "jpeg" then "jpg" else . end;
      def render_path($state; $context):
        [$renders[] | select(.state == $state and .context == $context) | .path][0];
      {
        schema_version: 1,
        ok: true,
        source: "senomy-avatar-manifest",
        observed_at: $observed_at,
        data: {
          default_state: .default_state,
          supported_formats: ["svg", "png", "jpg", "jpeg", "gif"],
          animated_formats: ["gif"],
          states: [
            .states[] | {
              id,
              label,
              emotion,
              activity,
              chibi_path: ($root + "/" + .chibi),
              portrait_path: ($root + "/" + .portrait),
              chibi_format: (.chibi | asset_format),
              portrait_format: (.portrait | asset_format),
              bar_path: render_path(.id; "bar"),
              observer_path: render_path(.id; "observer"),
              overview_path: render_path(.id; "overview"),
              insights_hero_path: render_path(.id; "insights-hero"),
              power_path: render_path(.id; "power"),
              companion_path: render_path(.id; "companion"),
              companion_compact_path: render_path(.id; "companion-compact")
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
    "$EWW_BIN" --no-daemonize --config "$EWW_CONFIG" get chibi_state
    ;;
  *)
    fail "Usage: senomy-avatar.sh {catalog|list|set STATE|reset|show}"
    ;;
esac
