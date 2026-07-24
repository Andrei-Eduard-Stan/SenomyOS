# SenomyOS Revival Implementation Plan

Every stage should remain independently reviewable and recoverable. A stage is
not complete until its diff and validation have been reported.

Portability is evaluated during every stage, not postponed until packaging.
The current T480 is the first validation machine.

## Stage 0 — Documentation baseline

Goals:

- establish repository instructions and durable product decisions;
- document current runtime and known failures;
- make Senomy Insights and the separate Performance Dashboard impossible to
  overlook in later sessions.

Files:

- `AGENTS.md`
- `README.MD`
- `docs/*`

Runtime impact: none.

## Stage 1 — Preserve and stabilize the baseline

Goals:

- review and commit the existing Hyprland 0.55.2 compatibility changes;
- remove the accidental comment-only whitespace hunk if appropriate;
- disable the deadlocked legacy `update-loop.sh` autostart in the tracked and
  live Hyprland files;
- leave the working workspace service and battery poll intact.

Validation:

- complete Git diff;
- tracked/live Hyprland comparison;
- `hyprctl configerrors`;
- process inspection after an explicitly approved stop or next login.

Runtime warning: changing the autostart line is safe for the current bar, but
stopping the already-running stuck process is a separate action requiring
notice.

## Stage 2 — Shared state and data foundation

Goals:

- introduce `active_surface` and `control_section`;
- create normalized read-only collectors;
- replace the non-executable ad-hoc volume/Wi-Fi path;
- define loading, unavailable, malformed, stale, and ready states.

Initial collectors:

- system summary;
- audio summary;
- network summary;
- device inventory.

Preserve:

- `battery.sh`;
- `workspaces.sh`;
- `workspaces.service`.

No visual redesign should depend on unvalidated collector output.

## Stage 3 — Obsidian Rail main bar

Goals:

- implement the selected compact bar hierarchy;
- add Senomy identity/status trigger;
- add CPU/MEM/UP Performance Dashboard trigger;
- add coherent Control Centre triggers;
- add hover, active, disabled, and tooltip states;
- retain workspace and dual-battery functionality.

The bar should be tested first with all primary surfaces closed.

Runtime warning: the first Eww reload may briefly remove the bar if Yuck or SCSS
fails. Warn immediately before it.

## Stage 4 — Senomy Insights foundation

Insights is implemented early so it does not become an afterthought.

Goals:

- add the separate Insights window and state transition;
- display truthful loading, unavailable, and planned states;
- show a small number of evidence-backed battery, maintenance, and resource
  observations;
- include source and freshness information.

No package update count is shown until a successful update check exists.

## Stage 5 — Control Centre shell and core sections

Goals:

- build one compact shared panel;
- implement section switching without opening multiple windows;
- add Overview, Network, Audio, Power, and Calendar one section at a time;
- close on repeated active click and clear close action;
- support Escape where Eww/GTK permits.

Each section gets its own validation and small commit.

## Stage 6 — Device Management

Goals:

- replace the old Performance navigation slot with Device Management;
- list connected monitors, audio endpoints, input devices, batteries, and
  network interfaces;
- show optional Bluetooth support only when its source is installed;
- expose read-only details before adding any mutating device actions.

Device actions require explicit scope and confirmation.

## Stage 7 — Cathedral Deck Performance Dashboard

Goals:

- add the separate expanded dashboard;
- open it from CPU/MEM/UP;
- add live metrics and bounded history;
- add sortable process inspection;
- add service and hardware health summaries;
- add report generation;
- add an allowlisted diagnostic task console.

Action rollout:

1. read-only inspection;
2. report generation;
3. confirmed graceful process termination;
4. allowlisted service restart;
5. separately confirmed force-kill only if necessary.

Never expose an unrestricted shell.

## Stage 8 — Advanced Insights

Goals:

- add manual/long-interval package and AUR update checks;
- derive health observations from successful source records;
- add a concise recent-action trail;
- link recommended actions to the appropriate safe surface;
- avoid alarm fatigue and duplicated messages.

## Stage 9 — Applications, Input, and Settings

Goals:

- finish remaining Control Centre sections;
- represent unsupported tray/background-app concepts honestly;
- add safe preferences for SenomyOS presentation and polling;
- keep settings separate from system-wide privileged configuration until a
  secure mechanism exists.

## Stage 10 — Hardening and responsive pass

Goals:

- test narrower and wider displays;
- remove monitor and resolution assumptions;
- test missing dependencies and disconnected hardware;
- verify focus, keyboard, tooltips, and click targets;
- inspect idle resource consumption;
- verify Eww logs and Hyprland errors;
- update documentation and runtime inventory.

## Stage 11 — Hardware and form-factor profiles

Goals:

- replace remaining monitor, path, interface, and battery assumptions;
- generate normalized capability data;
- define portable defaults and minimal overrides;
- add desktop, laptop, touch, portrait, and narrow layout profiles;
- test hot-plugged devices and missing hardware.

## Stage 12 — Touch and convertible support

Goals:

- add touch-oriented density and targets;
- ensure no essential action depends on hover;
- support portrait and landscape transitions where the stack permits;
- handle on-screen keyboard space;
- evaluate optional gestures with visible alternatives;
- document tested touchscreen hardware.

## Stage 13 — Reproducible system deployment

Goals:

- define the Arch package and service manifests;
- package SenomyOS configuration separately from user preferences;
- create repeatable installation/bootstrap tooling;
- create first-boot hardware/profile selection;
- define configuration migrations and rollback;
- verify deployment in a clean virtual machine before new hardware.

## Stage 14 — Bootable release and compatibility tiers

Goals:

- produce a bootable installation/recovery image;
- document installation, updates, recovery, and known limitations;
- test representative laptop, desktop/mini-PC, and touch hardware;
- define experimental ARM/tablet/phone work separately from supported x86_64
  releases;
- publish a compatibility matrix based on real tests.

## Commit strategy

Suggested early commits:

```text
docs: establish SenomyOS revival source of truth
fix(hyprland): preserve 0.55 compatibility baseline
fix(runtime): remove deadlocked update loop
feat(data): add normalized system status
feat(bar): introduce Obsidian Rail shell
feat(insights): add briefing surface foundation
```
