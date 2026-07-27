# SenomyOS Decision Log

This is a lightweight architecture and product decision record. Add a dated
entry when a decision changes surface ownership, safety policy, data contracts,
or the development workflow.

## D001 — Develop from the live Eww repository

**Date:** 2026-07-24
**Status:** Accepted

Development happens in `/home/Duku/.config/eww`. The secondary clone under
`/home/Duku/Projects/SenomyOS` is out of scope unless explicitly requested.

## D002 — Use a four-surface shell model

**Date:** 2026-07-24
**Status:** Accepted

The four surfaces are the persistent bar, compact Control Centre, expanded
Performance Dashboard, and Senomy Insights.

## D003 — Use Obsidian Rail for the main shell

**Date:** 2026-07-24
**Status:** Accepted

The compact bottom bar and right-anchored contextual panel from Option 1 are
the primary design direction.

## D004 — Make Performance a separate dashboard

**Date:** 2026-07-24
**Status:** Accepted

The broad Cathedral Deck layout from Option 2 becomes a separate Performance
Dashboard. CPU/MEM/UP telemetry opens it. It does not live inside the Control
Centre.

## D005 — Replace the Performance tab with Device Management

**Date:** 2026-07-24
**Status:** Accepted

The Control Centre navigation uses Device Management for monitors, audio
endpoints, input devices, batteries, interfaces, and optional Bluetooth
devices.

## D006 — Treat Senomy Insights as a first-class surface

**Date:** 2026-07-24
**Status:** Accepted

Insights is separate from the Control Centre and Performance Dashboard. It
opens from the mascot/message area and provides evidence-based system
briefings, not generic chat.

## D007 — Allow only one primary surface at a time

**Date:** 2026-07-24
**Status:** Accepted

`active_surface` is one of `none`, `control`, `performance`, or `insights`.
Opening one surface closes the previous one.

## D008 — Never fabricate system intelligence

**Date:** 2026-07-24
**Status:** Accepted

Metrics, insights, update counts, diagnoses, and actions must come from
successful sources. Missing sources produce unavailable or planned states.

## D009 — Require confirmation for disruptive actions

**Date:** 2026-07-24
**Status:** Accepted

Process termination, restart, disconnect, update installation, reboot, and
shutdown require explicit target-and-impact confirmation.

## D010 — Keep the dashboard console curated

**Date:** 2026-07-24
**Status:** Accepted

The mini console is an allowlisted diagnostic task runner. Eww will not expose
an unrestricted shell or interpolate arbitrary user text into commands.

## D011 — Preserve workspace and dual-battery implementations

**Date:** 2026-07-24
**Status:** Accepted

The workspace service/listener and UPower/jq dual-battery collector remain the
baseline until a replacement is proven safer and better.

## D012 — Use one visual system across all surfaces

**Date:** 2026-07-24
**Status:** Accepted

All surfaces share Obsidian Rail's near-black palette and periwinkle accent.
Cathedral Deck contributes information architecture, not a separate theme.

## D013 — Avoid resolution and monitor hard-coding

**Date:** 2026-07-24
**Status:** Accepted

1920x1080 is the first design target, not a permanent coordinate system.
Windows remain inside the current monitor work area.

## D014 — Establish documentation before implementation

**Date:** 2026-07-24
**Status:** Accepted

Repository instructions, product decisions, data policy, and staged recovery
workflow are documented before the live bar redesign begins.

## D015 — Make SenomyOS a deployable operating-system product

**Date:** 2026-07-24
**Status:** Accepted

The live Eww repository is the development starting point. The long-term output
includes reproducible packages, services, profiles, installation, first boot,
updates, rollback, and bootable recovery/installation artifacts.

## D016 — Treat cross-device adaptability as a core requirement

**Date:** 2026-07-24
**Status:** Accepted

The T480 is reference hardware rather than the permanent target. Portable
defaults use capability detection and work-area geometry. Machine-specific
values are isolated in small profiles.

