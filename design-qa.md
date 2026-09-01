# Primary Surface Masthead Design QA

## Visual source of truth

- Canonical masthead reference: `/home/Duku/Downloads/iAalFCH_.jpg`
  (`1542x2047`, photographed desktop). The Senomy Insights masthead defines the
  approved avatar, hierarchy, status chips, close target, padding, and spacing.
- Previous Control Centre problem reference:
  `/home/Duku/Downloads/DSYdb8Pj.jpg` (`2048x1542`).
- Previous Performance problem reference:
  `/home/Duku/Downloads/Bmnq-SBe.jpg` (`2048x1542`).

## Implementation captures

- Control Centre / Overview:
  `/tmp/senomy-control-overview-20260813.png` (`888x700`).
- Control Centre / Power, fresh open:
  `/tmp/senomy-control-power-fresh-20260813.png` (`888x700`).
- Control Centre / Power, after an in-place Overview-to-Power switch:
  `/tmp/senomy-control-power-switch-final-20260813.png` (`888x700`).
- Performance Dashboard:
  `/tmp/senomy-performance-header-20260813.png` (`1804x885`).
- Senomy Insights / Wiki:
  `/tmp/senomy-insights-wiki-20260813.png` (`750x700`).

All captures came from the focused `eDP-1` compositor workspace at 1920x1080
logical pixels and scale 1. They are exact 1:1 window captures rather than
photographs, so their top masthead regions are already readable at original
resolution and no additional focused crop is needed.

## Full-view comparison

The canonical Insights reference and all five implementation captures were
reviewed together, then each implementation was inspected at original
resolution. The implemented surfaces share:

- a 126px masthead with the same outer padding and border treatment;
- a 108px identity block containing a bounded 102px context avatar;
- one eyebrow, one primary title, one wrapping subtitle, and a status-chip row;
- a consistent 42px close target aligned at the far right;
- shared compact, narrow, and phone-sized responsive reductions.

Copy, avatar state, status data, and total window width intentionally remain
surface-specific. These are product distinctions, not visual drift.

## Focused findings

- P0: none.
- P1: none.
- P2: none.
- P3: the source reference is an angled photo of an earlier Insights state, so
  exact pixel comparison is not meaningful. Structural spacing and hierarchy
  were used as the source of truth; current tokens and live data were retained.

## Comparison history

1. Initial comparison found two P1 issues: Control Centre and Performance used
   compact, unrelated headers, and Power expanded Control Centre from 751px to
   888px.
2. A shared masthead widget and explicit 888px Control Centre geometry were
   implemented. Fresh-open captures matched the target structure.
3. The first automated in-place Power capture was taken during Eww's redraw
   and showed temporary clipping. A later Overview-to-Power switch capture was
   clean and remained `888x700`, so no persistent defect remained.

## Primary interaction coverage

- Opened each of the three primary surfaces through the guarded surface-state
  path and confirmed mutual exclusivity.
- Switched through all ten Control Centre routes; every route measured
  `888x700` at the same compositor position.
- Repeated the important Overview-to-Power in-place switch and confirmed no
  width jump or lasting clipping.
- Inspected the current Insights Wiki catalog and article rendering.
- Confirmed one live Eww daemon and one Obsidian Rail after guarded recovery.

masthead result: passed

# Senomy Companion Design QA

## Selected visual source

- Current desktop reference: `/tmp/senomy-companion-current-desktop.png`
  (`1920x1080`).
- Selected edge-sidecar direction:
  `/home/Duku/.codex/generated_images/019efbe2-8acc-7161-9f04-56c1f4427d98/exec-2c20d8f9-224f-426d-8ac6-2b095e92f6df.png`.
- Transparent music-state artwork source:
  `/home/Duku/.codex/generated_images/019efbe2-8acc-7161-9f04-56c1f4427d98/exec-4723fc19-f467-4473-b4d2-1ce231ddf3e8.png`.

The selected direction shows exactly one Rail avatar separated from, but
visually joined to, the adjacent Insights dialogue. The expanded companion is
an edge sidecar; compact mode keeps a large transparent character presentation
without reserving permanent work area.

## Pending live comparison

Static implementation and contract checks must pass before the guarded live
reload. After reload, capture the Rail identity, expanded companion, compact
companion, left/right edge states, music reaction where MPRIS is available, and
coexistence with each primary surface. Compare the captures together with the
selected source at the same desktop viewport, then record and fix visible
spacing, clipping, input-region, hierarchy, and responsive issues.

final result: blocked — awaiting user-approved guarded live reload and visual comparison

# Hyprlock / SDDM Authentication-Rail Design QA

## Comparison target

- Source visual truth: `/home/Duku/.config/eww/appearance/login/sddm/preview-final.png`
- Rendered implementation: `/home/Duku/.config/eww/appearance/lock/qa/implementation-1920x1080.png`
- Full combined evidence: `/home/Duku/.config/eww/appearance/lock/qa/comparison-full.png`
- Focused rail evidence: `/home/Duku/.config/eww/appearance/lock/qa/comparison-rail.png`
- Viewport and CSS-equivalent logical size: `1920x1080`, scale 1
- Source pixels: `1920x1080`; implementation pixels: `1920x1080`
- Density normalization: none; both captures are native 1:1 output captures
- State: primary display, dark theme, named user, empty focused password field,
  default keyboard layout

## Full-view comparison

The approved SDDM capture and real Hyprlock render were placed in one combined
image before review. Both use the same 56px side inset, 198px rail height,
130px bottom gap, five separators/zones, quiet upper negative space, dark
surface treatment, periwinkle authentication accent, and compact terminal
hierarchy. The lock intentionally retains a live blurred desktop capture while
SDDM uses its static privacy-safe background.

## Focused rail comparison

The focused evidence was cropped from `y=730` through `y=980` in both native
captures. It confirms matching rail bounds, separator positions, utility icon
row, avatar center, username baseline and underline, password label and field,
filled action geometry, session region, and clock/keyboard cluster.

## Required fidelity surfaces

- Fonts and typography: both surfaces use JetBrainsMono Nerd Font with matching
  hierarchy and letter-spaced metadata. Minor Qt-versus-Pango rasterization is
  expected and does not change size, wrapping, or hierarchy.
- Spacing and layout rhythm: the final native render matches the reference rail
  geometry and alignment at the reference viewport. No persistent clipping or
  overflow is visible.
- Colors and tokens: background, rail surface, foreground, muted text, border,
  and periwinkle accent resolve from the shared appearance token source.
- Image quality and assets: the same avatar is used. Hyprlock's PNG-only image
  path uses deterministic 64px PNG projections of the exact SDDM source SVG
  icons; no substitute glyphs, emoji, or handcrafted replacements are used.
- Copy and content: `AUTH` becomes `LOCK`, and `SIGN IN` becomes `PRESS ENTER`
  because Hyprlock authentication is keyboard-driven. `RECOVER`, power, and
  restart remain non-clickable status marks so the authenticated desktop cannot
  expose command execution before unlock. These are intentional product and
  security differences.

## Comparison history

1. The previous physical-screen capture showed a P1 readability failure: the
   rail content sat at its lower edge and was nearly invisible over a dark
   desktop.
2. The first 1920x1080 nested-compositor render fixed contrast and structure,
   but found P2 vertical drift in the avatar, username, password field, session
   label, and time plus a centered rather than left-aligned password label.
3. Those positions were corrected against the focused comparison. The final
   combined and focused evidence show no remaining actionable P0/P1/P2 visual
   mismatch.

## Runtime evidence and residual gap

Hyprlock 0.9.6 parsed the deployed configuration, acquired an
`ext-session-lock-v1` lock inside a disposable nested Hyprland compositor,
loaded every projected image asset, exposed the PAM password prompt, and
rendered at 1920x1080. No missing-resource or configuration error appeared.
The sandbox did not inject password characters because no virtual-keyboard test
client is installed; the live field still uses Hyprlock's native left-aligned
password-dot renderer and the user's real-session unlock remains the final
interaction acceptance check.

final result: passed

# Command Lens and Thunar Reliquary Adoption

## Comparison target

