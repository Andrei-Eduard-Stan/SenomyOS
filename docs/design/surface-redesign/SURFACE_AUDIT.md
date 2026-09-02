# SenomyOS Surface Audit

Status: visual architecture proposal only<br>
Audit date: 2026-08-28<br>
Live reference: T480, `eDP-1`, 1920x1080, scale 1<br>
Branch inspected: `revival/live`

This document maps the current desktop surfaces before any broad restyling. It preserves the implemented data sources, actions, confirmation states, routes, navigation, scripts, application logic, telemetry, security boundaries, and the rule that only one primary surface is active at a time.

No Eww or Hyprland reload, service restart, configuration change, system action, commit, or push was performed for this audit. The current-run evidence was captured from the live daemon one surface at a time and the shell was restored to `active_surface=none`, `active_flyout=none`, `companion_mode=closed`, with only `main-bar` open.

## 1. Sources and evidence

Functional source of truth:

- the current live implementation in `eww.yuck`, `windows/`, `widgets/`, `sections/`, and `scripts/`;
- the live and tracked Hyprland Lua configuration, which were byte-identical during the audit;
- the live and tracked legacy `hyprland.conf`, also byte-identical during the audit;
- the installed Rofi, Thunar, SwayNC, SDDM, Hyprlock, recovery, GTK, boot, and deployment sources;
- `docs/HANDBOOK.md`, `PRODUCT_SPEC.md`, `PLATFORM_STRATEGY.md`, `ARCHITECTURE.md`, `DESIGN_SYSTEM.md`, `DATA_SOURCES.md`, `DEVELOPMENT.md`, `IMPLEMENTATION_PLAN.md`, `DECISIONS.md`, and `RUNTIME_INVENTORY.md`.

Visual source of truth:

- the approved Luminous Reliquary, Obsidian Rail, Cathedral Deck, Command Lens, authentication, companion, and File Workspace references already in the repository;
- the canonical frame system in `appearance/shared/frames/frame-system.json` and its generated Compact, Standard, Large, crest, and motif SVGs;
- current-run live captures in [`baseline/current-run/`](baseline/current-run/README.md).

Evidence overview:

- [Rail, flyouts, and companion](baseline/current-run/contact-rail-flyouts-companion.png)
- [Control Centre routes](baseline/current-run/contact-control-centre.png)
- [Insights routes](baseline/current-run/contact-insights.png)
- [Performance routes](baseline/current-run/contact-performance.png)
- [Command Lens](baseline/current-run/command-lens-apps.png)
- [File Workspace](baseline/current-run/thunar-file-workspace.png)
- [SwayNC centre](baseline/current-run/swaync-notification-centre.png)

The authentication surfaces were not opened live. SDDM would require leaving the session, and Hyprlock would deliberately lock it. Their source, approved previews, and existing QA captures were inspected instead. This is an intentional evidence limitation, not a claim that their live rendering was verified in this run.

## 2. Current surface model

The live Eww tree defines eight windows:

1. `main-bar`
2. `actioncenter`
3. `insights`
4. `performance`
5. `volume-flyout`
6. `tray-flyout`
7. `companion`
8. `surface-dismiss`

`windows/battery-panel.yuck` and `windows/clock-panel.yuck` are included but empty legacy files. They are not current surfaces. There is no separate live battery, clock, calendar, network, or power flyout: those Rail controls route into the Control Centre. Wofi is not the active launcher; the deployed surface is Rofi Command Lens.

Primary ownership remains:

```text
none | control | performance | insights
```

`active_flyout` separately owns `none | volume | tray`. The companion is a non-primary edge overlay with `closed | expanded | compact` modes. The transparent dismiss layer is functional infrastructure, not a visible fifth surface.

## 3. Evidence-led findings

### Strengths to preserve

1. The Rail has already established the strongest visual identity. Its segmented Compact frames, disciplined silhouette, dense but readable grouping, and avatar/dialogue pairing are the correct foundation.
2. The primary-surface state coordinator prevents Control Centre, Insights, and Performance from overlapping.
3. Route ownership is clear. Control owns contextual operations, Performance owns deep telemetry, and Insights owns briefing, evidence, local memory, and diagnostics.
4. Data is generally truthful and capability-aware. Missing sources degrade to unavailable or loading states instead of fabricated values.
5. Destructive or disruptive operations are already routed through bounded confirmation and status states.
6. The Performance Dashboard has real synchronized history, useful process data, and a credible dense information model.
7. Rofi and the namespaced GTK 3 File Workspace demonstrate a viable path for native surfaces without pretending every application is Eww.

### Systemic visual problems

