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
starts one replacement daemon. It opens and verifies `main-bar`, then restores
the dismiss layer and remembered surface with responsive geometry before
restoring state. Raw `eww reload` is unsupported because Eww 0.5.0 may reset `defvar`
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
**Status:** Superseded by D030

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

## D026 — Use event-triggered authoritative workspace snapshots

**Date:** 2026-07-28
**Status:** Accepted

`workspaces.service` remains the single owner of workspace publication. Its
listener consumes Hyprland `.socket2.sock` events through `socat`, but treats
events only as invalidation signals. After a short debounce it queries fresh
Hyprland JSON and rebuilds the complete workspace/application snapshot instead
of trying to reconstruct state from incomplete event payloads.

Change detection compares normalized data without the observation timestamp.
The listener republishes cached state every 10 seconds for Eww recovery, takes
a full safety snapshot every 30 seconds, and exits for systemd to reconnect
when the event socket closes. An Eww `deflisten` must not duplicate this
systemd-owned lifecycle. Configured icon names are resolved through standard
XDG data locations and emitted as image paths, with a generic executable icon
fallback, so rendering does not depend on Eww theme-icon lookup behavior.

## D027 — Model volume as a transient flyout

**Date:** 2026-07-28
**Status:** Accepted

Immediate volume adjustment does not require opening the full Control Centre.
The bar audio control toggles one allowlisted transient flyout containing mute,
a 0–100 default-output slider, and a visible route to the Audio section.
`active_flyout` is separate from `active_surface`, but the coordinator enforces
that a transient flyout and a primary surface cannot overlap.

Transient flyouts are not restored after an Eww restart. Expensive or detailed
audio routing remains in the Control Centre rather than expanding the flyout.

## D028 — Use one non-consuming Escape dismissal path

**Date:** 2026-07-28
**Status:** Accepted

Hyprland owns a non-consuming bare Escape binding that invokes
`scripts/surface-state.sh dismiss`. The key event still reaches the focused
application. The coordinator closes an open transient flyout first, otherwise
the active primary surface, and finally reconciles stale known windows.

Future SenomyOS panels must register with the coordinator instead of adding
independent Escape bindings.

## D029 — Begin Performance with a read-only Cathedral Deck

**Date:** 2026-07-28
**Status:** Accepted

CPU/MEM/UP opens a broad separate Performance Dashboard. Its first stage uses
the shared Obsidian Rail tokens with Cathedral Deck's four-part hierarchy:
bounded metric history, one process table, system health, and a Senomy
diagnostics route.

Process data polls every three seconds only on its route. System and hardware
inventory polls every 15 seconds while Performance is open. Sorting, reports,
diagnostic task integration, and confirmed process/service actions remain
explicit later stages; no unrestricted shell or process mutation is exposed.

## D030 — Put the single native tray host in an overflow flyout

**Date:** 2026-07-28
**Status:** Accepted

The Obsidian Rail exposes one Windows-style overflow arrow instead of rendering
native StatusNotifier items inline. Opening it creates the only Eww `systray`
inside `tray-flyout`; repeated activation or Escape closes it. `tray` is an
allowlisted `active_flyout` value, so the tray cannot overlap the volume flyout
or a primary surface.

The Applications section remains the managed, descriptive view of allowlisted
background applications and does not instantiate another tray host. Live
validation confirmed that Flameshot stays active and re-registers its native
item after the transient host is closed and reopened.

## D031 — Retain a five-minute runtime metric history

**Date:** 2026-07-28
**Status:** Accepted

The persistent two-second system summary invokes
`scripts/performance-history.sh sample`, which forwards the current
`performance-live.sh` envelope and adds one aggregate point at most every five
seconds for CPU, memory, temperature, load, pressure, disk, network, and
optional GPU metrics. Points are pruned to a rolling 300-second window and
written atomically to a mode-0600 file under
`${XDG_RUNTIME_DIR}/senomyos`.

