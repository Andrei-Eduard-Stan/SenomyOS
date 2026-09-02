#!/usr/bin/env bash

# Run one bounded, read-only diagnostic task from a closed allowlist and cache
# only sanitized display output for Senomy Insights.

set -u

export LC_ALL=C

readonly ACTION="${1:-read}"
readonly REQUESTED_TASK="${2:-}"
readonly USER_HOME="${HOME:-/nonexistent}"
readonly USER_NAME="${USER:-unknown}"
readonly CACHE_FILE="${SENOMY_DIAGNOSTICS_CACHE:-${XDG_CACHE_HOME:-"$USER_HOME/.cache"}/senomyos/diagnostics.json}"
readonly CACHE_DIR="$(dirname "$CACHE_FILE")"
readonly LOCK_FILE="${CACHE_FILE}.lock"
readonly COMMAND_TIMEOUT="${SENOMY_DIAGNOSTICS_TIMEOUT:-8}"
readonly LINE_LIMIT="${SENOMY_DIAGNOSTICS_LIMIT:-60}"
readonly LINE_WIDTH="${SENOMY_DIAGNOSTICS_LINE_WIDTH:-240}"
readonly PROC_ROOT="${SENOMY_PROC_ROOT:-/proc}"

TASK_ID=""
TASK_CODE=""
TASK_TITLE=""
TASK_CATEGORY=""
TASK_SUMMARY=""
TASK_PREVIEW=""
TASK_SCOPE=""
TASK_GUIDANCE=""
TASK_EXECUTION_SOURCE=""
RUN_SOURCE="senomy-diagnostics"
RUN_ERROR_CODE=""
RUN_ERROR_MESSAGE=""
WORK_DIR=""

now_epoch() {
  printf '%(%s)T' -1
}

epoch_label() {
  local epoch="$1"

  if ((epoch > 0)); then
    date -d "@$epoch" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || printf 'UNKNOWN'
  else
    printf 'NEVER'
  fi
}

emit_dependency_error() {
  local observed_at
  observed_at="$(now_epoch)"

  printf \
    '{"schema_version":1,"ok":false,"source":"senomy-diagnostics","observed_at":%s,"data":{"state":"unavailable","state_label":"UNAVAILABLE","active_task":"none","task_id":"none","code":"ERR","title":"Diagnostics unavailable","category":"policy","summary":"The task catalog could not be loaded.","command_preview":"none","scope":"No command was run.","guidance":"Install jq before using Diagnostics.","started_at":0,"started_at_label":"NEVER","finished_at":0,"finished_at_label":"NEVER","duration_ms":0,"exit_code":null,"line_count":0,"shown_line_count":0,"truncated":false,"output":[]},"error":{"code":"dependency_missing","message":"Required command jq is unavailable"}}\n' \
    "$observed_at"
  exit 0
}

command -v jq >/dev/null 2>&1 || emit_dependency_error

catalog_tasks() {
  jq -nc '
    {
      tasks: [
        {
          id: "failed-units",
          code: "SVC",
          title: "Failed user units",
          category: "services",
          summary: "List user services currently in the failed state.",
          command_preview: "systemctl --user --failed --no-pager --plain",
          execution_source: "systemctl-user",
          scope: "Current user service manager; read-only.",
          guidance: "Zero failed units is a healthy result. Inactive units are not failures."
        },
        {
          id: "workspace-service",
          code: "EWW",
          title: "Workspace listener",
          category: "services",
          summary: "Inspect the allowlisted Eww workspace publisher.",
          command_preview: "systemctl --user status workspaces.service --no-pager --lines=20",
          execution_source: "systemctl-user",
          scope: "workspaces.service only; no restart action.",
          guidance: "This verifies the publisher state. Restart remains a separate confirmed future action."
        },
        {
          id: "recent-errors",
          code: "LOG",
          title: "Recent user warnings",
          category: "logs",
          summary: "Read warning-or-higher user journal entries from the last 30 minutes.",
          command_preview: "journalctl --user --priority=warning..alert --since=-30min --no-pager --lines=40 --output=short-iso",
          execution_source: "journalctl-user",
          scope: "User journal; 30-minute window; at most 40 source lines.",
          guidance: "Output is sanitized and bounded. Timeline provides broader source navigation."
        },
        {
          id: "memory-pressure",
          code: "MEM",
          title: "Memory pressure",
          category: "memory",
          summary: "Capture a memory snapshot plus Linux PSI pressure counters.",
          command_preview: "free -h + read /proc/pressure/memory",
          execution_source: "procfs-memory",
          scope: "Current memory snapshot and procfs PSI; read-only.",
          guidance: "A single snapshot is evidence, not a diagnosis. Sustained pressure requires history."
        },
        {
          id: "filesystems",
          code: "DSK",
          title: "Persistent filesystems",
          category: "storage",
          summary: "Show persistent filesystem capacity without temporary or Snap loop noise.",
          command_preview: "df -h -x tmpfs -x devtmpfs -x squashfs -x efivarfs --output=source,fstype,size,used,avail,pcent,target",
          execution_source: "df",
          scope: "Mounted persistent filesystems; read-only.",
          guidance: "High use is not automatically a fault. Confirm the affected mount before acting."
        },
        {
          id: "power-inventory",
          code: "PWR",
          title: "UPower inventory",
          category: "power",
          summary: "List power devices currently exposed by UPower.",
          command_preview: "upower -e",
          execution_source: "upower",
          scope: "UPower device paths only; read-only.",
          guidance: "Use Briefing or Control Centre Power for interpreted battery values."
        }
      ]
    }
  '
}

