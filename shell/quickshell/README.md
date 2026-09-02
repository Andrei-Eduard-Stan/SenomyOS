# SenomyOS Shell V2 — Milestone 3 functional shell

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
- native volume, tray, calendar, notification-history and guarded power popups;
- one Control Centre with ten routes;
- a separate seven-route Performance Dashboard with conditional telemetry;
- a separate eight-route Senomy Insights surface and companion overlay;
- native BlueZ, MPRIS and notification-server ownership in Quickshell mode;
- one shared surface coordinator with hot-unplug cleanup;
- an allowlisted, two-stage session-action service boundary;
- modular SenomyOS Luminous Reliquary SVG frames.

Normal Quickshell use does not start an Eww process, Eww workspace publisher,
or SwayNC. Eww is deliberately retained as the login-time and automatic
failure fallback. Physical pointer/keyboard acceptance items remain before
Milestone 3 sign-off; see `../../docs/QUICKSHELL_V3_QA.md`.

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
`docs/MIGRATION_MAP.md`, `docs/BENCHMARK.md`,
`../../docs/QUICKSHELL_V3_PARITY.md`, and
`../../docs/QUICKSHELL_V3_QA.md` for architecture, migration decisions,
measured results, and the remaining manual acceptance gate.