Performance reads this cache only while open. Closing, reopening, or rebuilding
the dashboard therefore does not reset its graph, while the cache remains
session-scoped and does not become permanent activity history.

## D032 — Own deterministic bar-control vectors

**Date:** 2026-07-28
**Status:** Accepted

Right-side bar controls use repository-owned SVGs on identical canvases,
rendered into fixed 16px image boxes inside 36px controls. This avoids both
Nerd Font glyph baseline differences and the installed Eww 0.5.0 build's
unreliable theme-icon painting. Native application icons remain owned by the
StatusNotifier tray and workspace/application icon resolvers.

## D033 — Prevent implicit Eww bootstrap during state transitions

**Date:** 2026-07-28
**Status:** Accepted

Ordinary `surface-state.sh` client calls pass `--no-daemonize` and run under a
three-second timeout. If Eww IPC disappears between the coordinator's initial
health check and a window command, the foreground fallback is terminated and
the transition fails instead of creating a second detached daemon.

Only the controlled reload path may auto-start Eww, after it has verified that
the old daemon stopped. This keeps one daemon as an invariant rather than a
best-effort startup convention.

## D034 — Separate deep performance from power policy

**Date:** 2026-07-28
**Status:** Accepted

The read-only Cathedral Deck uses six stable routes: Overview, CPU + GPU,
Memory, Storage, Network, and Processes. Current values come from synchronized
counter deltas, rate graphs disclose their dynamic scale, hardware fields are
capability-detected, and absent sources remain explicitly unavailable.

Performance retains only a compact power snapshot. Battery health, charge
thresholds, power profiles, policy, and settings belong to Control Centre /
Power. This keeps one authoritative settings surface and prevents duplicated or
contradictory controls.

## D035 — Float only the Flameshot utility launcher

**Date:** 2026-07-28
**Status:** Superseded by D038

Hyprland matches Flameshot's `flameshot` class together with the exact initial
title `Capture Launcher`, then floats and centers only that utility window. The
specific match prevents the launcher from entering the tiling tree and
resizing the active application when an Eww panel is open, without changing
the full-screen `flameshot gui` capture overlay.

Later live reproduction showed the capture overlay itself could race with
layer cleanup and briefly enter the tiling tree. D038 retains this launcher
rule while adding a separate exact capture-client rule.

## D036 — Recover the Hyprland workspace runtime at the listener boundary

**Date:** 2026-07-29
**Status:** Accepted

`scripts/workspaces.sh` must not depend solely on session variables imported
into the user service manager. It first validates any inherited
`HYPRLAND_INSTANCE_SIGNATURE` against `.socket2.sock`; otherwise it selects the
newest valid runtime from `hyprctl instances -j` and exports that instance and
Wayland socket for its own child commands.

`workspaces.service` retries failures after two seconds with start limiting
disabled. Hyprland login still imports its environment, but also clears an old
failed state before restarting the service. This makes runtime discovery the
listener's responsibility and prevents an early login race from permanently
leaving Eww workspace state at `loading`.

## D037 — Pair every contextual surface with one shared dismiss layer

**Date:** 2026-07-29
**Status:** Accepted

Every Control Centre, Performance, Insights, volume, or tray activation opens
one transparent `surface-dismiss` window. It occupies the compositor's usable
work area at `fg`, below the contextual `overlay` window and outside the
exclusive main bar. Pointer clicks on that layer invoke
`surface-state.sh dismiss`.

Outside click, the non-consuming Hyprland Escape binding, repeated triggers,
close controls, and cross-trigger switching therefore converge on one
serialized coordinator. Individual panels must not add independent backdrop
flags or dismissal state.

## D038 — Keep contextual layers non-focusable and dismiss before capture

**Date:** 2026-07-29
**Status:** Accepted

SenomyOS context windows use `:focusable false`. Pointer dismissal is owned by
the shared backdrop and Escape is owned by Hyprland, so tray, volume, Control
Centre, Performance, and Insights do not need exclusive GTK layer-shell
keyboard focus.

