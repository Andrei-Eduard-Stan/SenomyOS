# SenomyOS Data Sources and Command Policy

## Principles

- Presentation consumes normalized data.
- Status collectors are read-only.
- Mutating actions live in separate scripts.
- Missing tools and hardware are normal states.
- No collector may expose credentials or secrets through Eww variables.
- Expensive checks should run on demand or at long intervals.

## Common JSON envelope

New collectors should prefer:

```json
{
  "ok": true,
  "source": "pamixer",
  "observed_at": 0,
  "data": {},
  "error": null
}
```

On failure:

```json
{
  "ok": false,
  "source": "missing-command",
  "observed_at": 0,
  "data": null,
  "error": {
    "code": "dependency_missing",
    "message": "Required command is unavailable"
  }
}
```

Messages must be safe to show in the UI and must not contain command lines with
secrets.

## Source inventory

| Domain | Preferred source | Suggested cadence | Notes |
|---|---|---:|---|
| Workspaces | `hyprctl -j workspaces`, `activeworkspace` | existing 1s listener | Preserve current service |
| Battery | UPower + `jq` | 10–30s | Existing dual-battery script works |
| Volume/mute | `pamixer` | event or 1–2s while visible | `wpctl`/`pactl` for endpoints |
| Audio devices | `wpctl`, `pactl` | event or panel-open poll | Handle PipeWire naming changes |
| Wi-Fi state | `nmcli` | 5–15s while visible | Never request stored passwords |
| Wi-Fi scan | `nmcli` | manual refresh | Scans can be slow and disruptive |
| Ethernet | `nmcli` | 5–15s while visible | Show disconnected cleanly |
| CPU/RAM | Eww built-ins or `/proc` | 1–2s while dashboard open | Keep bar summary lightweight |
| Uptime/load | `/proc/uptime`, `uptime` | 30–60s | No reason for one-second polling |
| Processes | `ps` and `/proc` | 3–5s while dashboard open | Stable PID and command parsing |
| Monitors | `hyprctl -j monitors` | panel open / events | Avoid monitor index assumptions |
| Input devices | `hyprctl -j devices` | panel open / events | Redact nothing sensitive |
| Temperatures | Eww built-ins or `sensors` | 3–5s while dashboard open | Show unavailable if unsupported |
| Storage | `df`, optional SMART tooling | 30–60s / manual | SMART may require tools/privilege |
| Official packages | `checkupdates`, fallback `pacman -Qun` | manual | Fallback uses potentially stale local databases |
| AUR packages | `paru -Qua --nodevel` | explicit manual action | Sends installed foreign package names to AUR |
| User services | `systemctl --user` | panel open / manual | Allowlist restart targets |
| Background applications | user systemd, session D-Bus, StatusNotifierWatcher | 2s while Applications is visible | Registry is metadata; actions remain hard-coded |
| Logs | `journalctl --user` | manual | Limit lines and redact sensitive data |
| Display geometry | `hyprctl -j monitors` | events / surface open | Drives responsive work area |
| Input capabilities | `hyprctl -j devices`, optional libinput/udev data | login / device events | Prefer capabilities over model names |
| Orientation | compositor/profile source | events when available | Fall back to configured profile |

Optional commands must be checked with `command -v`.

Hardware detection should produce normalized capabilities rather than branching
the UI on a laptop model. Example capabilities include:

```text
has_touchscreen
has_pointer
has_keyboard
has_battery
battery_count
has_bluetooth
has_internal_display
orientation_supported
```

Detection must tolerate devices appearing and disappearing at runtime.

## Existing verified commands

Verified on 2026-07-24:

- `eww`
- `hyprctl`
- `jq`
- `upower`
- `pamixer`
- `nmcli`
- `pactl`
- `wpctl`
- `paru`
- `pacman`
- `systemctl`
- `journalctl`
- `ps`
- `free`
- `uptime`

`checkupdates` and `yay` were not installed.

## System status collector

`scripts/system-status.sh` is the first normalized SenomyOS system collector.
It reads Linux procfs and emits schema version 1 JSON containing:

- sampled CPU utilization;
- total, used, and available memory;
- memory utilization;
- uptime in seconds and human-readable form;
- one-, five-, and fifteen-minute load averages.

It does not inspect a model name, monitor, user, home path, battery, or network
interface. `SENOMY_PROC_ROOT` and `SENOMY_CPU_SAMPLE_DELAY` are test overrides;
production uses `/proc` and a short sample delay.