1. **The Rail and the panels are from different design generations.** The Rail uses the emerging silver/violet frame family, while primary panels still read as flat near-black rectangles with thin cyan rules.
2. **Legacy cyan is structural.** The live appearance preference is `cyan`, and cyan currently paints panel edges, selected routes, headings, progress, and the active Hyprland border. This conflicts with the locked Luminous Reliquary direction, where ivory/silver defines structure and violet is sparse signaling.
3. **Text is too small.** The selected Iosevka profile currently resolves to roughly 16px titles, 11px body, 10px navigation, and 9px metadata. Dense surfaces routinely fall below comfortable desktop readability and far below touch readability.
4. **Primary panels are not keyboard-focus surfaces.** Their windows are declared `:focusable false`. Pointer interaction works, but this is a P0 accessibility and product-architecture gap for keyboard operation.
5. **Card soup has replaced composition.** Repeated rectangular borders are used for almost every datum, message, action, and group. Hierarchy comes from boxes rather than spatial topology.
6. **The shared header is only partly shared.** Control Centre and Performance use `surface-hero-header`; Insights hand-builds a parallel header. The result is visually similar but structurally divergent.
7. **Panel topology is too generic.** Control and Insights both use the same left-navigation/content rectangle. Performance is a uniform instrument grid. Their functions differ more than their compositions show.
8. **The current visual density hides system meaning.** Performance graphs are shallow history bars, Insights evidence is mostly stacked rectangles, and Control actions often look equivalent to read-only data.
9. **Current compositor decoration is a legacy layer.** A saturated cyan-to-green active border, 10px rounding, heavy pop-in animation, and uniform shadows do not belong to Luminous Reliquary.
10. **Some integration surfaces are visually unowned.** SwayNC is essentially default dark GTK; Volume and Tray are thin cyan boxes; native GTK 4 utilities remain outside the namespaced Thunar theme.
11. **Responsive behavior exists but has not been designed as a family.** `bar_layout` and touch variants exist, yet narrow, portrait, phone, and touch topologies need explicit mockups and content priorities.
12. **Privacy must remain visible in the design architecture.** Notifications, process users, network names, addresses, and device identifiers are legitimate runtime data, but screenshots and report surfaces must not casually publish them.

## 4. Global design architecture: Luminous Reliquary

### 4.1 One family, different topology

All Senomy-owned surfaces should share:

- transparent obsidian fields with enough opacity for stable text contrast;
- luminous ivory and silver edge structure;
- very sparse violet for focus, selected state, urgent state, and active diagnostic flow;
- terminal precision, short technical labels, and truthful state language;
- restrained cathedral geometry expressed through corners, crests, junctions, and vertical/horizontal axes rather than ornament pasted over content;
- visible loading, empty, disabled, warning, error, success, pending-confirmation, and running states;
- pointer, keyboard, and touch affordances with the same action semantics.

The family must not force every surface into the same layout:

- the Rail is a horizontal instrument chain;
- Control Centre is an operational switchboard;
- Insights is a briefing and evidence reader;
- Performance is a wide telemetry deck;
- flyouts are anchored instruments;
- the companion is an edge presence;
- native applications receive restrained integration rather than Eww panel chrome.

### 4.2 Frame tiers

| Tier | Canonical safe inset | Use |
| --- | --- | --- |
| Compact | 9px horizontal, 7px vertical | Rail islands, workspace cells, compact companion state, small embedded status capsules |
| Standard | 16px horizontal, 14px vertical | Volume and Tray flyouts, Command Lens, notification popups/centre, expanded companion frame, compact native dialogs where supported |
| Large | 24px horizontal, 22px vertical | Control Centre, Senomy Insights, Performance Dashboard, major authentication/recovery compositions |

The generated SVGs should be treated as structural parts with a content-safe zone. They must not be stretched as a single decorative image. Use explicit corners and edges, keep the motif outside the safe zone, and let long edges repeat or extend without scaling the corner geometry.

### 4.3 Colour roles

| Role | Direction |
| --- | --- |
| Deep field | Near-black obsidian, approximately 92–97% opaque for dense text surfaces |
| Floating field | Obsidian at approximately 86–94% with tested compositor blur |
| Primary structure | Luminous ivory/silver, never a saturated full-perimeter glow |
| Secondary structure | Cool grey with low contrast, used for dividers and dormant paths |
| Signal | Sparse violet `#9892e8` family for focus, selected route, urgent state, and active flow |
| Success/warning/error | Semantic green/amber/red in small labels, ticks, or local bars only |

The current appearance accent picker must not continue recolouring the structural shell. Preserve the control and persistence path during implementation, but require a product decision before remapping it. The recommended migration is to keep Luminous Reliquary structure fixed and limit user palette choice to optional content data-series accents or a future explicitly scoped personalization layer.

### 4.4 Typography

- Use a technical mono face for instrumentation, codes, values, and terminal-adjacent content.
- Use the same mono family or a highly compatible readable face for body copy, but do not set all prose in uppercase.
- Desktop baseline: 18–20px primary titles, 13–14px body, 12px navigation, 10.5–11px metadata, 12px Rail labels.
- Touch baseline: 20–22px titles, 15–16px body, 14px navigation and controls.
- Uppercase plus tracking belongs to short eyebrows, route codes, state chips, and column headings—not paragraphs or long button labels.
- Long-form Wiki and report content should target a 62–78 character reading measure.

### 4.5 Spacing and controls

Use a 4px base scale: 4, 8, 12, 16, 24, 32, and 48px. Large-frame safe insets are additional structural clearance, not the full content padding.

