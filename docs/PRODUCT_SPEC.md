# SenomyOS Product Specification

## Product intent

SenomyOS should feel like a coherent desktop environment rather than a
collection of Eww widgets. Its interface is compact, dark, technical, and
quiet. System information should be understandable without pretending the
desktop has capabilities or knowledge that are not implemented.

The first target is the user's 1920x1080 ThinkPad display, but layout decisions
must adapt to narrower widths and other monitor configurations.

## Product destination

SenomyOS should ultimately be deployable as an Arch-based system, not only
copied as personal configuration files.

The product includes:

- the base operating-system package selection;
- Hyprland, Eww, services, fonts, and supporting commands;
- SenomyOS configuration and assets;
- hardware and form-factor detection or profiles;
- installation and first-boot setup;
- update, rollback, diagnostics, and recovery guidance;
- a bootable installation or recovery path.

The deployment experience should minimize machine-specific editing. Unsupported
hardware must be reported plainly rather than hidden behind broken UI.

## Supported interaction and form factors

SenomyOS is designed for:

- keyboard and mouse;
- touchpads and pointing sticks;
- touchscreen laptops and convertibles;
- mini PCs and desktop monitors;
- landscape and portrait work areas;
- experimental tablets and phone-sized devices where mainline Linux,
  Hyprland, Eww, and device drivers are viable.

Phone-sized support is not a promise that every Android phone can run SenomyOS.
Bootloader, kernel, modem, GPU, power-management, sensor, and input support vary
by device. Compatibility must be expressed in tested tiers.

All primary actions need a visible click/touch path and a keyboard path where
GTK permits. Gestures may enhance an action but cannot be the only way to
perform it.

## Primary surfaces

### 1. Main bar

The bar is the persistent navigation and status layer.

Left group:

- stable Hyprland workspace indicators;
- one Senomy avatar button that opens the companion;
- an adjacent Senomy Insights dialogue button. The avatar and dialogue are
  separate targets but read as one profile-and-message identity unit.

Middle group:

- CPU usage;
- memory usage;
- uptime;
- the entire telemetry group acts as the Performance Dashboard trigger.

Right group:

- applications/background activity;
- network;
- audio;
- input;
- power and dual-battery state;
- calendar/time;
- Device Management;
- settings where a separate entry remains useful.

The clock uses two compact rows: local time above a short local date. Clicking
it opens Calendar. Clicking the dual-battery control opens Power. Both controls
follow the shared repeated-click-to-close and switch-in-place behavior.

The bar must prioritize scanning and clickability over showing every possible
metric. On narrower displays, secondary words disappear before essential
status and controls.

### Companion overlay (non-primary)

The Rail avatar opens one ambient Senomy companion. It is not a fifth primary
surface and does not replace Senomy Insights.

- **Expanded:** a large edge sidecar with the current character state,
  observation, evidence source, and a route into Insights.
- **Compact:** a mostly transparent avatar form with a bounded observation
  strip; it keeps the character visible without permanently consuming a panel.
- **Closed:** no companion window is mapped; the Rail avatar remains the
  persistent entry point.

The overlay snaps to the left or right edge of the focused monitor instead of
pretending to be a freely draggable desktop window. It never reserves work
area, creates a full-screen backdrop, or participates in primary-surface
mutual exclusion. Minimize, close, edge-switch, and session-pin controls remain
visible. An unpinned expanded session may collapse after a bounded quiet
period; pinning suppresses that collapse for the current session only.

Companion reactions must come from bounded, local, truthful sources. The first
implementation prioritizes verified low-battery evidence from UPower, then an
actively playing MPRIS session exposed by `playerctl`, then the normal Senomy
briefing state. Missing media metadata is shown as unavailable, never inferred.

### 2. Unified Control Centre

The Control Centre is a compact contextual panel anchored above the bar. A
bar control opens it directly on the matching section. Selecting another
control switches the existing panel instead of opening another window.

Sections:

- Overview
- Network
- Audio
- Power
- Calendar
- Input
- Device Management
- Applications
- Appearance
- Settings

There is no Performance section. Performance has its own expanded dashboard.

Device Management is the physical and logical connection inventory. Depending
on available tools, it may include:

- monitors and display state;
- audio outputs, inputs, headphones, and headsets;
- keyboards, mice, trackpads, and layouts;
- batteries and power devices;
- network interfaces;
- Bluetooth devices when an optional safe source is available.

Unavailable sources must show an honest unavailable or planned state.

Appearance remains a distinct Control Centre route because it owns the growing
set of validated shell-presentation controls: typography, density, accent,
edge treatment, and future bounded visual preferences. Settings remains the
runtime, maintenance, and general shell-control route. Neither accepts
arbitrary CSS or privileged system configuration.

### 3. Performance Dashboard

The Performance Dashboard is a separate large surface inspired by the
Cathedral Deck concept. It opens when the CPU/MEM/UP telemetry area is clicked.

Its purpose is investigation and controlled intervention:

- live CPU, memory, temperature, disk, network, and battery metrics;
- process list, sorting, filtering, and detail inspection;
- service and process health;
- hardware observations;
- generated diagnostic summaries and reports;
- an allowlisted mini console for common diagnostic commands;
- graceful terminate, restart, or force-kill flows where appropriate;
- troubleshooting guidance based only on collected evidence.

The dashboard must not expose a general shell through Eww. Its mini console is
a curated task runner with visible commands, bounded arguments, captured
output, and clear execution state.

