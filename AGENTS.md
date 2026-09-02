# SenomyOS Repository Instructions

## Purpose

This repository is the live development tree for SenomyOS, a custom Arch Linux
desktop shell built with Hyprland and Eww. SenomyOS is not yet a full operating
system distribution, but becoming a reproducibly deployable operating-system
product is the long-term goal.

The design target is a dark, precise, terminal-inspired desktop shell with:

- a responsive bottom system bar;
- one unified contextual Control Centre;
- a separate full Performance Dashboard;
- a separate Senomy Insights briefing surface;
- dual-battery support;
- safe system controls and truthful diagnostic information;
- adaptive pointer, keyboard, and touchscreen operation;
- portable deployment across supported laptops, desktops, mini PCs, tablets,
  and phone-sized Linux devices with minimal manual configuration.

Read the documents in `docs/` before making structural changes. Start with:

1. `docs/HANDBOOK.md`
2. `docs/PRODUCT_SPEC.md`
3. `docs/PLATFORM_STRATEGY.md`
4. `docs/ARCHITECTURE.md`
5. `docs/DESIGN_SYSTEM.md`
6. `docs/DATA_SOURCES.md`
7. `docs/DEVELOPMENT.md`
8. `docs/IMPLEMENTATION_PLAN.md`
9. `docs/DECISIONS.md`
10. `docs/RUNTIME_INVENTORY.md`

## Workspace and live-state boundaries

- Live Eww configuration and Git repository:
  `/home/Duku/.config/eww`
- Actual live Hyprland configuration:
  `/home/Duku/.config/hypr/hyprland.conf`
- Tracked Hyprland mirror:
  `/home/Duku/.config/eww/hyprland.conf`
- Recovery snapshot:
  `/home/Duku/SenomyOS-recovery/20260719-170831`
- Out-of-scope secondary clone:
  `/home/Duku/Projects/SenomyOS`

Never use, modify, delete, or synchronize the secondary clone unless the user
explicitly asks. Develop directly in the live Eww repository.

The tracked and live Hyprland files are separate files. Never assume that a
change to one updates the other. Compare them explicitly and synchronize them
deliberately.

## Mandatory safety workflow

This repository controls the user's live desktop.

1. Inspect `git status`, the current branch, and relevant diffs before editing.
2. Work on `revival/live` or a later feature branch. Never push directly to
   `main`.
3. Preserve unrelated or pre-existing changes.
4. Before editing, explain the intended file scope and visible effect.
5. Before reloading Eww, restarting a service, stopping a process, or changing
   the live Hyprland file, explain the action and warn if the bar or desktop
   could briefly disappear.
6. Do not run `git init`, create another clone, or use destructive Git commands.
7. Do not commit without first showing the diff and validation results.
8. Keep commits small and centered on one recoverable stage.
9. Never push unless the user explicitly asks.

Prefer read-only diagnosis first. A request to inspect or diagnose does not
authorize a reload, restart, process termination, or configuration change.

## Product decisions that must not regress

The approved surface model is:

- **Main bar:** based on the compact "Obsidian Rail" direction.
- **Control Centre:** compact contextual panel for Overview, Network, Audio,
  Power, Calendar, Input, Device Management, Applications, Appearance, and
  Settings.
- **Performance Dashboard:** a separate, expanded system-management surface
  based on the "Cathedral Deck" direction. It opens from the CPU/MEM/UP
  telemetry labels, not from a Control Centre Performance tab.
- **Senomy Insights:** a separate, first-class system briefing opened from the
  Senomy identity/message area. It must not be omitted or treated as a generic
  chatbot. Its stable routes are Briefing, Notifications, Timeline, Updates,
  Diagnostics, Console, Reports, and Wiki.
- **Senomy companion:** a non-primary edge overlay opened from the Rail avatar.
  The avatar is a separate control immediately beside the Insights dialogue,
  so the pair still reads as one profile-and-message unit. Primary panel
  headers and content cards do not reserve duplicate character artwork.

Only one primary surface should be active at a time:

`none`, `control`, `performance`, or `insights`.

The companion is not a fifth primary surface. Its `closed`, `expanded`, and
`compact` modes may coexist with one primary surface; pinning applies only to
the current companion session and prevents its timed collapse.