- Pointer target minimum: 36px for dense desktop instruments.
- Primary action and route target: 40–44px.
- Touch target minimum: 48px with at least 8px separation.
- Route rows must show hover, focus, selected, disabled, and pending states independently.
- Icon-only controls retain tooltips and gain a visible keyboard focus mark.

### 4.6 Layering

Recommended visual stack:

1. wallpaper/environment;
2. optional compositor dim or blur behind a floating surface;
3. obsidian field;
4. Large/Standard/Compact structural frame;
5. navigation spine and major content axes;
6. content and instruments;
7. local violet signal/focus;
8. confirmation, warning, or modal layer.

Avoid stacking a compositor animation, an Eww translation, and a widget crossfade on the same transition. Every motion should have one owner.

### 4.7 Motion

- Flyouts: 120–160ms opacity plus 4–6px anchor settle.
- Primary panels: 180–220ms opacity plus 6–10px movement from their anchor.
- Route changes: 90–140ms crossfade or short directional reveal; never animate the entire frame again.
- Telemetry: interpolate changed values over 180–300ms where truthful; do not animate stale or unavailable values.
- Urgent state: one restrained violet edge or diagnostic tick; no continuous pulsing.
- Reduced motion: opacity-only transitions under 100ms, no moving charts or decorative loops.

## 5. Surface inventory and proposals

### 5.1 Obsidian Rail

**Current files:** `windows/main-bar.yuck`; `widgets/workspace-widget.yuck`, `senomy-status.yuck`, `system-widget.yuck`, `volume-widget.yuck`, `wifi-widget.yuck`, `battery-widget.yuck`, `clock-widget.yuck`, `system-tray.yuck`; Rail sections of `appearance/shell/eww.scss`; Compact generated frame assets.<br>
**How it opens:** always visible, exclusive bottom layer, namespace `senomy-rail`.<br>
**Current size/placement:** 1920x64 at the bottom, 20px visual edge insets, 22px between right-side islands.<br>
**Primary function:** continuous workspace, identity, telemetry, system control, time/notification, and power access.<br>
**Data:** workspace listener/service, Rail system status, audio/network/notification listeners, dual-battery JSON, clock/date, tray registry, avatar catalog.<br>
**Actions:** switch workspaces; open Insights, Performance, Control routes, Volume, Tray, and companion; adjust or inspect bounded controls; open power controls.<br>
**Navigation:** direct spatial access rather than a route list.<br>
**Current visual structure:** two Compact workspace cells followed by five framed instrument islands.<br>
**Problems:** the active Hyprland cyan/green window border creates a bright line directly above it; small icons and metadata need verified focus/touch states; narrow and portrait priority rules need visual proof.<br>
**Frame tier:** Compact.<br>
**Direction:** keep the current island chain and refine it, not redesign it into a conventional taskbar. The frame is the visual baseline for the rest of the shell.<br>
**Motifs:** workspace, identity, telemetry, controls, clock-notification, power.<br>
**Content-safe zone:** the generated Compact inset plus a minimum 36px desktop target; 48px in touch density.<br>
**Complexity:** small modules sharing one highly constrained topology.<br>
**Evidence:** [resting Rail](baseline/current-run/rail-rest.png).

### 5.2 Control Centre

**Current files:** `windows/actioncenter-panel.yuck`; `sections/control/*.yuck`; `widgets/surface-header.yuck`; Control styles in `appearance/shell/eww.scss`; status/action scripts for network, audio, power, brightness, Bluetooth, applications, appearance, and shell state.<br>
**How it opens:** Rail application, audio, Wi-Fi, battery, clock, and power controls route into it; other surfaces can deep-link through `surface-state.sh show-control SECTION`.<br>
**Current size/placement:** 888x700, bottom-right, 12px above the Rail.<br>
**Primary function:** contextual system control and guarded device action.<br>
**Data:** NetworkManager/kernel, PipeWire/WirePlumber, UPower/sysfs/TLP, Hyprland devices/monitors, BlueZ, background-application registry, preferences/profile/recovery status.<br>
**Actions:** scans, saved network connection, guarded network removal/disconnect, audio volume/mute/route, brightness, power plan changes, guarded Bluetooth operations, app lifecycle actions, appearance changes, diagnostic/settings handoffs.<br>
**Navigation:** Overview, Network, Audio, Power, Calendar, Input, Devices, Applications, Appearance, Settings.<br>
**Current visual structure:** Large header, 170px left route rail, one content column containing repeated bordered cards.<br>
**Problems:** generic topology, tiny text, frequent clipped or below-fold content, read-only data and actions have similar weight, broad cyan structure, and `:focusable false`.<br>
**Frame tier:** Large.<br>
**Direction:** an operational switchboard with one stable route spine, one route-specific instrument stage, and one guarded action dock. Keep bottom-right anchoring and stable geometry. Increase desktop height to approximately 740–780px where the work area allows; narrow layouts collapse the route spine to a horizontal or drawer pattern.<br>
**Motif:** controls, with local power or junction marks only where the route requires them.<br>
**Content-safe zone:** Large frame inset plus 24px interior; no action, scrollbar, or text may intersect decorative corners.<br>
**Complexity:** large shared shell with bespoke route compositions.<br>
**Evidence:** [all current routes](baseline/current-run/contact-control-centre.png).

