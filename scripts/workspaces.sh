#!/usr/bin/env bash

# Publish workspace/application state after Hyprland events.
# The existing user service remains the single workspace update path.

set -uo pipefail

export LC_ALL=C

readonly EWW_BIN="${SENOMY_EWW_BIN:-/usr/bin/eww}"
readonly FIND_BIN="${SENOMY_FIND_BIN:-/usr/bin/find}"
readonly HYPRCTL_BIN="${SENOMY_HYPRCTL_BIN:-/usr/bin/hyprctl}"
readonly JQ_BIN="${SENOMY_JQ_BIN:-/usr/bin/jq}"
readonly SOCAT_BIN="${SENOMY_SOCAT_BIN:-/usr/bin/socat}"
readonly EWW_CONFIG="${SENOMY_EWW_CONFIG:-${XDG_CONFIG_HOME:-"$HOME/.config"}/eww}"
readonly ICON_MAP="${SENOMY_ICON_MAP:-$EWW_CONFIG/data/app-icons.json}"

readonly HEARTBEAT_SECONDS=10
readonly FULL_RESYNC_SECONDS=300
readonly EVENT_DEBOUNCE_SECONDS="0.04"
readonly EVENT_DRAIN_SECONDS="0.01"
readonly MAX_DRAINED_EVENTS=100
readonly ACTIVE_APP_LIMIT=4
readonly INACTIVE_APP_LIMIT=2

next_text=""
next_json=""
next_data=""

cached_text=""
cached_json=""
cached_data=""

last_published_text=""
last_published_data=""
last_heartbeat_at=0
last_full_resync_at=0

event_fd=""
socat_pid=""
event_socket=""

icon_map_source=""
resolved_icon_map="{}"
resolved_icon_path=""
fallback_icon_path=""
declare -A icon_path_cache=()

log() {
  printf 'SenomyOS workspaces: %s\n' "$1" >&2
}

usage() {
  printf 'Usage: %s [--print-once|--publish-once]\n' "$0" >&2
  exit 2
}

snapshot_commands_available() {
  local command_path

  for command_path in "$FIND_BIN" "$HYPRCTL_BIN" "$JQ_BIN"; do
    if [[ ! -x "$command_path" ]]; then
      log "required command is unavailable: $command_path"
      return 1
    fi
  done
}

runtime_commands_available() {
  local command_path

  snapshot_commands_available || return

  for command_path in "$EWW_BIN" "$SOCAT_BIN"; do
    if [[ ! -x "$command_path" ]]; then
      log "required command is unavailable: $command_path"
      return 1
    fi
  done
}

now_seconds() {
  printf '%(%s)T\n' -1
}

resolve_hyprland_session() {
  local instances_json
  local discovered_signature
  local discovered_wayland

  event_socket=""

  if [[ -z "${XDG_RUNTIME_DIR:-}" && -d "/run/user/$EUID" ]]; then
    export XDG_RUNTIME_DIR="/run/user/$EUID"
  fi

  if [[ -n "${XDG_RUNTIME_DIR:-}" &&
        -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    event_socket="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"

    if [[ -S "$event_socket" ]]; then
      return 0
    fi
  fi

  instances_json="$("$HYPRCTL_BIN" instances -j 2>/dev/null)" || {
    log "unable to discover a running Hyprland instance"
    return 1
  }

  discovered_signature="$(
    "$JQ_BIN" -r '
      [
        .[]?
        | select(
            (.instance | type) == "string"
            and (.instance | test("^[A-Za-z0-9._-]+$"))
            and (.time | type) == "number"
          )
      ]
      | if length == 0 then "" else (max_by(.time).instance) end
    ' <<< "$instances_json"
  )" || return 1

  discovered_wayland="$(
    "$JQ_BIN" -r \
      --arg instance "$discovered_signature" '
        [
          .[]?
          | select(.instance == $instance)
          | .wl_socket
          | select(type == "string")
        ][0] // ""
      ' <<< "$instances_json"
  )" || return 1

  if [[ -z "${XDG_RUNTIME_DIR:-}" || -z "$discovered_signature" ]]; then
    log "Hyprland session environment is unavailable"
    return 1
  fi

  event_socket="$XDG_RUNTIME_DIR/hypr/$discovered_signature/.socket2.sock"
  if [[ ! -S "$event_socket" ]]; then
    log "discovered Hyprland event socket is unavailable: $event_socket"
    return 1
  fi

  export HYPRLAND_INSTANCE_SIGNATURE="$discovered_signature"
  if [[ -n "$discovered_wayland" ]]; then
    export WAYLAND_DISPLAY="$discovered_wayland"
  fi

  log "recovered Hyprland session from runtime instance discovery"
}

