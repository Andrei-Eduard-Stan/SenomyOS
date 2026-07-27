#!/usr/bin/env bash

# Publish the legacy workspace label and structured workspace/application state.
# The existing user service remains the single workspace update path.

set -u

export LC_ALL=C

readonly EWW_BIN="/usr/bin/eww"
readonly HYPRCTL_BIN="/usr/bin/hyprctl"
readonly JQ_BIN="/usr/bin/jq"
readonly EWW_CONFIG="${XDG_CONFIG_HOME:-"$HOME/.config"}/eww"
readonly ICON_MAP="$EWW_CONFIG/data/app-icons.json"

readonly SHRINK_THRESHOLD=3
readonly SYNC_INTERVAL=10
readonly ACTIVE_APP_LIMIT=4
readonly INACTIVE_APP_LIMIT=2

last_text=""
last_json=""
last_max=1
shrink_streak=0
sync_age=0

next_text=""
next_json=""

required_commands_available() {
  [[ -x "$EWW_BIN" ]] &&
    [[ -x "$HYPRCTL_BIN" ]] &&
    [[ -x "$JQ_BIN" ]]
}

read_icon_map() {
  local icon_json

  if [[ ! -r "$ICON_MAP" ]]; then
    printf '{}\n'
    return
  fi

  icon_json="$(< "$ICON_MAP")"

  if "$JQ_BIN" -e 'type == "object"' >/dev/null 2>&1 <<< "$icon_json"; then
    printf '%s\n' "$icon_json"
  else
    printf '{}\n'
  fi
}