Route compositions:

| Route | Preserve | Proposed topology |
| --- | --- | --- |
| Overview | CPU, memory, internet, power summary and route shortcuts | A connected operational spine with four nodes and one system-brief line, not four equal cards |
| Network | state, routes, AP inventory, scan/connect/disconnect/edit/remove controls | Internet → interface → access-point topology, signal arc, compact AP ledger, guarded operation dock |
| Audio | output/input, routes, hardware, volume and mute | Duplex channel bus with output and capture lanes, endpoint selector, fader and port metadata |
| Power | dual batteries, energy, policy, brightness, confirmation | Paired battery cells with charge-flow thread, policy selector, brightness rail, action confirmation bay |
| Calendar | local time, timezone, locale, ISO/system clock evidence | Calendar field plus chronometer column and evidence footer; remove the large empty framed block |
| Input | keyboards, pointers, touch/tablet capability | Capability matrix and device tree, with explicit unavailable/read-only states |
| Devices | displays, audio, batteries, network, Bluetooth and guarded operations | Central capability bus with grouped endpoints; device rows open bounded details rather than nesting cards |
| Applications | tray/native/background registry and lifecycle controls | Runtime ledger with state rail, origin, autostart, tray registration, and guarded lifecycle actions |
| Appearance | font, scale, accent, gradient, density and preview | Live specimen stage plus token controls; explain the fixed structural palette before legacy accent remapping |
| Settings | shell state, density, manifest, recovery/maintenance actions | System manifest with explicit ownership and an action dock; separate informational facts from maintenance actions |

### 5.3 Senomy Insights

**Current files:** `windows/insights-panel.yuck`; `sections/insights/*.yuck`; notification, timeline, updates, diagnostics, console, report, wiki, event, and Rail status scripts.<br>
**How it opens:** the Rail identity/dialogue opens Briefing; Rail notifications opens Notifications; companion can open Briefing; other surfaces may deep-link.<br>
**Current size/placement:** 750x700, bottom-centre, 12px above the Rail.<br>
**Primary function:** first-class local system briefing, evidence, maintenance context, diagnostics, reports, and knowledge. It is not a chatbot.<br>
**Data:** bounded notification memory, sanitized local event timeline, package discovery, allowlisted diagnostics, shell discovery, report collectors, Markdown Wiki, Rail/system/power telemetry.<br>
**Actions:** clear notification history, filter/follow timeline, manually check update sources, run allowlisted diagnostics, open real terminal handoffs, choose and build reports, navigate Wiki.<br>
**Navigation:** Briefing, Notifications, Timeline, Updates, Diagnostics, Console, Reports, Wiki.<br>
**Current visual structure:** hand-built header, left route rail, scrollable one-column evidence body.<br>
**Problems:** narrow measure for Wiki and Console, very small prose, weak distinction between narrative and operations, repeated evidence cards, no shared header primitive, and `:focusable false`.<br>
**Frame tier:** Large.<br>
**Direction:** a readable evidence chamber, approximately 900–1000px wide on a 1920px reference work area, with a slim route index and a route-specific reading plane. Briefing needs editorial hierarchy; Timeline needs a true event rail; Wiki needs a stable reading measure.<br>
**Motif:** identity at the frame crest, diagnostic tick for state changes; no duplicate character artwork in the panel.<br>
**Content-safe zone:** Large inset plus 24–32px; long-form content capped at 62–78 characters per line.<br>
**Complexity:** large shared shell with narrative, ledger, diagnostic, and reader topologies.<br>
**Evidence:** [all current routes](baseline/current-run/contact-insights.png).

Route compositions:

| Route | Proposed topology |
| --- | --- |
| Briefing | Ranked briefing ribbon: current condition, material change, recommended attention, and source freshness |
| Notifications | Time-ordered private ledger with app marker, urgency tick, relative time, bounded actions, and clear redaction/export rules |
| Timeline | Vertical event rail with source lane, severity tick, time anchor, filters, and follow state |
| Updates | Trust-chain view showing source, cache age, check action, freshness, candidate packages, and explicit no-install boundary |
| Diagnostics | Runbook rows with task code, exact scope, last state, run action, and bounded output drawer |
| Console | Curated command strips plus real-terminal handoff; never imitate an unrestricted embedded shell |
| Reports | Evidence docket with profile, included collectors, privacy classification, build state, and artifact location |
| Wiki | Two-pane index and reader with breadcrumb, readable line length, source path, and refresh state |

### 5.4 Performance Dashboard

