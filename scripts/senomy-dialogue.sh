#!/usr/bin/env bash

# Select one bounded Senomy dialogue record from the versioned catalog.
# The selector is deterministic within a time slot, so Eww reloads do not make
# the line flicker. Uncommon lines appear in one out of every five slots.

set -u

export LC_ALL=C

readonly CATEGORY="${1:-ambient}"
readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly CATALOG="${SENOMY_DIALOGUE_CATALOG:-"$SCRIPT_DIR/../data/senomy-dialogue.json"}"
readonly SLOT_SECONDS="${SENOMY_DIALOGUE_SLOT_SECONDS:-900}"

printf -v observed_at '%(%s)T' -1

emit_fallback() {
  printf '%s\n' \
    '{"schema_version":1,"ok":false,"source":"senomy-dialogue","observed_at":0,"data":{"id":"ambient-fallback","category":"ambient","severity":"ambient","rarity":"common","language":"en","tone":"calm","text":"Everything looks steady."},"error":{"code":"catalog_unavailable","message":"Dialogue catalog is unavailable"}}'
  exit 0
}

command -v jq >/dev/null 2>&1 || emit_fallback
[[ -r "$CATALOG" ]] || emit_fallback
[[ "$SLOT_SECONDS" =~ ^[1-9][0-9]*$ ]] || emit_fallback

jq -e '
  .schema_version == 1
  and (.lines | type == "array")
  and all(
    .lines[];
    (.id | type == "string")
    and (.category | type == "string")
    and (.severity | type == "string")
    and (.rarity | type == "string")
    and (.language | type == "string")
    and (.tone | type == "string")
    and (.text | type == "string")
  )
' "$CATALOG" >/dev/null 2>&1 || emit_fallback

slot=$((observed_at / SLOT_SECONDS))

# Every fifth slot selects from the uncommon pool when one exists.
rarity="common"
((slot % 5 == 0)) && rarity="uncommon"

jq -nc \
  --argjson catalog "$(cat "$CATALOG")" \
  --argjson observed_at "$observed_at" \
  --argjson slot "$slot" \
  --arg category "$CATEGORY" \
  --arg rarity "$rarity" \
  '
    (
      $catalog.lines
      | map(select(.category == $category and .rarity == $rarity))
    ) as $preferred
    | (
        if ($preferred | length) > 0 then
          $preferred
        else
          $catalog.lines | map(select(.category == $category))
        end
      ) as $pool
    | if ($pool | length) == 0 then
        {
          schema_version: 1,
          ok: false,
          source: "senomy-dialogue",
          observed_at: $observed_at,
          data: {
            id: "ambient-fallback",
            category: "ambient",
            severity: "ambient",
            rarity: "common",
            language: "en",
            tone: "calm",
            text: "Everything looks steady."
          },
          error: {
            code: "category_unavailable",
            message: "Requested dialogue category is unavailable"
          }
        }
      else
        {
          schema_version: 1,
          ok: true,
          source: "senomy-dialogue",
          observed_at: $observed_at,
          data: $pool[($slot % ($pool | length))],
          error: null
        }
      end
  '