Live reproduction showed that an exclusive Eww layer changes
`flameshot gui` from a fullscreen capture client into a normal tiled client.
The single screenshot entry point therefore calls the surface coordinator's
`dismiss`, waits briefly for one compositor repaint, ensures the existing
Flameshot user service is active, and then launches capture. Hyprland uses an
exact class-and-initial-title match to float the capture client before forcing
fullscreen, preventing it from resizing the underlying tiling tree.

## D039 — Resolve every Senomy avatar through one manifest and domain state

**Date:** 2026-07-29
**Status:** Accepted

`data/senomy-avatars.json` owns the state vocabulary and chibi/portrait asset
paths. `scripts/senomy-avatar.sh` validates the manifest, and one
`senomy-avatar` widget renders a centrally resolved domain state. The manual
`chibi_state` controls only the ambient domain; battery, performance, and
Insights derive independent states from their own bounded evidence.

Adding a state or replacing final artwork must not require editing each
surface. Automatic mood selection may be added later, but verified warning
conditions must outrank decorative activity and no state may fabricate system
evidence.

This permits simultaneous moods without duplicating asset paths or selection
rules in individual panels. A low-battery warning is local to battery
contexts rather than forcing every Senomy image into the same state.

## D040 — Build the Insights Wiki from bounded local Markdown

**Date:** 2026-07-29
**Status:** Accepted

Wiki is the sixth stable Senomy Insights route. Authors maintain ordinary
Markdown below `wiki/`; `scripts/wiki-status.py` converts a restricted,
bounded subset into structured JSON only while the route is visible.

The UI renders native headings, paragraphs, lists, quotes, code, tables,
category tabs, article indexes, and validated internal links. It does not
evaluate HTML or Markdown as UI code, execute fenced code, follow symlinks, or
launch external links.

## D041 — Acknowledge Eww transitions by observed postcondition

**Date:** 2026-07-29
**Status:** Accepted

Eww 0.5 can return `Resource temporarily unavailable` to a client while the
application thread is constructing a large window, including after the
requested mutation already happened. Treating the response alone as truth can
leave an open window paired with stale state.

The surface coordinator retries read-only queries only. It does not replay
open, close, or update blindly. Instead it verifies the requested window and
state postconditions under bounded waits, accepts an errored mutation only
when those postconditions are true, and otherwise preserves the failure.
Repeated-toggle decisions use the verified target window as well as shared
state.

## D042 — Treat the installed Eww build by source provenance

**Date:** 2026-07-30
**Status:** Accepted

The installed Arch package is `eww 0.6.0-1`, its files pass `pacman -Qkk`, and
its binary was built from upstream tag `v0.6.0` at commit
`d87c2fdbfdc012e76d229e4e9ea3325bc0f23e89`. That upstream tag retains
`version = "0.5.0"` in `crates/eww/Cargo.toml`, so `eww --version` reports
0.5.0 despite the v0.6.0 source provenance.

SenomyOS records both values and does not reinstall or locally patch an intact
package merely to alter its self-reported version string.

## D043 — Keep widget command timeouts above bounded surface transitions

**Date:** 2026-07-30
**Status:** Accepted

Eww applies a widget's `:timeout` to the command launched by `:onclick`; it is
not a visual delay. Large contextual windows can require approximately two
seconds to construct on the reference hardware. A two-second widget timeout
therefore killed `surface-state.sh` during a valid transition, leaving
`active_surface` detached from the real window set and making panels appear to
close themselves.

All controls that open, switch, close, or dismiss a contextual surface use an
eight-second command timeout. Fast transitions still return immediately. The
larger value is only a failure bound and must remain above the coordinator's
normal verified transition time. The shared dismiss eventbox also remains
insensitive until a surface or flyout has been published as active.

## D044 — Weight battery aggregates and gate TLP plans by capability

**Date:** 2026-07-30
**Status:** Accepted