**Current files:** `windows/performance-dashboard.yuck`; `widgets/performance-components.yuck`; `sections/performance/*.yuck`; performance status/history/action/process/benchmark scripts.<br>
**How it opens:** clicking CPU, MEM, or UP Rail telemetry. It does not live in the Control Centre.<br>
**Current size/placement:** coordinator target 1480x760 on the reference display, bottom-centre above the Rail; the Yuck default is 94% x 80%.<br>
**Primary function:** deep system telemetry, retained runtime history, process investigation, and guarded benchmark control.<br>
**Data:** `/proc`, `/sys`, kernel pressure counters, block/network devices, synchronized 300-second history, processes, failed services, UPower, benchmark state.<br>
**Actions:** route/filter/sort process views, export report, select process for guarded action, open diagnostics, start/stop bounded benchmarks with warnings and thresholds.<br>
**Navigation:** Overview, CPU + GPU, Memory, Storage, Network, Processes, Benchmarks.<br>
**Current visual structure:** shared hero header, horizontal route strip, uniform metric-card grid, footer provenance.<br>
**Problems:** charts are shallow and visually generic, dozens of equal borders flatten priority, labels are extremely small, the deck lacks a strong central machine-heart topology, and `:focusable false`.<br>
**Frame tier:** Large.<br>
**Direction:** Cathedral Deck topology: a strong central telemetry nave, secondary diagnostic transepts, and a persistent provenance rail. Keep the density, but make hierarchy spatial. Use arcs, history threads, mirrored flow bands, and topology lines only where they correspond to real data.<br>
**Motif:** telemetry crest, junctions at real metric relationships, diagnostic ticks for warning/guarded states.<br>
**Content-safe zone:** Large inset plus 18–24px; charts and footer labels must not enter the corner or crest zones.<br>
**Complexity:** bespoke large surface; shared instruments, not shared layout with Control or Insights.<br>
**Evidence:** [all current routes](baseline/current-run/contact-performance.png).

Route compositions:

| Route | Proposed topology |
| --- | --- |
| Overview | CPU and memory as paired machine-heart arcs, one 300s activity thread, power state, platform manifest, diagnostic handoff |
| CPU + GPU | Package/frequency/thermal spine, utilization history, normalized load band, thread topology; explicit GPU unavailable state |
| Memory | Composition river for used/cache/free, pressure history, swap boundary, reclaim/kernel/virtual memory ledger |
| Storage | Mirrored read/write ribbons, capacity rail, block-device topology, pressure and health boundary |
| Network | Mirrored receive/transmit streams, route/interface/address topology, link-integrity rail; keep sensitive values local |
| Processes | Dense sortable table as the main plane, persistent filters, selection inspector, explicit guarded action drawer |
| Benchmarks | Warning gate, phase timeline, live thermal/load thread, stop control, cooldown state, and comparable result ledger |

### 5.5 Volume flyout

**Current files:** `windows/volume-flyout.yuck`, audio widgets/status/action scripts, flyout styles.<br>
**How it opens:** Rail volume control.<br>
**Current size/placement:** 350x62, bottom-right, anchored above the Rail with a 10px gap.<br>
**Function/data/actions:** shows current output, mute, volume, and route; adjusts volume/mute and links to Control Centre Audio.<br>
**Current structure/problems:** a useful single-line instrument, but visually a cyan-edged rectangle with undersized labels and targets.<br>
**Frame tier/direction:** Standard, shaped as a horizontal channel strip with output identity, accessible fader, mute state, route affordance, and close. No extra cards.<br>
**Motif/content-safe zone:** controls motif; Standard inset, 44px pointer/touch-capable controls.<br>
**Complexity:** small shared flyout shell.<br>
**Evidence:** [volume flyout](baseline/current-run/volume-flyout.png).

### 5.6 Tray overflow

**Current files:** `windows/tray-flyout.yuck`, `widgets/system-tray.yuck`, tray registry/background application scripts.<br>
**How it opens:** Rail tray control.<br>
**Current size/placement:** 260x112, bottom-right above its Rail anchor.<br>
**Function/data/actions:** reveals native tray/background entries, allows their existing activation semantics, and links to Applications.<br>
**Current structure/problems:** status heading, count, close, and icon field; sparse content creates an empty cyan box and native item semantics are not visually explained.<br>
**Frame tier/direction:** Standard vertical ledger with one row per item, app identity, state, native-menu hint, and Applications handoff. Empty state collapses to a compact instrument rather than preserving a large void.<br>
**Motif/content-safe zone:** controls or junction motif; Standard inset.<br>
**Complexity:** small shared flyout shell with native-item adapter.<br>
**Evidence:** [tray flyout](baseline/current-run/tray-flyout.png).

### 5.7 Senomy companion

