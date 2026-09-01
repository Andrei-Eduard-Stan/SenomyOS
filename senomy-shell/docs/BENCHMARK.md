# Milestone 1 Resource and Responsiveness Benchmark

Measured on the reference T480 on 2026-09-01 with Hyprland 0.56.2 at
1920×1080. Quickshell V2 and Eww were visible concurrently for the normal-mode
sample, so Hyprland reserved 128 px; Eww alone reserves 64 px.

Quickshell was not installed system-wide. Runtime validation used an uninstalled
Release build of Quickshell 0.3.1 under `/tmp`, with Hyprland, UPower, PipeWire,
System Tray, and layer-shell features enabled. The temporary build is not a
deployment decision.

## Measured results

| Metric | Eww V0 | Quickshell V2 | Notes |
|---|---:|---:|---|
| Process count | 20 | 1 | Direct child/process-tree snapshot; Quickshell had 17 threads |
| RSS | 208,524 KiB baseline; 214,360 KiB concurrent | 236,388 KiB | RSS double-counts shared libraries across processes |
| PSS | 96,770 KiB baseline; 96,839 KiB concurrent | 90,040 KiB | Best like-for-like resident cost estimate |
| Private memory | 80,228 KiB baseline; 75,804 KiB concurrent | 61,160 KiB | Snapshot values vary with allocator/cache state |
| Idle CPU | 2.46% of one core baseline | 0.60% of one core | 11.4 s Eww baseline and 15.0 s normal V2 sample |
| Concurrent Eww CPU | 5.53% of one core | — | Same 15.0 s interval as V2; includes live poll/listener activity |
| First V2 config load | not safely remeasured | 299 ms | Log delta from launch to `Configuration Loaded` |
| Second V2 config load | not safely remeasured | 288 ms | Fresh process after caches were warm |

The prototype meets the requested `<1%` idle CPU target and `<250 MB` RSS
ceiling. It does not meet the preferred 150–200 MB RSS range, but its PSS and
private memory are lower than the live Eww process tree. Both values are kept
because quoting RSS alone would misrepresent Qt shared mappings, while quoting
only PSS would hide the larger address/resident footprint.

## Process and polling behavior

Quickshell had no child processes at either resource snapshot. Hyprland,
UPower, PipeWire, and System Tray state arrive through native service objects.
CPU, memory, and uptime use one two-second timer that reloads three `/proc`
files inside the same process. Launching Rofi remains an explicit user action,
not an idle poll.

The live Eww tree contains the daemon, Glycin helpers, shell listeners,
`pactl subscribe`, `swaync-client`, `jq`, NetworkManager listener processes,
and transient commands produced by poll scripts. Five short-lived `sleep`
children appeared during the baseline sampling window. `workspaces.service`
is a further two-process Eww support path and was excluded from the table so
the shell-tree comparison stays conservative.

## Responsiveness and visual QA

- Native workspace objects rendered the actual dynamic workspaces and current
  app indicators. Three occupied workspaces were visible during QA; the active
  state and viewport were not hard-coded.
- Calendar open/close was exercised through a temporary per-monitor QA hook
  removed after the test. The popup rendered the real September 2026 month,
  highlighted today, anchored to the correct clock island, and closed
  deterministically.
- Popup content is exposed on the next event-loop turn (1 ms timer) and the
  restrained opacity/translation transition completes in 130 ms. This is a
  code-path bound, not a compositor photon-to-photon measurement.
- Workspace and active-window changes are signal-driven; no workspace switch
  polling interval exists. End-to-end compositor-to-display latency was not
  instrumented, so no fabricated millisecond claim is made.
- Static components have no continuous animation. Calendar and workspace
  geometry animate only while state changes.

## Measurement limits

- Eww cold/warm startup was not measured because restarting the authoritative
  live shell solely for a benchmark was outside the safety boundary.
- `intel_gpu_top` was unavailable and `/sys/kernel/debug/dri` was not readable.
  The exposed GT frequency stayed at its 300 MHz floor, but that is shared by
  the entire compositor and cannot attribute GPU cost to either shell. GPU
  utilization is therefore **not measured**.
- Popup and workspace end-to-end latency need a presentation-timestamp or
  camera-based harness. The milestone verifies event-driven paths, designed
  transition bounds, and visible behavior only.
- The remaining launch warnings were environmental: the tool harness imposed
  `LC_ALL=C`, and the uninstalled temporary binary had no desktop file for its
  portal app ID. The real user-manager locale is `en_GB.UTF-8`. No source QML
  warnings remained after the missing icon and deprecated popup sizing were
  corrected.

## Avoidable Eww costs relevant to interpretation

Eww currently uses separate minute polls for time/date, shell scripts for Rail
telemetry and battery, multiple persistent parsing pipelines, and external
commands for data available through native buses/protocols. Conditional
`:run-while` guards already avoid the worst hidden-surface work, so V0 is not an
unoptimized strawman. V2's advantage comes chiefly from collapsing the
always-on Rail path into one process and using event-driven native services.