catalog_payload() {
  local observed_at
  local tasks

  observed_at="$(now_epoch)"
  tasks="$(catalog_tasks)"

  jq -nc \
    --argjson observed_at "$observed_at" \
    --argjson tasks "$tasks" \
    '{
      schema_version: 1,
      ok: true,
      source: "senomy-diagnostics-catalog",
      observed_at: $observed_at,
      data: $tasks,
      error: null
    }'
}

load_task() {
  local task="$1"
  local entry

  entry="$(
    catalog_tasks |
      jq -c --arg task "$task" '.tasks[] | select(.id == $task)'
  )"
  [[ -n "$entry" ]] || return 1

  TASK_ID="$(jq -r '.id' <<<"$entry")"
  TASK_CODE="$(jq -r '.code' <<<"$entry")"
  TASK_TITLE="$(jq -r '.title' <<<"$entry")"
  TASK_CATEGORY="$(jq -r '.category' <<<"$entry")"
  TASK_SUMMARY="$(jq -r '.summary' <<<"$entry")"
  TASK_PREVIEW="$(jq -r '.command_preview' <<<"$entry")"
  TASK_EXECUTION_SOURCE="$(jq -r '.execution_source' <<<"$entry")"
  TASK_SCOPE="$(jq -r '.scope' <<<"$entry")"
  TASK_GUIDANCE="$(jq -r '.guidance' <<<"$entry")"
  RUN_SOURCE="$TASK_EXECUTION_SOURCE"
}

build_payload() {
  local ok="$1"
  local state="$2"
  local state_label="$3"
  local active_task="$4"
  local started_at="$5"
  local finished_at="$6"
  local duration_ms="$7"
  local exit_code="$8"
  local summary="$9"
  local result="${10}"
  local error="${11}"
  local observed_at
  local started_at_label
  local finished_at_label

  observed_at="$(now_epoch)"
  started_at_label="$(epoch_label "$started_at")"
  finished_at_label="$(epoch_label "$finished_at")"

  jq -nc \
    --argjson ok "$ok" \
    --argjson observed_at "$observed_at" \
    --arg state "$state" \
    --arg state_label "$state_label" \
    --arg active_task "$active_task" \
    --arg task_id "$TASK_ID" \
    --arg code "$TASK_CODE" \
    --arg title "$TASK_TITLE" \
    --arg category "$TASK_CATEGORY" \
    --arg execution_source "$RUN_SOURCE" \
    --arg summary "$summary" \
    --arg command_preview "$TASK_PREVIEW" \
    --arg scope "$TASK_SCOPE" \
    --arg guidance "$TASK_GUIDANCE" \
    --argjson started_at "$started_at" \
    --arg started_at_label "$started_at_label" \
    --argjson finished_at "$finished_at" \
    --arg finished_at_label "$finished_at_label" \
    --argjson duration_ms "$duration_ms" \
    --argjson exit_code "$exit_code" \
    --argjson result "$result" \
    --argjson error "$error" \
    '{
      schema_version: 1,
      ok: $ok,
      source: "senomy-diagnostics-cache",
      observed_at: $observed_at,
      data: {
        state: $state,
        state_label: $state_label,
        active_task: $active_task,
        task_id: $task_id,
        code: $code,
        title: $title,
        category: $category,
        execution_source: $execution_source,
        summary: $summary,
        command_preview: $command_preview,
        scope: $scope,
        guidance: $guidance,
        started_at: $started_at,
        started_at_label: $started_at_label,
        finished_at: $finished_at,
        finished_at_label: $finished_at_label,
        duration_ms: $duration_ms,
        exit_code: $exit_code,
        line_count: $result.line_count,
        shown_line_count: $result.shown_line_count,
        truncated: $result.truncated,
        output: $result.output
      },
      error: $error
    }'
}