**Current files:** `windows/companion.yuck`; `widgets/senomy-avatar.yuck`; avatar/media/state scripts and cached variants.<br>
**How it opens:** separate Rail avatar control. It may coexist with one primary surface.<br>
**Current size/placement:** expanded 330x760 or compact 300x410, top-right or top-left at 12x72; session pin prevents timed collapse.<br>
**Function/data/actions:** ambient Senomy presence, state message, bounded media context, open Insights, dock, pin, collapse/expand, close.<br>
**Current structure/problems:** expanded mode is a long mostly empty rectangle; the toolbar is tiny; compact mode is visually stronger but oversized for a true compact state.<br>
**Frame tier/direction:** Standard edge-ribbon frame. Expanded mode uses character art once, a concise state plate, optional media strip, and Insights handoff. Compact mode becomes an avatar-and-state tab rather than a 300x410 panel.<br>
**Motif/content-safe zone:** identity motif; Standard inset around the plate, art may cross only designated non-interactive frame zones.<br>
**Complexity:** medium bespoke edge composition.<br>
**Evidence:** [expanded](baseline/current-run/companion-expanded.png), [compact](baseline/current-run/companion-compact.png).

### 5.8 Shared dismiss layer

**Current files:** `windows/surface-dismiss.yuck`, `scripts/surface-state.sh`.<br>
**How it opens:** coordinator-managed transparent layer behind an active primary surface or flyout.<br>
**Function/actions:** outside click dismisses the active transient or primary surface after a release guard.<br>
**Visual direction:** remain visually transparent. It must never carry frame, blur, or ornament. If a backdrop dim is approved, implement it as a separate non-interactive visual layer so dismiss hit-testing remains simple and testable.<br>
**Frame tier:** none.<br>
**Complexity:** invisible shared infrastructure.

### 5.9 Command Lens / Rofi

**Current files:** `appearance/launcher/rofi/config.rasi`, theme/token files, `components/launcher/rofi/scripts/*`, deployed wrappers in `~/.local/bin`.<br>
**How it opens:** Super+R, Rail Applications shortcut, and other bounded launcher handoffs.<br>
**Current size/placement:** 720px wide, upper-centre with 60px y offset, seven results on the reference display.<br>
**Function/data/actions/navigation:** Applications, Files, Windows, Actions; native Rofi keyboard navigation; bounded file/action providers.<br>
**Current structure/problems:** functionally clear and keyboard-strong, but it is a conventional rounded dark launcher with a violet selection block rather than a Standard Reliquary instrument.<br>
**Frame tier/direction:** Standard Command Lens frame, strong input line, four scope tabs, result ledger, shortcut footer. Keep one selection signal and avoid animating every result.<br>
**Motif/content-safe zone:** junction motif; Standard inset.<br>
**Complexity:** medium composition implemented in Rasi, not Eww.<br>
**Evidence:** [current Command Lens](baseline/current-run/command-lens-apps.png).

### 5.10 SwayNC notification popup and centre

**Current files:** live `~/.config/swaync/config.json`; notification listener/history scripts. No active Senomy SwayNC stylesheet was found. `ignore-gtk-theme` is enabled.<br>
**How it opens:** transient notifications are provider-driven; the SwayNC centre can be opened by its client, while the Rail intentionally opens Insights Notifications instead.<br>
**Current size/placement:** 500x600, top-right; notification window width 500.<br>
**Function/data/actions:** transient notification display, DND, grouping, clear-all, action dispatch, and history capture.<br>
**Current structure/problems:** visually generic GTK, rounded and grey, disconnected from the Rail and Insights; the live config contains an absolute `/home/Duku` history-script path; the centre duplicates part of the first-class Insights Notifications role.<br>
**Frame tier/direction:** Standard native projection. Keep provider functionality and keyboard shortcuts, but style popups as concise notification plates. If the centre remains user-visible, present it as a provider ledger, not a fourth primary shell. Do not add another Rail entry without a product decision.<br>
**Motif/content-safe zone:** clock-notification motif; Standard inset and strict body-image bounds.<br>
**Complexity:** medium native-provider surface.<br>
**Evidence:** [current empty centre](baseline/current-run/swaync-notification-centre.png).

### 5.11 File Workspace / Thunar and GTK 3

**Current files:** `appearance/file-manager/gtk3/SenomyOS*`; `components/file-manager/thunar/*`; deployed wrapper and desktop entry.<br>
**How it opens:** Super+E, Command Lens Files, Control Applications, and approved file handoffs.<br>
**Current size/placement:** normal Hyprland application window; captured tiled at work-area size.<br>
**Function/data/actions:** native file management and bounded reveal/open actions.<br>
**Current structure/problems:** the namespaced theme successfully produces a dark precise workspace, but the bright cyan/green compositor border dominates it. The GTK treatment is mostly utilitarian and has no Luminous Reliquary header hierarchy. GTK 4 applications do not inherit this GTK 3 theme.<br>
**Frame tier/direction:** no Eww frame inside the client. Use a restrained native Level-1 integration: dark field, ivory dividers, violet selection/focus, 38–40px desktop header controls, 48px touch controls, and the compositor's window edge.<br>
**Motif/content-safe zone:** no decorative motif in file content; optional single junction mark in the header only.<br>
**Complexity:** native application adapter.<br>
**Evidence:** [current namespaced Thunar](baseline/current-run/thunar-file-workspace.png).

### 5.12 Hyprland tiled, floating, modal, urgent, and fullscreen windows