- Launcher source/live comparison:
  `/home/Duku/.config/eww/appearance/launcher/qa/frame-source-vs-live-pass-1.png`.
- Launcher responsive evidence:
  `appearance/launcher/qa/narrow-pass-2.png` and
  `appearance/launcher/qa/touch-pass-1.png`.
- Thunar source/live comparison:
  `/home/Duku/.config/eww/appearance/file-manager/qa/source-vs-live-pass-1.png`.
- Thunar state evidence: `appearance/file-manager/qa/before-vs-live-pass-1.png`
  and `appearance/file-manager/qa/touch-pass-1.png`.

## Findings

1. The actual Super+R Rofi Command Lens and live GTK 3 Thunar theme consume
   repository-owned frame modules; no unused Wofi-only parallel was built.
2. Both surfaces retain the approved obsidian, cold-silver, ivory, and violet
   hierarchy with canonical fixed corner geometry and semi-opaque fills.
3. Launcher input, rows, categories, footer controls, and Thunar toolbar,
   sidebar, content pane, status bar, and menus keep usable allocation without
   clipping in the captured pointer and touch variants.
4. Rofi and GTK parsers, appearance generation, theme contracts, deployment
   contracts, and whitespace checks pass. No actionable P0/P1/P2 mismatch
   remains in the combined comparisons.

final result: passed

# Dedicated Calendar, Notifications, Power, Bell, and Fullscreen

## Comparison target

- Standard-tier source plus three live flyouts in one comparison input:
  `/home/Duku/.config/eww/appearance/shell/qa/flyouts-source-vs-live-final.png`.
- Normal work area versus true fullscreen in one comparison input:
  `/home/Duku/.config/eww/appearance/shell/qa/fullscreen-normal-vs-true-final.png`.
- Focused notification control:
  `/home/Duku/.config/eww/appearance/shell/qa/notification-bell-pass-1.png`.
- Guarded power confirmation:
  `/home/Duku/.config/eww/appearance/shell/qa/power-confirm-reboot-panel-pass-2.png`.
- Viewport: 1920x1080, scale 1, standard Rail density, live VS Code client.

## Findings

1. **Frame and token fidelity:** Calendar, Notifications, and Power reuse the
   canonical Standard fixed corners, extensible edges, safe insets, glass fill,
   and clock/power motifs. Their visual density remains subordinate to the
   Large primary surfaces and consistent with the volume/tray family.
2. **Layout and spacing:** Final allocations are 430x470, 480x560, and 440x560.
   Headers, close buttons, status chips, content, and footers clear the 32px
   corner modules. The notification ledger shows three readable rows before
   scrolling; Power preserves five 48px-plus actions and a stable confirmation
   dock without changing window height.
3. **Bell centring:** Removing the inherited 1px SVG translation places the
   bell on the optical centre of its 64x52 stage. The count remains an overlay
   at the top-right and does not participate in icon allocation.
4. **Core behavior:** Clock/date, bell, and power each open their own flyout.
   The state coordinator permits only one primary or flyout window at a time;
   outside-click and Escape still dismiss. DND and live dismissal use fixed
   SwayNC commands. Local history clearing and every session action retain an
   explicit confirmation state; no destructive action was invoked during QA.
5. **Fullscreen:** The focused client changes from 22,22 at 1876x986 to 0,0 at
   1920x1080 in Hyprland fullscreen mode 2. The exclusive Rail is absent while
   fullscreen and reopens after exit. The top edge is fully on-screen and no
   reserved bottom area remains.
6. **Native client decoration:** Ordinary clients keep the accepted 18px
   compositor rounding, silver-to-violet active border, muted inactive border,
   and soft shadow. Repository SVG ornaments remain on app-owned/Eww surfaces;
   Hyprland does not expose a stable native facility for painting those SVG
   modules around arbitrary clients.

## Comparison history

- Pass 1 exposed two implementation defects: unitless SCSS line-height values
  made Eww fall back to unstyled GTK, and the Notifications scroll collapsed
  because its content root did not expand. The unsupported declarations were
  removed, the guarded reload restored the Rail, and the notification root now
  fills the window.
- The first fullscreen helper used legacy dispatcher syntax. Live Lua-provider
  evidence rejected it before any geometry changed; the helper now detects the
  provider and dispatches the typed Lua fullscreen action. Entry and exit then
  passed with exact geometry and Rail restoration.
- The first Power confirmation increased the GTK minimum height. Action rows
  were compacted above the 48px interaction minimum and the confirmation dock
  was made allocation-stable. Normal and armed states now remain 440x560.

## Validation

- 16 focused state-machine transitions passed.
- 42 full surface routes/transitions passed and restored the idle Rail.
- Isolated Eww/Yuck parsing defines all 11 windows; SCSS, Bash, JSON,
  Hyprland Lua, deployment, action allowlist, and whitespace checks pass.
- Live tracked/Lua and compatibility-conf mirrors are byte-identical;
  `hyprctl configerrors` is empty.

No actionable P0/P1/P2 issue remains. Physical portrait/touch-only capture is
still a P3 follow-up; deterministic narrow sizing remains covered by the
responsive state contract.

final result: passed

# Control Centre Large-frame migration

## Comparison target

- Content and interaction truth: `appearance/control/baseline-live-overview.png`
  (`888x700`) plus the ten captured pre-change routes under
  `appearance/control/qa/`.
- Visual truth: `docs/design/frame-system/live/rail-frame-system-dynamic-workspace-created-crop.png`,
  `appearance/insights/preview-live-briefing.png`, and
  `appearance/performance/qa/overview-final.png`.
- Implementation: `appearance/control/qa/overview-pass-1.png` and
  `appearance/control/qa/routes-final-contact.png`.
- Viewport: `1920x1080`, compositor scale 1; final Control layer `960x760` at
  `x=960`, `y=244`. All captures are native 1x. The 888x700 baseline is centred
  on a 960x760 canvas only for before/after composition comparison.
- State: dark shell; Overview, Network, Audio, Power, Calendar, Input, Devices,
  Applications, Appearance, and Settings with live local data.
- Full-view evidence: `appearance/control/qa/reference-comparison-final.png`
  and `appearance/control/qa/routes-final-contact.png`.
- Focused evidence: `appearance/control/qa/frame-navigation-focus-final.png`
  isolates the Large corners, controls motif, masthead, Standard route spine,
  active state, and pre-change shell at readable scale.

## Findings

1. **Fonts and typography:** The JetBrains Mono/Nerd Font stack, uppercase
   masthead, readable section hierarchy, route labels, state codes, truncation,
   and compact telemetry weights match the finished primary surfaces without
   collisions or broken wrapping.
2. **Spacing and layout rhythm:** The Large 24/22px safe zone, 12px chamber
   rhythm, 184px route spine, connected four-node buses, scroll clearance, and
   bottom-right 960x760 allocation remain stable on all ten routes.
3. **Colors and tokens:** Cold-silver structure, ivory text, graphite glass,
   sparse violet selection, and semantic success/warning/danger states use the
   canonical tokens. The former cyan perimeter and background show-through are
   absent.
4. **Image quality and asset fidelity:** Visible ornament uses the existing
   generated Large/Standard SVG modules at authored optical sizes. No raster
   placeholder, new image asset, inline SVG, emoji, or CSS-drawn substitute was
   introduced.
5. **Copy and content:** Existing telemetry, source, privacy, confirmation,
   maintenance, and capability-unavailable copy is preserved. No action scope
   or live value was fabricated.
6. **States and interactions:** All ten routes, cross-surface transitions,
   repeat toggles, close controls, scrollable dense routes, selected states,
   and guarded Process/Benchmark surfaces passed the 36-route harness. Control
   action scripts and confirmation commands were not changed.
7. **Accessibility and responsiveness:** Controls retain labels, tooltips,
   focus/hover states, and at least 36px desktop targets. Narrow and phone
   projections retain their existing route-orientation logic and receive safe
   frame padding; no persistent desktop control is clipped.

No actionable P0/P1/P2 difference remains.

## Comparison history

- The first rendered comparison passed without an actionable P0/P1/P2 issue.
  All ten routes remained exactly 960x760, so no post-comparison visual fix was
  required.

