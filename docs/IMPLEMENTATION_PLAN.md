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

Progress:

- completed in `f9e1402` and `547bab3`;
- tracked and live Hyprland configs match and report no errors;
- the old current-session process remains until logout/reboot by deliberate
  safety choice.

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

Progress:

- `scripts/system-status.sh` now provides validated procfs CPU, memory, uptime,
  and load JSON;
- `scripts/surface-state.sh` now centralizes allowlisted primary-surface
  transitions and serializes rapid actions;
- window instances are reconciled with `active_surface`, and
  `scripts/reload-eww.sh` preserves validated surface, section, and Timeline
  state across a verified full-daemon restart;
- the replacement daemon verifies `main-bar` before restoring the dismiss
  layer and remembered surface at responsive geometry, while the workspace
  publisher refuses to update an absent daemon;
- the workspace listener recovers a missing or stale Hyprland session
  signature from `hyprctl instances -j`, while its user unit retries failures
  without entering a permanent start-limit state;
- `scripts/audio-status.sh` now provides validated output/input, volume, mute,
  route, and endpoint JSON;
- `scripts/network-status.sh` now provides validated connectivity, primary
  connection, Wi-Fi/Ethernet, address, and interface JSON;
- Eww consumes audio status only while the volume flyout or Audio section is
  visible; `scripts/volume.sh` now owns validated volume and mute actions.

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

Progress:

- the right-side rail now uses one compact control rhythm and shows only the
  combined battery summary; physical battery detail remains available in
  larger surfaces and tooltips;
- fixed repository-owned SVGs keep the arrow, Applications, volume, Wi-Fi, and
  battery marks on one visual centerline;
- native tray items now live in an arrow-triggered overflow flyout instead of
  consuming permanent rail width;
- CPU/MEM/UP is a working Performance Dashboard trigger;
- volume opens a compact slider flyout instead of jumping directly to Audio.
- persistent Audio and Network marks are event-driven, and standard/compact/
  narrow information density is capability-derived or user-overridden;
- all Rail routes, native tray overflow, click-again close, cross-surface
  replacement, and accessible status states passed live validation.

## Stage 4 — Senomy Insights foundation

Insights is implemented early so it does not become an afterthought.

Goals:

- add the separate Insights window and state transition;
- display truthful loading, unavailable, and planned states;
- show a small number of evidence-backed battery, maintenance, and resource
  observations;
- include source and freshness information.

No package update count is shown until a successful update check exists.

Progress:

- the bar now has a replaceable Senomy identity/status trigger;
- the dedicated Insights window participates in the shared primary-surface
  state and cannot overlap the Control Centre;
- the first briefing shows live procfs and UPower observations;
- Insights exposes modular Briefing, Timeline, Updates, Diagnostics, and
  Reports sections in one shared Obsidian Rail shell;
- sections without safe connected sources show explicit planned, policy, or
  not-connected states;
- Timeline now reads bounded and sanitized User, System, Kernel, and Eww
  sources with source-specific polling and a working Follow/Pause state;
- Updates now provides separate manual official and AUR checks, a locked and
  atomic local cache, source/freshness labels, bounded package lists, and
  truthful never-checked, checking, ready, partial, unavailable, and error
  states;
- Diagnostics now provides six catalog-driven read-only tasks, exact operation
  previews, explicit scopes and execution sources, a locked mode-0600 cache,
  bounded sanitized output, and idle, running, complete, failed, timed-out,
  unavailable, and cache-error states;
- the Diagnostics runner revalidates task IDs and maps them to fixed argument
  arrays; no arbitrary prompt, shell interpolation, privilege elevation, or
  mutating command is connected;
- package installation remains deliberately disconnected pending a separate
  review and confirmation design;
- temporary text marks reserve the avatar locations without committing
  unfinished character artwork.

## Stage 5 — Control Centre shell and core sections

Goals:

- build one compact shared panel;
- implement section switching without opening multiple windows;
- add Overview, Network, Audio, Power, and Calendar one section at a time;
- close on repeated active click and clear close action;
- support Escape where Eww/GTK permits.

Each section gets its own validation and small commit.

Progress:

- Audio is the first live core section, with default output/input state,
  validated volume adjustment, and mute control;
- `dismiss` is the common close action for flyouts and primary surfaces;
- the tracked Hyprland config uses a non-consuming Escape binding so the
  focused application still receives Escape;
- every contextual window opens above one transparent shared dismiss layer;
  outside click, Escape, repeated trigger, and cross-trigger switching now
  converge on the same serialized lifecycle.
- Overview, Network, Audio, Power, Calendar, Input, Device Management,
  Applications, and Settings are connected; collector polling follows the
  visible section rather than leaving Overview or Device Management on initial
  placeholders;
- Control Centre, Insights, Performance, Volume, and Tray expose visible close
  controls and all five pass the compositor Escape command.

## Stage 6 — Device Management

Goals:

- replace the old Performance navigation slot with Device Management;
- list connected monitors, audio endpoints, input devices, batteries, and
  network interfaces;
- show optional Bluetooth support only when its source is installed;
- expose read-only details before adding any mutating device actions.

Device actions require explicit scope and confirmation.

Progress:

- read-only monitor, input, audio hardware, battery, Bluetooth, and network
  interface inventories are connected with capability-aware empty states;
- mutating device actions remain deliberately outside this stage.

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

Progress:

- the six-route read-only dashboard is implemented for Overview, CPU + GPU,
  Memory, Storage, Network, and Processes;
- a runtime cache retains five minutes of CPU, memory, temperature, load,
  pressure, disk, network, and optional GPU history across dashboard
  close/reopen cycles;
- a synchronized live collector supplies total/per-core compute, memory, root
  I/O, active-link, pressure, frequency, thermal, fan, and GPU metrics;
- a three-second collector provides twelve instantaneous process rows only on
  the Processes page;
- a 15-second collector provides host, topology, package, service, socket,
  thermal, GPU, network, filesystem, and block-device inventory while open;
- battery remains a compact snapshot and routes future detailed power work to
  Control Centre / Power;
- the allowlisted Insights diagnostics route is visible;
- process sorting and selection, bounded procfs detail, private report
  generation, confirmed current-user SIGTERM/SIGKILL, and confirmed restart of
  currently failed user units are connected;
- system-unit restart and arbitrary shell execution remain excluded.

## Stage 8 — Advanced Insights

Goals:

- add manual/long-interval package and AUR update checks;
- derive health observations from successful source records;
- add a concise recent-action trail;
- link recommended actions to the appropriate safe surface;
- avoid alarm fatigue and duplicated messages.

Progress:

- the manual, cached package-discovery foundation is implemented under the
  Updates tab;
- official and AUR checks remain separate so the external AUR disclosure is
  explicit;
- a sixth Wiki route renders bounded local Markdown with category tabs,
  article navigation, tables, code blocks, and validated internal links;
- a central avatar manifest and shared widget replace per-surface text marks
  and support separate chibi and portrait assets for seven initial states;
- automatic schedules and installation are not connected.
- Briefing now derives maintenance state from successful cached checks instead
  of presenting a disconnected placeholder;
- Reports generates a mode-0600 local artifact, previews at most 80 non-empty
  redacted lines, and never uploads automatically.

## Stage 9 — Applications, Input, and Settings

Goals:

- finish remaining Control Centre sections;
- represent unsupported tray/background-app concepts honestly;
- add safe preferences for SenomyOS presentation and polling;
- keep settings separate from system-wide privileged configuration until a
  secure mechanism exists.

Progress:

- the Rail exposes a Windows-style overflow arrow and the transient flyout owns
  the single native StatusNotifier host;