**Current files:** tracked/live `hyprland.lua` and compatibility mirror `hyprland.conf`.<br>
**Current decoration:** 2px cyan-to-green active border, grey inactive border, 10px rounding, full opacity, shadow range 4/power 3, blur size 3/pass 1, and `popin 87%` window entry/exit. Only the Rail namespace has a dedicated blur rule.<br>
**Problems:** active decoration is more saturated than every content surface; pop-in feels like a generic compositor effect; tiled and floating windows have insufficient role distinction; urgent treatment is not visibly designed.<br>
**Direction:** use the compositor as a quiet outer ownership layer:

- active window: 2px luminous silver edge, with a local violet focus/urgent signal only where technically supportable;
- inactive window: low-contrast cool-grey edge;
- tiled windows: 4–6px rounding, minimal or no shadow;
- floating windows: 6–8px rounding and restrained low-opacity shadow;
- modal dialogs: centred, restrained shadow, clear parent dim, no decorative Eww frame;
- fullscreen: no border, rounding, gap, or shadow;
- urgent: one static violet edge or title marker, never a pulsing full glow;
- animation: replace 87% pop-in with a subtle 98–100% resolve plus fade, or fade-only under reduced motion;
- gaps: regularize outer gaps around 12–16px and coordinate the bottom gap with the Rail's exclusive zone.

This is a proposal only. Both tracked/live configuration pairs matched during the audit and were not changed.

### 5.13 Native utility handoffs

Current surfaces can open Kitty terminal sessions, `nm-connection-editor`, Flameshot, GTK Inspector, native tray menus, and other third-party utilities. These are not Senomy-owned panel routes.

- Preserve the allowlisted command and argument boundaries.
- Give them Level-0 or Level-1 integration through Hyprland, native GTK tokens where safely namespaced, and clear handoff language.
- Do not wrap arbitrary third-party clients in Large Senomy frames.
- Password, authentication, polkit, and system dialogs must remain native, legible, centred, and unmistakably privileged.

### 5.14 SDDM login

**Current files:** `appearance/login/sddm/senomyos/*`, `sddm.conf`, approved previews/QA, deployment scripts and Wayland/X11 session helpers.<br>
**How it opens:** pre-session display manager.<br>
**Current composition:** privacy-safe blurred wallpaper and a lower authentication rail containing identity, password, session, time/layout, utility, recovery, and confirmation states.<br>
**Direction:** keep the approved lower-rail composition. Project the Large/Standard frame language through QML primitives and approved assets, not by copying Eww code. Preserve keyboard-first authentication, error/success states, session choice, accessibility, power/restart/recovery confirmation, and privacy.<br>
**Frame tier:** Large authentication rail with Compact utility cells.<br>
**Motif:** identity and power, kept away from password text.<br>
**Evidence limitation:** source and existing QA only; no live SDDM transition in this run.

### 5.15 Hyprlock

**Current files:** `appearance/lock/hyprlock.conf(.in)`, lock assets, QA captures, `components/lock/scripts/senomy-lock`.<br>
**How it opens:** guarded lock action.<br>
**Current composition:** live wallpaper blur, lower lock rail, avatar/user/password, session/time/layout, and non-clickable utility marks.<br>
**Direction:** visually match the SDDM authentication rail while preserving Hyprlock's more limited interaction model. Do not imply utility controls are clickable when they are not. Use a simplified frame projection supported by Hyprlock primitives.<br>
**Frame tier:** Large authentication rail with Compact markers.<br>
**Evidence limitation:** source and existing QA only; live lock was intentionally not triggered.

### 5.16 Recovery UI

**Current files:** `components/recovery/senomy-recovery-ui`, session/helper/desktop/sudoers sources, `recovery-hyprland.lua`, deployment and recovery documents.<br>
**How it opens:** explicit recovery session from authentication/recovery paths.<br>
**Current size/placement:** restricted fullscreen GTK session with an approximately 700x560 centred password-reset panel.<br>
**Function/actions:** authenticated recovery boundary, password reset, return action, error/success state.<br>
**Direction:** Large native recovery reliquary with one task, one explanation, two fields, and a clearly separated return path. Use GTK-native focus/error semantics; decorative structure must never obscure credential fields or status.<br>
**Frame tier:** Large native projection.<br>
**Motif:** diagnostic tick and identity mark, never telemetry decoration.<br>
**Evidence limitation:** source inspection only; no recovery session was started.

### 5.17 Boot stages

GRUB and Plymouth sources exist under `appearance/boot/`. They are adjacent owned experiences rather than desktop panels. Keep the shared mark, obsidian/ivory/violet token projection, and deterministic handoff sequence, but do not force Eww frame topology into GRUB or Plymouth. Their implementation should follow the primary desktop surfaces and authentication validation.

## 6. Shared primitives to create before surface implementation