Detailed Power combines UPower interpretation, kernel power-supply counters,
and optional TLP runtime policy. Combined percentage and health are weighted
from Wh values rather than averaging differently sized pack percentages.
Cycles, temperature, current, estimates, thresholds, and policy fields are
shown only when their source exists.

The only mutable first-stage power operation is an allowlisted TLP profile
change: `power-saver`, `balanced`, or `performance`. Selection opens a visible
impact confirmation and execution delegates to `pkexec`. Controls remain
disabled when TLP, pkexec, or a graphical polkit authentication agent is
unavailable. Eww never handles a password or constructs an arbitrary privileged
command.

The reference session uses the already-installed `polkit-gnome` agent from
`/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1`. Hyprland launches
that absolute path once per login. Runtime capability requires both an
installed executable and a currently registered agent process.

## D045 — Separate rich connectivity telemetry from disruptive actions

**Date:** 2026-07-30
**Status:** Accepted

Network and Audio use normalized schema-version-2 collectors and the same
operational-detail standard as Power. Collectors remain read-only and run only
while their surfaces need them. Separate exact-vocabulary helpers validate
current interfaces, endpoints, and ports before every mutation.

Audio gain, mute, and valid route selection are immediate. Network radio
disable and active-interface disconnect require visible impact confirmation.
Wi-Fi scans are manual, and no collector or Eww variable reads saved
credentials.

## D046 — Delegate Wi-Fi secrets to NetworkManager

**Date:** 2026-07-30
**Status:** Accepted

The Control Centre owns network discovery and orchestration, not credential
storage. Nearby access points are grouped by SSID and joined to saved profiles
using non-secret metadata. Existing profiles connect by validated UUID.

Unknown secured networks launch `nmcli --ask` in Kitty, and hidden/profile
configuration launches `nm-connection-editor`. Eww never presents a password
field and never transports a secret through widget state, interpolation, logs,
or collector JSON. Forget, disconnect, and radio-disable operations remain
confirmation-gated; all identifiers are revalidated immediately before an
action.

## D047 — Arm outside-click after the opening pointer release

**Date:** 2026-07-30
**Status:** Accepted

Opening the shared dismiss window under an in-progress pointer click can let
the release event hit that new full-screen eventbox and immediately close the
context that was just opened. `dismiss_armed` therefore remains false while
the backdrop and target are created. It becomes true only after the target
window/state postcondition and a short pointer-release guard.

Heavy GTK trees can also make Eww temporarily return `EAGAIN` before a new
window is queryable. Fast transitions now wait for bounded authoritative
open/closed postconditions, retry idempotent state updates, and fall back to
the reconciled close path. Network, Audio, and Power each passed repeated
open-hold-dismiss validation.

## D048 — Distinguish Wi-Fi association from internet access

**Date:** 2026-07-30
**Status:** Accepted

An associated AP with DHCP and a default route is not necessarily usable
internet. Network presents NetworkManager connectivity as full internet,
captive portal, limited, link only, or offline. Only `full` is labelled online.

Open hotspots connect without Wi-Fi credentials. If global connectivity is
not verified, Control Centre explains that distinction and offers a captive
portal browser entry. Unknown secured APs continue to authenticate through
`nmcli --ask`; cached BSSID and security state are revalidated immediately
before either connection path.

## D049 — Keep Performance intervention bounded and confirmation-gated

**Date:** 2026-07-31
**Status:** Accepted

The Performance Processes page may inspect one selected PID using bounded
procfs fields, sort its twelve-row sample, and generate a private mode-0600
runtime report. It is not an arbitrary task manager or shell.

Only current-user processes may receive SIGTERM or SIGKILL, and only currently
failed user units may be restarted. Each operation requires a visible second
confirmation click and the helper revalidates the target at execution time.
System services remain read-only because restarting them crosses the
administrative boundary.

## D050 — Drive persistent Rail status from cheap event streams

**Date:** 2026-07-31
**Status:** Accepted

