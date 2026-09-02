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
prototype has passed manual and visual validation. That gate later passed;
activation is recorded in D080.

## D075 — Deploy user configuration through recorded transactions

**Date:** 2026-08-16
**Status:** Accepted

The live Eww repository is the development source and the source of truth for
SenomyOS configuration deployed elsewhere. Developers do not maintain separate
editable copies under each application's live configuration directory.

A versioned manifest allowlists every component, repository source, target
root, relative destination, strategy, and mode. User apply operations show a
plan, require confirmation, back up every affected target before mutation,
write a private prepared receipt, install complete files through an atomic
rename, and verify content and permissions. Rollback restores the recorded
file or recorded absence and refuses to overwrite unrecorded drift.

The first deployer supports only complete SenomyOS-owned regular files inside
allowlisted user roots. It does not replace user-owned Thunar XML, deploy
directory trees, reload applications, or write privileged locations. Thunar
requires deterministic merge semantics; GTK requires isolated and cross-app
QA. SDDM now uses a separate privileged transaction and recovery boundary;
Plymouth, initramfs, and GRUB still require boot-specific recovery work.

## D076 — Bound Command Lens providers and keep activation data-only

**Date:** 2026-08-16
**Status:** Accepted

The first Command Lens uses Rofi's native `drun` and `window` modes and exactly
two project-owned script providers. Files mode searches a finite set of
relative roots that resolve beneath the real user home. Root count, traversal
depth, per-root time, and result count are bounded; hidden paths and
cross-filesystem traversal are excluded. The original path travels through
Rofi's opaque `info` field, is resolved and checked again at activation, and
is passed as one quoted argument to GIO or the scoped file-workspace wrapper.
Result text is never shell syntax.

Actions mode is a finite mapping from opaque IDs to existing SenomyOS surface,
capture, and file-workspace entry points. It rejects custom input and does not
offer direct logout, reboot, shutdown, recovery restart, or arbitrary command
execution. Disruptive actions may be added only through a visible confirmation
surface.

The Rofi config, theme, wrapper, and adapters are complete-file user deployment
entries with isolated parser and hostile-path fixtures. Deployment, manual
visual QA, and the later `Super+R` Hyprland switch are separate reviewed
actions. All three were completed in that order.

## D077 — Merge only registered Thunar actions and block live-process writes

**Date:** 2026-08-16
**Status:** Accepted

Thunar `uca.xml` is user-owned state and is never replaced wholesale by the
repository. SenomyOS stores a bounded action registry and a fixed helper in the
repository. During plan and apply, the deployer parses the existing XML,
preserves unrelated actions, removes only registered SenomyOS unique IDs,
capability-detects dependencies, and generates a deterministic validated
candidate. The exact prior XML and mode are still covered by the normal
receipt and rollback transaction.

The first managed actions are Copy Path and Copy SHA-256. They accept only a
bounded set of existing absolute local paths and never evaluate selected text
as a command. Actions with missing dependencies are omitted truthfully.

Apply and rollback fail closed while a Thunar process is running because it may
rewrite custom-action state on exit. The deployer does not stop Thunar itself.
Accelerators, Xfconf preferences, GTK appearance, and native file operations
remain outside this action-layer transaction.

## D078 — Share tokens by contract and inherit GTK mechanics

**Date:** 2026-08-16
**Status:** Accepted

`appearance/tokens.json` is the portable machine-readable appearance
registry. Eww, Rofi, and GTK 3 retain syntax-specific projections rather than
sharing a fragile runtime include. Validation enforces their core colour and
font values and loads the full GTK provider through GTK's own CSS parser.

The SenomyOS GTK 3 theme is namespaced and imports GTK's built-in Adwaita
contained stylesheet before applying Obsidian overrides. This preserves native
widget mechanics, accessibility states, menus, dialogs, and application
behavior while changing visual tokens. Toolkit scope is explicit: a GTK 3
theme does not style GTK 4 applications.

Theme installation and global theme selection are separate decisions. The
source must pass isolated Thunar and multiple GTK 3 application checks before
deployment becomes ready, and a global preference requires its own review and
rollback path.

## D079 — Scope Thunar appearance and use its supported reveal interface

**Date:** 2026-08-16
**Status:** Accepted

SenomyOS installs `senomy-file-workspace` as the stable Thunar entry point for
Command Lens and other project surfaces. When no Thunar session exists, the
wrapper starts one with the installed namespaced SenomyOS GTK 3 theme. When a
session already exists, the wrapper reuses it without quitting or restarting
it. This gives SenomyOS-owned launches a coherent appearance while leaving the
global GTK preference and unrelated GTK applications unchanged.

Thunar 4.20 does not provide the assumed `--select` command-line option. File
reveal therefore uses GIO to obtain a safe URI and calls the supported
`org.freedesktop.FileManager1.ShowItems` method with typed arguments. A fresh
selection launch starts the themed daemon first and sends exactly one reveal
request, preventing the duplicate windows found during live acceptance. Paths
remain data throughout; no command string is evaluated.