1. `surface-frame`: tier, motif, active/focus state, content-safe slot, reduced-motion mode.
2. `surface-header`: eyebrow, title, subtitle, source/availability chips, close action, optional route-specific status; Insights must use it too.
3. `surface-route`: icon/code, label, selected, hover, focus, warning, disabled, badge.
4. `state-mark`: loading, unavailable, empty, read-only, warning, error, running, succeeded, failed.
5. `source-line`: source name, freshness, retention, privacy class.
6. `guarded-action`: action label, scope, confirmation, running state, result and failure.
7. `instrument-value`: label, value, unit, trend/state, availability.
8. `history-thread`: bounded time-series with scale, freshness, empty/error state, reduced motion.
9. `topology-node` and `topology-link`: real device/data relationships only.
10. `ledger-row`: time/name/state/detail/actions without wrapping every row in a decorative card.
11. `reading-plane`: controlled measure, headings, tables, code and source metadata.
12. `native-token-projection`: the subset that can be expressed in Rasi, GTK 3, SwayNC CSS, QML, Hyprlock, and recovery GTK.

## 7. Accessibility risks and required decisions

P0 before restyling:

- decide how primary Eww windows become keyboard focusable without breaking Rail interaction or global shortcuts;
- define visible focus treatment that does not rely on colour alone;
- raise default text sizes and verify contrast over wallpaper/blur;
- define 48px touch density targets and route navigation for portrait/narrow layouts;
- preserve screen-reader labels/tooltips for icon-only controls where the toolkit supports them;
- keep dangerous actions behind explicit confirmation and never make their visual emphasis resemble a safe navigation action.

Evidence limitations:

- this audit did not run a screen reader or automated contrast sampler;
- Eww keyboard navigation could not be validated because the current primary windows are non-focusable;
- SDDM, Hyprlock, recovery, notification popups with action buttons, urgent native windows, and phone/portrait modes were not exercised live;
- current screenshots are visual evidence, not proof of touch, keyboard, or assistive-technology behavior.

## 8. Mockups required before implementation

1. Rail at 1920x1080, 1366x768, ultrawide, portrait, phone-width, and touch density; include overflow and unavailable states.
2. Control Centre Overview, Network, Devices, Appearance, and one confirmation state at desktop and narrow widths.
3. Insights Briefing, Notifications, Timeline, and Wiki, including empty/error/privacy states.
4. Performance Overview, CPU, Processes selection/guarded action, and Benchmark confirmation/running/cooldown.
5. Volume, Tray empty/populated, companion compact/expanded/left-docked, and outside-dismiss layering.
6. Command Lens apps/files/actions; SwayNC popup/centre; Thunar standard/touch; one GTK 4 utility integration example.
7. Active/inactive tiled windows, floating window, modal, urgent, fullscreen, and reduced-motion transition storyboard.
8. SDDM normal/error/confirmation, Hyprlock normal/error, and Recovery normal/error/success using their actual renderer constraints.

## 9. Implementation order

1. Approve tokens, type scale, spacing, frame-tier contract, colour-role migration, focus model, and representative mockups.
2. Build and validate the shared frame/header/route/state/action primitives in an isolated harness.
3. Migrate Volume and Tray as the lowest-risk Standard-frame proof.
4. Migrate Control Centre shell and one read-only route, then action-heavy routes with confirmation tests.
5. Migrate Insights shell and Briefing/Timeline/Wiki reading primitives.
6. Migrate Performance shell and shared telemetry instruments, then each route.
7. Refine companion topology without changing its state machine.
8. Project tokens into Rofi, SwayNC, and namespaced GTK; validate third-party limits.
9. Change Hyprland decoration and motion in one independently recoverable stage, synchronizing tracked/live files deliberately.
10. Apply the approved native projection to SDDM, Hyprlock, Recovery, and finally boot stages.

## 10. Technical constraints and migration risks

- `appearance/shell/eww.scss` is large and contains accumulated selector overrides and literal legacy colours. Tokenization must precede visual migration.
- Eww/GTK support for scalable border images must be proven in a harness. The safe default is explicit SVG corner/edge widgets with defined content-safe insets.
- The installed Eww package and binary version reporting differ; validate against the actual runtime before relying on newer syntax.
- Dynamic panel sizes are partly supplied by coordinator open overrides, not only Yuck geometry.
- Polling and listeners must retain existing `:run-while` and event-driven behavior; design must not force expensive always-on sampling.
- Frame and content animation must not duplicate Hyprland layer animation.
- Rofi Rasi, SwayNC CSS, GTK 3, GTK 4, QML, Hyprlock, and GRUB/Plymouth do not share one renderer. Share tokens and intent, not implementation assumptions.
- SwayNC currently opts out of the GTK theme and has an absolute live history-script path. Portability repair is a separate functional change and should not be hidden inside restyling.
- The namespaced Thunar theme does not style already-running instances or GTK 4 utilities.
- The legacy appearance palette currently changes structural shell colours. Any remapping needs explicit product approval and migration behavior for saved preferences.
- Large artwork remains exclusive to the companion and authentication contexts. Primary panel headers and content cards do not reserve duplicate character artwork.
- Screenshot, report, and notification workflows must define redaction and local-only handling for network names, addresses, hardware identifiers, usernames, and retained prose.

## 11. Stop condition

This audit defines the design map only. No broad implementation should begin until the frame contract, colour-role migration, focus model, representative mockups, and implementation order are reviewed and approved.
