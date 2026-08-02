# SenomyOS Architecture

## Current runtime

Hyprland starts:

- the workspace listener service;
- the Eww daemon and `main-bar`;
- a legacy `update-loop.sh`;
- both Hyprpaper and swww wallpaper paths.

The stable data flows are:

```text
Hyprland .socket2.sock events
  └── workspaces.service
        └── scripts/workspaces.sh
              ├── discover the active Hyprland runtime instance when needed
              ├── debounce related workspace/window events
              ├── query workspaces, activeworkspace, and clients
              ├── normalize workspace/application JSON
              └── eww ping, then update workspaces and workspace_state

Eww batt_json poll
  └── scripts/battery.sh
        ├── UPower
        └── jq

Visible Control Centre telemetry
  ├── scripts/network-status.sh
  │     ├── NetworkManager via nmcli
  │     └── bounded kernel link facts
  └── scripts/audio-status.sh
        ├── PipeWire Pulse compatibility via pactl
        └── PipeWire and WirePlumber service state
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
├── windows/volume-flyout.yuck
├── windows/tray-flyout.yuck
├── windows/surface-dismiss.yuck
├── widgets/
│   ├── bar-icon.yuck
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
active_flyout = "none"
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

Valid transient flyouts:

```text
none
volume
tray
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
console
reports
wiki
```

Opening a surface is a single state transition, not a sequence of unrelated
window flags. Visual active state is derived from this shared state.

`scripts/surface-state.sh` owns primary-surface and transient-flyout
transitions. Bar triggers and panel close buttons pass it only allowlisted
verbs and section names. The helper serializes transitions with a runtime
`flock`, validates existing Eww state, closes non-target windows, selects
content while the state is `none`, opens and verifies the target window, and
only then publishes `active_surface` or `active_flyout`. A failed Eww window
query is an error, not evidence that a window is closed.

Eww 0.5 may briefly return `EAGAIN` while constructing a large widget tree.
Read-only queries retry a bounded five times. Mutations are never blindly
replayed: open, close, and update buffer any client error, then accept success
only if a bounded authoritative query proves the requested window or state
postcondition. Repeated toggles also close a verified open target even if its
state publication was briefly delayed.

The volume and tray flyouts are transient, not additional primary surfaces.
Opening either closes primary surfaces and the other flyout; opening any
primary surface closes both. Reload deliberately does not restore transient
flyouts. The generic `dismiss` action closes the open flyout first and
otherwise closes the active primary surface. Hyprland's non-consuming Escape
binding invokes this action while preserving Escape for the focused
application.

Every open primary surface or transient flyout is paired with the shared
`surface-dismiss` window. It is a transparent `fg` event layer over the usable
work area, below `overlay` panels and outside the exclusive main-bar area.
Clicking it invokes the same coordinator `dismiss` action as Escape. Because
the bar remains clickable, activating a different bar trigger goes through the
serialized coordinator and atomically replaces the old context window.

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
        ├── open main-bar, then the dismiss layer and remembered surface
        ├── wait for daemon IPC
        ├── verify the exact initial window set
        └── restore active, section, and Timeline state
```

The new Eww process must not inherit the transition lock descriptor.
`scripts/workspaces.sh` pings Eww before publishing, so neither an
event-triggered update nor its cached recovery heartbeat can bootstrap a
competing daemon during the intentional restart gap.

Ordinary coordinator calls invoke Eww with `--no-daemonize` under a bounded
timeout. If IPC disappears after the initial ping, the command fails instead of
leaving an implicitly bootstrapped daemon behind. Only
`start_reload_windows`, after the old daemon has been verified stopped, uses
the separate auto-start call.

Session startup treats socket, configuration, and window readiness as separate
gates. `scripts/start-eww.sh` requires a successful ping, a loaded `main-bar`
definition, and an active `main-bar` window. A pingable daemon with no loaded
definitions is an explicit failure, not a healthy desktop.

`scripts/surface-state.sh reconcile` is the recovery operation when window
instances disagree with `active_surface` or `active_flyout`. An unavailable
target returns state to `none`.

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
- `insights-status.sh`

Implemented collectors:

- `battery.sh`
- `workspaces.sh`
- `bar-audio-listener.sh` (PipeWire/Pulse event stream for the persistent bar)
- `bar-network-listener.sh` (NetworkManager event stream for the persistent bar)
- `bar-layout.sh` (capability-derived standard, compact, or narrow density)
- `performance-live.sh` (synchronized persistent bar and dashboard metrics)
- `performance-history.sh` (five-minute multidomain runtime cache)
- `audio-status.sh` (scoped to the volume flyout or Audio section)
- `performance-processes.sh` (three seconds on the Processes page only)
- `performance-status.sh` (15-second inventory while Performance is open)
- `network-status.sh` (visible-only Control Centre poll with nearby and saved
  network catalog)
- `background-apps-status.sh` (connected while Applications or tray is visible)

Collectors must degrade independently. A network error cannot break the clock,
bar, or battery display.

Persistent audio and network marks use event listeners rather than waking the
full panel collectors. The listeners publish only cheap status-area fields;
endpoint inventories and nearby access-point catalogs remain scoped to visible
surfaces. Rail density is derived from the focused monitor's logical width and
never from a machine model or fixed interface name.

