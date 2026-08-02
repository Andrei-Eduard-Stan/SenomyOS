# Performance Dashboard Design QA

## Scope

- Reference images:
  - `/home/Duku/.codex/attachments/68a8b940-4c30-46b5-a674-68fcf8fb4f5c/image-1.png`
  - `/home/Duku/.codex/attachments/68a8b940-4c30-46b5-a674-68fcf8fb4f5c/image-2.png`
- Implemented surface: `performance`
- Native implementation: Eww/Yuck/SCSS on Hyprland
- Verification viewport: 1920x1080 on `eDP-1`
- Implementation screenshot: `/tmp/senomy-performance-dashboard-final-2.png`
- Final comparison: `/tmp/senomy-performance-final-comparison.png`

## Comparison Method

The source panel was normalized from a `1334x430+181+392` crop. The final
implementation was normalized from a `1613x518+154+505` crop. Both were resized
to 1500 pixels wide and vertically appended for a direct visual comparison.

The implementation was captured with the Performance Dashboard open, the main
bar visible, and real local telemetry active. The panel was then exercised
through its live coordinator rather than inspected as a static mock.

## Fidelity Review

- Typography: the existing SenomyOS JetBrains Mono family preserves the
  reference's narrow terminal character while remaining consistent with the
  rest of the shell. Header and table labels no longer truncate.
- Composition: CPU and memory telemetry, process inspection, system health,
  dual batteries, and the Senomy observer rail reproduce the reference's four
  primary information regions.
- Proportions: the first implementation was too tall at 52 percent of the work
  area. It was reduced to 48 percent to match the reference's broad, low
  Cathedral Deck silhouette more closely.
- Color: the shell uses the approved SenomyOS periwinkle accent instead of
  copying the reference's red accent. Green is reserved for truthful live and
  battery state rather than general decoration.
- Content: displayed CPU, memory, processes, host, kernel, packages, storage,
  temperature, and battery values come from local collectors. Missing data is
  represented as unavailable; no telemetry is fabricated.
- Navigation: the reference's Control Centre navigation row is intentionally
  omitted. The approved product model makes Performance a separate surface
  opened by CPU/MEM/UP, not a Control Centre tab.
- Senomy art: the `S` observer mark is an explicitly approved temporary
  placeholder while the user prepares the final Senomy character asset.

## Interaction Review

- CPU/MEM/UP opens the Performance Dashboard through the shared surface
  coordinator.
- The close control dismisses the dashboard through the same coordinator.
- `INSPECT` transfers to Senomy Insights diagnostics without overlapping
  primary surfaces.
- The global non-consuming Escape dispatcher closes Performance, Insights, the
  Control Centre, and transient flyouts while leaving Escape available to the
  focused application.
- Opening any primary surface closes the previous primary surface and any
  transient flyout.
- Native runtime checks replaced browser-console checks because this is a GTK
  desktop shell, not a web application.

## Iterations

- P2: long headings were truncated. Fixed with explicit expansion and
  `show-truncated false`.
- P2: the first panel was visibly taller than the reference and the memory
  graph used semantic green decoratively. Fixed by reducing the panel height
  from 52 to 48 percent and using the neutral telemetry treatment.
- Post-fix comparison: no actionable P0, P1, or P2 visual issue remains.
- Accepted P3 follow-up: replace the temporary `S` observer mark after the
  final Senomy asset is supplied.

## 2026-07-28 Rail, Tray, And History Follow-up

- Main-bar capture: `/tmp/senomy-mainbar-icons-svg-crop.png`
- Tray capture: `/tmp/senomy-tray-popup-crop.png`
- Retained-history capture: `/tmp/senomy-performance-history-final.png`
- Final single-bar capture: `/tmp/senomy-single-daemon-bottom.png`
- Theme-icon images parsed but painted transparently on the installed Eww
  0.5.0 build. The final rail uses repository-owned SVGs in exact 16x16 image
  boxes, and arrow, Applications, volume, Wi-Fi, and battery share one vertical
  centerline.
- The inline native tray was replaced by one arrow-triggered overflow. Live
  Flameshot registration was present on first open and after close/reopen.
- CPU and memory history now comes from a five-minute runtime cache rather than
  window-local Eww graph state. Forty-seven retained points loaded immediately
  after opening, and an older sample remained after close/restart/reopen.
- Initial vertical bars filled downward. `flipped=true` corrected both series
  to grow upward from their common baseline.
- One IPC race during QA created a second daemon and duplicated the bar. The
  older PID was terminated gracefully; final visual and process checks showed
  one daemon and one bar. Ordinary coordinator calls were then hardened with
  `--no-daemonize` and a timeout; a post-fix tray transition retained that
  single-daemon state.

final result: passed
