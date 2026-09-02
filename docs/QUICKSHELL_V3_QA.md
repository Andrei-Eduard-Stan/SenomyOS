# Quickshell V3 functional QA record

Date: 2026-09-02. Hardware: reference T480, one physical 1920x1080 scale-1
panel; temporary headless outputs supplied multi-monitor, fractional-scale and
portrait evidence. Quickshell 0.3.1; Hyprland 0.56.2.

## Automated and live evidence

- Git branch remained `quickshell-v2`; no merge, push, login-default change,
  Eww deletion, SDDM change, or destructive power/session action occurred.
- Live selector status ended with Quickshell active, Eww and
  `workspaces.service` inactive, SwayNC inactive, one Quickshell Rail, and the
  Quickshell PID as sole `org.freedesktop.Notifications` owner.
- All 10 Control Centre, 7 Performance and 8 Insights routes loaded against
  the live service graph with no QML warning or service error.
- PipeWire reported one output, two inputs and real mute/volume state;
  NetworkManager reported the real connected SSID, signal and connectivity;
  UPower reported two batteries; BlueZ reported the adapter and visible
  devices; MPRIS truthfully reported no active player.
- Bluetooth discovery stopped after the Device Management route closed.
- Primary surfaces replaced each other, primary open closed a popup, popup
  tokens replaced each other, companion plus primary remained co-visible, and
  unplugging the source output cleared all target state.
- Every power action (`lock`, `suspend`, `logout`, `reboot`, `poweroff`)
  entered `pending` and returned to `idle` through cancel. No confirm path was
  invoked.
- The isolated private-bus notification suite passed ownership, metadata,
  replacement ID, action signal, urgency, DND, transient policy, timeout,
  close reason, persistence, individual dismissal, and clear-all behavior.
  Live Eww -> Quickshell -> Eww -> Quickshell ownership/rollback also passed.
- A legacy history read can now distinguish installed from active SwayNC and
  cannot D-Bus-activate SwayNC while Quickshell owns notifications.
- Dashboard Level 2 ran for 65 seconds. CPU, memory, RX and TX histories each
  capped at 60 samples; four seconds after closure they remained at 60 and no
  detail/process/benchmark child remained. Benchmark pages loaded only plan
  and status data; no workload ran.
- Temporary outputs verified two Rails, target-screen Control, Calendar,
  Insights, companion and Performance, 1.25 fractional scale, portrait at 864
  logical pixels, and hot-unplug. Visual captures confirmed side-by-side
  companion/primary layout and the compact portrait CPU/clock Rail. Outputs
  were removed and the session returned to one Rail/monitor.
- `qmllint`, Bash syntax, `git diff --check`, the 31-check static shell suite,
  21 collector contracts, workspace carousel contract, Command Lens contract,
  Insights/report/deployment/bootstrap/theme/login-recovery contracts, and
  the isolated notification suite passed. Legacy live Eww interaction tests
  are not rerun while Quickshell is active.

## Broad resource guardrail

Thirty requested idle samples ran for 32.565 seconds with all surfaces closed.

| Metric | Mean | Median | p95 | Growth |
|---|---:|---:|---:|---:|
| CPU, % of one core | 1.323 | 0.978 | 3.681 | n/a |
| RSS, KiB | 347,263 | 347,264 | 347,332 | -80 |
| PSS, KiB | 195,289 | 195,291 | 195,360 | -80 |
| Private, KiB | 163,058 | 163,060 | 163,128 | -80 |
| Threads | 18 | 18 | 18 | 0 |

No child PID was observed. Compared with the Milestone 2 median, PSS increased
about 14.7 MiB and mean CPU increased from 0.694% to 1.323% after adding the
full service/surface graph. The interval is bounded, below the preferred 200
MiB PSS threshold, and shows no growth, but CPU remains a later soak/watch
item. GPU use is unavailable and is not fabricated.

## Required user input acceptance

These items cannot be marked PASS from IPC, code inspection, or screenshots.
Use real pointer and keyboard input in the live Quickshell session:

1. Click a workspace and both carousel arrows; create/move/close an app and
   confirm occupancy/icons update and the active workspace stays visible.
2. Click the separate Senomy avatar and message targets; use companion buttons
   and open Insights while the companion remains usable.
3. Open Performance from CPU telemetry and Command Lens from Applications.
4. Drag output/input volume sliders, toggle mute, and select a device if a
   second safe endpoint is available.
5. Open Network and Device Management; exercise only non-disruptive controls.
   Pair/connect Wi-Fi or Bluetooth only if the user chooses a safe target.
6. Exercise a real tray item's primary click, right-click menu, nested menu if
   present, wheel action, attention state, and removal/reappearance.
7. Navigate Calendar, rapidly toggle every popup, click outside, press Escape,
   and confirm focus returns without a stale grab.
8. Open Power, request then cancel an action. Do not confirm logout, reboot,
   poweroff, suspend, or lock as part of this checklist.

Also still unverified: a real second monitor/hotplug, touch input, active MPRIS
playback, Bluetooth pairing, and a new secured Wi-Fi secret prompt. These are
capability-specific follow-ups, not permission to disrupt the current session.

## Promotion gate

Milestone 3 can be signed off only after the required physical interaction
checklist is reported. Even then, Quickshell login-default promotion remains a
separate later decision requiring an extended session soak, suspend/resume and
real-hardware input/display evidence. Eww stays installed and recoverable.