## Residual test gaps

- The reference laptop verified the standard landscape profile. Portrait,
  phone, touch, multi-scale, and non-T480 hardware remain broader platform QA.
- No disruptive network, Bluetooth, power, application, or maintenance action
  was executed during visual QA; existing confirmation and handoff code was
  preserved and route-tested.

final result: passed

# Performance Dashboard Large-frame migration

## Comparison target

- Source visual truth:
  `docs/design/frame-system/live/rail-frame-system-dynamic-workspace-created-crop.png`
  (`1920x120`) and `appearance/insights/preview-live-briefing.png`
  (`960x760`).
- Implementation screenshots: `appearance/performance/qa/overview-final.png`
  and `appearance/performance/qa/cpu-pass-2.png` (`1480x760` each).
- Viewport: `1920x1080`, compositor scale 1, Performance layer `1480x760` at
  `x=220`, `y=244`; source and implementation use native 1x captures.
- State: dark shell; all seven Performance routes with live telemetry;
  Processes and Benchmarks retain guarded-control mode.
- Full-view comparison evidence:
  `appearance/performance/qa/reference-comparison-final.png` and
  `appearance/performance/qa/routes-final-contact.png`.
- Focused comparison evidence:
  `appearance/performance/qa/frame-navigation-focus-final.png`; this isolates
  the fixed Large corners, telemetry motif, header rhythm, Standard route
  frame, and active-route treatment at readable 1x size.

## Findings

1. **Fonts and typography:** JetBrains Mono/Nerd Font fallback, condensed
   uppercase hierarchy, weights, truncation, and small telemetry labels match
   the Rail and Insights language without wrapping or collision.
2. **Spacing and layout rhythm:** The 24/22px Large safe zone, 12px chamber
   rhythm, 1480x760 outer geometry, four-column KPI row, paired history nave,
   and reclaimed two-column Overview footer remain aligned on every route.
3. **Colors and tokens:** Ivory, cold silver, structural graphite, violet
   focus, and truthful semantic accents come from the canonical frame/theme
   tokens. No competing palette was introduced.
4. **Image quality and asset fidelity:** All visible ornaments use the existing
   generated Large/Standard SVG modules at their authored optical sizes. No
   raster placeholder, inline SVG, emoji, CSS drawing, or new image asset was
   introduced.
5. **Copy and content:** Existing truthful telemetry, provenance, retention,
   safety, and unavailable-state copy is preserved. The duplicate Senomy
   Observer component and its diagnostics CTA are absent from Overview.
6. **States and interactions:** Overview, CPU/GPU, Memory, Storage, Network,
   Processes, and Benchmarks were opened live. Active routes, scrolling,
   process selection controls, benchmark warning/stop state, and close/surface
   coordination remain visible and operational.
7. **Accessibility and responsiveness:** Real buttons retain tooltips, focus
   styling, and practical targets. Compact, narrow, phone, and touch overrides
   remain in the shared shell; no persistent control is hidden by overflow.

No actionable P0/P1/P2 difference remains.

## Comparison history

- Pass 1 found one P2 viewport regression: the CPU route widened the live layer
  from 1480 to 1500px because the eight logical-thread instruments retained too
  much horizontal padding. Their internal padding was reduced from 9px to 7px
  while preserving content and target size.
- Post-fix evidence is `appearance/performance/qa/cpu-pass-2.png` and
  `appearance/performance/qa/frame-navigation-focus-final.png`. All seven
  routes then held `1480x760`; the 36-route transition harness passed and
  restored the idle bar.

## Residual test gaps

- The reference laptop verified the standard landscape profile. Narrow, phone,
  touch, multi-scale, and non-T480 hardware remain broader platform QA work.
- The benchmark was observed in its existing running/cooldown state; no new
  benchmark or destructive process action was started during this visual pass.

final result: passed

# Senomy Insights Luminous Reliquary Design QA

## Comparison target

- Source visual truth: `docs/design/frame-system/live/rail-frame-system-dynamic-workspace-created-crop.png`
  (`1920x120`, compositor scale 1), supported by the pre-change Insights capture
  `docs/design/surface-redesign/baseline/current-run/insights-briefing.png`
  (`766x716`).
- Final implementation: `appearance/insights/preview-live-full.png`
  (`1920x1080`, compositor scale 1; Insights layer `960x760`).
- Combined comparison: `appearance/insights/qa/rail-insights-comparison.png`
  (`1920x1200`; equal-width 1x source Rail and live desktop capture).
- Focused route comparison: `appearance/insights/qa/routes-contact-sheet.png`
  (all eight `960x760` live route captures, normalized to `480x380` cells).
- State: standard laptop density, dark theme, nominal live telemetry, Briefing
  selected; route sheet also covers Notifications, Timeline, Updates,
  Diagnostics, Console, Reports, and Wiki.

## Findings

- P0: none.
- P1: none.
- P2: none after iteration.
- Typography keeps the Rail's JetBrains Mono/Nerd Font contract, establishes a
  20px primary title and 12px reading baseline, and preserves wrapping and
  source/state hierarchy across dense routes.
- Spacing uses the Large tier's exact 24px horizontal/22px vertical safe zone,
  a 22px shell/instrument rhythm, 44px route targets, and a stable two-pane
  Wiki measure without clipping the panel or persistent controls.
- The final field is neutral obsidian. Ivory/silver owns structure; violet is
  local to active routes, state labels, frame nodes, and diagnostic marks.
- All visible frame imagery is composed from the generated Large/Standard SVG
  modules. Corners and motifs retain manifest dimensions; only neutral edge
  modules stretch. Existing route icons and copy remain intact.
- Briefing is now a ranked evidence ribbon; notifications and updates read as
  ledgers; Timeline uses a vertical event rail; Diagnostics and Console retain
  their allowlisted boundaries; Reports remains an evidence docket; Wiki keeps
  its bounded local reader.

## Comparison history

1. The pre-change panel was a flat cyan-outlined `750x700` application window
   with a generic left rail, small prose, and no production frame modules.
2. The first live reload exposed a P0 stylesheet fallback: one non-ASCII dash
   caused Eww 0.5's compiled `@charset` rule to be rejected. The source was
   returned to ASCII and the generator now projects a self-contained runtime
   stylesheet; the live frame and typography then rendered correctly.
3. The first framed capture retained a P2 violet field across the reading
   plane. The Large shell gradient was changed to neutral surface tokens. The
   final combined comparison shows sparse violet signaling consistent with the
   Rail.

## Interaction and validation coverage

- All eight Insights routes were switched and captured through the live Eww
  daemon; scrolling content remains bounded inside the `960x760` layer.
- The full panel acceptance suite passed 36 routes/transitions and restored an
  idle bar with `active_surface=none` and `active_flyout=none`.
- No additional focused crop was required: the 1x route captures keep labels,
  frame corners, route states, and dense row structure readable.

final result: passed

# Obsidian Rail Edge-to-Edge Hover Restoration

## Comparison target

- Source visual truth: `/home/Duku/.config/eww/assets/mockups/ChatGPT Image Aug 26, 2026, 05_32_43 AM.png` (`1672x941`).
- Density-normalized source Rail: `/home/Duku/.config/eww/docs/design/rail-pass/reference-rail-1920x160.png` (`1920x160`).
- Resting live implementation: `/home/Duku/.config/eww/docs/design/rail-pass/hover-controls-clean-rest-rail.png` (`1920x160`).
- Full-view combined evidence: `/home/Duku/.config/eww/docs/design/rail-pass/hover-restoration-reference-vs-clean-current.png` (`1920x320`).
- Focused interaction evidence:
  - Applications: `/home/Duku/.config/eww/docs/design/rail-pass/hover-controls-clean-applications-rail.png`.
  - Notifications: `/home/Duku/.config/eww/docs/design/rail-pass/hover-controls-clean-notifications-v2-rail.png`.
  - Power: `/home/Duku/.config/eww/docs/design/rail-pass/hover-controls-clean-power-v2-rail.png`.
  - Senomy avatar: `/home/Duku/.config/eww/docs/design/rail-pass/hover-controls-final-v3-avatar-rail.png`.
  - Telemetry: `/home/Duku/.config/eww/docs/design/rail-pass/hover-controls-final-v3-telemetry-rail.png`.