- the Applications trigger opens the existing Control Centre on `apps`;
- Flameshot is the first registry-backed managed background application;
- its card distinguishes service, D-Bus, and tray evidence and exposes fixed
  capture, launcher, configuration, start, and confirmed-stop actions;
- the status collector runs only while Applications or the tray flyout is
  visible;
- arbitrary process enumeration and generic process termination remain outside
  this section.
- Settings writes a versioned mode-0600 user density preference outside
  packaged defaults and applies Auto, Standard, Compact, or Narrow immediately.

## Stage 10 — Hardening and responsive pass

Goals:

- test narrower and wider displays;
- remove monitor and resolution assumptions;
- test missing dependencies and disconnected hardware;
- verify focus, keyboard, tooltips, and click targets;
- inspect idle resource consumption;
- verify Eww logs and Hyprland errors;
- update documentation and runtime inventory.

Progress on the T480 reference system:

- standard and injected compact/narrow Rail modes passed visual inspection;
- missing UPower, audio, and NetworkManager paths emit truthful unavailable
  state, including zero-battery desktops without false low-charge warnings;
- all contextual windows open on the focused monitor through Eww `--screen`,
  so shared Yuck no longer embeds monitor `0`;
- Escape, X, trigger toggle, outside click, panel replacement, reload restore,
  idle subscribers, Eww logs, Hyprland errors, and tracked/live config sync
  were validated;
- fixed panel geometry remains an Eww 0.5/profile-stage limitation. Physical
  multi-monitor, portrait, disconnected-device, and non-T480 testing is still
  required before portability claims.

## Stage 11 — Hardware and form-factor profiles

Before Stage 11 broadens hardware support, the current shell must pass the
following locked Obsidian Rail completion program. This is a release gate, not
an optional backlog.

### Rail and Surface UX Freeze

1. Freeze one component-island Rail composition with transparent unused space,
   flat translucent fills, palette-aware edges, and one control rhythm.
2. Require every trigger to open, repeat-click close, cross-switch, outside
   dismiss, Escape dismiss, and X-close through the shared coordinator.
3. Require exactly one primary surface, at most one transient flyout, and one
   shared dismiss layer. No independent popup flag may bypass this invariant.
4. Normalize Volume, Tray, Network, Calendar, and Battery quick surfaces around
   shared geometry, padding, focus, close, responsive, and truthful-state rules.
5. Apply font, typography, palette, focus, and edge preferences to the Rail,
   Control Centre, Performance, Insights, and every flyout. Safety semantics
   remain fixed independently of decorative themes.

### Functional completion gates

- Control Centre sections must expose truthful ready, loading, empty,
  unavailable, warning, error, confirmation, running, success, and failure
  states where applicable.
- Performance metrics must identify source, freshness, units, unavailability,
  and retention period; process and service mutations remain confirmed and
  allowlisted.
- Insights Briefing, Timeline, Updates, Diagnostics, Console, Reports, and Wiki
  must each have a tested data contract and must not fabricate evidence.
- Persistent Rail sources should be event-driven. Expensive detailed collectors
  run only while their owning surface is visible.
- Trigger-to-visible latency is measured, with a 200ms target for cached
  flyouts and a documented reason for slower hardware-backed surfaces.

### Production acceptance gates

- static shell, JSON, Python, SCSS, Yuck, and whitespace validation;
- automated state-machine transition tests and collector fixture tests;
- screenshot comparisons for standard, compact, narrow, and touch profiles;
- restart, malformed-source, suspend/resume, and last-known-good recovery tests;
- keyboard, pointer, touch-target, tooltip, and visible-focus review;
- physical validation at multiple logical sizes and scale factors;
- measured idle CPU, memory, process, and wake-up cost;
- a clean-machine installation test before claiming portability.

The shell is considered complete only when these gates pass without a major
visual inconsistency, behavioral race, false state, or undocumented platform
limitation.

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
