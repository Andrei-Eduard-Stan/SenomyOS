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
| Packages | `paru -Qu` | manual or 30–60min | Never install automatically |
| User services | `systemctl --user` | panel open / manual | Allowlist restart targets |
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

## Polling budget

Persistent bar:

- clock: 30–60s;
- battery: 10–30s;
- telemetry summary: 2–5s;
- workspaces: preserve current listener until an event-driven replacement is
  proven better.

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

- package checks: manual or long interval;
- maintenance and health summaries: derived from cached source records;
- never run an AUR update check every few seconds.

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

The dashboard console is a menu of safe diagnostic tasks, not arbitrary command
execution.

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