## D080 — Activate Command Lens and scope normal Thunar launches

**Date:** 2026-08-16
**Status:** Accepted

After isolated contracts and manual visual acceptance passed, the tracked and
live Hyprland configurations route `Super+R` to `senomy-command-lens` and
`Super+E` to `senomy-file-workspace`. A user-level `thunar.desktop` override
routes normal application-menu launches through the same wrapper while leaving
the distribution desktop file untouched and recoverable through deployment
rollback.

The global GTK preference remains unchanged. Standard file-workspace launches
use `SenomyOS`; touch launches use the separately namespaced
`SenomyOS-Touch` projection with 48px primary targets. Automatic density reads
only the bounded SenomyOS appearance preference and falls back to standard.

## D081 — Own the fresh Thunar daemon environment

**Date:** 2026-08-20
**Status:** Accepted

Launching a client with `GTK_THEME` is insufficient when D-Bus activates
`/usr/bin/Thunar --daemon` independently: the activated daemon does not inherit
the client-only theme environment and falls back to the global GTK preference.
For a fresh file-workspace session, `senomy-file-workspace` therefore starts
the daemon through a collected transient user service with the selected
namespaced theme, waits for the owned `org.xfce.Thunar` name, and then opens an
explicit window or sends one typed FileManager1 reveal. A detached `nohup`
daemon is the bounded fallback when the user manager cannot start the transient
service.

The wrapper never restarts an existing Thunar session merely to change its
appearance. Existing sessions retain their environment and are reused. This
preserves user work while making fresh `Super+E`, desktop-entry, and Command
Lens launches deterministic. Clean live QA verified the daemon environment,
standard Preferences and Properties, a 640px narrow window, and the touch main
and Preferences states without changing the global Adwaita preference.

The user desktop entry must also remain eligible when the display-manager
session PATH omits `~/.local/bin`. It therefore invokes the installed wrapper
through an explicit shell-expanded `~/.local/bin` path and does not use a
PATH-dependent `TryExec`. Gio resolution with a system-only PATH is part of the
Thunar contract.

## D082 — Centralize appearance sources and separate login from lock

**Date:** 2026-08-20
**Status:** Accepted

`appearance/` is the single editable visual source tree for Eww, Rofi, the
namespaced GTK 3 file-manager themes, SDDM, and Hyprlock. One generator maps
the shared token registry into native toolkit syntax, while the appearance
entry point routes preview, validation, transactional deployment, and rollback
to the correct user or privileged boundary. Applications continue reading
their required XDG or system paths; those paths are deployment targets rather
than development copies.

SDDM runs before an authenticated desktop exists and therefore uses a static,
privacy-safe blurred wallpaper. Hyprlock runs inside the user session and
captures and blurs the real desktop at lock time. Both implement the approved
lower authentication rail without pretending these trust boundaries are the
same.

## D083 — Authenticate recovery separately and confine its session

**Date:** 2026-08-20
**Status:** Accepted

Password reset is not an unauthenticated SDDM/QML action. `RECOVER` selects a
separate `senomy-recovery` account and one dedicated Wayland session. The
account has its own credential and `/usr/bin/nologin`; root-owned SDDM session
guards deny it all X11 sessions and any Wayland command other than the exact
recovery launcher. Its minimal Hyprland configuration defines no launcher,
browser, terminal, or general command binding.

The full-screen GTK recovery UI can only return to SDDM or pass two password
lines over standard input to one exact, root-owned helper. The sudo rule names
that helper with no arguments; the helper revalidates caller identity,
root-owned configuration, target UID and shell, password match, and length
before calling `chpasswd`. System deployment and account provisioning remain
separate confirmed operations with backups and validation.

This boundary does not claim physical-device security. Protecting offline
system and user data requires a separately designed data-at-rest encryption
and boot-integrity strategy.

## D084 — Make Super+L a visible session lock, not logout

**Date:** 2026-08-20
**Status:** Accepted

`Super+L` invokes the deployed `senomy-lock` wrapper and preserves the active
Hyprland session. SDDM remains the pre-session login and recovery boundary;
ending the compositor merely to show SDDM would discard application state and
is not a lock operation.

The Hyprlock rail reproduces the approved SDDM rail geometry, zones, typography,
iconography, avatar, password underline, action treatment, and clock placement
at the 1920x1080 reference size. The only intentional trust-boundary changes
are its live blurred desktop capture and the honest `PRESS ENTER` action label:
Hyprlock does not expose SDDM's session or power callbacks. The pointer remains
visible, authentication stays keyboard-driven, and no arbitrary command-
launching click target is introduced.

## D085 — Move Hyprland and recovery to verified Lua sources