The script returns structured error envelopes for missing procfs data, invalid
configuration, malformed sources, failed sampling, and a missing `jq`
dependency.

## Audio status collector

`scripts/audio-status.sh` reads PipeWire/PulseAudio compatibility data through
`pactl` and emits schema version 1 JSON containing:

- the default output and input;
- normalized display names and stable source IDs;
- volume, mute, state, and active port;
- all available non-monitor outputs and inputs;
- endpoint counts and overall output availability.

The collector is read-only. It never changes volume, mute state, or routing.
PulseAudio monitor sources are excluded from the user-facing input list.

The script returns structured errors for missing dependencies, unavailable
audio services, and malformed JSON.

## Network status collector

`scripts/network-status.sh` reads NetworkManager state through `nmcli` and
emits schema version 1 JSON containing:

- global state and connectivity;
- networking and Wi-Fi radio state;
- the primary non-loopback connection;
- connected Wi-Fi and Ethernet summaries;
- normalized device type, state, connection, IPv4 addresses, and gateway;
- the complete interface inventory for Device Management.

The collector is read-only. It never scans for networks, connects,
disconnects, changes radios, or reads saved credentials.

The script returns structured errors for missing dependencies and an
unavailable NetworkManager service.

## Polling budget

Persistent bar:

- clock: 30–60s;
- battery: 10–30s;
- telemetry summary: 2–5s;
- workspaces: preserve current listener until an event-driven replacement is
  proven better.
- ambient Senomy dialogue: select from the local catalog every 15 minutes;
  verified warnings override ambient dialogue in the presentation layer.

Control Centre:

- poll a section only while it is active where Eww supports `:run-while`;
- scan Wi-Fi manually;
- prefer PipeWire/NetworkManager events where the complexity is justified.

Performance Dashboard:

- CPU/RAM/network history: 1–2s while open;
- processes: 3–5s while open;
- storage and hardware inventory: 30–60s or manual;
- stop expensive collectors when the dashboard closes.

Insights:

- package source checks: explicit manual action;
- update cache reads: 2s only while the Updates tab is visible;
- maintenance and health summaries: derived from cached source records;
- never run an AUR update check every few seconds.

Applications:

- the native Eww tray host remains instantiated by the persistent bar;
- managed application status polls every two seconds only while Applications
  is visible;
- service state, application D-Bus readiness, and tray registration remain
  separate evidence fields;
- the registry supplies metadata only, while the action helper independently
  allowlists every application and verb.

## Senomy dialogue catalog

`data/senomy-dialogue.json` contains versioned personality lines. Each record
has a stable ID plus category, severity, rarity, language, tone, and text.
Wording belongs in the catalog rather than in the selector.

`scripts/senomy-dialogue.sh` validates the catalog and returns one normalized
record. Selection remains stable within a 15-minute time slot so Eww reloads do
not make the message flicker. One in five slots prefers the uncommon pool.

Ambient selection never overrides verified critical, warning, recommended, or
unavailable conditions. Those conditions are derived from successful system
sources before the selected ambient line reaches the bar.

## Insights timeline collector

`scripts/timeline-status.sh` provides a bounded, read-only Timeline source.
Its allowlisted modes are `user`, `system`, `kernel`, and `eww`.

Journal records are reduced to an event ID, local date/time, normalized
severity, source/unit, and message. Messages are capped at 240 characters,
control characters are replaced, the current home path is normalized to
`$HOME`, and entries containing obvious credential terms are redacted before
they reach Eww state.

Each result contains at most 40 entries by default and rejects limits above
100. Eww maintains one source-specific poll per mode because Eww 0.5 poll
commands cannot interpolate variables. `:run-while` ensures continued
five-second polling applies only to the selected source while Insights
Timeline is visible and Follow is enabled.

## Insights updates collector

`scripts/update-status.sh` maintains the schema-version-1 Updates cache at
`${XDG_CACHE_HOME:-$HOME/.cache}/senomyos/updates.json`.

The allowlisted actions are:

- `read`: return the cache or a truthful `never_checked` envelope;
- `check-official`: prefer `checkupdates`, otherwise run `pacman -Qun` against
  the existing local sync databases;
- `check-aur`: run `paru -Qua --nodevel` only after the dedicated AUR action.

Official fallback results use the source name `pacman-local-db`, include the
newest local sync-database timestamp, and always warn that the result may be
stale. They are not described as a live repository check. AUR results use the
source name `paru-aur` and retain a visible notice that the query sends
installed foreign package names to `aur.archlinux.org`. `--nodevel` prevents
additional VCS-remote probes during this check.