empty_result() {
  jq -nc '{
    line_count: 0,
    shown_line_count: 0,
    truncated: false,
    output: []
  }'
}

initial_payload() {
  TASK_ID="none"
  TASK_CODE="RUN"
  TASK_TITLE="Awaiting task"
  TASK_CATEGORY="policy"
  TASK_PREVIEW="select <allowlisted-task>"
  TASK_SCOPE="No command has run."
  TASK_GUIDANCE="Choose a task above. Arbitrary commands belong in a real terminal."

  build_payload \
    true "idle" "READY" "none" 0 0 0 null \
    "Six read-only tasks are available." "$(empty_result)" null
}

cache_is_valid() {
  jq -e '
    .schema_version == 1
    and (.data | type == "object")
    and (.data.state | type == "string")
    and (.data.active_task | type == "string")
    and (.data.task_id | type == "string")
    and (.data.execution_source | type == "string")
    and (.data.output | type == "array")
  ' "$CACHE_FILE" >/dev/null 2>&1
}

emit_invalid_cache() {
  local payload
  local observed_at

  observed_at="$(now_epoch)"
  payload="$(initial_payload)"

  jq -c \
    --argjson observed_at "$observed_at" \
    '
      .ok = false
      | .observed_at = $observed_at
      | .data.state = "failed"
      | .data.state_label = "CACHE ERROR"
      | .data.summary = "The cached diagnostic result is invalid."
      | .error = {
          code: "cache_invalid",
          message: "Run a diagnostic task to replace the invalid cache."
        }
    ' <<<"$payload"
}

emit_collector_error() {
  local code="$1"
  local message="$2"
  local payload
  local observed_at

  observed_at="$(now_epoch)"
  payload="$(initial_payload)"

  jq -c \
    --argjson observed_at "$observed_at" \
    --arg code "$code" \
    --arg message "$message" \
    '
      .ok = false
      | .observed_at = $observed_at
      | .data.state = "failed"
      | .data.state_label = "RUNNER ERROR"
      | .data.summary = $message
      | .error = {
          code: $code,
          message: $message
        }
    ' <<<"$payload"
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

write_cache() {
  local payload="$1"
  local temporary

  mkdir -p "$CACHE_DIR" 2>/dev/null || return 1
  temporary="$(mktemp "$CACHE_DIR/.diagnostics.json.XXXXXX")" || return 1

  if ! printf '%s\n' "$payload" >"$temporary" ||
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

set_dependency_error() {
  local command_name="$1"

  RUN_ERROR_CODE="dependency_missing"
  RUN_ERROR_MESSAGE="Required command $command_name is unavailable"
}

run_timeout_command() {
  local output_file="$1"
  local timeout_bin="$2"
  shift 2

  SYSTEMD_COLORS=0 SYSTEMD_PAGER=cat \
    "$timeout_bin" "${COMMAND_TIMEOUT}s" "$@" >"$output_file" 2>&1
}

run_task_command() {
  local output_file="$1"
  local timeout_bin
  local command_bin
  local status=0
  local pressure_file="$PROC_ROOT/pressure/memory"

  timeout_bin="$(resolve_command "${SENOMY_TIMEOUT_BIN:-}" timeout)" || {
    set_dependency_error "timeout"
    return 127
  }

  case "$TASK_ID" in
    failed-units)
      command_bin="$(resolve_command "${SENOMY_SYSTEMCTL_BIN:-}" systemctl)" || {
        set_dependency_error "systemctl"
        return 127
      }
      run_timeout_command \
        "$output_file" "$timeout_bin" "$command_bin" \
        --user --failed --no-pager --plain ||
        status=$?
      ;;
    workspace-service)
      command_bin="$(resolve_command "${SENOMY_SYSTEMCTL_BIN:-}" systemctl)" || {
        set_dependency_error "systemctl"
        return 127
      }
      run_timeout_command \
        "$output_file" "$timeout_bin" "$command_bin" \
        --user status workspaces.service --no-pager --lines=20 ||
        status=$?
      ;;
    recent-errors)
      command_bin="$(resolve_command "${SENOMY_JOURNALCTL_BIN:-}" journalctl)" || {
        set_dependency_error "journalctl"
        return 127
      }
      run_timeout_command \
        "$output_file" "$timeout_bin" "$command_bin" \
        --user --priority=warning..alert --since=-30min \
        --no-pager --lines=40 --output=short-iso ||
        status=$?
      ;;
    memory-pressure)
      command_bin="$(resolve_command "${SENOMY_FREE_BIN:-}" free)" || {
        set_dependency_error "free"
        return 127
      }
      run_timeout_command "$output_file" "$timeout_bin" "$command_bin" -h ||
        status=$?
      if ((status == 0)); then
        {
          printf '\nMemory pressure (PSI):\n'
          if [[ -r "$pressure_file" ]]; then
            while IFS= read -r line; do
              printf '%s\n' "$line"
            done <"$pressure_file"
          else
            printf 'Unavailable: %s is not readable.\n' "$pressure_file"
          fi
        } >>"$output_file"
      fi
      ;;
    filesystems)
      command_bin="$(resolve_command "${SENOMY_DF_BIN:-}" df)" || {
        set_dependency_error "df"
        return 127
      }
      run_timeout_command \
        "$output_file" "$timeout_bin" "$command_bin" \
        -h -x tmpfs -x devtmpfs -x squashfs -x efivarfs \
        --output=source,fstype,size,used,avail,pcent,target ||
        status=$?
      ;;
    power-inventory)
      command_bin="$(resolve_command "${SENOMY_UPOWER_BIN:-}" upower)" || {
        set_dependency_error "upower"
        return 127
      }
      run_timeout_command "$output_file" "$timeout_bin" "$command_bin" -e ||
        status=$?
      ;;
    *)
      RUN_ERROR_CODE="invalid_task"
      RUN_ERROR_MESSAGE="Diagnostic task is not allowlisted"
      return 126
      ;;
  esac

  return "$status"
}