**Date:** 2026-08-20
**Status:** Accepted

Hyprland 0.56 warns that legacy `.conf` support will be removed in 0.57. The
portable desktop and constrained recovery compositor therefore use repository-
owned Lua sources validated by `Hyprland --verify-config` before deployment.
The user deployer creates `~/.config/hypr/hyprland.lua` transactionally without
reloading the current compositor; Hyprland selects it on the next session
start. The older tracked `.conf` remains a migration reference rather than the
deployment source.

The desktop Lua config discovers connected outputs, derives user paths from
`HOME`, and exposes an explicit nested-QA guard that suppresses autostart during
safe runtime tests. The recovery launcher points only to the root-owned Lua
config, whose source still defines no application or command bindings. LuaLS
uses Hyprland's installed API stubs so later maintenance can be type-aware.

## D086 — Separate live shell palettes from reviewed system projection

**Date:** 2026-08-20
**Status:** Accepted

Cyan, Violet, and Amber are explicit, unique palette records in
`appearance/tokens.json`. Their generated SCSS variables are applied after
component refinements so a fixed legacy literal cannot silently override the
selected live Eww palette. Swatches and palette-aware edges make the choices
visibly distinguishable in the Rail and every primary shell surface.

The live Control Centre selector changes Eww only. Rofi, GTK, SDDM, and
Hyprlock continue to project the stable `colors.accent` value until a reviewed
system-wide palette promotion is built and deployed. This prevents an instant
shell preview from unexpectedly rewriting pre-login or toolkit configuration.

## D087 — Make profiles and one generated wallpaper portable defaults

**Date:** 2026-08-20
**Status:** Accepted

`automatic`, `desktop`, `touch`, and `narrow` are complete, schema-validated
profile files deployed beneath the user's XDG configuration root. They express
only shell density, appearance defaults, wallpaper mode, and file-workspace
density. Explicit bounded user preferences retain higher precedence, and
unknown hardware resolves to `automatic` rather than a model-name branch.

The editable wallpaper master is a tokenized SVG in `appearance/`; generation
produces deterministic desktop and privacy-safe login PNGs. The next-session
Hyprland source starts one bounded `senomy-wallpaper` wrapper backed by
`swaybg`. Shared configuration no longer contains a username, Downloads path,
monitor name, or competing wallpaper daemons.

## D088 — Treat package, service, and bootstrap manifests as release inputs

**Date:** 2026-08-20
**Status:** Accepted

The Arch package manifest distinguishes required official dependencies,
optional capabilities, development validators, system integration, and the
explicitly reviewed external Eww package. The service manifest records
required enablement separately from package-managed presets. The bootstrap
coordinates these contracts, profile selection, transactional deployment,
workspace-unit enablement, and interactive recovery provisioning without
restarting SDDM, reloading Hyprland, regenerating boot files, logging out, or
rebooting.

Clean-home and clean-root acceptance use the real manifests and native parsers.
They prove deterministic staging and configuration integrity, not a successful
kernel, display-manager, recovery, or boot-loader cold boot. Compatibility
claims still require a disposable VM or representative physical hardware.

## D089 — Stage boot appearance separately from boot-path activation

**Date:** 2026-08-20
**Status:** Accepted

Plymouth and GRUB theme files are ready root-owned deployment components with
checksummed receipts and rollback. Staging only writes isolated theme
directories. It never selects a theme, edits mkinitcpio/dracut or GRUB
configuration, rebuilds an initramfs, regenerates `grub.cfg`, or writes a boot
sector.

Activation stays unavailable until a real disposable-machine acceptance record
proves both a cold boot and recovery boot. Even after that evidence exists,
`senomy-bootctl` reports review-required rather than mutating the boot path;
activation needs its own implementation, recovery instructions, and approval.

## D090 — Make compositor scale explicit and bound every primary surface

**Date:** 2026-08-21
**Status:** Accepted

Hyprland's PPI-derived `scale = "auto"` selected 1.5 on the 1920x1080
reference panel, reducing the logical work area to 1280x720 and unexpectedly
enlarging Rofi, Eww, and ordinary applications. Display scale is therefore an
explicit validated profile value. Automatic, desktop, and narrow default to
1; touch may deliberately select 1.25. Unknown or invalid profile data falls
back to 1 rather than inferring a machine-specific scale.

Control Centre and Insights retain fixed wide-desktop targets capped to 90%
of monitor width and 82% of height. Performance targets 1480x760 under the
same caps. Route labels truncate or wrap inside the allocation so GPU names,
sensors, or other runtime strings cannot change the outer window size. Live
compositor QA must compare all Performance routes, not only verify that the
window remains open.

## D091 — Centralize owned boot visuals without claiming firmware or video control

**Date:** 2026-08-21
**Status:** Accepted

