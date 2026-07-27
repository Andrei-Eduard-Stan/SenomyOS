# SenomyOS Architecture

## Current runtime

Hyprland starts:

- the workspace listener service;
- the Eww daemon and `main-bar`;
- a legacy `update-loop.sh`;
- both Hyprpaper and swww wallpaper paths.

The stable data flows are:

```text
Hyprland
  └── workspaces.service
        └── scripts/workspaces.sh
              └── eww ping, then eww update workspaces=...

Eww batt_json poll
  └── scripts/battery.sh
        ├── UPower
        └── jq
```

The legacy update loop is not part of the target architecture. It launches the
continuous workspace listener inside command substitution and waits forever.

## Target layers

### Portable system layers

SenomyOS should evolve into layers that can be deployed and tested
independently:

```text
SenomyOS release
├── Arch base and package manifest
├── system services and policies
├── compositor/session defaults
├── SenomyOS Eww shell
├── portable data and action scripts
├── hardware capability detection
├── hardware/form-factor profiles
├── user preferences
└── installer, update, rollback, and recovery tooling
```

Portable defaults must not contain the current username, home directory,
monitor name, network interface, battery count, wallpaper path, or a single
resolution.

Machine-specific values belong in a generated or selected profile. Profiles
should override the smallest possible set of defaults.

### Presentation layer

```text
eww.yuck
├── windows/main-bar.yuck
├── windows/control-center.yuck
├── windows/performance-dashboard.yuck
├── windows/insights-panel.yuck
├── widgets/
│   ├── workspace-widget.yuck
│   ├── senomy-status.yuck
│   ├── system-telemetry.yuck
│   ├── system-controls.yuck
│   └── battery-widget.yuck
└── sections/
    ├── overview.yuck
    ├── network.yuck
    ├── audio.yuck
    ├── power.yuck
    ├── calendar.yuck
    ├── input.yuck
    ├── devices.yuck
    ├── apps.yuck
    └── settings.yuck
```

The exact migration may retain `windows/actioncenter-panel.yuck` temporarily
until `control-center.yuck` is verified.

### State layer

Global state should remain small and explicit:

```text
active_surface = "none"
control_section = "overview"
pending_action = "none"
action_status = "idle"
```

Valid primary surfaces:

```text
none
control
performance
insights
```

Valid Control Centre sections:

```text
overview
network
audio
power
calendar
input
devices
apps
settings
```

Valid Senomy Insights sections:

```text
briefing
timeline
updates
diagnostics
reports
```

Opening a surface is a single state transition, not a sequence of unrelated
window flags. Visual active state is derived from this shared state.

`scripts/surface-state.sh` owns primary-surface transitions. Bar triggers and
panel close buttons pass it only allowlisted verbs and section names. The
helper serializes transitions with a runtime `flock`, validates existing Eww
state, closes non-target windows, selects content while the state is `none`,
opens and verifies the target window, and only then publishes the target
`active_surface`. A failed Eww window query is an error, not evidence that a
window is closed.

Window lifecycle remains explicit. `active_surface` drives active styling and
collector scope, while the coordinator makes the actual open window set match
that state. Do not bind `defwindow :visible` to `active_surface`; mixing dynamic
visibility with explicit `eww open`/`eww close` creates two competing lifecycle
mechanisms.

The supported reload path is:

```text
scripts/reload-eww.sh
  └── scripts/surface-state.sh reload
        ├── capture and validate surface/section state
        ├── close all windows and stop the old daemon
        ├── wait until old IPC is unavailable
        ├── eww open-many with main-bar and the remembered surface
        ├── wait for daemon IPC
        ├── verify the exact initial window set
        └── restore active, section, and Timeline state
```

The new Eww process must not inherit the transition lock descriptor.
`scripts/workspaces.sh` pings Eww before publishing, so its periodic update
cannot bootstrap a competing daemon during the intentional restart gap.

`scripts/surface-state.sh reconcile` is the recovery operation when window
instances and `active_surface` disagree. It never invents a missing
Performance Dashboard; an unavailable target returns state to `none`.

Raw `eww reload` is unsupported for this configuration. Eww 0.5.0 resets
`defvar` values while it may retain window instances, which can detach visible
panels from `active_surface`.

Adaptive state may include:

```text
layout_density = "compact" | "comfortable" | "touch"
orientation = "landscape" | "portrait"
form_factor = "desktop" | "laptop" | "tablet" | "phone"
```

These values should come from capability/profile data and work-area geometry,
not from a hard-coded model name.

### Data layer

Data collectors live under `scripts/` and emit compact JSON. Presentation
components should not contain long command pipelines.

Planned collectors:

- `device-status.sh`
- `processes.sh`
- `insights-status.sh`

Implemented collectors:

- `battery.sh`
- `workspaces.sh`
- `system-status.sh` (validated, not yet connected to Eww)
- `audio-status.sh` (validated, not yet connected to Eww)
- `network-status.sh` (validated, not yet connected to Eww)
- `background-apps-status.sh` (connected only while Applications is visible)

Collectors must degrade independently. A network error cannot break the clock,
bar, or battery display.

The native StatusNotifier tray host lives in the persistent main bar. The
Applications section does not create a second tray host; it combines an
allowlisted registry with user-systemd, session D-Bus, and StatusNotifier
evidence to present larger managed-application controls. Native application
menus remain owned by their tray items.