## D017 — Support touch as a first-class input mode

**Date:** 2026-07-24
**Status:** Accepted

Primary actions must work by pointer, keyboard, and touch where the underlying
stack permits. Touch layouts use larger targets, avoid hover dependencies, and
adapt to portrait, narrow, and on-screen-keyboard constraints.

## D018 — Express hardware support in tested tiers

**Date:** 2026-07-24
**Status:** Accepted

Desktop and laptop support are the first stable targets. Touch and convertible
support follow. Tablet, ARM, and phone-sized devices remain explicit
compatibility tiers because kernels, bootloaders, GPUs, modems, sensors, and
power management vary by device.

## D019 — Use a five-section Senomy Insights shell

**Date:** 2026-07-26
**Status:** Accepted

Senomy Insights uses Briefing, Timeline, Updates, Diagnostics, and Reports.
Timeline is bounded and source-filtered. Diagnostics is an allowlisted task
runner rather than an unrestricted terminal. Arbitrary interactive commands
belong in a real terminal, and privileged mutations require narrow
authorization plus explicit confirmation.

## D020 — Share one Obsidian Rail shell language

**Date:** 2026-07-26
**Status:** Accepted

The Control Centre and Senomy Insights use the same panel, header, navigation,
close-control, body-spacing, typography, border, hover, and active-state
classes. Surface-specific classes add behavior or unique content rather than
forking the visual theme.

## D021 — Never query AUR silently

**Date:** 2026-07-26
**Status:** Accepted

Official and AUR package checks are separate manual actions. The AUR action
must disclose that it sends installed foreign package names to
`aur.archlinux.org`. Opening Insights, switching tabs, polling Eww state, or
checking only the local official package database must never trigger that
network query. Package discovery remains separate from installation.

## D022 — Centralize and reconcile primary-surface transitions

**Date:** 2026-07-26
**Status:** Accepted

Bar triggers, close controls, reload restoration, and recovery use one
allowlisted surface-state helper. `active_surface` remains the source of truth,
and the helper makes explicit window instances match it. Activation opens and
verifies a target before publishing it as active.

Reload captures validated state, closes all windows, stops the daemon, and
starts one replacement process with exactly `main-bar` plus the remembered
surface through `eww open-many`. It then verifies the windows and restores
state. Raw `eww reload` is unsupported because Eww 0.5.0 may reset `defvar`
values while retaining visible window instances.

Background Eww publishers must verify an existing daemon before updating and
must never bootstrap one during the restart gap.

## D023 — Hidden Yuck content must remain safe to evaluate

**Date:** 2026-07-26
**Status:** Accepted

`:visible false` is presentation, not a guarantee that descendant expressions
will not be evaluated. Every expression must tolerate loading, unavailable,
and null data independently. Optional chaining and explicit fallbacks are
required for optional collector fields; a hidden error row must not directly
index a nullable error object.

## D024 — Make the diagnostic catalog the execution boundary

**Date:** 2026-07-26
**Status:** Accepted

Diagnostics accepts only a built-in task ID and maps it inside the runner to a
fixed executable and argument array. The UI may display and request catalog
records, but it never supplies executable names, arguments, paths, or shell
fragments. Output is timeout-bounded, sanitized, and atomically cached with no
history. This contract is reusable by Insights and the future Performance
Dashboard without exposing an unrestricted shell.

## D025 — Keep one persistent native tray host

**Date:** 2026-07-27
**Status:** Accepted

The Obsidian Rail owns one persistent Eww `systray`, so native
StatusNotifier icons and application-provided menus survive Control Centre
closure. The Applications section represents the same user-facing background
applications through larger managed cards rather than instantiating a second
tray.

Managed status combines allowlisted registry metadata with user-systemd,
session D-Bus, and StatusNotifier evidence. Service activity, D-Bus readiness,
and tray registration are not treated as interchangeable. Presentation invokes
only fixed actions from an allowlisted helper, and stopping an application
requires a visible confirmation state.