`appearance/boot/sequence.json` is the canonical stage/capability record for
the owned pre-login sequence. A tokenized OS mark generates one SVG/PNG family
for GRUB and Plymouth; their native layouts remain beside it and are staged
through the same appearance entry point. Firmware remains device-owned, GRUB
is treated as a static boot-menu renderer, and Plymouth as a constrained
early-userspace image/text renderer. Arbitrary video playback is not presented
as supported in any of those stages.

ASCII/text animation and optimized short image sequences are future Plymouth
options with bounded frame rate and initramfs size. Device variants are based
on graphics/text capabilities rather than BIOS or model names. Activation is
still blocked by D089 and requires disposable cold-boot and recovery evidence;
centralizing source does not expand permission to mutate a live boot path.

## D092 — Give the OS mark one shared editable geometry source

**Date:** 2026-08-25
**Status:** Accepted

The August 25 visual references converge on a narrow three-lancet mark but
contain inconsistent raster approximations and repeated placements. SenomyOS
therefore defines the mark once at
`appearance/shared/brand/senomyos-mark.svg.in`: a monochrome full-height centre
spire flanked by two shorter balanced spires. Generated SVG and 64px, 128px,
and 256px PNG projections may be copied into toolkit-owned locations, but they
are not editable artwork.

GRUB and Plymouth retain their existing `appearance/boot/assets/` filenames as
generated regular-file compatibility projections. This preserves their
transactional manifests and existing rollback history while moving authority
out of the boot-specific directory. Symlinks are not used because both
deployers deliberately reject them. Adding the shared asset to Eww, Rofi,
SDDM, or Hyprlock remains a separate consumer change with native validation;
Thunar is not structurally modified merely to force OS branding into a native
file-manager window.

## D093 — Lock the Rail to the Luminous Reliquary composition

**Date:** 2026-08-26
**Status:** Accepted

The persistent Obsidian Rail adopts the selected Luminous Reliquary reference
as its visual composition: stable unboxed workspaces, a joined but separately
interactive Senomy avatar/dialogue unit, a distinct CPU/MEM/UP island, grouped
system controls, a compact calendar/notification island, and an isolated Power
entry. The standard reference profile uses a 142px exclusive window and a
120px visible Rail; compact, narrow, and phone variants remain capability- or
profile-derived rather than hard-coded to the T480 model.

Rail structure is neutral silver/obsidian with violet restricted to active,
focus, selected, and Senomy identity traces. Semantic warning, critical, and
success colors remain truthful and are not recolored by the decorative
palette. Larger surfaces retain the existing user-selectable palette system;
the Rail-specific final projection does not create a second appearance source.

Standard and compact workspace data keeps a five-slot visual floor while every
slot continues to consume the real Hyprland client array and may show several
real application icons. Empty slots remain empty. The notification badge is
fed by an event-driven SwayNotificationCenter subscription that exposes only
count and provider state; notification content and mutations remain in the
existing guarded Insights paths. The mock's illustrative values and large
bottom gap are not copied over live data, exclusive-work-area behavior, or the
accepted single-primary-surface coordinator.

## D094 — Make the Rail window invisible and workspace content authoritative

**Date:** 2026-08-26
**Status:** Accepted; supersedes D093's five-slot visual floor

The exclusive Eww window remains responsible for layout and reserved work area,
but it has no visible background, border, radius, or shadow. Workspaces are
unboxed content followed by separately bounded Senomy, telemetry, system,
calendar/notification, and Power instruments. The individual instruments use
low-opacity smoked surfaces and quiet silver edges; violet remains restricted
to focus, selected state, Senomy identity, and notification energy.

The systemd-owned Hyprland listener is the only workspace authority. Its
normalized state contains only existing positive workspace IDs plus the active
positive workspace, sorted numerically; special workspaces and fabricated
numeric gaps are excluded. Each workspace owns a centred two-column application
grid below its number. Active workspaces expose up to four cells and inactive
workspaces up to two. When the real application count exceeds that capacity,
the final cell is a same-size `+N` overflow entry rather than loose text.

## D095 — Restore the enclosed compositor-glass Rail and visible workspace floor

**Date:** 2026-08-26
**Status:** Accepted; supersedes D094 where the final reviewed reference and live feedback conflict

The persistent Rail again exposes one quiet rounded outer enclosure around the
unboxed workspace strip and the five bounded instruments. The enclosure and
islands use translucent GTK surfaces, while a namespace-specific Hyprland
layer rule supplies the actual desktop backdrop blur. Silver borders use
restrained multi-radius bloom; violet remains a focus, identity, selection,
and notification trace. The Rail does not use an opaque GTK approximation of
blur, and its hover states do not paint large rectangular fills.

The standard workspace strip keeps visible anchors 1 through 5 and extends
when Hyprland reports a higher positive workspace. Empty anchors contain no
fabricated application data. Special workspaces remain excluded from the
strip, but a Rail click closes a currently visible special-workspace overlay
before focusing the requested normal workspace so the visible application and
the active underline cannot disagree.