sanitize_output() {
  local output_file="$1"

  jq -Rsc \
    --arg user_home "$USER_HOME" \
    --arg user_path "/home/$USER_NAME" \
    --argjson limit "$LINE_LIMIT" \
    --argjson width "$LINE_WIDTH" \
    '
      def replace_literal($from; $to):
        if ($from | length) == 0 then
          .
        else
          split($from) | join($to)
        end;

      def sanitize:
        explode
        | map(if . < 32 or . == 127 then 32 else . end)
        | implode
        | gsub("  +"; " ")
        | replace_literal($user_home; "$HOME")
        | replace_literal($user_path; "$HOME")
        | if test(
            "(?i)(password|passwd|secret|token|authorization[:=]|cookie[:=]|api[_-]?key|private[_-]?key)"
          ) then
            "[redacted potentially sensitive output]"
          else
            .
          end
        | .[0:$width];

      (split("\n") | map(select(length > 0)) | map(sanitize)) as $lines
      | {
          line_count: ($lines | length),
          shown_line_count: ([($lines | length), $limit] | min),
          truncated: (($lines | length) > $limit),
          output: (
            $lines[0:$limit]
            | to_entries
            | map({
                line_no: (.key + 1),
                text: .value
              })
          )
        }
    ' "$output_file"
}

cleanup() {
  if [[ -n "$WORK_DIR" && -d "$WORK_DIR" ]]; then
    rm -rf -- "$WORK_DIR"
  fi
}

