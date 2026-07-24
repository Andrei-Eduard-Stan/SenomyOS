# SenomyOS

SenomyOS is a custom Arch Linux desktop shell built around Hyprland and Eww.
It is currently a live desktop configuration, but the long-term target is a
reproducibly deployable Arch-based operating-system experience.

The intended product should install on supported laptops, desktops, mini PCs,
touch devices, and eventually compatible phone-sized Linux hardware with as
little manual configuration as practical. The current T480 is reference
hardware, not the final hardware specification.

The project is being revived around four coordinated surfaces:

1. A compact bottom system bar.
2. A unified contextual Control Centre.
3. A separate full Performance Dashboard.
4. A separate Senomy Insights system briefing.

The approved everyday direction is the compact **Obsidian Rail** design. The
expanded **Cathedral Deck** direction is reserved for the Performance
Dashboard, opened by clicking the CPU/MEM/UP telemetry area.

## Repository location

This repository is also the live Eww configuration:

```text
/home/Duku/.config/eww
```

The actual live Hyprland configuration is separate:

```text
/home/Duku/.config/hypr/hyprland.conf
```

The repository contains a tracked mirror at `hyprland.conf`. The two files must
be compared and synchronized deliberately.

## Current structure

```text
.
├── eww.yuck                 Eww entry point, includes, polls, and state
├── eww.scss                 Current global styling
├── windows/                 Eww window definitions
├── widgets/                 Reusable bar widgets
├── scripts/                 Data collectors and workspace updater
├── systemd/                 Workspace-listener user service source
├── hyprland.conf            Tracked mirror of the live Hyprland config
├── AGENTS.md                Repository rules for coding agents
└── docs/                    Product, architecture, design, and workflow docs
```

The workspace listener and dual-battery collector are the strongest original
parts. The current Action Centre is incomplete. The legacy deadlocking update
loop has been removed from future-session autostart; an old process may remain
until the development session is logged out or rebooted.

## Documentation

- [Product specification](docs/PRODUCT_SPEC.md)
- [Project handbook](docs/HANDBOOK.md)
- [Deployment and platform strategy](docs/PLATFORM_STRATEGY.md)
- [Architecture and state model](docs/ARCHITECTURE.md)
- [Design system](docs/DESIGN_SYSTEM.md)
- [Data sources and command policy](docs/DATA_SOURCES.md)
- [Development and validation workflow](docs/DEVELOPMENT.md)
- [Implementation plan](docs/IMPLEMENTATION_PLAN.md)
- [Decision log](docs/DECISIONS.md)
- [Runtime inventory](docs/RUNTIME_INVENTORY.md)

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

Revival work belongs on the `revival/live` branch. Before every commit:

1. inspect the complete diff;
2. validate changed shell and JSON output;
3. check Eww or Hyprland errors as applicable;
4. warn before any live reload or service restart;
5. keep the commit limited to one recoverable stage.

Do not push directly to `main`.