The approved Senomy Rail identity restores the existing browsing chibi rather
than the generated composition-study avatar. Avatar and dialogue remain
separate controls without a decorative divider between them. The notification
badge uses the truthful SwayNotificationCenter count and is positioned over
the bell's upper-right corner. The selected cathedral raster is the editable
desktop-art source; deterministic generated projections remain deployment
outputs, and the earlier SVG remains the portable fallback.

## D096 — Keep the glass instruments but remove the enclosing Rail frame

**Date:** 2026-08-26
**Status:** Accepted; supersedes D095's enclosing frame and five-slot floor

The Eww layer remains 142px high for stable exclusive work-area behavior, but
its top-level `.bar` is visually transparent and contributes no horizontal
margin, padding, border, radius, background, or shadow. Only the individual
glass instruments remain visible. They stay packed as one right-aligned group,
leaving the unboxed workspace region free to grow.

The workspace listener publishes only real positive Hyprland IDs plus the
active positive ID. It does not synthesize empty 1–5 anchors. Hoverable Rail
controls avoid padded rectangular hover fills; hover feedback is color-only,
while selected and semantic states remain truthful. The visible Senomy message
does not open an overlapping GTK tooltip; icon-only controls retain tooltips.

## D097 — Compact the Rail and make each live workspace an island

**Date:** 2026-08-27
**Status:** Accepted; supersedes D096's 142px geometry and unboxed workspace presentation

The standard exclusive Rail layer is 104px high and its visible islands are
80px high. The top-level layer stays transparent and frameless; only a minimal
internal top reserve and bottom safe inset remain. This returns 38 vertical
pixels to the compositor work area while preserving the existing chibi,
telemetry, clock, notification, and system-control content.

Each real positive workspace published by the Hyprland listener is presented
as its own glass island with the same neutral border, radius, translucent fill,
and restrained bloom as the instrument islands. There is no enclosing
workspace box and no synthetic numeric floor. Active and hover states may add
violet emphasis without changing allocation.

The standard system-control island is a 320px five-column group. Applications,
volume, Wi-Fi, battery, and tray each own one equal 64px column and expand with
the parent allocation. Internal padding and inter-control gaps stay at zero so
the hover surface reaches its complete column.

## D098 — Make the standard Rail genuinely 44px tall

**Date:** 2026-08-27
**Status:** Accepted; supersedes D097's 104px layer and 80px island geometry

Changing only a container minimum does not compact GTK content whose children
retain larger minimums. The standard Rail therefore uses one coordinated
allocation chain: a 56px exclusive layer, 44px island surfaces, and 42px
interactive children. Workspace grids, avatar artwork, icons, telemetry,
clock text, badge geometry, and internal spacing scale with that chain so no
descendant silently restores the former height.

Notification-badge acknowledgement is session-local presentation state, not a
provider mutation. Clicking the notification control records the listener's
current observation before opening Insights and hides the numeric badge. The
truthful SwayNotificationCenter count remains unchanged; a newer listener
observation may show the badge again. Clearing, dismissing, and Do Not Disturb
remain in the existing guarded notification action paths.

## D099 — Align 56px Rail islands to compositor geometry

**Date:** 2026-08-27
**Status:** Accepted; supersedes D098's 44px island geometry

The standard Rail uses a 64px exclusive layer with 56px visible workspace and
instrument islands. A shared 22px gap separates adjacent islands; no edge
wrapper adds a second component-specific margin. The Rail content is inset
20px from the monitor's left and right edges so its outer limits follow the
same line as tiled-window outer gaps.

Hyprland preserves 20px top, right, and left outer gaps but reduces the bottom
gap to 6px. This is represented as a four-sided `css_gaps` value in both the
canonical Lua configuration and the compatibility `.conf` mirror. The smaller
bottom value reduces dead space above the Rail without changing the desktop's
side alignment or inter-window rhythm.

## D100 — Build Gothic Rail borders from fixed vector modules

**Date:** 2026-08-27
**Status:** Accepted

The five supplied ornamental PNG sheets are art direction only. Compact Rail
borders are authored as native SVG geometry from one editable template and
projected through the existing appearance-token generator. Runtime and QA
assets do not embed, crop, auto-trace, or nine-slice those raster studies.

The compact grammar uses a 44px optical canvas, a continuous rail loop, four
fixed 12px corner modules mirrored without scaling, and fixed-size edge
ornaments. Exact-width projections absorb width only in straight edge
geometry, keeping corner shape and stroke weight stable. The optical 44px
canvas is independent from D099's 56px visible widget allocation.

The initial production validation set is 68x44, 200x44, and 397x44. A dedicated
validator rejects raster or foreign SVG content, verifies intrinsic geometry
and centre transparency, renders through librsvg, and pixel-compares corner
and straight-edge crops across all widths. Adding a new consumer width means
generating a new exact projection rather than stretching an existing asset.

