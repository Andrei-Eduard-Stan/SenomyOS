#!/usr/bin/env bash

# Deterministic contract tests for the presentation-only workspace viewport.

set -euo pipefail
export LC_ALL=C

readonly CONFIG_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly CAROUSEL="$CONFIG_DIR/scripts/workspace-carousel.sh"
readonly WORKSPACE_ACTION="$CONFIG_DIR/scripts/workspace-action.sh"
readonly WIDGET="$CONFIG_DIR/widgets/workspace-widget.yuck"
readonly STANDARD_LAYOUT='{"data":{"phone":false,"narrow":false}}'
readonly PHONE_LAYOUT='{"data":{"phone":true,"narrow":true}}'

make_state() {
  local ids="$1"
  local active_id="$2"

  jq -cn \
    --argjson ids "$ids" \
    --argjson active_id "$active_id" '
      {
        data: {
          workspaces: [
            $ids[] as $id
            | {
                id: $id,
                active: ($id == $active_id),
                occupied: true,
                app_count: 1,
                grid_rows: []
              }
          ]
        }
      }
    '
}

calculate() {
  local action="$1"
  local state="$2"
  local layout="$3"
  local offset="$4"
  local slot="${5:-0}"

  env \
    SENOMY_WORKSPACE_CAROUSEL_STATE_JSON="$state" \
    SENOMY_WORKSPACE_CAROUSEL_LAYOUT_JSON="$layout" \
    SENOMY_WORKSPACE_CAROUSEL_OFFSET="$offset" \
    SENOMY_WORKSPACE_CAROUSEL_SLOT="$slot" \
    "$CAROUSEL" "$action"
}

fewer_state="$(make_state '[2,7,42]' 7)"
calculate reconcile "$fewer_state" "$STANDARD_LAYOUT" 2 |
  jq -e '.count == 3 and .capacity == 4 and .offset == 0 and .overflow == false and .changed == true and .slot == 1' >/dev/null

exact_state="$(make_state '[2,7,42,88]' 42)"
calculate next "$exact_state" "$STANDARD_LAYOUT" 0 |
  jq -e '.count == 4 and .max_offset == 0 and .offset == 0 and .changed == false' >/dev/null

one_over_state="$(make_state '[2,7,42,88,99]' 2)"
calculate next "$one_over_state" "$STANDARD_LAYOUT" 0 0 |
  jq -e '.overflow == true and .offset == 1 and .previous_offset == 0 and .slot == 1' >/dev/null
calculate next "$one_over_state" "$STANDARD_LAYOUT" 1 1 |
  jq -e '.offset == 1 and .max_offset == 1 and .slot == 1 and .changed == false' >/dev/null
env \
  SENOMY_WORKSPACE_CAROUSEL_STATE_JSON="$one_over_state" \
  SENOMY_WORKSPACE_CAROUSEL_LAYOUT_JSON="$STANDARD_LAYOUT" \
  SENOMY_WORKSPACE_CAROUSEL_OFFSET=0 \
  "$CAROUSEL" scroll right |
  jq -e '.offset == 1 and .direction == "next"' >/dev/null
env \
  SENOMY_WORKSPACE_CAROUSEL_STATE_JSON="$one_over_state" \
  SENOMY_WORKSPACE_CAROUSEL_LAYOUT_JSON="$STANDARD_LAYOUT" \
  SENOMY_WORKSPACE_CAROUSEL_OFFSET=1 \
  "$CAROUSEL" scroll left |
  jq -e '.offset == 0 and .direction == "previous"' >/dev/null

many_state="$(make_state '[2,7,42,88,99,105,144,233,377]' 2)"
step_one="$(calculate next "$many_state" "$STANDARD_LAYOUT" 0 0)"
step_two="$(calculate next "$many_state" "$STANDARD_LAYOUT" 1 1)"
step_back="$(calculate previous "$many_state" "$STANDARD_LAYOUT" 2 0)"
jq -e '.offset == 1 and .slot == 1' >/dev/null <<<"$step_one"
jq -e '.offset == 2 and .slot == 0' >/dev/null <<<"$step_two"
jq -e '.offset == 1 and .slot == 1 and .direction == "previous"' >/dev/null <<<"$step_back"

active_last_state="$(make_state '[2,7,42,88,99,105,144,233]' 233)"
calculate reconcile "$active_last_state" "$STANDARD_LAYOUT" 0 |
  jq -e '.active_index == 7 and .offset == 4 and .max_offset == 4' >/dev/null

active_before_state="$(make_state '[2,7,42,88,99,105,144,233]' 7)"
calculate reconcile "$active_before_state" "$STANDARD_LAYOUT" 4 |
  jq -e '.active_index == 1 and .offset == 1' >/dev/null

calculate reconcile "$fewer_state" "$STANDARD_LAYOUT" 5 |
  jq -e '.offset == 0 and .max_offset == 0 and .overflow == false and .changed == true and .slot == 1' >/dev/null

calculate reconcile "$one_over_state" "$PHONE_LAYOUT" 3 |
  jq -e '.count == 1 and .capacity == 1 and .offset == 0 and .overflow == false' >/dev/null

grep -qF '(stack' "$WIDGET"
[[ "$(grep -cF '(workspace-carousel-page' "$WIDGET")" -eq 2 ]]
grep -qF ':onscroll "$HOME/.config/eww/scripts/workspace-carousel.sh scroll {}"' "$WIDGET"
if grep -qF 'hyprctl' "$CAROUSEL"; then
  printf 'Carousel helper must not duplicate or mutate Hyprland workspace truth.\n' >&2
  exit 1
fi

action_test_root="$(mktemp -d)"
trap 'rm -rf -- "$action_test_root"' EXIT
cat >"$action_test_root/hyprctl" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  binds)
    printf '[]\n'
    ;;
  monitors)
    printf '[{"focused":true,"specialWorkspace":{"name":""}}]\n'
    ;;
  dispatch)
    printf '%s\n' "$*" >"$SENOMY_WORKSPACE_ACTION_LOG"
    ;;
  *)
    exit 2
    ;;
esac
EOF
chmod 755 "$action_test_root/hyprctl"
SENOMY_HYPRCTL_BIN="$action_test_root/hyprctl" \
  SENOMY_WORKSPACE_ACTION_LOG="$action_test_root/action.log" \
  "$WORKSPACE_ACTION" switch 377
grep -qxF 'dispatch workspace 377' "$action_test_root/action.log"

printf 'PASS  Workspace carousel clamps arbitrary IDs/counts, double-buffers transitions, follows active state, and returns cleanly to non-overflow\n'