The persistent Audio and Network marks subscribe to PipeWire/Pulse and
NetworkManager events. They do not continuously execute the detailed Audio or
Network collectors. A mute transition was visible in Eww in 76ms on the
reference system. Detailed inventories remain scoped to their flyout or
Control Centre section.

Rail density is capability-derived from focused-monitor logical width:
standard at 1500px and above, compact below 1500px, and narrow below 1100px.
This changes presentation only; it does not encode monitor names or hardware
models.

## D051 — Require explicit success from surface postconditions

**Date:** 2026-07-31
**Status:** Accepted

Window-open and window-closed verification must return explicit success after
all forbidden windows are absent. Returning the final negative membership
test falsely treated a correct state as failure, exhausted forty retries, and
forced reconciliation. Correcting the return contract reduced volume open
from 9979ms to 814ms and close from 8569ms to 264ms in live validation.

## D052 — Select monitors at Eww open time and verify asynchronous close

**Date:** 2026-07-31
**Status:** Accepted

Eww 0.5 window-definition properties cannot consume runtime poll variables,
but `eww open --screen` accepts a discovered monitor. Shared windows therefore
omit `:monitor 0`; startup, reload restoration, and the surface coordinator
open them on Hyprland's focused monitor with monitor 0 only as an unavailable-
source fallback.

An IPC-successful `eww close` does not guarantee GTK has destroyed the window.
Escape/outside dismissal always verifies the closed-window postcondition and
falls back to full reconciliation. Five consecutive Control Centre Escape
cycles ended with state `none` and only `main-bar` open.

## D053 — Separate shell activity from operating-system journals

**Date:** 2026-07-31
**Status:** Accepted

Insights Timeline labels user-session, system, kernel, and native Eww logs by
their actual provenance. The former User source is called Session because a
user-level systemd journal describes application and service messages, not all
human activity.

Senomy interactions use a separate private, bounded structured journal. Only
allowlisted surface transitions, navigation choices, and explicit shell actions
are recorded. Keystrokes, file contents, browsing, credentials, and arbitrary
command text are outside its contract. An empty native Eww log is reported as
empty rather than silently implying that daemon logging is operational.

## D054 — Keep unrestricted shells in a real PTY

**Date:** 2026-08-01
**Status:** Accepted

Senomy Insights includes a Console cockpit, but Eww does not impersonate a
terminal emulator. Its text-entry callbacks execute command strings and do not
provide a PTY, terminal escape-sequence engine, job control, signals, secure
sudo prompts, or full-screen application support. Interpolating free-form text
there would also create a command-injection boundary.

Console therefore offers fixed, bounded, read-only commands in-panel and
launches unrestricted Bash, Zsh, Fish, or PowerShell sessions in Kitty only
when the executable is detected. Kitty supplies the real PTY. Missing shells
remain visibly unavailable and are never installed automatically.

## D055 — Make evidence reports profile-based and persistent

**Date:** 2026-08-01
**Status:** Accepted

Reports are immutable mode-0600 text artifacts with JSON sidecar manifests in
the user state directory. Overview, Performance, Network, Power, and Full
profiles map to fixed read-only collectors. The manifest records the profile,
sections, timestamp, size, line count, path, and privacy policy.

The panel retains a bounded local manifest history, previews the latest
artifact, and confirmation-gates deletion. Reports exclude credentials,
unrestricted journals, saved network secrets, and environment dumps, and they
are never uploaded automatically.

## D056 — Treat Bluetooth pairing as a confirmed BlueZ operation

**Date:** 2026-08-01
**Status:** Accepted

Device Management uses BlueZ through `bluetoothctl` for capability discovery,
bounded scanning, pairing, trust, connection, disconnection, and removal. The
UI never treats a cached device as connected without reading BlueZ's current
`Connected` property.

State-changing targets must pass strict MAC-address validation. Pair,
disconnect, forget, and controller power-off require a visible confirmation.
The non-interactive pairing path uses `NoInputNoOutput`, appropriate for
JustWorks devices such as many earbuds. Devices requiring a PIN, passkey, or
keyboard confirmation fail with guidance rather than weakening authentication.