## D101 — Apply exact Gothic SVG projections to the standard Rail

**Date:** 2026-08-27
**Status:** Accepted

The standard-density Rail consumes D100's frame grammar as background artwork
at the exact width of each live island: 68px for workspace and Power, 188px for
Calendar/Notifications, 320px for system controls, 392px for telemetry, and
397px for Senomy. The generator owns every width; CSS does not stretch one
projection to impersonate another.

The ornament remains 44px high and is optically centered inside D099's 56px
widget allocation. This preserves interaction height, internal control
centres, 22px inter-island gaps, and monitor-edge alignment. The previous
generic one-pixel border is removed on standard islands so it cannot compete
with the vector frame; glass fill and child hover surfaces remain functional.

Compact, narrow, and phone densities retain their existing CSS border until
their allocated widths are measured and receive exact projections. This is a
deliberate no-distortion fallback rather than permission to scale the standard
assets.

## D102 — Compose fluid Rail frames from fixed SVG modules

**Date:** 2026-08-27
**Status:** Accepted; supersedes D101's exact-width runtime selection

Every Rail density now consumes one CSS-fluid vector composition instead of
selecting a complete SVG by island width. CSS places fixed 12x44 left and right
caps and a fixed 10x44 centre jewel above one straight-edge SVG stretched to
the island's computed width. Only that straight segment scales, so changing a
panel or island width in CSS requires no new runtime asset and does not distort
corner geometry or jewel stroke weight.

D100's exact 68x44, 200x44, and 397x44 projections remain required QA fixtures;
the additional live-width projections remain deterministic comparison assets.
The vector validator also constructs the CSS-equivalent modular frame at all
three required widths and pixel-compares its fixed corners and edge samples.
A single complete frame with `background-size: 100%` remains prohibited because
it visibly scales corners and ornaments.

## D103 — Adopt the three-tier Luminous Reliquary frame system

**Date:** 2026-08-28
**Status:** Accepted; supersedes D100–D102's Compact-only asset architecture

The August 28 production sheet is visual direction, not a runtime bitmap.
SenomyOS now owns one canonical JSON manifest, one token-driven standalone SVG
module template, separately authored Compact/Standard/Large path geometry,
eight component motifs, and three optional crests. The generator emits 35
transparent native-vector assets. Fixed corners, motifs, and crests preserve
aspect ratio and optical dimensions; only neutral straight-edge modules may
stretch into the CSS allocation.

Compact remains the only deployed tier in this stage. The Obsidian Rail
composes its independent Workspace, Senomy, Telemetry, System Controls,
Clock/Notifications, and Power frames from those production modules. It does
not acquire a master frame. Each real Hyprland workspace has an adaptive,
structurally open top-centre number bay; the existing app grid, overflow,
actions, and listener data remain authoritative.

Standard and Large are complete reusable asset families and are proven by the
frame harness, but no Control Centre, Performance, Insights, Command Lens,
GTK, Thunar, SDDM, Hyprlock, or boot surface consumes them yet. Migrating those
surfaces requires its own layout and interaction pass rather than a bulk theme
replacement.

The canonical validation matrix is Compact 68/120/200/280/397x44, Standard
160x88/240x120/420x180, and Large 240x120/480x320/1480x760. Validation must
also parse the fully compiled Eww stylesheet through GTK 3 so an unsupported
property cannot silently degrade the live Rail to toolkit fallback styling.

## D104 — Bound workspace growth with a presentation-only carousel

**Date:** 2026-08-28
**Status:** Accepted

The standard Rail preserves its established workspace layout while four or
fewer real workspace islands fit. At five or more, the workspace region becomes
a fixed four-item viewport with allocated previous/next controls. Individual
workspace geometry, the 22px inter-workspace rhythm, and every neighbouring
Rail island remain unchanged. Boundary controls disable without collapsing, so
the containing width does not move between the first, middle, and final views.

Eww uses two fixed, same-size GtkStack page buffers because generated `for`
children cannot be direct stack pages. The selected buffer receives the current
slice and the inactive buffer retains the previous slice for native clipped
slide motion. `scripts/workspace-carousel.sh` serializes short input bursts and
owns only presentation offset/direction state. It never calls Hyprland.
`workspaces.service` remains the sole workspace publisher and reconciles the
viewport after authoritative creation, removal, focus, and client events.

Manual arrows and wheel/touchpad scrolling change only which indicators are
visible. Workspace buttons continue to focus their actual positive Hyprland ID;
no synthetic numeric range or UI-owned workspace list is introduced. Active
workspaces outside the current view are brought into view, invalid end offsets
are clamped after removal, and non-overflow state resets to offset zero.

## D105 — Make SDDM a Standard-tier frame consumer and isolate Recovery selection