resolve_icon_path() {
  local icon_name="$1"
  local data_dir
  local theme_dir
  local candidate
  local size
  local category
  local extension
  local -a data_dirs

  resolved_icon_path=""

  if [[ -z "$icon_name" ]]; then
    return
  fi

  if [[ "$icon_name" == /* ]]; then
    if [[ -r "$icon_name" ]]; then
      resolved_icon_path="$icon_name"
    fi
    return
  fi

  if [[ ! "$icon_name" =~ ^[A-Za-z0-9._+-]+$ ]]; then
    return
  fi

  if [[ ${icon_path_cache[$icon_name]+cached} ]]; then
    resolved_icon_path="${icon_path_cache[$icon_name]}"
    return
  fi

  IFS=: read -r -a data_dirs <<< \
    "${XDG_DATA_HOME:-"$HOME/.local/share"}:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"

  for data_dir in "${data_dirs[@]}"; do
    [[ -n "$data_dir" ]] || continue

    for extension in png svg xpm; do
      candidate="$data_dir/pixmaps/$icon_name.$extension"

      if [[ -r "$candidate" ]]; then
        resolved_icon_path="$candidate"
        break 2
      fi
    done

    for size in 16x16 22x22 24x24 32x32 48x48 scalable; do
      for category in apps mimetypes; do
        for extension in png svg xpm; do
          candidate="$data_dir/icons/hicolor/$size/$category/$icon_name.$extension"

          if [[ -r "$candidate" ]]; then
            resolved_icon_path="$candidate"
            break 4
          fi
        done
      done
    done
  done

  if [[ -z "$resolved_icon_path" ]]; then
    for data_dir in "${data_dirs[@]}"; do
      for theme_dir in "$data_dir"/icons/*; do
        [[ -d "$theme_dir" ]] || continue

        for size in 16x16 22x22 24x24 32x32 48x48 scalable; do
          for category in apps mimetypes; do
            for extension in png svg xpm; do
              candidate="$theme_dir/$size/$category/$icon_name.$extension"

              if [[ -r "$candidate" ]]; then
                resolved_icon_path="$candidate"
                break 5
              fi
            done
          done
        done
      done
    done
  fi

  if [[ -z "$resolved_icon_path" ]]; then
    for data_dir in "${data_dirs[@]}"; do
      [[ -d "$data_dir/icons" ]] || continue

      while IFS= read -r candidate; do
        resolved_icon_path="$candidate"
        break
      done < <(
        "$FIND_BIN" "$data_dir/icons" -type f \
          \( -name "$icon_name.png" \
          -o -name "$icon_name.svg" \
          -o -name "$icon_name.xpm" \) \
          -print 2>/dev/null
      )

      [[ -n "$resolved_icon_path" ]] && break
    done
  fi

  icon_path_cache["$icon_name"]="$resolved_icon_path"
}

load_icon_map() {
  local raw_icon_map

  if [[ -r "$ICON_MAP" ]]; then
    raw_icon_map="$(< "$ICON_MAP")"
  else
    raw_icon_map="{}"
  fi

  if [[ "$raw_icon_map" == "$icon_map_source" ]]; then
    resolved_icon_map="$icon_map_source"
    return
  fi

  if ! "$JQ_BIN" -e 'type == "object"' >/dev/null 2>&1 \
    <<< "$raw_icon_map"; then
    log "icon map is invalid; using generic application icons"
    raw_icon_map="{}"
  fi

  icon_map_source="$raw_icon_map"
  resolved_icon_map="$icon_map_source"

  if [[ -z "$fallback_icon_path" ]]; then
    resolve_icon_path "application-x-executable"
    fallback_icon_path="$resolved_icon_path"
  fi
}

resolve_client_icon_paths() {
  local snapshot_json="$1"
  local key
  local icon_name

  while IFS=$'\t' read -r key icon_name; do
    resolve_icon_path "$icon_name"
    resolved_icon_map="$(
      "$JQ_BIN" -c \
        --arg key "$key" \
        --arg icon_path "$resolved_icon_path" \
        '.[$key].icon_path = $icon_path' \
        <<< "$resolved_icon_map"
    )" || return 1
  done < <(
    "$JQ_BIN" -r \
      --argjson snapshot "$snapshot_json" \
      --argjson icons "$resolved_icon_map" \
      '
        [
          $snapshot.clients[]
          | select(
              (.mapped == true)
              and ((.hidden // false) == false)
              and (.workspace.id > 0)
            )
          | (
              if ((.initialClass // "") | length) > 0 then
                .initialClass
              elif ((.class // "") | length) > 0 then
                .class
              else
                "unknown"
              end
              | ascii_downcase
            ) as $key
          | [
              $key,
              ($icons[$key].icon // "application-x-executable")
            ]
        ]
        | unique_by(.[0])[]
        | @tsv
      ' -n
  )
}

build_once() {
  local snapshot_json
  local observed_at
  local normalized_output
  local -a normalized_lines

  snapshot_json="$(
    "$HYPRCTL_BIN" --batch \
      'j/workspaces;j/activeworkspace;j/clients' 2>/dev/null
  )" || {
    log "hyprctl workspace batch query failed"
    return 1
  }

  snapshot_json="$(
    "$JQ_BIN" -sc \
      '
        if (
          length == 3
          and (.[0] | type) == "array"
          and (.[1] | type) == "object"
          and (.[2] | type) == "array"
        ) then
          {
            workspaces: .[0],
            active_workspace: .[1],
            clients: .[2]
          }
        else
          error("invalid Hyprland workspace batch")
        end
      ' <<< "$snapshot_json"
  )" || {
    log "hyprctl workspace batch returned invalid JSON"
    return 1
  }

  load_icon_map || {
    log "failed to resolve the application icon map"
    return 1
  }
  resolve_client_icon_paths "$snapshot_json" || {
    log "failed to resolve running application icons"
    return 1
  }
  observed_at="$(now_seconds)"

  normalized_output="$(
    "$JQ_BIN" -nr \
      --argjson snapshot "$snapshot_json" \
      --argjson icons "$resolved_icon_map" \
      --arg fallback_icon_path "$fallback_icon_path" \
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

        def client_icon_path($metadata):
          if (($metadata.icon_path // "") | length) > 0 then
            $metadata.icon_path
          else
            $fallback_icon_path
          end;

        def workspace_apps($workspace_id; $clients):
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
                icon: client_icon($metadata),
                icon_path: client_icon_path($metadata)
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

        ($snapshot.active_workspace.id // 1) as $active_candidate
        | (
            if (
              ($active_candidate | type) == "number"
              and $active_candidate > 0
            ) then
              $active_candidate
            else
              1
            end
          ) as $active_id
        | (
            [
              $snapshot.workspaces[]
              | .id
              | select(type == "number" and . > 0)
            ] + [$active_id]
            | max // 1
          ) as $max_id
        | (
            [
              range(1; $max_id + 1)
              | . as $workspace_id
              | if $workspace_id == $active_id then
                  "[\($workspace_id)]"
                else
                  "\($workspace_id)"
                end
            ]
            | join(" ")
          ) as $legacy_text
        | ({
            schema_version: 1,
            ok: true,
            source: "hyprland",
            observed_at: $observed_at,
            data: {
              active_id: $active_id,
              max_id: $max_id,
              workspaces: [
                range(1; $max_id + 1) as $workspace_id
                | workspace_apps($workspace_id; $snapshot.clients) as $all_apps
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
          }) as $state
        | $legacy_text,
          ($state | tojson),
          ($state.data | tojson)
      '
  )" || {
    log "failed to normalize the Hyprland workspace snapshot"
    return 1
  }

  mapfile -t normalized_lines <<< "$normalized_output"

  if [[ ${#normalized_lines[@]} -ne 3 ||
        -z "${normalized_lines[0]}" ||
        -z "${normalized_lines[1]}" ||
        -z "${normalized_lines[2]}" ]]; then
    log "workspace normalization returned an incomplete result"
    return 1
  fi

  next_text="${normalized_lines[0]}"
  next_json="${normalized_lines[1]}"
  next_data="${normalized_lines[2]}"
}

publish_cached() {
  [[ -n "$cached_json" ]] || return 1

  "$EWW_BIN" --no-daemonize --config "$EWW_CONFIG" ping >/dev/null 2>&1 ||
    return 1

  if "$EWW_BIN" --no-daemonize --config "$EWW_CONFIG" update \
    "workspaces=$cached_text" \
    "workspace_state=$cached_json" >/dev/null 2>&1; then
    last_published_text="$cached_text"
    last_published_data="$cached_data"
    return 0
  fi

  # Preserve the legacy label while Eww is still loading an older config.
  if "$EWW_BIN" --no-daemonize --config "$EWW_CONFIG" update \
    "workspaces=$cached_text" >/dev/null 2>&1; then
    last_published_text="$cached_text"
  fi

  return 1
}

refresh_snapshot() {
  local force="${1:-false}"

  build_once || return 1

  cached_text="$next_text"
  cached_json="$next_json"
  cached_data="$next_data"
  last_full_resync_at="$(now_seconds)"

  if [[ "$force" != true &&
        "$cached_text" == "$last_published_text" &&
        "$cached_data" == "$last_published_data" ]]; then
    return 0
  fi

  publish_cached
}

event_requires_refresh() {
  case "$1" in
    "workspace>>"* | \
    "workspacev2>>"* | \
    "focusedmon>>"* | \
    "focusedmonv2>>"* | \
    "createworkspace>>"* | \
    "createworkspacev2>>"* | \
    "destroyworkspace>>"* | \
    "destroyworkspacev2>>"* | \
    "moveworkspace>>"* | \
    "moveworkspacev2>>"* | \
    "renameworkspace>>"* | \
    "openwindow>>"* | \
    "closewindow>>"* | \
    "kill>>"* | \
    "movewindow>>"* | \
    "movewindowv2>>"* | \
    "monitoradded>>"* | \
    "monitoraddedv2>>"* | \
    "monitorremoved>>"* | \
    "monitorremovedv2>>"* | \
    "configreloaded>>"*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

drain_event_burst() {
  local ignored_event
  local drained

  sleep "$EVENT_DEBOUNCE_SECONDS"

  for ((drained = 0; drained < MAX_DRAINED_EVENTS; drained++)); do
    if ! IFS= read -r -t "$EVENT_DRAIN_SECONDS" -u "$event_fd" ignored_event; then
      break
    fi
  done
}

perform_maintenance() {
  local current_time

  current_time="$(now_seconds)"

  if ((current_time - last_full_resync_at >= FULL_RESYNC_SECONDS)); then
    if ! refresh_snapshot true; then
      publish_cached || true
    fi
    last_heartbeat_at="$current_time"
  elif ((current_time - last_heartbeat_at >= HEARTBEAT_SECONDS)); then
    publish_cached || true
    last_heartbeat_at="$current_time"
  fi
}

cleanup_listener() {
  if [[ -n "$event_fd" ]]; then
    exec {event_fd}<&- 2>/dev/null || true
  fi

  if [[ -n "$socat_pid" ]] && kill -0 "$socat_pid" 2>/dev/null; then
    kill "$socat_pid" 2>/dev/null || true
    wait "$socat_pid" 2>/dev/null || true
  fi
}

listen_for_events() {
  local event_socket="$1"
  local event
  local read_status

  exec {event_fd}< <(
    "$SOCAT_BIN" -U - "UNIX-CONNECT:$event_socket"
  )
  socat_pid="$!"

  while true; do
    IFS= read -r -t "$HEARTBEAT_SECONDS" -u "$event_fd" event
    read_status=$?

    if ((read_status == 0)); then
      if event_requires_refresh "$event"; then
        drain_event_burst
        refresh_snapshot false ||
          log "event-triggered workspace refresh failed"
      fi
    elif ((read_status == 1)); then
      log "Hyprland event socket closed"
      return 1
    fi

    perform_maintenance
  done
}

main() {
  case "${1:-}" in
    --print-once)
      [[ $# -eq 1 ]] || usage
      snapshot_commands_available || return 1
      resolve_hyprland_session || return 1
      build_once || return 1
      printf '%s\n' "$next_json"
      return
      ;;
    --publish-once)
      [[ $# -eq 1 ]] || usage
      runtime_commands_available || return 1
      resolve_hyprland_session || return 1
      refresh_snapshot true
      return
      ;;
    "")
      [[ $# -eq 0 ]] || usage
      ;;
    *)
      usage
      ;;
  esac

  runtime_commands_available || return 1

  resolve_hyprland_session || return 1

  refresh_snapshot true ||
    log "initial workspace publication will retry"
  last_heartbeat_at="$(now_seconds)"

  listen_for_events "$event_socket"
}

trap cleanup_listener EXIT
trap 'exit 0' INT TERM

main "$@"