- Viewport: `1920x1080`, compositor scale 1. Both comparison crops are `1920x160`; no further density normalization was required.
- State: dark theme, workspace 1, no primary surface, no flyout. Hover captures use the named control under the compositor pointer.

## Findings and comparison history

1. The pre-fix live capture showed the reported P1 interaction regression: the Applications target had no visible hover response. The final Rail cascade had explicitly made hover backgrounds and shadows transparent.
2. The controls were also only 62px tall inside 96px islands, producing a P2 dead perimeter where an eventual hover could not reach the island edge. System and calendar boxes retained 2px inter-control spacing that interrupted the hover surface.
3. Controls now use the island's 94px inner height, zero parent padding, zero inter-control spacing, edge-aware corner radii, and 160ms color/background/border/shadow transitions. The live Applications, Notifications, Power, Senomy-avatar, and telemetry captures show continuous edge-to-edge hover fills without changing surrounding geometry.
4. The first live iteration exposed persistent GTK focus styling on Applications. Focus is now visually neutral at rest and hover wins when both states coexist. The resting capture after Notifications confirms the filled hover and underline clear on pointer exit.

## Required fidelity surfaces

- Fonts and typography: unchanged; JetBrains Mono hierarchy, weights, wrapping, and live copy remain stable during hover.
- Spacing and layout rhythm: hover owns the full island interior and respects the outer 1px border. Removing the 2px child spacing eliminates the unfocused seams without moving island bounds or icons.
- Colors and visual tokens: hover uses a restrained neutral-white tint plus the canonical violet bottom trace and inner bloom. Active states retain a stronger violet tint and remain distinct.
- Image quality and assets: chibi, notification, Power, workspace, and system icon assets are unchanged and remain sharp at their existing allocations.
- Copy and content: all live workspace, telemetry, date, notification, battery, and Senomy values remain truthful; only interaction styling changed.

## Runtime evidence

- `main-bar` remained active after the final live verification.
- Applications, Notifications, Power, Senomy avatar, and telemetry were exercised independently with the real compositor pointer.
- The cursor was restored outside the Rail, and the resting capture confirmed that hover styling clears.
- SCSS compilation, isolated Eww parsing, and targeted whitespace validation passed.

No actionable P0/P1/P2 finding remains. The mock does not define a hover frame, so the user-specified edge-to-edge animated hover behavior is the interaction source of truth while the mock remains the resting visual source.

final result: passed

# Obsidian Rail / Luminous Reliquary Final Glass Pass

## Comparison target

- Source visual truth:
  `/home/Duku/.config/eww/assets/mockups/ChatGPT Image Aug 26, 2026, 05_32_43 AM.png`
  (`1672x941`).
- Density-normalized source Rail:
  `/home/Duku/.config/eww/docs/design/rail-pass/reference-rail-1920x160.png`
  (`1920x160`).
- Final live implementation:
  `/home/Duku/.config/eww/docs/design/rail-pass/live-glass-v6-rail.png`
  (`1920x160`).
- Full-view comparison evidence:
  `/home/Duku/.config/eww/docs/design/rail-pass/reference-vs-live-glass-v6.png`
  (`1920x320`).
- Focused Senomy evidence:
  `/home/Duku/.config/eww/docs/design/rail-pass/reference-vs-live-v6-senomy-2x.png`.
- Focused clock/notification evidence:
  `/home/Duku/.config/eww/docs/design/rail-pass/reference-vs-live-v6-clock-4x.png`.
- Wallpaper/live-empty-state evidence:
  `/home/Duku/.config/eww/docs/design/rail-pass/live-cathedral-wallpaper-v2.png`
  (`1920x1080`).

Viewport and CSS-equivalent logical size are `1920x1080` at compositor scale
1. Source and implementation Rail crops were normalized to the same
`1920x160` pixel region before comparison. The source contains illustrative
workspace applications and telemetry; the implementation intentionally uses
truthful live state. The final comparison state is dark theme, no primary
surface, no flyout, normal workspace 1 active, five visible workspace anchors,
and nine live notifications.

## Required fidelity surfaces

- Fonts and typography: the implementation retains JetBrains Mono throughout.
  Number, metadata, metric, identity, and dialogue hierarchy match the source's
  condensed terminal treatment. Remaining glyph-shape differences are the
  source raster's AI rendering rather than wrapping, weight, or allocation
  failures.
- Spacing and layout rhythm: the final enclosure is aligned to the same lower
  safe inset. Workspace centres, the post-workspace divider, the Senomy start,
  and the telemetry/system/calendar/Power boundaries are within a few pixels
  of the normalized source. The right group expands inward as one sequence;
  there is no uncontrolled gap between telemetry and system controls.
- Colors and visual tokens: the live Rail uses translucent obsidian fills,
  neutral silver borders and multi-radius bloom, with violet limited to active
  workspace, Senomy identity, telemetry separators, and the notification
  badge. Hyprland supplies real namespace-scoped backdrop blur behind non-zero
  alpha rather than a solid GTK imitation.
- Image quality and asset fidelity: the generated cathedral source is a clean
  1672x941 raster and its deterministic 1920x1080 projection remains soft and
  readable behind the Rail. The user-requested existing Senomy browsing chibi
  replaces the composition-study avatar; this is an intentional override of
  the mock. Repository/system icon assets remain rasterized cleanly and no
  emoji, CSS drawing, or placeholder is used.
- Copy and content: `Seno: Everything looks steady.` matches the target's
  hierarchy. CPU, memory, uptime, battery, workspace applications, time, date,
  and notification count remain live values rather than copying the mock.
- Icons and state: the clock/notification crop confirms the badge count is
  legible at the bell's upper-right. Hover/focus rules keep backgrounds
  transparent with a narrow underline/glow, and the charging battery state no
  longer creates the previous rectangular pseudo-hover block.
- Accessibility and behavior: workspace and island controls retain labels,
  tooltips, native button semantics, focus styling, and their existing guarded
  action paths. The five workspace anchors preserve practical pointer targets;
  empty anchors fabricate no application state.

## Comparison history

1. The pre-pass live Rail had a P1 behavior fault: switching the normal
   workspace left `special:magic` visibly covering it. The workspace action now
   closes a visible special overlay first. A live check confirmed workspace 2
   and Firefox became visible, then restored workspace 1.
2. The first glass render fixed the wallpaper and right grouping but exposed a
   P1 surface error: the edge wrapper color bled through the entire card,
   making Senomy and other islands look solid grey/purple. Borders and shadows
   moved to the actual translucent island surfaces and the layer rule changed
   to `xray = false`.
3. The second and third comparisons found P2 enclosure, workspace-floor,
   notification-placement, and charging-state drift. The outer glass rail was
   restored, workspace anchors 1 through 5 were reinstated, the battery block
   fill was removed, and the badge received a bounded positioning stage.
4. The fourth and fifth comparisons found P2 horizontal rhythm drift. The
   workspace cells/divider, wider Senomy-to-telemetry separator, and individual
   island widths were measured against the normalized reference and corrected.
5. The final v6 full and focused comparisons show no remaining actionable
   P0/P1/P2 mismatch. The different chibi and dynamic values are explicit user
   and product requirements; tiny anti-aliasing and source-raster differences
   are P3 only.

## Interaction and runtime evidence

- The same Rail action used by the buttons dismissed a visible special
  workspace, activated workspace 2, and exposed Firefox rather than only
  moving the underline.
- The live layer is namespace `senomy-rail`, `1920x142` at `y=938`.
- One Eww daemon, one `main-bar`, one `swaybg`, active
  `workspaces.service`, matching tracked/live Hyprland Lua files, and an empty
  `hyprctl configerrors` result were observed after the final reload.
- Isolated Eww parsing, SCSS compilation, Rail contracts, appearance contracts,
  shell syntax, JSON validation, and repository whitespace validation passed.

## Findings