### Action layer

System mutations are separate from status collectors.

Recommended shape:

```text
scripts/actions/
├── audio.sh
├── network.sh
├── process.sh
├── power.sh
└── diagnostics.sh
```

Each action accepts an allowlisted verb and validated arguments. It returns
structured success or failure information. Presentation code should not build
arbitrary shell strings.

## Primary surface geometry

The bar remains bottom-anchored and reserves only its real height.

The compact Control Centre is anchored above the relevant right-side controls
and constrained to the monitor work area.

Senomy Insights is visually connected to the mascot/status region and may
anchor above the left or middle-left bar area.

The Performance Dashboard is a broad, separate surface above the bar. It may
use more width than the Control Centre, but should be sized relative to the
monitor work area rather than a fixed 1920x1080 coordinate.

Monitor selection should use Eww/Hyprland runtime context where possible.
Hard-coded monitor `0` is a migration constraint, not a target design.

## Performance Dashboard architecture

The dashboard combines:

- Eww polls/listeners for lightweight metrics;
- a process collector that only runs while the dashboard is open;
- bounded history maintained in Eww or a dedicated collector;
- an allowlisted diagnostics runner;
- an explicit confirmation state for process and service actions;
- report assembly from already-collected, redacted data.

The mini console is not an interactive PTY. It is a task interface:

```text
choose task → preview command and scope → run → stream/display result
```

Examples include:

- inspect a process;
- view an allowlisted user service;
- show recent logs for an allowlisted service;
- summarize memory pressure;
- inspect batteries;
- inspect monitors and connected devices;
- collect a troubleshooting report.

## Senomy Insights architecture

Insights consumes normalized summaries rather than re-running every source on
each render. Expensive checks, such as package updates, use manual refresh or a
long interval.

The Insights window is a stable five-section shell. Section content remains
modular under `sections/insights/`. Briefing may consume lightweight live
sources. Timeline uses bounded and redacted readers. Updates caches successful
checks. Diagnostics invokes only allowlisted tasks. Reports assemble
previewable evidence from approved sources.

Updates uses a command/cache split:

```text
Updates tab
  ├── 2s run-while poll
  │     └── scripts/update-status.sh read
  │           └── $XDG_CACHE_HOME/senomyos/updates.json
  ├── CHECK OFFICIAL
  │     └── checkupdates, or local pacman -Qun fallback
  └── CHECK AUR
        └── paru -Qua --nodevel against aur.archlinux.org
```

The two checks are separate because the AUR query discloses installed foreign
package names to an external service. Each check is manual, lock-protected,
bounded by a timeout, parsed into a maximum-size structured list, and written
atomically. The Eww poll reads only the local cache and never launches a
package query by itself. No install, removal, system pacman-database
synchronization, or privileged package command is connected to this collector.

Diagnostics uses the same presentation/operation separation, with the task
catalog acting as its policy boundary:

```text
Diagnostics tab
  ├── hourly run-while catalog poll
  │     └── scripts/diagnostics-status.sh catalog
  ├── 1s run-while result poll
  │     └── scripts/diagnostics-status.sh read
  │           └── $XDG_CACHE_HOME/senomyos/diagnostics.json
  └── selected task ID
        └── scripts/diagnostics-status.sh run <allowlisted-id>
              ├── resolve fixed executable and argument array
              ├── execute under timeout and non-blocking lock
              ├── sanitize and bound display output
              └── atomically replace the mode-0600 result cache
```

The UI catalog and runner are generated from the same internal task records,
but the runner independently validates every requested ID. Yuck never supplies
an executable, argument, path, or shell fragment. The cache stores one current
result, including its exact operation preview, execution source, scope,
timestamps, exit state, truncation metadata, and sanitized line objects. It
does not retain command history.

This first implementation lives in Senomy Insights and provides six read-only
system snapshots. A future Performance Dashboard may reuse the runner
contract, but it must not bypass the catalog or turn it into an interactive
PTY.

An insight record should contain:

```json
{
  "id": "stable-id",
  "severity": "recommended",
  "title": "Short truthful title",
  "summary": "Evidence-based explanation",
  "source": "battery",
  "observed_at": 0,
  "action": null
}
```

Missing sources produce an unavailable record only when that absence is useful
to the user. They should not flood the briefing.

## Responsiveness

Use priority-based reduction:

1. preserve workspaces, primary status, clock, and core controls;
2. shorten telemetry labels;
3. shorten the Senomy message;
4. hide secondary labels while retaining tooltips;
5. reduce visible optional controls and expose them through Overview;
6. keep all panels inside the current monitor work area.

The implementation should not assume the bar always has 1920 pixels.

## Deployment architecture

The current repository is the live development source. It should eventually
produce installable artifacts rather than being copied directly into a fixed
home directory.

Target artifact classes:

- package/service manifests;
- versioned SenomyOS configuration packages;
- default and hardware-profile packages;
- installer or bootstrap tooling;
- bootable installation/recovery images;
- release metadata and migrations.

The shell should follow XDG paths and resolve the active configuration at
runtime. User-owned preferences must remain separate from packaged defaults so
updates do not overwrite personal state.

See `PLATFORM_STRATEGY.md` for the staged delivery model and compatibility
tiers.