run_task() {
  local task="$1"
  local started_at
  local finished_at
  local duration_ms
  local status=0
  local running
  local final
  local result
  local error="null"
  local state
  local state_label
  local result_summary
  local exit_code
  local output_file

  [[ "$COMMAND_TIMEOUT" =~ ^[1-9][0-9]*$ ]] &&
    ((COMMAND_TIMEOUT <= 30)) || {
      emit_collector_error \
        "invalid_configuration" "Diagnostic timeout must be between 1 and 30 seconds"
      return 1
    }
  [[ "$LINE_LIMIT" =~ ^[1-9][0-9]*$ ]] && ((LINE_LIMIT <= 100)) || {
    emit_collector_error \
      "invalid_configuration" "Diagnostic line limit must be between 1 and 100"
    return 1
  }
  [[ "$LINE_WIDTH" =~ ^[1-9][0-9]*$ ]] && ((LINE_WIDTH <= 500)) || {
    emit_collector_error \
      "invalid_configuration" "Diagnostic line width must be between 1 and 500"
    return 1
  }

  load_task "$task" || {
    emit_collector_error "invalid_task" "Diagnostic task is not allowlisted"
    return 1
  }

  mkdir -p "$CACHE_DIR" 2>/dev/null || {
    emit_collector_error \
      "cache_write_failed" "Unable to create the diagnostic cache directory"
    return 1
  }

  exec 9>"$LOCK_FILE" || {
    emit_collector_error \
      "lock_failed" "Unable to open the diagnostic task lock"
    return 1
  }

  command -v flock >/dev/null 2>&1 || {
    emit_collector_error \
      "dependency_missing" "Required command flock is unavailable"
    return 1
  }

  if ! flock -n 9; then
    read_cache
    return 0
  fi

  started_at="$(now_epoch)"
  running="$(
    build_payload \
      true "running" "RUNNING" "$TASK_ID" "$started_at" 0 0 null \
      "$TASK_SUMMARY" "$(empty_result)" null
  )"
  write_cache "$running" || {
    emit_collector_error \
      "cache_write_failed" "Unable to write the diagnostic running state"
    return 1
  }

  WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/senomy-diagnostics.XXXXXX")" || {
    emit_collector_error \
      "temporary_directory_failed" "Unable to create the diagnostic workspace"
    return 1
  }
  trap cleanup EXIT
  output_file="$WORK_DIR/output"

  run_task_command "$output_file" || status=$?
  [[ -e "$output_file" ]] || : >"$output_file"

  result="$(sanitize_output "$output_file")" || {
    emit_collector_error \
      "output_invalid" "Unable to sanitize the diagnostic output"
    return 1
  }

  finished_at="$(now_epoch)"
  duration_ms=$(((finished_at - started_at) * 1000))

  if [[ -n "$RUN_ERROR_CODE" ]]; then
    state="unavailable"
    state_label="UNAVAILABLE"
    result_summary="$RUN_ERROR_MESSAGE"
    exit_code="null"
    error="$(
      jq -nc \
        --arg code "$RUN_ERROR_CODE" \
        --arg message "$RUN_ERROR_MESSAGE" \
        '{code: $code, message: $message}'
    )"
  elif ((status == 0)); then
    state="ready"
    state_label="COMPLETE"
    result_summary="Task completed with bounded, sanitized output."
    exit_code=0
  elif ((status == 124)); then
    state="failed"
    state_label="TIMED OUT"
    result_summary="The task exceeded the configured ${COMMAND_TIMEOUT}-second limit."
    exit_code="$status"
    error="$(
      jq -nc \
        --arg message "$result_summary" \
        '{code: "timeout", message: $message}'
    )"
  else
    state="failed"
    state_label="FAILED"
    result_summary="The task exited unsuccessfully; captured output is shown below."
    exit_code="$status"
    error="$(
      jq -nc \
        --argjson status "$status" \
        '{
          code: "command_failed",
          message: ("Diagnostic command exited with status " + ($status | tostring))
        }'
    )"
  fi

  final="$(
    build_payload \
      "$([[ "$state" == "ready" ]] && printf true || printf false)" \
      "$state" "$state_label" "none" \
      "$started_at" "$finished_at" "$duration_ms" "$exit_code" \
      "$result_summary" "$result" "$error"
  )"

  write_cache "$final" || {
    emit_collector_error \
      "cache_write_failed" "Unable to save the diagnostic result"
    return 1
  }

  printf '%s\n' "$final"
}

case "$ACTION" in
  read)
    [[ $# -eq 1 ]] || {
      emit_collector_error "invalid_arguments" "read accepts no task"
      exit 1
    }
    read_cache
    ;;
  catalog)
    [[ $# -eq 1 ]] || {
      emit_collector_error "invalid_arguments" "catalog accepts no task"
      exit 1
    }
    catalog_payload
    ;;
  run)
    [[ $# -eq 2 ]] || {
      emit_collector_error "invalid_arguments" "run requires one task ID"
      exit 1
    }
    run_task "$REQUESTED_TASK"
    ;;
  *)
    emit_collector_error "invalid_action" "Diagnostic action is not allowlisted"
    exit 1
    ;;
esac