- P0: none.
- P1: none.
- P2: none.
- P3: compositor blur strength is shared with the current Hyprland blur
  settings; per-island blur-radius tuning would require a compositor-level
  extension and is unnecessary for the approved restrained glass treatment.

final result: passed

# Obsidian Rail Dynamic Paddingless Correction

- Source visual truth: `/home/Duku/.config/eww/assets/mockups/ChatGPT Image Aug 26, 2026, 05_32_43 AM.png` (`1672x941`).
- Pre-correction live capture: `/home/Duku/.config/eww/docs/design/rail-pass/current-user-correction-pre-rail.png` (`1920x180`).
- Final live capture: `/home/Duku/.config/eww/docs/design/rail-pass/dynamic-paddingless-v2-hover-senomy-rail.png` (`1920x180`).
- Same-image before/after evidence: `/home/Duku/.config/eww/docs/design/rail-pass/pre-vs-dynamic-paddingless-hover-v2.png` (`1920x360`).
- Normalized reference/final evidence: `/home/Duku/.config/eww/docs/design/rail-pass/reference-vs-dynamic-paddingless-v2.png` (`1920x320`).
- Viewport: `1920x1080`, scale 1; dark theme; workspace 1; Senomy hover state.

The P1 enclosing frame and fabricated five-slot workspace floor are removed.
The P2 Senomy tooltip/underline overlay and padded rectangular control hovers
are removed. Typography, live copy, existing chibi, generated wallpaper,
translucent island colors, luminous borders, icon assets, real notification
count, and right-aligned island order remain intact. Dynamic values and the
user-requested chibi intentionally differ from the illustrative mock.

Focused hover evidence was required because the reported defect occurred only
under pointer interaction; both Senomy and system-control hover states were
captured live without a filled block. No actionable P0/P1/P2 finding remains.

final result: passed

# Obsidian Rail Horizontal Hover Allocation Correction

## Comparison target

- Resting source visual truth: `/home/Duku/.config/eww/assets/mockups/ChatGPT Image Aug 26, 2026, 05_32_43 AM.png` (`1672x941`).
- Normalized resting source: `/home/Duku/.config/eww/docs/design/rail-pass/reference-rail-1920x160.png` (`1920x160`).
- Final resting implementation: `/home/Duku/.config/eww/docs/design/rail-pass/width-audit-final-rest-rail.png` (`1920x160`).
- Full-view combined evidence: `/home/Duku/.config/eww/docs/design/rail-pass/width-fill-reference-vs-final.png` (`1920x320`).
- Focused before/after interaction evidence: `/home/Duku/.config/eww/docs/design/rail-pass/width-audit-before-vs-final.png` (`1840x240`). The upper row is pre-fix and the lower row is final; columns are Senomy, system tray, Notifications, and Power.
- Viewport: `1920x1080`, compositor scale 1. Full Rail crops are normalized 1:1 to `1920x160`; focused crops preserve native pixels.
- State: dark theme, workspace 1, no primary surface, no flyout; each focused crop shows the named control under the real compositor pointer.

## Findings and comparison history

1. The reported P1 defect was horizontal rather than vertical. GTK allocated the multi-control island's minimum width to the outer box but left surplus width after its children: about 40px after Senomy dialogue, 43px after the tray arrow, and 24px after Notifications. That unowned width could never receive the child's hover state.
2. The first width pass made each trailing control expandable. System tray and Notifications then reached their right borders; telemetry and Power were confirmed already edge-to-edge.
3. Senomy retained its gap because the `senomy-identity-group` wrapper itself remained content-width. Expanding that wrapper and its dialogue child removed the final dead zone while preserving avatar size and the left-aligned copy baseline.
4. Final focused evidence shows every multi-control island's trailing hover surface meeting its inner border. No icon or label moves on hover, and the resting full Rail keeps its established geometry.

## Required fidelity surfaces

- Fonts and typography: unchanged. JetBrains Mono family, weights, baselines, wrapping, and live copy are stable before, during, and after hover.
- Spacing and layout rhythm: unused trailing allocation is removed without changing island widths, inter-island gaps, icon order, or control heights. Only the final logical control absorbs each island's remainder.
- Colors and visual tokens: the existing neutral hover tint, violet trace, glass fill, border, and bloom are unchanged; the correction changes allocation only.
- Image quality and assets: Senomy chibi and all repository-owned control icons retain their native allocations and sharpness.
- Copy and content: Senomy, telemetry, battery, date, notification, and workspace values remain live and truthful.

## Runtime evidence

- One reachable Eww daemon, one `main-bar`, and one `senomy-rail` layer at `1920x142`, `y=938` were observed after the controlled restart.
- Senomy dialogue, telemetry, tray, Notifications, and Power were captured independently under the compositor pointer; the pointer was restored outside the Rail.
- SCSS compilation, isolated Eww parsing, targeted whitespace validation, and Hyprland configuration checks passed.

No actionable P0/P1/P2 finding remains.

final result: passed

# Obsidian Rail CSS-Fluid SVG Frame Application

## Comparison target

- Exact-width live baseline:
  `/home/Duku/.config/eww/docs/design/rail-frame-svg/live/frame-live-first-apply-rail.png`.
- Final CSS-fluid live Rail:
  `/home/Duku/.config/eww/docs/design/rail-frame-svg/live/frame-live-fluid-css-final-rail.png`.
- Same-state comparison:
  `/home/Duku/.config/eww/docs/design/rail-frame-svg/live/frame-live-exact-vs-fluid-final.png`.
- Multi-width modular validation board:
  `/home/Duku/.config/eww/docs/design/rail-frame-svg/obsidian-rail-frame-validation.png`.

## Findings

1. Workspace, Senomy, telemetry, system-control, Calendar/Notifications, and
   Power frames all consume the same modular CSS composition. No selector
   chooses an SVG from a hard-coded island width.
2. Only the straight edge layer stretches to the island's computed CSS width.
   The two 12x44 caps and 10x44 centre jewel retain fixed optical geometry.
3. Pixel comparison at 68x44, 200x44, and 397x44 reports zero changed pixels
   in the fixed corner and straight-edge samples. Interiors remain transparent.
4. The live exact-versus-fluid capture preserves frame rhythm, island gaps,
   content alignment, and the 56px control allocation across every island.
5. The guarded reload returned one Eww daemon and one `main-bar`; the live Rail
   layer remains `1920x64` at `y=1016`, with no Hyprland configuration errors.

No actionable P0/P1/P2 finding remains.

final result: passed

# Obsidian Rail Live SVG Frame Application

## Comparison target

- Art direction: the five supplied August 27 ornamental PNG studies, used only
  to judge silver rail ribs, violet crystal nodes, pointed corners, and compact
  Gothic character.
- Pre-application live Rail:
  `/home/Duku/.config/eww/docs/design/rail-frame-svg/live/frame-live-before-rail.png`.
- Final live Rail:
  `/home/Duku/.config/eww/docs/design/rail-frame-svg/live/frame-live-first-apply-rail.png`.
- Same-state combined evidence:
  `/home/Duku/.config/eww/docs/design/rail-frame-svg/live/frame-live-before-vs-first-apply.png`.
- Focused hover evidence:
  `/home/Duku/.config/eww/docs/design/rail-frame-svg/live/frame-live-hover-evidence.png`.

## Findings

1. Every standard workspace and instrument island now displays the native
   Gothic frame. Generic rectangular border strokes no longer compete with the
   silver/violet vector rails.
2. Runtime consumer widths use exact generated SVGs at 68px, 188px, 320px,
   392px, and 397px. The 44px ornament is centered inside the unchanged 56px
   island allocation; corners and stroke weights are not scaled.
3. The before/after comparison preserves Rail position, content order, live
   values, workspace count, 22px gaps, chibi artwork, and icon alignment. Only
   the border language changes.
4. Senomy and system-control hover captures retain their full interactive
   allocations. Hover fill remains inside the ornamental edge and does not
   displace content or erase the frame.
5. Offline SCSS, Eww, theme, XML, and vector-contract checks passed before the
   guarded reload. The final session has one Eww daemon, one `main-bar`, a
   `1920x64` Rail layer at `y=1016`, and no Hyprland configuration errors.