Destructive or disruptive actions require a confirmation view that states:

- the exact target;
- the exact action;
- likely impact;
- whether the action can be reversed;
- the result after execution.

Terminate should prefer `SIGTERM`. Force-kill with `SIGKILL` is a separate,
more strongly confirmed action. Restart is offered only when the system knows
how the target is managed.

### 4. Senomy Insights

Senomy Insights is a first-class surface, not a secondary feature and not a
generic chat window. It opens from the Senomy mascot/message area.

Its job is to provide an evidence-based system briefing:

- package and AUR update availability;
- outdated applications;
- recent meaningful system actions;
- battery and charging observations;
- hardware and performance observations;
- unusual resource use;
- maintenance and security notices;
- clear recommended actions.

Every item has a source and state:

- **Informational:** useful context with no action needed.
- **Recommended:** a low-risk action may improve the system.
- **Warning:** something deserves attention soon.
- **Critical:** a verified condition needs prompt attention.
- **Unavailable:** the required source or command is missing.
- **Planned:** the feature is designed but not implemented.

Insights must never fabricate a diagnosis, update count, command result, or
hardware condition. A missing source is a visible state, not a reason to invent
content.

Insights uses eight stable sections:

- **Briefing:** prioritized observations, evidence, freshness, and recommended
  navigation;
- **Notifications:** a bounded, private local history of notifications already
  received by SwayNotificationCenter, retained after transient popups close,
  with explicit clearing and privacy state;
- **Timeline:** bounded, filtered system, application, shell, and SenomyOS
  events;
- **Updates:** successful package checks, source, age, review, and confirmed
  installation flow;
- **Diagnostics:** terminal-inspired allowlisted tasks with command preview and
  bounded output, plus a path to a real terminal for arbitrary work;
- **Console:** detected shell inventory, a bounded read-only command palette,
  and launch into a real Kitty PTY for unrestricted Bash, Zsh, Fish, or
  PowerShell work when installed;
- **Reports:** selectable Overview, Performance, Network, Power, and Full
  evidence profiles with manifests, previews, local history, and confirmed
  deletion;
- **Wiki:** a local Markdown-maintained knowledge base with category tabs,
  article navigation, bounded rendering, and validated internal article links.

Notifications stores only bounded application, title, body, urgency, category,
desktop-entry, identifier, and receive-time fields. It excludes notification
actions and hints, never uploads automatically, uses private local storage, and
requires confirmation before clearing. Timeline does not silently record
unrestricted user activity. Diagnostics and Console do not interpolate
free-form Eww text into shell commands or expose direct first-click `sudo`
execution. Unrestricted work runs in a real terminal PTY. Wiki does not
execute Markdown, scripts, embedded HTML, or external links.

## Shared interaction model

One primary surface is active at a time:

```text
none | control | performance | insights
```

Interaction rules:

- clicking a closed control opens the Control Centre on that section;
- clicking a different control switches the open section in place;
- clicking the active control closes the Control Centre;
- clicking CPU/MEM/UP opens or closes the Performance Dashboard;
- clicking the Insights dialogue opens or closes Insights;
- clicking the adjacent avatar independently opens or closes the companion;
- the companion may coexist with one primary surface and does not affect
  `active_surface`;
- opening any primary surface closes the previous one;
- every surface has a clear close action;
- a non-consuming compositor Escape binding closes every active SenomyOS
  surface or flyout while preserving Escape for the focused application;
- destructive actions open confirmation state rather than executing directly.

## Failure and empty states

The bar must remain operational if one subsystem fails.

Each data-backed component distinguishes:

- loading;
- ready;
- empty;
- unavailable dependency;
- disconnected hardware;
- malformed output;
- command failure;
- stale data.

Errors should be short in the bar and more descriptive inside the relevant
surface.

## Launcher and file workspace

SenomyOS uses the approved Command Lens direction for its application launcher
and file workflow:

- Rofi is a temporary, focused command surface for Applications, Files,
  Windows, and allowlisted Actions;
- Thunar remains the persistent GTK file workspace for navigation, preview,
  organization, native file operations, and small validated custom actions;
- selecting a directory in Command Lens hands the task to Thunar rather than
  reproducing file-management controls inside Rofi;
- Rofi does not expose unrestricted shell execution, and destructive system
  actions route to confirmation instead of executing on first selection;
- bounded file search excludes sensitive and expensive roots by default and
  treats every returned path as data;
- both tools share SenomyOS semantic tokens while keeping their independent
  Rasi and GTK configuration models.

The current Wofi binding is replaced only after a staged Rofi prototype passes
functional and visual validation. GTK styling is reviewed across affected GTK
applications before it becomes a global user preference. Full design and
deployment requirements live in `docs/LAUNCHER_FILE_MANAGER.md`.

## Accessibility

- Keep visible text comfortably readable at laptop viewing distance.
- Use at least 36x36 logical click targets in pointer-dense mode and at least
  44x44 in touch-oriented mode.
- Give icon-only controls tooltips or accessible labels.
- Do not rely on colour alone for active, warning, or disabled state.
- Maintain visible keyboard focus where GTK provides it.
- Keep semantic status language calm and direct.
- Avoid motion that does not explain a state transition.
- Keep controls reachable and panels inside safe work areas in portrait and
  landscape orientations.
- Do not depend on hover for essential information on touchscreen devices.