## D057 — Size surfaces from focused-monitor logical geometry

**Date:** 2026-08-01
**Status:** Accepted

Insights preserves its approved 750 by 700 desktop proportion. Control Centre
uses 888 by 700 so every route shares the Power route's required width instead
of resizing after a section switch. Both are capped from the focused monitor's
logical dimensions. Performance uses a bounded percentage of the same work
area. Narrow profiles stack multi-column controls and metric cards, remove
fixed text widths, and retain readable text and touch targets rather than
uniformly shrinking the interface. Compact flyouts use the same runtime size
path, with Volume becoming a vertical control stack below 600 logical pixels.

This is responsive reflow, not universal device support. Monitor names,
resolutions, and scale factors remain runtime observations rather than portable
defaults.

## D058 — Persist validated appearance tokens, not arbitrary CSS

**Date:** 2026-08-01
**Status:** Accepted

Control Centre Appearance writes a small validated preference schema for font
family, global and category text scales, accent, gradient strength, and rail
density. Only allowlisted values become root classes on Control Centre,
Insights, Performance, and compact flyouts. Missing fonts are detected and
disabled instead of silently substituted.

The advanced action opens GTK Inspector because Eww uses GTK CSS, not a browser
DOM or browser media-query engine. Arbitrary CSS text is not accepted from an
Eww input callback; source editing remains the deliberate advanced path.

## D059 — Fail closed before replacing the live Eww daemon

**Date:** 2026-08-01
**Status:** Accepted

The surface coordinator compiles SCSS and asks a temporary windowless daemon
at a copied config path to parse the complete configuration before it replaces
the live daemon. A failed preflight leaves the current bar and its window graph
untouched. The parser probe must define all seven required windows and must be
fully terminated afterward. After a successful restart and state restoration,
the validated root configuration and compiled CSS are copied with mode 0600
into the SenomyOS recovery state directory as the last-known-good shell
snapshot.

A missing daemon may be started deliberately, but reload code must not blindly
kill a healthy shell before proving that replacement definitions include the
main bar.

## D060 — Separate rail telemetry from dashboard history

**Date:** 2026-08-01
**Status:** Accepted

The always-visible rail reads a cheap procfs collector for CPU, memory, uptime,
load, and logical-thread count. A bounded ten-second performance sampler stays
active while the shell runs so closing the Dashboard does not create gaps or
reset its five-minute graphs. Dashboard-specific inventory, process, and
detail collectors still run only while their surface or section is visible.

Event listeners remain the preferred path for workspaces, network summary, and
audio summary. Recovery polls may exist, but they must not become the primary
feedback mechanism for user actions.

## D061 — Keep operation feedback separate from observed system state

**Date:** 2026-08-01
**Status:** Accepted

Network, discrete audio, power-profile, process, application, and brightness
mutations publish private, atomic operation records
with `running`, `succeeded`, or `failed` state and sanitized messages. They also
request an immediate authoritative status refresh. The panel may say that a
request completed, but connected, active, muted, routed, and online indicators
come only from NetworkManager or PipeWire observations.

Operation records never contain passwords, saved secrets, SSIDs, BSSIDs,
profile UUIDs, endpoint IDs, process command lines, or Bluetooth addresses.
Polling remains as self-healing fallback when an immediate Eww update cannot
be delivered.

## D062 — Treat phone width as a capability, not a smaller desktop

**Date:** 2026-08-01
**Status:** Accepted

Below 480 logical pixels the rail preserves the active workspace and primary
system entry points while collapsing workspace application icons, secondary
telemetry, battery percentage copy, and the separate Applications button.
Applications remains reachable from the tray flyout. Control Centre and
Insights move their vertical navigation into horizontally scrollable tab
strips above content instead of shrinking text and touch targets.

The `phone` capability is derived from focused-monitor logical width and is
validated independently from user-selected density. It does not claim phone
hardware support; modem, rotation, on-screen keyboard, suspend, and touch
validation remain separate platform gates.