No actionable P0/P1/P2 finding remains.

final result: passed

# Obsidian Rail Production SVG Frame System

## Comparison target

- Art-direction-only source sheets:
  `/home/Duku/Downloads/ChatGPT Image Aug 27, 2026, 05_17_40 PM (1).png`
  through `(5).png`.
- Editable vector source:
  `/home/Duku/.config/eww/appearance/shared/frames/obsidian-rail-compact.svg.in`.
- Exact generated SVGs: 68x44, 200x44, and 397x44 under
  `/home/Duku/.config/eww/appearance/shared/frames/`.
- Same-board rendered evidence:
  `/home/Duku/.config/eww/docs/design/rail-frame-svg/obsidian-rail-frame-validation.png`.

## Findings

1. The shipped artwork contains SVG paths, gradients, groups, and `use`
   instances only. It contains no `image`, `foreignObject`, base64 raster, crop,
   or traced source-sheet geometry.
2. All three assets use the same four fixed 12px corner modules. Pixel
   comparison of the top-left corner crop reports zero changed pixels at
   68px, 200px, and 397px widths.
3. The straight horizontal edge sample also reports zero changed pixels across
   all widths. Width is added to the continuous path rather than scaling the
   frame, so stroke weight does not drift.
4. Intrinsic width, intrinsic height, and viewBox match at every target size.
   The centre pixel is fully transparent in every rendered projection.
5. The compact art deliberately reduces the references to silver rail ribs,
   violet crystal nodes, pointed corner modules, and restrained bloom. It does
   not attempt to preserve their painterly noise or oversized spires at 44px.

No actionable P0/P1/P2 finding remains.

final result: passed

# Obsidian Rail 56px Height, Gap Rhythm, and Screen Alignment

## Comparison target

- User target: the attached full-width Rail screenshot plus the annotated
  bottom-right screenshot identifying edge alignment and wasted vertical gap.
- Pre-correction live capture:
  `/home/Duku/.config/eww/docs/design/rail-pass/rail-56-spacing-before-full.png`
  (`1920x1080`).
- Final live capture:
  `/home/Duku/.config/eww/docs/design/rail-pass/rail-56-spacing-after-live-full.png`
  (`1920x1080`).
- Same-viewport combined evidence:
  `/home/Duku/.config/eww/docs/design/rail-pass/rail-56-spacing-before-vs-live.png`
  (`1920x280`).
- State: `1920x1080`, compositor scale 1, special workspace visible, two real
  occupied workspace islands, no primary Eww surface or flyout.

## Findings

1. The visible islands are now 56px inside a 64px layer. Avatar, clock,
   telemetry, workspace contents, notification, and system controls remain
   centered without increasing that allocation.
2. The group already supplied 22px separation, but the telemetry edge added a
   second 22px left margin. Removing it makes Seno→performance,
   performance→system, system→calendar, calendar→Power, and
   workspace→workspace gaps consistently 22px.
3. The Rail begins at x=20 and the Power island ends at x=1900. These bounds
   follow the compositor's 20px side-gap line and visually align with the open
   window frame instead of touching the screen corners.
4. Hyprland's per-side outer gap changed from `20 20 20 20` to
   `20 20 6 20`. The active window bottom moved from y=994 to y=1008 while the
   Rail begins at y=1016, reducing the measurable separation to 8px without
   altering the top or side margins.
5. The running config provider is the synchronized Lua file. Legacy and Lua
   configs both parse, repository/live pairs match, `hyprctl configerrors` is
   empty, and one Eww daemon owns one `main-bar`.

No actionable P0/P1/P2 finding remains.

final result: passed

# Obsidian Rail Compact Height and Workspace Islands

## Comparison target

- Source visual truth: `/home/Duku/.config/eww/assets/mockups/ChatGPT Image Aug 26, 2026, 05_32_43 AM.png` (`1672x941`).
- Normalized source Rail: `/home/Duku/.config/eww/docs/design/rail-pass/reference-rail-1920x160.png` (`1920x160`).
- Final resting implementation: `/home/Duku/.config/eww/docs/design/rail-pass/compact-workspaces-final-rest-rail.png` (`1920x160`).
- Combined visual evidence: `/home/Duku/.config/eww/docs/design/rail-pass/reference-vs-compact-workspaces-final.png` (`1920x320`).
- Two-workspace functional evidence: `/home/Duku/.config/eww/docs/design/rail-pass/compact-workspaces-two-live-rail.png` (`1920x150`).
- Viewport: `1920x1080`, compositor scale 1, dark theme, no primary surface and no flyout.

## Findings

1. The previous Rail reserved 142px while its 96px islands were shifted down by a 17px internal margin. The final layer reserves 104px, aligns 80px islands with a 4px internal offset, and returns 38px to application windows.
2. Workspace navigation no longer reads as loose content. Every real positive workspace is a separate 80px glass island using the instrument border, radius, translucent fill, silver bloom, and violet active trace. There is no enclosing workspace frame.
3. A live switch to workspace 2 published IDs 1 and 2, visibly changed the compositor workspace, and rendered two separate islands. Returning to workspace 1 removed the empty workspace 2 and restored `[1]`; the indicators are not hard-coded.
4. The system island is 320px wide and its five controls have equal 64px allocations. Icon centres are separated by exactly 64px, child spacing is zero, and each control retains its full-column hover surface.
5. SCSS compilation, isolated Eww parsing, Rail contracts, whitespace validation, one-daemon/one-window checks, and `hyprctl configerrors` passed after the guarded live restart.

No actionable P0/P1/P2 finding remains for this correction.

final result: passed

# Obsidian Rail 44px Allocation and Badge Acknowledgement

## Comparison target

- User target: the attached compact clock/notification island and the explicit
  request for a real 44px island rather than a minimum overridden by content.
- Pre-correction live capture:
  `/home/Duku/.config/eww/docs/design/rail-pass/ultracompact-before-rail.png`
  (`1920x160`).
- Final live capture:
  `/home/Duku/.config/eww/docs/design/rail-pass/ultracompact-44-final-full.png`
  (`1920x1080`).
- Height comparison:
  `/home/Duku/.config/eww/docs/design/rail-pass/ultracompact-80-vs-44.png`
  (`1920x320`).
- Badge-state comparison:
  `/home/Duku/.config/eww/docs/design/rail-pass/ultracompact-44-notification-before-vs-after.png`
  (`300x180`).
- Viewport: `1920x1080`, compositor scale 1, standard Rail density, two real
  occupied workspaces, no primary surface and no flyout.

## Findings

1. Changing `.mainbar-island-groups` to 44px could not affect the visible
   result because 80px island surfaces, 78px buttons, 76px telemetry content,
   a 54px avatar frame, and the workspace stack remained larger descendants.
2. The final allocation is coordinated from outside inward: 56px exclusive
   layer, 44px islands, 42px controls, 30px avatar source, 16px system icons,
   18px notification artwork, and 12px workspace application cells. The live
   compositor reports `1920x56` at `y=1024`; content remains centered and does
   not reinforce a larger height.
3. The two-row clock and date remain legible, both occupied workspace islands
   preserve their number/application/dot hierarchy, and the five system
   controls preserve their equal 64px horizontal allocations.
4. A live six-notification state showed the numeric badge before
   acknowledgement. Running the same acknowledgement command chained into the
   notification button set `rail_notification_ack_at` to the current listener
   observation and removed the badge without changing the bell, count, DND, or
   provider state.
5. SCSS compilation, isolated Eww parsing, Bash syntax, Rail contracts,
   whitespace checks, one-daemon/one-window checks, and
   `hyprctl configerrors` passed.

No actionable P0/P1/P2 finding remains.

final result: passed

# Luminous Reliquary Frame System and Compact Rail Deployment

## Comparison target

- Source visual truth:
  `/home/Duku/Downloads/ChatGPT Image Aug 28, 2026, 06_21_33 AM.png`
  (`1536x1024`, supplied design sheet, 1x source density).
- Rendered production harness:
  `/home/Duku/.config/eww/docs/design/frame-system/harness/frame-system-harness.png`
  (`1500x1120`, actual generated SVG modules at 1x validation dimensions).
