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
              └── eww update workspaces=...

Eww batt_json poll
  └── scripts/battery.sh
        ├── UPower
        └── jq
```

The legacy update loop is not part of the target architecture. It launches the
continuous workspace listener inside command substitution and waits forever.

## Target layers

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

Opening a surface is a single state transition, not a sequence of unrelated
window flags. Visual active state is derived from this shared state.

### Data layer

Data collectors live under `scripts/` and emit compact JSON. Presentation
components should not contain long command pipelines.

Planned collectors:

- `system-status.sh`
- `audio-status.sh`
- `network-status.sh`
- `device-status.sh`
- `processes.sh`
- `insights-status.sh`

Existing stable collectors:

- `battery.sh`
- `workspaces.sh`

Collectors must degrade independently. A network error cannot break the clock,
bar, or battery display.

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