Device Management replaces Performance in the Control Centre. It covers
connected monitors, audio endpoints, input devices, batteries, network
interfaces, and optional Bluetooth devices when a safe data source exists.

## Deployment and portability are product requirements

Every feature should move SenomyOS toward a deployable system rather than a
single-machine dotfile collection.

- Treat the current T480 as reference hardware, not the permanent target.
- Separate portable defaults from machine-specific hardware profiles.
- Prefer capability detection over model-name checks.
- Keep user identity, home paths, monitor names, battery counts, interface
  names, resolutions, and device IDs out of portable defaults.
- Design for mouse, keyboard, and touch from the beginning.
- Preserve usable layouts in landscape, portrait, narrow, and wide work areas.
- Use larger touch targets and adequate spacing when a touch-oriented profile
  is active.
- Do not claim universal hardware support. Record unsupported hardware and
  platform limitations honestly.
- Keep packaging, installation, first-boot configuration, updates, rollback,
  and recovery in the architecture even while the project is still a live
  configuration.

Read `docs/PLATFORM_STRATEGY.md` before introducing a machine-specific
assumption or deployment mechanism.

## Existing functionality to preserve

- `scripts/workspaces.sh` and `workspaces.service` are the stable workspace
  update path.
- `scripts/battery.sh` provides working dual-battery JSON using UPower and
  `jq`.
- Hyprland 0.55.2 compatibility changes in the tracked `hyprland.conf` are a
  known-good baseline and must not be discarded.

Refactor these only with a clear reason, targeted validation, and a small
commit.

## Implementation standards

### Eww and Yuck

- Keep windows, reusable widgets, and section content modular.
- Use one explicit active-surface state and one Control Centre section state.
- Avoid independent popup flags that can leave overlapping windows open.
- Keep presentation separate from data collection and system actions.
- Do not hard-code `/home/Duku`, monitor `0`, or a 1920x1080 coordinate when a
  relative, anchored, `$HOME`, or runtime-discovered alternative exists.
- Route necessary hardware-specific values through documented profiles rather
  than embedding them in shared components.
- Keep the bar usable when one script, command, or hardware source fails.
- Provide hover, active, disabled, loading, empty, warning, and error states.
- Icon-only controls need tooltips or accessible labels and useful click
  targets.
- Senomy avatar assets may be SVG, PNG, JPG/JPEG, or GIF. Animated GIFs must be
  bounded and rendered through context-sized cached variants rather than
  decoded at unbounded source size.
- Make primary controls usable by pointer, keyboard, and touch. Gesture-only
  behavior must have a visible alternative.

### Shell and data

- New project shell scripts should use Bash deliberately and begin with
  `#!/usr/bin/env bash`.
- Run `bash -n` on every changed shell script.
- Prefer structured JSON generated with `jq -n`/`jq -c`.
- Return explicit availability and error information; never emit fabricated
  values.
- Check optional commands before using them and degrade gracefully.
- Avoid expensive polling. Poll only while a surface needs the data when Eww
  supports `:run-while`; use event listeners where they materially help.
- Never put saved Wi-Fi passwords, credentials, tokens, private environment
  variables, or unrestricted logs into Eww state.
- Never interpolate untrusted widget text into a shell command.

### System actions

- Informational reads may run directly.
- Killing or restarting processes, disconnecting networking, installing
  updates, rebooting, shutting down, or changing devices requires an explicit
  confirmation state.
- Prefer graceful process termination before force-killing.
- The Performance Dashboard's mini console is a curated diagnostic runner, not
  an arbitrary shell. Commands and arguments must be allowlisted.
- Clearly distinguish unavailable, planned, running, succeeded, and failed
  actions.

## Validation checklist

Run checks appropriate to the changed stage:

- `git diff --check`
- `bash -n` for all changed shell scripts
- `jq -e .` against every changed JSON-producing script
- Eww/Yuck and SCSS validation without disturbing the live daemon where
  possible
- `eww logs` and `eww active-windows` after an approved live reload
- `hyprctl configerrors` after any approved Hyprland change
- byte comparison between the tracked and live Hyprland configs when they are
  intended to match
- manual verification that the bar remains visible and primary-surface toggles
  cannot overlap

Record meaningful architecture or product changes in `docs/DECISIONS.md`, and
update `docs/RUNTIME_INVENTORY.md` when a known runtime fact changes.
