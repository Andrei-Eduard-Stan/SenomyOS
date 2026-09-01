# SenomyOS Shell V2 — Milestone 1

This directory is a parallel Quickshell 0.3 / QtQuick implementation of the
SenomyOS Obsidian Rail. It does not replace or modify Eww, Hyprland startup, or
the current surface controller.

## Current scope

- one transparent, bottom-anchored `PanelWindow` per screen;
- native Hyprland workspace, focused-workspace, monitor, and toplevel state;
- animated workspace overflow with a bounded four-item viewport;
- native UPower aggregation across all present laptop batteries;
- native PipeWire default-sink volume and mute state;
- one shared, process-free `/proc` sampler for CPU, memory, and uptime;
- native System Tray item count;
- a real QtQuick calendar popup with compositor-backed click-away behavior;
- modular SenomyOS Luminous Reliquary SVG frames.

Performance Dashboard, Insights, Control Centre, companion overlay, detailed
flyouts, notifications, network control, and destructive session actions remain
on Eww for this milestone.

## Manual development launch

Quickshell is intentionally not an autostart dependency yet. Once the Arch
`quickshell` package is installed, run:

```bash
./senomy-shell/scripts/dev.sh
```

This starts V2 in parallel and will reserve another 64 pixels at the bottom
while Eww remains active. For a visually meaningful A/B test, first run V2 and
then manually close only the V2 instance with:

```bash
./senomy-shell/scripts/dev.sh kill
```

Runtime logs are available without attaching another reader to Eww:

```bash
./senomy-shell/scripts/dev.sh log
```

Live Eww must remain the recovery path until the migration acceptance gates in
the migration map are complete. No autostart or default-shell change belongs in
Milestone 1.

## Runtime requirements

- Quickshell 0.3.x built with Hyprland, UPower, PipeWire, and System Tray support
- Qt 6.9 or newer
- Hyprland with the focus-grab protocol used by Quickshell
- UPower and PipeWire/WirePlumber for their respective controls
- the SenomyOS Nerd Font and icon theme for exact visual fidelity

The shell degrades honestly when a battery or audio sink is unavailable. It
does not fabricate a status value.

See `docs/CURRENT_STATE.md`, `docs/MIGRATION_MAP.md`, and `docs/BENCHMARK.md` for
the audited source architecture, migration decisions, and measured prototype
results.
