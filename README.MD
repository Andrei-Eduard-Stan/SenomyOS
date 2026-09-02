# SenomyOS

SenomyOS is a custom Arch Linux desktop shell built around Hyprland. Eww is the
current login-time shell and rollback path; Quickshell V2 is the live-selectable
migration target. The long-term target is a reproducibly deployable Arch-based
operating-system experience.

The intended product should install on supported laptops, desktops, mini PCs,
touch devices, and eventually compatible phone-sized Linux hardware with as
little manual configuration as practical. The current T480 is reference
hardware, not the final hardware specification.

The project is being revived around four coordinated surfaces and one ambient
companion overlay:

1. A compact bottom system bar.
2. A unified contextual Control Centre.
3. A separate full Performance Dashboard.
4. A separate Senomy Insights system briefing.
5. A single edge-mounted Senomy companion opened from the Rail avatar.

The approved everyday direction is the compact **Obsidian Rail** design. The
expanded **Cathedral Deck** direction is reserved for the Performance
Dashboard, opened by clicking the CPU/MEM/UP telemetry area.

## Repository location

The authoritative V2 source worktree is:

```text
/home/Duku/SenomyOS
```

The known-good live Eww fallback remains a detached checkout at:

```text
/home/Duku/.config/eww
```

The actual live Hyprland configuration is separate and currently uses Lua:

```text
/home/Duku/.config/hypr/hyprland.lua
```

The repository contains tracked Lua and compatibility `.conf` mirrors. Live and
tracked files must be compared and synchronized deliberately.

## Current structure

```text
.
├── eww.yuck                 Eww entry point, includes, polls, and state
├── shell/quickshell/        Quickshell V2 shell and native services
├── eww.scss                 Current global styling
├── windows/                 Eww window definitions
├── widgets/                 Reusable bar widgets
├── scripts/                 Data collectors and workspace updater
├── systemd/                 Legacy and V2 user-service sources
├── appearance/              Canonical tokens and native projections
├── assets/                  Canonical shared artwork and Rail icons
├── hyprland.lua             Tracked mirror of the active Hyprland config
├── AGENTS.md                Repository rules for coding agents
└── docs/                    Product, architecture, design, and workflow docs
```

The original workspace listener and dual-battery collector remain preserved.
The current shell now connects all ten Control Centre routes, the separate
Performance Dashboard, the eight-route Senomy Insights surface, responsive
Rail profiles, the single-avatar companion foundation, guarded recovery, and
structured data/action contracts. The
legacy deadlocking update loop is no longer part of startup.

This is still a live configuration, not a finished OS release. Physical
multi-monitor/touch/non-T480 validation, clean-machine deployment, packaging,
installer/recovery media, and final avatar artwork remain release work.

## Documentation

- [Product specification](docs/PRODUCT_SPEC.md)
- [Project handbook](docs/HANDBOOK.md)
- [Deployment and platform strategy](docs/PLATFORM_STRATEGY.md)
- [Architecture and state model](docs/ARCHITECTURE.md)
- [Design system](docs/DESIGN_SYSTEM.md)
- [Launcher and file workspace](docs/LAUNCHER_FILE_MANAGER.md)
- [Data sources and command policy](docs/DATA_SOURCES.md)
- [Development and validation workflow](docs/DEVELOPMENT.md)
- [Implementation plan](docs/IMPLEMENTATION_PLAN.md)
- [Decision log](docs/DECISIONS.md)
- [Runtime inventory](docs/RUNTIME_INVENTORY.md)
- [Quickshell V2 foundation](docs/QUICKSHELL_V2_FOUNDATION.md)

Anyone changing the live shell should read `AGENTS.md` first.

## Long-term deliverables

The project should grow in layers:

1. a reliable portable shell configuration;
2. declarative package and service manifests;
3. hardware and form-factor profiles;
4. an automated installer or reproducible system deployment;
5. a bootable installation/recovery image;
6. documented updates, rollback, diagnostics, and recovery.

Pointer, keyboard, and touch interaction are product requirements. Phone-class
support remains hardware-dependent and should be treated as an explicit
compatibility tier rather than assumed to work everywhere.

## Development status

V2 integration work belongs on `quickshell-v2`; Eww revival fixes belong on
`revival/live`. Before every commit:

1. inspect the complete diff;
2. validate changed shell and JSON output;
3. check Eww or Hyprland errors as applicable;
4. warn before any live reload or service restart;
5. keep the commit limited to one recoverable stage.

Do not push directly to `main`.