The main bar contains only a tray-overflow trigger. The single native
StatusNotifier host is instantiated inside `tray-flyout`, and the Applications
section does not create a second host. Applications combines an allowlisted
registry with user-systemd, session D-Bus, and StatusNotifier evidence to
present larger managed-application controls. Native menus remain owned by
their tray items.

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

Window definitions do not embed a monitor index. `start-eww.sh`, reload
restoration, and `surface-state.sh` discover Hyprland's focused monitor and
pass it through `eww open --screen`. Eww 0.5 cannot consume runtime variables
inside window-definition monitor/geometry properties, so geometry profiles
remain a generated/profile-stage concern rather than dynamic Yuck state.

The compact Control Centre is anchored above the relevant right-side controls
and constrained to the monitor work area.

The volume flyout is a compact secondary window anchored above the audio
control. It contains only immediate volume/mute controls and a visible route to
the full Audio section.

The tray flyout is a compact secondary window anchored above the right-side
overflow arrow. It contains the native StatusNotifier items and no duplicate
managed-application controls.

Senomy Insights is visually connected to the mascot/status region and may
anchor above the left or middle-left bar area.

The Performance Dashboard is a broad, separate surface above the bar. It may
use more width than the Control Centre, but should be sized relative to the
monitor work area rather than a fixed 1920x1080 coordinate.

Monitor selection should use Eww/Hyprland runtime context where possible.
Hard-coded monitor `0` is a migration constraint, not a target design.

## Performance Dashboard architecture

The dashboard combines:

- one 250ms synchronized procfs/sysfs delta sample every two seconds for the
  persistent rail summary and current dashboard values;
- a three-second bounded process delta collector that only runs on the
  Processes page;
- a 15-second host, CPU topology, service, socket, storage, network, GPU, and
  sensor inventory while Performance is open;
- a five-minute runtime cache sampled globally every five seconds for CPU,
  memory, temperature, normalized load, pressure, root-disk, active-network,
  and optional GPU history;
- an allowlisted diagnostics runner;
- an explicit confirmation state for process and service actions;
- report assembly from already-collected, redacted data.

The implemented read-only dashboard has six routes: Overview, CPU + GPU,
Memory, Storage, Network, and Processes. It exposes per-core utilization and
frequency, CPU time distribution and scheduler rates, memory composition and
commit, pressure stall information, root-device throughput and IOPS, active
interface rates and counters, aggregate socket state, sensors, hardware
inventory, and twelve instantaneous process rows.

Power remains a deliberately compact snapshot here. Battery health, charge
thresholds, profiles, and power-policy settings belong to Control Centre /
Power so the two surfaces do not compete or drift into contradictory controls.
The Processes page now supports CPU, memory, and name ordering through a
mode-0600 runtime preference; bounded `/proc` inspection for one selected PID;
and private runtime report generation. SIGTERM, SIGKILL, and failed user-unit
restart remain behind explicit two-step confirmation. The action helper
revalidates current ownership or failed-unit state immediately before acting;
system-unit recovery remains read-only.

Control Centre Power uses a separate capability-driven path:

```text
UPower + /sys/class/power_supply + TLP runtime
  -> scripts/power-status.sh
  -> power_status (5s, only while Power is visible)
  -> sections/control/power.yuck

confirmed plan ID
  -> scripts/power-action.sh
  -> pkexec /usr/bin/tlp <allowlisted-profile>
```

Aggregate charge and health are weighted by energy capacity, not averaged by
pack count. Missing cycle, temperature, threshold, electrical, policy, or
authorization sources remain null/unavailable. Power-plan actions accept only
`power-saver`, `balanced`, or `performance`, require a confirmation view, and
remain disabled when no supported backend or graphical polkit agent exists.

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

The Insights window is a stable seven-section shell. Section content remains
modular under `sections/insights/`. Briefing may consume lightweight live
sources. Timeline uses bounded and redacted readers. Updates caches successful
checks. Diagnostics invokes only allowlisted tasks. Console combines a bounded
read-only command palette with capability-detected handoff to a real Kitty PTY.
Reports assemble profile-based, previewable evidence from approved sources.
Wiki renders a bounded local Markdown catalog.

Wiki keeps authoring separate from presentation:

```text
wiki/*.md
  └── scripts/wiki-status.py catalog
        ├── validate bounded UTF-8 files and restricted front matter
        ├── parse headings, paragraphs, lists, quotes, code, tables, and links
        ├── resolve internal article targets
        └── emit schema-version-1 JSON
              └── sections/insights/wiki.yuck
```

The parser never evaluates Markdown as Yuck, GTK markup, HTML, or shell code.
External links are labelled but deliberately not launched. The three-second
poll runs only while the Wiki route is visible.

Senomy identity artwork follows one manifest and domain-aware resolver:

```text
data/senomy-avatars.json
  └── scripts/senomy-avatar.sh catalog
        └── senomy_avatar_catalog
              └── widgets/senomy-avatar.yuck

state catalog = idle | focused | thinking | happy | warning | busy | sleeping
```

Each state maps independently to a compact chibi asset and a larger portrait
asset. Bar, Power, Insights, and Performance reuse the same widget and catalog
instead of selecting private image paths. The widget centrally resolves an
independent state per domain:

```text
ambient     <- manual chibi_state
battery     <- UPower state + percentage
performance <- resource and service observations
insights    <- active Insights route
```

Domain separation means one verified warning does not incorrectly change
Senomy in unrelated surfaces.

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