- Final live implementation:
  `/home/Duku/.config/eww/docs/design/frame-system/live/rail-frame-system-canonical-apply-final.png`
  (`1920x1080`, compositor scale 1, Rail `1920x64` at `y=1016`).
- Same-input full comparison:
  `/home/Duku/.config/eww/docs/design/frame-system/reference-harness-live-comparison.png`
  (`1920x760`; source and production harness above, live Rail below).
- Focused resting evidence:
  `/home/Duku/.config/eww/docs/design/frame-system/live/rail-before-vs-frame-system.png`.
- Focused dynamic evidence:
  `/home/Duku/.config/eww/docs/design/frame-system/live/rail-frame-system-dynamic-workspace-created-crop.png`
  (`1920x120`).
- State: dark desktop, standard Rail density, primary surfaces and flyouts
  closed, real workspace IDs 1, 2, and 3 at rest.

## Findings

1. **Shape and asset fidelity:** The implementation reproduces the sheet's
   fixed-corner, neutral-edge, anchored-node, safe-centre grammar without using
   the supplied raster. Compact, Standard, and Large have distinct geometry.
   Corners, motifs, and crests retain aspect ratio; only neutral edges absorb
   width. Native SVG construction is the explicit production requirement.
2. **Spacing and layout rhythm:** Compact remains a right-aligned set of six
   independent Rail component types with no enclosing frame. The accepted 20px
   monitor-edge alignment, 22px inter-island rhythm, 56px interaction
   allocation, and 64px exclusive layer remain stable. Frame art adds no dead
   hover padding.
3. **Colors and tokens:** Ivory/cold-silver structure dominates steel and
   structural black; violet is limited to small nodes and semantic emphasis.
   The live idle state is intentionally quieter than the presentation sheet
   and rises through CSS interaction states rather than duplicate assets.
4. **Typography and copy:** Existing JetBrains Mono/Symbols Nerd Font fallback,
   sizes, weights, dialogue, telemetry, clock, and dynamic values are
   unchanged. Text stays inside each safe centre without clipping.
5. **Icons and image quality:** Existing repository-owned icons and the Senomy
   chibi remain sharp and centred. QA PNGs are test rasterizations; all 35 live
   frame modules are transparent SVG without embedded image or foreign content.
6. **Workspace behavior and responsiveness:** A live action created and
   switched to workspace 4, published it through the existing listener, and
   rendered a fourth independent frame. Returning to workspace 1 removed the
   empty workspace 4 and restored IDs 1/2/3. The adaptive number bay and
   centred 1/2/3/4/+N app states pass the Compact width matrix.
7. **Interactions and accessibility:** Existing click, scroll, tooltip, hover,
   focus, selected, warning, and disabled routes remain. Performance, Insights,
   Calendar/Control Centre, Power section, Audio flyout, notification
   acknowledgement, and workspace commands were exercised and restored closed.
   No destructive action was issued; SVG backgrounds do not intercept input.

The full-view comparison covers tier hierarchy and live composition. The
resting and dynamic crops cover the workspace bay, icon grid, corners, motifs,
gaps, and states that are not readable at the full sheet scale.

## Comparison history

- Initial live-facing pass: Eww's source watcher encountered the unsupported
  compiled declaration `min-width: 100%` and briefly showed GTK fallback
  styling. The declaration was removed before guarded reload, the Rail
  recovered, and compiled Eww CSS parsing was added to the permanent validator.
- Post-fix evidence: `rail-frame-system-canonical-apply-final.png`,
  `rail-before-vs-frame-system.png`, and
  `reference-harness-live-comparison.png`. No actionable P0/P1/P2 visual or
  functional mismatch remains.

## Residual test gaps

- Standard and Large are validated asset families, not live surface
  migrations. Per-surface interaction and responsive QA begins when an
  approved consumer adopts either tier.
- Touch-only gestures were not changed or re-tested because this deployment
  changes backgrounds and one pointer-neutral label row, not input routes.

final result: passed

# Workspace Indicator Bounded Carousel

## Comparison target

- Source visual truth:
  `/home/Duku/.config/eww/docs/design/workspace-carousel/live/workspace-carousel-before.png`
  (`1920x1080`, approved pre-change Rail with two real workspaces).
- Non-overflow comparison:
  `/home/Duku/.config/eww/docs/design/workspace-carousel/live/workspace-carousel-nonoverflow-before-vs-after.png`
  (`640x240`, equal 1x crops; source above, implementation below).
- Implemented state matrix:
  `/home/Duku/.config/eww/docs/design/workspace-carousel/live/workspace-carousel-state-matrix.png`
  (`900x480`, 1x crops in the order exact capacity, first overflow, final page,
  runtime removal, restored non-overflow).
- Canonical final implementation:
  `/home/Duku/.config/eww/docs/design/workspace-carousel/live/workspace-carousel-canonical-final.png`
  (`1920x1080`, guarded post-apply capture).
- Viewport: `1920x1080`, compositor scale 1, standard Rail density, Rail
  `1920x64` at `y=1016`.
- State: dark shell, no primary Eww surface or flyout, real user workspaces 1
  and 2 plus bounded temporary Kitty fixtures used only during QA.

## Findings

1. **Fonts and typography:** Workspace IDs and application imagery keep the
   existing JetBrains Mono/Nerd Font fallback, size, weight, centring, and bay
   clearance. No label was reduced or wrapped to accommodate overflow.
2. **Spacing and layout rhythm:** Four 68x56px workspace islands retain the
   established 22px separation. At overflow, 28x56px navigation controls bound
   the region. The Senomy island begins at x=446 in every matrix row, showing
   that exact capacity, overflow, navigation, removal, and restoration do not
   shift neighbouring islands.
3. **Colors and tokens:** Existing obsidian, silver, ivory, and violet Rail
   tokens remain the visible source of fill, frame, hover, active, and disabled
   state. The controls reuse generated junction motifs and the existing tray
   arrow asset; they introduce no competing palette.
4. **Image quality and asset fidelity:** Workspace frame modules, application
   icons, Senomy artwork, and repository-owned navigation artwork remain sharp
   at 1x. No complete frame is stretched and no raster placeholder, inline SVG,
   emoji, or CSS-drawn substitute was introduced.
5. **Copy and content:** Dynamic workspace IDs and app cells remain truthful.
   Tooltips name previous/next availability; no decorative or fabricated
   workspace copy was added.
6. **States and interactions:** Counts 2, 4, 5, 7, and 8 were exercised.
   Repeated concurrent next/previous actions clamped cleanly, manual movement
   left Hyprland workspace 1 active, switching to workspace 8 auto-followed to
   offset 4, runtime removal clamped to offset 3, and cleanup restored IDs 1/2
   with offset 0. Boundary controls are disabled but retain allocation.
7. **Accessibility and responsiveness:** Controls are real labelled Eww
   buttons with tooltips and 28x56px pointer targets; workspace buttons retain
   their 68x56px targets. Horizontal touchpad and vertical wheel directions are
   accepted. Narrow filtering and phone active-only behavior remain sourced
   from `bar_layout`.

No actionable P0/P1/P2 difference remains.

## Comparison history

- The first live source-watcher draft placed generated loop children directly
  under GtkStack, which Eww rejected and briefly closed the Rail. It was
  replaced before final QA with two valid static page buffers, the daemon was
  recovered through the guarded reload path, and isolated parsing now passes.
- The first rapid-input pass exposed transient Eww reads under simultaneous
  helper processes. The helper now queues updates with `flock`, retries IPC
  reads, and validates both JSON inputs. Eight concurrent next and previous
  actions then reached only the legal offsets 4 and 0.
- The first runtime-removal pass exposed a stored offset that was already above
  the new maximum. Change detection now compares the reconciled offset against
  the stored value; the seven-workspace live state corrected from 4 to 3 and
  rendered a complete 4/5/6/7 page with no blank end gap.

## Residual test gaps

- Native slide motion was visually observed on the reference laptop, but no
  touch-only hardware gesture capture was available. The same event route is
  covered for Eww's horizontal and vertical scroll direction strings.