build_once() {
  local workspaces_json
  local active_json
  local clients_json
  local icons_json
  local active
  local proposed_max
  local workspace_id
  local observed_at
  local output

  workspaces_json="$("$HYPRCTL_BIN" -j workspaces 2>/dev/null)" ||
    return 1

  active_json="$("$HYPRCTL_BIN" -j activeworkspace 2>/dev/null)" ||
    return 1

  clients_json="$("$HYPRCTL_BIN" -j clients 2>/dev/null)" ||
    return 1

  "$JQ_BIN" -e 'type == "array"' >/dev/null 2>&1 \
    <<< "$workspaces_json" ||
    return 1

  "$JQ_BIN" -e 'type == "object"' >/dev/null 2>&1 \
    <<< "$active_json" ||
    return 1

  "$JQ_BIN" -e 'type == "array"' >/dev/null 2>&1 \
    <<< "$clients_json" ||
    return 1

  active="$("$JQ_BIN" -r '.id // 1' <<< "$active_json")"

  [[ "$active" =~ ^[1-9][0-9]*$ ]] ||
    active=1

  proposed_max="$(
    "$JQ_BIN" -r \
      --argjson active "$active" \
      '
        [
          .[]
          | .id
          | select(type == "number" and . > 0)
        ] + [$active]
        | max // 1
      ' <<< "$workspaces_json"
  )"

  [[ "$proposed_max" =~ ^[1-9][0-9]*$ ]] ||
    proposed_max="$last_max"

  if ((proposed_max < last_max)); then
    shrink_streak=$((shrink_streak + 1))

    if ((shrink_streak < SHRINK_THRESHOLD)); then
      proposed_max="$last_max"
    fi
  else
    shrink_streak=0
  fi

  last_max="$proposed_max"

  output=""

  for ((workspace_id = 1; workspace_id <= proposed_max; workspace_id++)); do
    if ((workspace_id == active)); then
      output+=" [$workspace_id]"
    else
      output+=" $workspace_id"
    fi
  done

  next_text="${output# }"
  icons_json="$(read_icon_map)"
  printf -v observed_at '%(%s)T' -1

  next_json="$(
    "$JQ_BIN" -nc \
      --argjson workspaces "$workspaces_json" \
      --argjson active_workspace "$active_json" \
      --argjson clients "$clients_json" \
      --argjson icons "$icons_json" \
      --argjson max_id "$proposed_max" \
      --argjson observed_at "$observed_at" \
      --argjson active_app_limit "$ACTIVE_APP_LIMIT" \
      --argjson inactive_app_limit "$INACTIVE_APP_LIMIT" \
      '
        def client_key:
          if ((.initialClass // "") | length) > 0 then
            .initialClass | ascii_downcase
          elif ((.class // "") | length) > 0 then
            .class | ascii_downcase
          else
            "unknown"
          end;

        def client_name($client; $metadata):
          if (($metadata.name // "") | length) > 0 then
            $metadata.name
          elif (($client.initialClass // "") | length) > 0 then
            $client.initialClass
          elif (($client.class // "") | length) > 0 then
            $client.class
          else
            "Application"
          end;

        def client_icon($metadata):
          if (($metadata.icon // "") | length) > 0 then
            $metadata.icon
          else
            "application-x-executable"
          end;

        def workspace_apps($workspace_id):
          [
            $clients[]
            | select(
                (.mapped == true)
                and ((.hidden // false) == false)
                and (.workspace.id == $workspace_id)
                and (.workspace.id > 0)
              )
            | . as $client
            | ($client | client_key) as $key
            | ($icons[$key] // {}) as $metadata
            | {
                key: $key,
                name: client_name($client; $metadata),
                icon: client_icon($metadata)
              }
          ]
          | sort_by(.key)
          | group_by(.key)
          | map(
              . as $group
              | $group[0] + {
                  count: ($group | length)
                }
            );

        ($active_workspace.id // 1) as $active_id
        | {
            schema_version: 1,
            ok: true,
            source: "hyprland",
            observed_at: $observed_at,
            data: {
              active_id: $active_id,
              max_id: $max_id,
              workspaces: [
                range(1; $max_id + 1) as $workspace_id
                | workspace_apps($workspace_id) as $all_apps
                | (
                    if $workspace_id == $active_id then
                      $active_app_limit
                    else
                      $inactive_app_limit
                    end
                  ) as $display_limit
                | {
                    id: $workspace_id,
                    active: ($workspace_id == $active_id),
                    occupied: (($all_apps | length) > 0),
                    app_count: ($all_apps | length),
                    apps: $all_apps[0:$display_limit],
                    overflow_count: (
                      [
                        (($all_apps | length) - $display_limit),
                        0
                      ]
                      | max
                    ),
                    summary: (
                      $all_apps
                      | if length == 0 then
                          "Empty workspace"
                        else
                          map(
                            .name
                            + (
                                if .count > 1 then
                                  " ×\(.count)"
                                else
                                  ""
                                end
                              )
                          )
                          | join(", ")
                        end
                    )
                  }
              ]
            },
            error: null
          }
      '
  )" || return 1
}

publish() {
  local combined_update_succeeded=false

  build_once || return

  sync_age=$((sync_age + 1))

  if [[ "$next_text" == "$last_text" &&
        "$next_json" == "$last_json" &&
        "$sync_age" -lt "$SYNC_INTERVAL" ]]; then
    return
  fi

  "$EWW_BIN" --config "$EWW_CONFIG" ping >/dev/null 2>&1 ||
    return

  if "$EWW_BIN" --config "$EWW_CONFIG" update \
    "workspaces=$next_text" \
    "workspace_state=$next_json" >/dev/null 2>&1; then
    combined_update_succeeded=true
  fi

  if [[ "$combined_update_succeeded" == true ]]; then
    last_text="$next_text"
    last_json="$next_json"
    sync_age=0
    return
  fi

  # Preserve the old workspace label while Eww is still loading an older config.
  if "$EWW_BIN" --config "$EWW_CONFIG" update \
    "workspaces=$next_text" >/dev/null 2>&1; then
    last_text="$next_text"
  fi
}

required_commands_available || {
  printf 'SenomyOS workspaces: required commands are unavailable\n' >&2
  exit 1
}

while true; do
  publish
  sleep 1
done