## D063 — Report degraded services without inventing usable devices

**Date:** 2026-08-01
**Status:** Accepted

A running service is not equivalent to a working hardware path. Audio marks
itself degraded when ALSA hardware exists but PipeWire exposes only
`auto_null`, and explains that the dummy sink is not physical output. Endpoint,
default-route, port, and hardware-profile controls are rendered only from
objects and profiles returned by PipeWire.

## D064 — Verify and stage recovery; never overwrite the live shell automatically

**Date:** 2026-08-01
**Status:** Accepted

After a guarded reload, SenomyOS archives the complete Eww runtime definition:
root Yuck and SCSS, windows, widgets, sections, scripts, data, assets, wiki,
user-service units, and the tracked Hyprland mirror. Generated Python cache is
excluded. The archive and its SHA-256 checksum are private mode-0600 files in
the user state directory.

Recovery tooling may verify, list, or extract that archive only into a new,
previously absent staging directory. It must not automatically overwrite the
live configuration. Promotion remains a deliberate, reviewable operation so a
valid but older snapshot cannot silently discard newer user work.

## D065 — Treat runtime stylesheet and window readiness as release gates

**Date:** 2026-08-01
**Status:** Accepted

Successful Sass compilation and an Eww IPC ping do not prove a usable shell.
GTK may reject values accepted by Sass, and an Eww daemon can remain reachable
without loaded window definitions. SenomyOS therefore statically rejects CSS
custom-property interpolation unsupported by GTK 3 and nullable responsive
ternaries, and validates the actual themed surfaces with screenshots.

Session startup succeeds only after IPC responds, `main-bar` exists in
`list-windows`, and exactly one `main-bar` appears in `active-windows`.

## D066 — Verify Bluetooth transitions against BlueZ

**Date:** 2026-08-02
**Status:** Accepted

Bluetooth action exit status is not connection truth. Pairing performs a
bounded power, pairable, pair, trust, and connect sequence and only succeeds
after `bluetoothctl info` confirms the expected fields. Connect performs one
bounded discovery retry for sleeping accessories. Device ordering is stable by
active operation, connection, pairing, name, and address; fluctuating RSSI must
not move controls under the pointer.

## D067 — Keep benchmarks bounded, confirmed, and reproducible

**Date:** 2026-08-02
**Status:** Accepted

The Performance benchmark suite requires explicit confirmation, has a visible
stop path, and offers finite Quick and Standard profiles. It caps CPU workers,
uses at most one private 512 MiB scratch file, refuses unsafe low-power or
low-memory starts, watches thermal evidence when sensors are available, and
performs no network, privileged, package-installing, or indefinite stress work.
Progress and logs are retained independently of the window. Markdown is the
canonical report; a dependency-free renderer creates a private PDF derivative
and SHA-256 checksums. Reports exclude hardware serials, network addresses,
credentials, environment dumps, and unrestricted logs.

## D068 — Retain notification history through a narrow private SwayNC hook

**Date:** 2026-08-10
**Status:** Accepted

Senomy Insights owns a Notifications route backed by SwayNotificationCenter's
documented receive-script environment. The hook records a bounded sanitized
copy of visible notification metadata after a popup disappears without
replacing SwayNC or changing popup policy. Storage is local and mode 0600;
actions and opaque hints are excluded; clearing requires confirmation.

## D069 — Pre-size animated avatars at the catalog boundary

**Date:** 2026-08-10
**Status:** Accepted

Avatar sources may be SVG, PNG, JPG/JPEG, or GIF. Eww 0.5 can animate GIFs but
does not apply widget dimensions to them reliably, so the avatar catalog
validates size, dimensions, frame count, MIME, and containment, then produces
private context-sized animated variants. Surfaces consume only resolved
catalog paths and never add format-specific logic.

## D070 — Make shell recovery enforce one daemon and one Rail

**Date:** 2026-08-10
**Status:** Accepted

