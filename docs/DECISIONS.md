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