**Date:** 2026-08-29
**Status:** Accepted

The SDDM login surface now composes independent Standard-tier frame modules for
system utilities, identity, authentication, session, and clock/keyboard
instruments. The generator projects the approved shared SVG modules into the
self-contained SDDM theme; fixed corners and motifs preserve optical size while
only neutral edge centres stretch. There is no enclosing master frame.

Normal authentication must never submit the `Senomy Recovery` session. The
greeter ignores a remembered Recovery index, prefers the ordinary `Hyprland`
session when it must recover from an unsafe selection, excludes Recovery from
normal session cycling, and revalidates the index immediately before login.
Recovery remains reachable only through the explicit `RECOVER` mode and its
separate account credential; the session guards remain unchanged.

## D106 — Make Insights the first Large-tier desktop consumer

**Date:** 2026-08-29
**Status:** Accepted

Senomy Insights uses one Large-tier evidence chamber at 960x760 on the
reference display and one independent Standard-tier route instrument. The
outer identity motif, route junction, section diagnostic tick, fixed corners,
and neutral extensible edges come from the canonical frame manifest. Content
keeps open reading planes and local state rails instead of framing every row.

The eight stable routes, data collectors, allowlisted actions, and primary-
surface coordinator remain authoritative. Briefing gains ranked evidence;
ledger, event-rail, runbook, docket, and two-pane reader treatments are
presentation changes only. Because Eww 0.5 rejects the `@charset` emitted for
non-ASCII SCSS, the appearance generator projects the canonical shell source
as one ASCII, self-contained runtime `eww.scss`.

## D107 — Make Performance the Large-tier telemetry chamber

**Date:** 2026-08-29
**Status:** Accepted

The Performance Dashboard uses one Large-tier telemetry chamber at 1480x760
and one Standard-tier route instrument. KPI readouts and major diagnostic
groups use Standard frame modules; retained-history plots stay open and
separator-led so the overview preserves the Cathedral Deck telemetry nave.

The seven routes, synchronized collectors, runtime history, process controls,
benchmark safeguards, and primary-surface coordinator remain authoritative.
The duplicate Senomy Observer card is removed from Overview; System State and
Power Snapshot reclaim that row without adding a replacement mascot or dead
allocation.

## D108 — Make Control Centre the Large-tier operational switchboard

**Date:** 2026-08-29
**Status:** Accepted

The Control Centre uses one 960x760 Large controls chamber and one independent
Standard route spine. Route summaries use connected metric buses; major
endpoint, power, calendar, and settings instruments use Standard frames;
inventory and lifecycle collections remain open ledgers with local state rails.

All ten routes, deep links, live collectors, confirmations, polkit handoffs,
and system-action boundaries remain authoritative. The migration changes
geometry and presentation only and keeps the panel bottom-right with a 12px
gap above the Rail.

## D109 — Use one translucent frame hierarchy across shell and compositor

**Date:** 2026-08-30
**Status:** Accepted

Compact Rail islands, Standard utility flyouts, and Large primary surfaces use
one semi-opaque glass hierarchy and clip their painted backgrounds to the
fixed 16px, 32px, and 48px frame corners. Control, Performance, Insights,
flyouts, and the companion publish explicit Senomy namespaces so Hyprland can
blur only their translucent pixels. The Rail keeps its dedicated rule.

The volume and background-application trays become 420x96 and 340x150
Standard controls instruments. Existing audio, tray-host, close, outside-click,
Escape, and deep-link behavior is unchanged. The notification badge remains an
overlay on a fixed 64px stage so it cannot displace the bell from the centre of
its Rail button.

Ordinary Hyprland clients remain opacity 1.0. Their decoration adopts 18px,
power-2.4 rounding, silver-to-violet active structure, a muted inactive border,
and a broader soft shadow; application content is never made translucent.

## D110 — Give time, notifications, and session power dedicated Rail flyouts

**Date:** 2026-08-30
**Status:** Accepted

The clock/date, notification bell, and power button open separate Standard-tier
flyouts through the existing `active_flyout` coordinator. They no longer route
directly into Control Centre or Insights. Calendar stays read-only;
Notifications owns DND, live dismissal, and confirmed local-history clearing;
Power exposes lock, suspend, logout, reboot, and poweroff behind a visible
two-step confirmation state.

The deployed true-fullscreen helper closes transient shell surfaces and the
exclusive Rail before entering Hyprland fullscreen mode 2, then restores the
Rail after exit. Its original Super+V shortcut is superseded by D112.

## D111 — Freeze context before releasing it for Flameshot selection

**Date:** 2026-08-31
**Status:** Accepted

