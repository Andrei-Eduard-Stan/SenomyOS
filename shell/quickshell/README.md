# SenomyOS Shell V2 — Milestone 2 foundation

This directory is the source-owned Quickshell 0.3 / QtQuick implementation of
the SenomyOS Obsidian Rail. It can replace Eww during the current Hyprland
session through a guarded selector, but Eww remains the login default and
automatic fallback.

## Current scope

- one transparent, bottom-anchored `PanelWindow` per screen;
- native Hyprland workspace, focused-workspace, monitor, and toplevel state;
- animated workspace overflow with a bounded four-item viewport;
- native UPower aggregation across all present laptop batteries;
- native PipeWire default-sink volume and mute state;
- one shared, process-free `/proc` sampler for CPU, memory, and uptime;
- native, event-driven NetworkManager state;
- native System Tray lifecycle, activation, attention, scroll, and DBus menus;
- a real QtQuick calendar popup with compositor-backed click-away behavior;
- a native tray popup sharing one global popup coordinator with Calendar;
- an allowlisted, confirmation-gated session-action service boundary;
- modular SenomyOS Luminous Reliquary SVG frames.

Performance Dashboard, Insights, Control Centre, companion overlay, detailed
flyouts, notifications, broad network control, and power UI remain on Eww for
this milestone.

## Live development

From the source root, install only the explicit development links and non-enabled
units:

```bash
./scripts/senomy-v2-deploy apply
senomy-dev shell
```

Switch and inspect without logging out:

```bash
senomy-shell use quickshell
senomy-shell use eww
senomy-shell status
senomy-shell doctor
```

Runtime logs are available without attaching another reader to Eww:

```bash
senomy-shell logs 120
```

No V2 unit is enabled. The existing Hyprland startup remains Eww-owned, so the
next login still starts the known-good fallback.

## Runtime requirements

- Quickshell 0.3.x built with Hyprland, UPower, PipeWire, and System Tray support
- Qt 6.9 or newer
- Hyprland with the focus-grab protocol used by Quickshell
- UPower and PipeWire/WirePlumber for their respective controls
- the SenomyOS Nerd Font and icon theme for exact visual fidelity

The shell degrades honestly when a battery or audio sink is unavailable. It
does not fabricate a status value.

See `../../docs/QUICKSHELL_V2_FOUNDATION.md`, `docs/CURRENT_STATE.md`,
`docs/MIGRATION_MAP.md`, and `docs/BENCHMARK.md` for the source architecture,
migration decisions, and measured results.