Both session startup and the manual recovery command verify exactly one
config-matched Eww daemon and one `main-bar`. Recovery captures bounded private
incident evidence, preflights shell/SCSS/JSON/avatar contracts, closes the
owned window set, stops only exact config-matched daemons, restores one Rail,
and resynchronizes the workspace listener. Force-stop is a bounded fallback
only after graceful termination fails.

## D071 — Never let an ordinary Eww client bootstrap the shell

**Date:** 2026-08-10
**Status:** Accepted

Every ordinary Eww query, update, open, close, and kill client uses
`--no-daemonize`. Only `scripts/start-eww.sh` may deliberately create the
daemon, after parser preflight and exact process cleanup. Startup and recovery
count every Eww process whose command line names the exact configuration path,
not only commands ending in `daemon`: Eww 0.5 can retain an `open` client as a
second GTK/layer owner after an IPC failure. Hyprland's layer tree is the
authoritative verification source when Eww IPC and visible windows disagree.

## D072 — Keep Appearance distinct and share one surface masthead

**Date:** 2026-08-13
**Status:** Accepted

Appearance is the tenth stable Control Centre route. It remains separate from
Settings so validated presentation controls can grow without mixing decorative
preferences with recovery and runtime maintenance. The route does not permit
arbitrary CSS.

Control Centre, Performance, and Senomy Insights use one shared hero-header
component. Insights defines the identity scale, title hierarchy, description,
evidence-chip row, close target, spacing, and responsive reductions. Surfaces
provide only their truthful copy and status. Control Centre has
one 888px desktop width across every route; section content cannot resize the
window in place.

## D073 — Give Senomy one Rail identity and one ambient companion

**Date:** 2026-08-15
**Status:** Accepted

The Obsidian Rail renders one Senomy avatar button immediately beside a
separate Insights dialogue button. They remain visually joined so the avatar
reads as the dialogue profile image, while preserving two honest targets: the
avatar opens the companion and the dialogue opens Insights. Primary mastheads
and content cards no longer reserve duplicate character artwork; D072's shared
typographic hierarchy, evidence chips, close target, and stable geometry remain
in force.

The companion is an ambient overlay rather than a fifth primary surface. One
window has `closed`, `expanded`, and `compact` modes, snaps to either edge of
the focused monitor, stays non-exclusive and non-focusable, and may coexist
with Control Centre, Performance, or Insights. It provides visible edge,
session-pin, minimize/expand, and close controls. An unpinned expanded session
may collapse after a bounded quiet interval; pinning is session-only and stale
timers cannot mutate a later session.

Automatic character reaction is evidence-driven. A verified UPower low-battery
condition takes priority, active MPRIS playback through `playerctl` selects the
music state next, and the ordinary browsing identity is the fallback. The
avatar catalog owns the real bounded artwork and cached GIF variants; panel
code does not hard-code image paths or invent activity.

## D074 — Use Command Lens for Rofi and keep Thunar a native file workspace

**Date:** 2026-08-15
**Status:** Accepted

The first generated Rofi/Thunar concept, Command Lens, is the selected visual
direction. Rofi is a temporary upper-centre launcher with stable Applications,
Files, Windows, and Actions scopes. Thunar is the persistent file workspace
behind it, using a conventional Places sidebar, breadcrumb/location controls,
detailed rows, and an optional preview/metadata inspector.

Rofi may combine native application/window modes with project-owned bounded
file search and an allowlisted action registry. It is not an arbitrary shell or
replacement file manager. Thunar retains native file operations, dialogs,
menus, tabs, split view, and keyboard behavior; custom actions are small,
validated integrations rather than a dashboard embedded in the file manager.

Rofi themes and GTK 3 themes share semantic tokens but remain separately
generated because they have different styling systems. A global GTK theme can
affect applications beyond Thunar and therefore requires wider QA. Repository
sources are deployed deliberately to live user configuration with backup and
rollback. The current `Super+R` Wofi binding is not changed until the Rofi
prototype has passed manual and visual validation.