Print Screen must preserve visible SenomyOS panels, flyouts, and the companion
in the screenshot. Flameshot therefore takes and maps its frozen screencopy
before SenomyOS unmaps any layer-shell context. Once the capture client is
authoritatively visible, the primary coordinator and companion controller
release their live input regions without clearing route, dock, pin, or active
state. The user selects against Flameshot's frozen image; accepting or closing
the capture reconciles the exact prior context.

This ordering avoids both known failures: dismissing before capture erased the
surface from the screenshot, while leaving Eww overlay input regions mapped
prevented Flameshot from receiving drag selection. All utility flyouts remain
non-focusable, the exact Flameshot float/fullscreen rule stays narrow, and the
screenshot helper restores state from an EXIT trap if capture is interrupted.

## D112 — Keep floating, true fullscreen, and maximized modes explicit

**Date:** 2026-08-31
**Status:** Accepted

Super+V again toggles the focused client between tiled and floating. Super+F
invokes SenomyOS true fullscreen, including yielding the exclusive Rail.
Super+Shift+F toggles immersive compositor fullscreen: SenomyOS yields the
Rail, Hyprland fills the monitor, and the client remains non-fullscreen so its
own menu, tabs, and toolbar remain visible. Separate reversible shortcuts keep
each result predictable instead of hiding three different states behind one
cycle.

## D113 — Align Thunar's ornamental and compositor frames

**Date:** 2026-08-31
**Status:** Accepted

Thunar uses a dedicated 20px Reliquary window projection matched to its
Hyprland rounding. The SVG projection owns the visible structural edge; GTK
and Hyprland provide clipping and a restrained native border without drawing a
second ornamental outline. Toolbar, sidebar, content, and status surfaces use
responsive internal spacing rather than fixed application-wide geometry.

On a fresh Thunar daemon, the workspace wrapper preserves a reasonable saved
sidebar width and clamps stale extremes to 220px in Standard density or 260px
in Touch density. It never mutates an already-running daemon. Rail workspace
indicators use 54px Standard islands and 10px gaps so their 2x2 application
grid determines the footprint instead of legacy empty padding.

## D114 — Make SenomyOS the V2 source root without duplicating history

**Date:** 2026-09-01
**Status:** Accepted

`/home/Duku/SenomyOS` is the authoritative `quickshell-v2` worktree. The Eww
baseline is merged forward into that branch, and only the V2 directory moves to
`shell/quickshell/`; a speculative repository-wide rename is deferred. The
detached `/home/Duku/.config/eww` baseline remains the live Eww recovery tree.
Development links resolve back to source and refuse unmanaged collisions.

This corrects the historical “SenomyOS inside Eww” ownership model while
preserving all Git ancestry, the baseline tag, a direct runtime fallback, and
the existing transactional deployment sources.

## D115 — Use non-enabled user units with verified Rail handoff

**Date:** 2026-09-01
**Status:** Accepted

Migration-time shell ownership is serialized by `senomy-shell` and supervised
by three linked, non-enabled user units. A successful selection requires one
Rail namespace per active monitor, the competing namespace absent, and a 64px
bottom reserve on every monitor. Quickshell directly restarts after an ordinary
crash; repeated startup failure invokes an Eww fallback unit and records the
reason. Login-time startup remains unchanged and Eww-owned.

The Eww adapter delegates startup to the existing `start-eww.sh`, bounds later
IPC queries, and retains `workspaces.service` only in Eww mode. This avoids a
second Eww startup implementation and prevents a wedged IPC client from holding
the selector lock.

Both migration shell units want the graphical-session target and SwayNC. During
handoff, the selector retains a target-pinning service until the incoming Rail
is ready. This prevents stopping Eww-only workspace publication from also
stopping portals, notification ownership, and other services whose lifecycle is
correctly attached to the graphical session.

## D116 — Extend the appearance authority and consolidate V2 assets

**Date:** 2026-09-01
**Status:** Accepted

The existing JSON tokens and Luminous Reliquary manifest remain canonical.
Generation now projects a Quickshell singleton alongside Eww, application,
lock, login, and frame outputs. The V2 icon, Senomy, and frame directories are
repository-relative links to canonical assets after byte equality was verified.
Toolkit deployments that require self-contained system paths continue to use
generated regular files.

## D117 — Keep SwayNC transitional, make Quickshell the final notification owner

**Date:** 2026-09-01
**Status:** Accepted

SwayNC remains the sole `org.freedesktop.Notifications` owner during Milestone
2; V2 does not instantiate a competing server. The final V2 architecture will
move server and UI ownership into Quickshell after replacement IDs, actions,
urgency, timeout behavior, DND, bounded persistence, history, and crash rollback
pass isolated testing. A permanent SwayNC-backend/Quickshell-frontend split is
rejected because it retains private-protocol coupling and duplicate ownership.

SwayNC is transitional but not Eww-owned. The migration units pull it in as a
graphical-session dependency, and selector diagnostics expose loss of its DBus
name. Neither the unit nor a shell backend is newly enabled at login.