Checks use a non-blocking `flock`, a timeout of 30 seconds by default, and an
atomic temporary-file rename. Package output is accepted only in the
`name current -> available` format. Displayed lists are capped at 100 entries
per source by default while retaining the true parsed count and a truncation
flag. Raw command errors, package-manager progress, credentials, and
environment values never enter Eww state.

The collector has no action for package installation, removal, system
pacman-database synchronization, or privilege elevation.

## Insights diagnostics runner

`scripts/diagnostics-status.sh` owns both the Diagnostics task catalog and its
schema-version-1 cache at
`${XDG_CACHE_HOME:-$HOME/.cache}/senomyos/diagnostics.json`.

Its allowlisted actions are:

- `catalog`: return task metadata without executing a diagnostic;
- `read`: return the current cache or a truthful idle envelope;
- `run <task-id>`: execute exactly one built-in read-only task.

The initial task IDs and operations are:

- `failed-units`: `systemctl --user --failed --no-pager --plain`;
- `workspace-service`:
  `systemctl --user status workspaces.service --no-pager --lines=20`;
- `recent-errors`:
  `journalctl --user --priority=warning..alert --since=-30min --no-pager
  --lines=40 --output=short-iso`;
- `memory-pressure`: `free -h` plus a direct read of
  `/proc/pressure/memory`;
- `filesystems`: `df -h` with temporary, device, SquashFS, and EFI variable
  filesystems excluded;
- `power-inventory`: `upower -e`.

The selected ID is looked up again inside the runner. Each external operation
uses a fixed executable and argument array; there is no `eval`, `sh -c`,
`bash -c`, free-form command input, `sudo`, or mutation action. Missing
dependencies produce an explicit unavailable result.

Only one task can run at a time. The default timeout is eight seconds and is
rejected above 30 seconds. Captured output defaults to 60 lines of at most 240
characters each, with hard configuration maxima of 100 lines and 500
characters. Control characters are replaced, the user's home path is
normalized to `$HOME`, and whole lines containing common credential terms are
redacted before data reaches Eww. Cache replacement is atomic and the result
file is mode `0600`.

Eww polls the catalog hourly and the result cache once per second only while
the Insights Diagnostics tab is visible. Polling reads local state; it never
runs a task. The cache intentionally retains only the latest result rather
than a command history.

## Device Management

Device Management should normalize:

- display outputs from Hyprland;
- audio endpoints from PipeWire/PulseAudio tools;
- input devices from Hyprland;
- batteries from UPower;
- network interfaces from NetworkManager;
- optional Bluetooth devices only if `bluetoothctl` or another suitable source
  is present.

Each device record should include a stable ID, display name, class, connection
state, source, and supported safe actions.

Portable code must not assume device identifiers such as `eDP-1`, `wlp3s0`,
`BAT0`, or monitor `0`. Collectors translate discovered devices into normalized
records, while hardware profiles may provide carefully scoped overrides.

## Process and service actions

Read-only inspection is the default.

Allowed process flow:

1. select a PID from fresh process data;
2. inspect its current identity;
3. preview the action;
4. confirm;
5. re-check that the PID still identifies the same process;
6. send `SIGTERM`;
7. report the result;
8. offer separately confirmed `SIGKILL` only if still running.

Never kill by a broad text match.

Restart is available only when the target maps to an allowlisted user service
or another known restart mechanism.

## Curated diagnostic console

The Insights implementation above establishes the reusable console contract.
The future Performance Dashboard console is likewise a menu of safe diagnostic
tasks, not arbitrary command execution.

Potential allowlisted tasks:

- inspect selected process;
- inspect selected user service;
- show recent logs for an allowlisted service;
- summarize CPU and memory pressure;
- list disks and filesystems;
- inspect UPower batteries;
- inspect Hyprland monitors and input devices;
- inspect PipeWire endpoints;
- inspect NetworkManager connection state;
- assemble a redacted troubleshooting report.

Arguments come from validated selections, never raw shell fragments entered in
a text field.

## Insights data policy

Each insight must cite its internal source and observation time. Insight
generation may summarize facts, but it must not turn absence of data into a
diagnosis.

Examples:

- Valid: “BAT1 is discharging faster than BAT0 over the last 30 minutes.”
- Invalid without history: “BAT1 is unhealthy.”
- Valid: “Package check unavailable: neither the configured helper nor a
  successful `paru` result is present.”
- Invalid: “12 updates available” when no successful check ran.