- Narrow and phone behavior is deterministic-contract tested; this pass did
  not alter or live-switch the reference monitor into those profiles.

final result: passed

# Shell Glass, Utility Trays, and Compositor Corners

## Comparison target

- Source visual truth:
  `/home/Duku/.config/eww/docs/design/frame-system/harness/frame-system-harness.png`
  (`1500x1120`) and
  `/home/Duku/.config/eww/docs/design/frame-system/live/rail-frame-system-dynamic-workspace-created-crop.png`
  (`1920x120`).
- Implementation captures:
  `/home/Duku/.config/eww/appearance/shell/qa/after-window-and-rail-pass-1.png`,
  `after-volume-pass-1.png`, `after-tray-pass-1.png`,
  `after-control-glass-pass-1.png`, `after-insights-glass-pass-1.png`, and
  `after-performance-glass-pass-1.png` (all `1920x1080`).
- Combined full-view evidence:
  `/home/Duku/.config/eww/appearance/shell/qa/source-vs-live-full-and-rail-pass-1.png`
  (`1920x992`).
- Combined focused evidence:
  `/home/Duku/.config/eww/appearance/shell/qa/source-vs-live-focused-pass-1.png`
  (`2000x180`).
- Viewport: `1920x1080`, compositor scale 1, standard Rail density. Source and
  implementation were normalized on one 1x comparison canvas; no density
  resampling was used for focused live crops.
- State: dark shell; one ordinary focused VS Code client; resting Rail; volume,
  tray, Control Overview, Insights Briefing, and Performance Overview captured
  separately with truthful live data.

## Findings

1. **Fonts and typography:** JetBrains Mono/Nerd Font family, optical weights,
   metadata scale, line spacing, and hierarchy remain consistent across Rail,
   Standard trays, and Large surfaces. No new wrapping, clipping, or truncation
   is visible.
2. **Spacing and layout rhythm:** Compact 16px, Standard 32px, and Large 48px
   clipping follows the fixed source corner geometry. Standard safe insets fit
   every volume/tray control; Large safe insets keep all content away from the
   transparent corners. The bell sits on a fixed 64px stage and is optically
   centred beside the clock while its badge remains independent.
3. **Colors and visual tokens:** All Eww tiers are visibly semi-opaque over the
   live client and use the approved obsidian, ivory, cold-silver, and violet
   hierarchy. Background context remains visible, while primary labels and
   controls retain sufficient contrast. Client contents remain opacity 1.0.
4. **Image quality and asset fidelity:** Every visible frame corner, edge, and
   motif is a canonical generated SVG module. The combined focused evidence
   shows sharp 1x geometry with no stretched complete frame, raster placeholder,
   CSS drawing, or substitute icon.
5. **Copy and content:** Existing live copy, values, status counts, tray items,
   routes, and actions are unchanged and remain truthful. No decorative copy
   was introduced.
6. **Interactions and accessibility:** All controls remain native labelled Eww
   buttons with prior tooltips and focus behavior. The notification, volume,
   tray, primary-surface, outside-click, Escape, and cross-surface paths passed
   the 36-route live acceptance matrix. Profile fixtures cover 1920x1080 scale
   1, scale 1.5, and 390x844 flyout allocations.

No actionable P0/P1/P2 difference remains. The first combined comparison
passed without a visual correction cycle.

## Comparison history

- Pre-comparison implementation audit found near-solid 0.985 panel/tray fills,
  16px/22px background radii behind 32px/48px frame corners, generic flyout
  styling, a badge-dependent notification allocation, and the older 10px
  cyan/green compositor decoration. The implementation corrected those items
  before the first combined QA input was produced.
- The first combined full and focused comparison found no P0/P1/P2 mismatch.
  Static validation then exposed only a stale namespace/geometry expectation in
  the acceptance harness; the contract was updated to verify the new explicit
  namespaces and exact live allocations. This did not change visual output.

## Residual test gaps

- Portrait and touch-only physical-device captures remain outstanding. Their
  deterministic 390x844 geometry contracts pass, but this pass did not change
  the reference monitor into a portrait mode.

final result: passed

# Rail Inner Alignment and Hover Containment

## Comparison target

- Source visual truth: user-provided Rail defect crops, the implementation
  specification in
  `/home/Duku/.codex/attachments/12e0f6d5-8aa0-44d1-810f-7b13c910dc7a/pasted-text.txt`,
  and the live pre-change state at
  `/home/Duku/.config/eww/appearance/shell/qa/rail-alignment-before-contact-sheet.png`
  (`1920x672`).
- Implementation screenshot:
  `/home/Duku/.config/eww/appearance/shell/qa/rail-alignment-after-contact-sheet.png`
  (`1920x672`).
- Full-view combined evidence:
  `/home/Duku/.config/eww/appearance/shell/qa/rail-alignment-before-after.png`
  (`1920x232`; pre-change above, implementation below).
- Focused combined evidence:
  `/home/Duku/.config/eww/appearance/shell/qa/rail-alignment-focused-comparison.png`
  (`1158x176`; avatar and Applications/Tray/Clock/Bell/Power regions,
  pre-change above and implementation below).
- Viewport: `1920x1080`, compositor scale 1, standard Rail density, native 1x
  screenshots. Equal `1920x96` Rail crops were compared without density
  resampling.
- State: dark shell, no primary surface or flyout. Idle and Avatar, Telemetry,
  Applications, Tray, and Bell hover states were captured at identical viewport
  and density.

## Findings

1. **Fonts and typography:** Existing JetBrains Mono/Nerd Font family, weight,
   scale, truncation, and label hierarchy are unchanged. Removing the separate
   telemetry tooltip eliminates the only text surface that escaped the Rail
   frame; the CPU/MEM/UP labels remain readable and centred.
2. **Spacing and layout rhythm:** Every SVG island now owns a 60px outer
   silhouette with a centred 54px interactive bay and `3px 4px` frame gutter.
   The avatar artwork is inset asymmetrically while its button retains the full
   hover allocation. Inner radii are 13px, so fills remain inside the 16px
   ornamental corners. Workspaces and island groups share vertical centring.
3. **Colors and visual tokens:** Existing semi-opaque obsidian glass, silver,
   ivory, and violet tokens remain unchanged. Hover fills keep their approved
   alpha but no longer create top/bottom underline borders or spill across the
   frame stroke.
4. **Image quality and asset fidelity:** Existing repository SVG assets are
   retained. Bell, Applications, and Tray artwork stays sharp at native 1x and
   is centred in explicit stage allocations; no raster substitute, inline SVG,
   CSS drawing, or placeholder was introduced.
5. **Copy and content:** Rail copy and truthful telemetry are unchanged. The
   redundant `Open Performance Dashboard` GTK tooltip was removed because the
   entire telemetry bay is already a clear interactive instrument.
6. **States, behavior, and accessibility:** Native Eww buttons, actions,
   tooltips on the icon-only controls, badge overlay behavior, and focus routes
   remain intact. Sixteen live interaction transitions and 42 surface/flyout
   routes passed and restored the idle Rail.
7. **Compositor decoration:** The live and tracked Hyprland configs now use a
   1px application border and match byte-for-byte. `hyprctl configerrors`
   reports no errors. The violet application edge remains visible without
   visually competing with the Rail frame.

No actionable P0/P1/P2 difference remains.

## Comparison history

- The pre-change evidence showed controls consuming almost the full ornamental
  frame height, Senomy and telemetry underline borders, a deliberately
  right-shifted bell, implicit Applications/Tray child allocation, and a 2px
  compositor border.
- The implementation added the outer safe gutter, centred both Rail groups,
  moved the avatar through button padding, removed inner borders and the
  telemetry tooltip, added explicit icon stages, reset the Bell offset, and
  changed the application border to 1px.
- Post-fix full and focused combined evidence found no remaining P0/P1/P2
  mismatch. The canonical appearance projection, all 30 static checks, all 16
  interaction transitions, and all 42 panel routes passed after the live
  application.

## Residual test gaps

- Compact, narrow, and phone padding remain contract-validated rather than
  physically captured on the reference monitor. Their existing density rules
  are preserved, with a bounded 6px avatar inset override.

final result: passed
