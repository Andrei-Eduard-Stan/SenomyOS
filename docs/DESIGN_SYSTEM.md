# SenomyOS Design System

## Approved direction

The main shell uses the **Obsidian Rail** direction: a compact bottom bar and a
right-anchored contextual Control Centre.

The separate Performance Dashboard uses the broader information architecture
from **Cathedral Deck**. It is opened from CPU/MEM/UP telemetry and is not a
Control Centre section.

Senomy Insights is a separate surface linked to the mascot and status message.

Local concept references:

- Obsidian Rail:
  `docs/design-references/obsidian-rail-approved.png`
- Cathedral Deck:
  `docs/design-references/cathedral-deck-approved.png`
- Command Lens and File Workspace:
  `docs/design-references/command-lens-rofi-thunar.png`
- Original functional wireframes:
  `/home/Duku/Downloads/IHvCMvnv.jpg`,
  `/home/Duku/Downloads/E0sf21hK.jpg`,
  `/home/Duku/Downloads/uQWETAHL.jpg`

The wireframes define features only. Do not reproduce their proportions.

The approved launcher/file-manager direction is documented in
`docs/LAUNCHER_FILE_MANAGER.md`. It extends the same token system into Rofi and
GTK 3 while preserving their separate interaction and configuration models.

## Character

SenomyOS is:

- dark and near-black;
- precise rather than decorative;
- technical without becoming a cyberpunk HUD;
- subtly gothic through atmosphere and identity;
- compact but comfortably readable;
- mostly squared, with slight softening where it helps separation;
- custom without imitating stock Windows, macOS, or Waybar themes.

## OS mark

The SenomyOS mark is a precise monochrome set of three vertical Gothic
lancets: one full-height centre spire and two balanced shorter side spires.
The small waist in each stroke suggests a cathedral crossing without turning
the mark into an ornamental crest. It must remain legible at 16–64px and may
use restrained opacity on the two side lancets, but it does not gain coloured
outlines, glow baked into the asset, a surrounding box, or a substituted font
glyph.

`appearance/shared/brand/senomyos-mark.svg.in` is the only editable geometry
source. SVG and raster sizes elsewhere are generated projections. Mockups may
vary in placement or scale, but their embedded approximations must never be
traced into separate runtime logos. A surface should normally show the mark no
more than once; telemetry bars and the Senomy companion portrait are distinct
symbols and must not be mistaken for it.

## Colour tokens

Initial tokens for implementation and visual testing:

```text
--bg:             #08090b
--surface:        rgba(10, 12, 15, 0.94)
--surface-raised: rgba(15, 17, 21, 0.96)
--fg:             #f1f1f4
--fg-muted:       #92959f
--fg-dim:         #666a74
--border:         rgba(255, 255, 255, 0.18)
--border-strong:  rgba(255, 255, 255, 0.34)
--accent:         #9892e8
--success:        #7fa98a
--warning:        #c8a367
--danger:         #c46f7d
```

The periwinkle accent from Obsidian Rail is the product accent across all
surfaces. Cathedral Deck's garnet concept is layout inspiration, not a second
brand theme. Semantic colours appear only for real status.

The single editable appearance tree is `appearance/`; its machine-readable
portable registry is `appearance/tokens.json`. Eww, Rofi, GTK 3, SDDM, and
Hyprlock keep native syntax-specific projections because their styling
languages are not interchangeable. `scripts/generate-appearance.py` produces
those shared-token projections, and `scripts/senomy-appearance.sh` is the
common build, check, preview, deploy, and rollback entry point. A token change
is incomplete until every projection and its visual fixtures have been
reviewed.

## Typography

Primary UI font:

```text
JetBrainsMono Nerd Font
```

Icon fallback:

```text
Symbols Nerd Font Mono
```

Do not set the symbol-only font as the global text font.

Recommended scale:

```text
11px  metadata only
12px  compact secondary labels
13px  bar and dense table text
14px  normal panel body
16px  section title or key value
20px  important metric
```

Use tabular-looking alignment for metrics and process columns. Uppercase labels
are useful for short system headings, not long paragraphs.

## Spacing and geometry

Base spacing scale:

```text
4, 8, 12, 16, 24, 32
```

Current wide-desktop targets:

- standard Rail window: 64px high, containing 56px visible islands with a
  minimal transparent top reserve and a small bottom safe inset;
- compact pointer control target: at least 36x36px;
- touch-oriented control target: at least 44x44px, preferably 48x48px for
  frequently used actions;
- bar outer padding: zero horizontally; island separation supplies the rhythm;
- Control Centre width: approximately 888px on a wide desktop, capped to 90%
  of the focused monitor width and 82% of its height, then reflowed for
  compact/narrow profiles;
- Control Centre gap above bar: 12–16px;
- Performance Dashboard: 1480x760 logical pixels on a wide desktop, capped to
  90% of focused-monitor width and 82% of height; route content must truncate
  or wrap inside that fixed outer geometry;
- panel corner radius: 4–6px;
- row radius: zero unless the row is an actual selectable object.

The GTK file workspace follows the same density contract. `SenomyOS` is the
standard projection; `SenomyOS-Touch` imports it and raises primary controls,
sidebar and menu rows, tabs, entries, and scrollbars to touch-oriented sizes.
Density changes geometry only and must not fork the palette or global GTK
preference.

Use spacing and alignment before adding borders. Use one outer panel border,
then row separators only where scanning needs them.

## Main bar hierarchy

The bar has three scan zones containing six functional regions:

1. left: one individually bordered 56px island per real positive workspace;
2. centre: one joined Senomy identity unit and a distinct CPU/MEM/UP telemetry
   island;
3. right: system controls, calendar/notification status, and an isolated Power
   entry.

Workspace islands use the same obsidian fill, silver edge, radius, and bloom as
the instrument islands. They remain dynamically sourced rather than exposing a
fabricated numeric floor. On the standard desktop profile, the five controls
inside the system island occupy equal 64px columns so hover ownership and icon
centres are predictable.

Up to four standard workspace islands retain the established unconstrained
layout exactly. A fifth real workspace activates a bounded carousel with four
compact 54x56px islands, fixed 10px inter-workspace gaps, and 28x56px edge
navigation controls. The controls are allocated inside the workspace region;
they must not move the Senomy or instrument islands. Disabled boundary controls
remain allocated so the viewport width is stable. Native clipped slide motion
alternates between two same-size page buffers, while Hyprland remains the only
workspace data source. Pointer-wheel and horizontal-touchpad directions move
only the viewport; selecting a workspace remains the sole action that changes
the compositor workspace.

Standard desktop instrument groups use a shared 22px horizontal separation;
workspace indicators use their denser 10px internal rhythm. The Rail
content is inset 20px from both monitor edges to align with the compositor's
outer window gap. Hyprland retains 20px top/side gaps but uses a 6px bottom gap
above the Rail so windows and islands read as one anchored lower composition.

The clock is a compact two-row control with time above the short date. Battery
text and symbols use the same primary control scale as adjacent audio and
network controls; secondary clock date text may use the metadata scale.

Do not wrap every control in a visible box. Active state may combine:

- accent icon/text;
- a restrained bottom indicator;
- a subtle surface tint.

Hover should not move surrounding content.

Hover is supplementary. Active state, tooltips, and essential explanations
must remain available on devices that do not provide hover.

The avatar and dialogue have separate interaction targets but no visual gap
that makes them look unrelated. The avatar is the companion trigger and reads
as the profile image for the dialogue; the dialogue remains the Insights
trigger. No second Senomy portrait is added elsewhere in the Rail.

Right-side rail controls share one visual rhythm and at least a 52x62px target
in the standard profile. Tray, Applications,
Audio, Network, and battery glyphs align to the same visual center. The rail
shows only the combined battery percentage; physical-battery detail belongs in
tooltips and larger surfaces rather than expanding the bar unpredictably.

The arrow, Applications, Audio, Network, battery, Notifications, and Power
marks use repository-owned SVGs on identical 24x24 canvases, rendered into
20x20 image boxes. Do not
replace them with mixed font glyphs or theme-icon names without re-running
pixel-level alignment QA. Battery may use a wider control to pair the fixed
icon box with its percentage, but its icon remains on the same centerline.

### Luminous Reliquary production frame grammar

SenomyOS frame ornament is a generated native-vector system, not a traced,
cropped, or nine-sliced raster. The canonical contract is
`appearance/shared/frames/frame-system.json`; editable path geometry lives in
`scripts/frame_geometry.py`, and
`appearance/shared/frames/templates/senomy-frame-module.svg.in` projects that
geometry through the appearance-token pipeline. The approved August 28 sheet
is art direction only.

Every frame composes fixed optical corners, neutral extensible edge modules,
fixed anchored motifs, and optional fixed crests around a transparent content
centre. Only neutral edge files use `preserveAspectRatio="none"`; corners,
motifs, and crests use `xMidYMid meet` and retain manifest dimensions. Never
stretch a complete frame, corner, finial, node, junction, motif, or crest.

The three tiers are separately authored geometry rather than scaled variants:

- **Compact** is the deliberately simplified Rail language with 16x16 corners
  and a 44px optical validation height.
- **Standard** uses 32x32 corners and richer paired structural strokes for
  future cards and medium panels.
- **Large** uses 48x48 corners, deeper architectural rhythm, and optional
  threshold-controlled crests for future windows and overlays.

The production palette is ivory, cold silver, steel, structural black,
violet, and violet-light. White/silver structure dominates; violet is a small
semantic accent. Luminance and state glow remain CSS-controlled so idle,
hover, focused, warning, and critical states do not require duplicate SVGs.

Runtime glass remains translucent at every tier. Compact uses the low-density
surface token, Standard uses the raised glass token, and Large uses a 0.68
obsidian base beneath a restrained 0.42–0.52 gradient. The CSS clipping radius
matches each tier's fixed corner width: 16px, 32px, and 48px. This makes the
transparent corner allocation real instead of painting a square fill behind
rounded frame artwork.

Only Compact is deployed to the Obsidian Rail. Each workspace is its own
framed island and owns an adaptive top-centre number bay built from two neutral
top-edge segments and fixed junction modules; it is not an opaque patch.
Senomy, telemetry, system controls, clock/notifications, and Power use their
own restrained fixed motif. The Rail has no enclosing master border.

Validation covers Compact at 68/120/200/280/397x44, Standard at multiple
widths and heights, and Large through 1480x760. The validator rejects raster
or foreign content, confirms transparent safe centres, keeps corner and motif
geometry fixed, checks stable edge profiles, and hides unsafe optional crests.

## Transient flyouts

Immediate controls may use a compact transient flyout without becoming a new
primary surface. The Audio flyout contains one mute target, one default-output
slider, its current value, and one labelled route to the full Audio section.
The tray flyout contains the native background-application icons under a
compact status header. Both use the Standard controls frame, raised glass,
typography, accent, hover, and focus tokens from the Control Centre. Their
reference allocations are 420x96 and 340x150 so the fixed corners and safe
insets never compress the controls.

Flyouts should remain small enough to preserve context, close on repeated
trigger, outside click, or Escape, and never grow into a second Control Centre.

Hyprland client contents remain fully opaque. The compositor contributes only
an 18px, power-2.4 corner mask, a restrained silver-to-violet active border,
muted inactive border, and soft black shadow so ordinary application windows
belong to the same frame language without becoming glass panels.

The Rail has three density modes derived from logical monitor width. Standard
keeps the full Senomy dialogue, uptime, and two-row clock. Compact keeps the
single avatar trigger and primary telemetry while removing secondary
prose/date content.
Narrow also removes uptime and tightens workspace/application padding. Core
navigation, CPU, memory, audio, network, battery percentage, and time remain
available in every mode.
The same dismissal behavior applies to the Control Centre, Performance
Dashboard, and Senomy Insights. A transparent shared backdrop may intercept the
first outside click, but it must stop above the exclusive bar and remain below
the visible panel so bar triggers and panel controls stay interactive.

## Control Centre

Use a stable shell:

- title and state summary;
- close control;
- compact section navigation;
- one active section body.

Navigation may use a narrow labelled rail where width permits. On narrower
layouts, use a compact section selector without exposing a second panel.

Device Management replaces Performance in the navigation.

The primary-surface masthead is shared by Control Centre, Performance, and
Senomy Insights. Insights is the visual source of truth for hierarchy: an
approximately 100px desktop header with eyebrow, title, wrapped description,
compact evidence chips, and a 42px close target. It does not reserve character
artwork. Compact, narrow, and phone profiles reduce padding and typography
together; they do not return to unrelated utility-header proportions.

## Senomy companion

The companion owns the large character presentation. Expanded mode is a
roughly 330px edge sidecar with a large bounded avatar, a concise observation,
evidence source, and a route into Insights. Compact mode removes the opaque
panel wall around the character and keeps only a tight transparent avatar
stage with a small readable observation strip.

Both modes expose close, minimize/expand, left/right edge switch, and session
pin controls. The overlay remains above normal windows without requesting
keyboard focus, a backdrop, or exclusive work-area reservation. It snaps to
an edge rather than presenting a misleading free-drag affordance. Transparent
pixels do not make GTK's rectangular input window disappear, so compact bounds
must remain close to the visible artwork.

## Performance Dashboard

The dashboard is denser but follows the same Obsidian Rail tokens, typography,
border hierarchy, semantic colours, and interaction states as the Control
Centre and Senomy Insights. Cathedral Deck describes its information density,
not a separate visual theme.

Its hierarchy is:

1. dashboard title and scope;
2. six stable routes for Overview, CPU + GPU, Memory, Storage, Network, and
   Processes;
3. four current-value KPIs and paired retained-history charts;
4. detailed read-only cards and one process table;
5. a visible route to the curated diagnostic console;
6. later report and confirmed-action layers.

Graphs should be thin and quiet. Bars grow upward from one baseline, keep a
five-minute rolling period, and place older samples to the left. Rate graphs
state their current dynamic scale. A process table is one shared surface with
row separators, not a grid of cards.

Performance may summarize combined and per-battery charge, but must not grow
power controls or detailed battery policy. Those belong to Control Centre /
Power, which is the single future home for health, charging thresholds,
profiles, policy, and confirmed power-setting changes.

## Senomy Insights

Insights should feel like a briefing prepared by the desktop:

- concise leading status;
- grouped observations;
- evidence/source label;
- timestamp or freshness;
- one clear recommendation when applicable.

Severity uses text, icon shape, and restrained semantic colour together.
Critical styling is reserved for verified critical conditions.

The mascot is an identity asset, not an emoji. Artwork is stored as real image
assets for compact Rail and large companion contexts. Only the Rail trigger
and companion read those paths from `data/senomy-avatars.json` through the
shared `senomy-avatar` widget; primary headers and content cards use copy and
status rather than duplicate character portraits. No component owns a private
hard-coded mascot path.

The state vocabulary includes idle, focused, thinking, happy, warning, busy,
sleeping, browsing, and music. State expresses presentation, not evidence. A warning avatar may
only be selected automatically from a verified warning source, and decorative
mood changes must never imply an unobserved system condition.

Bar dialogue uses a short `Seno:` speaker label followed by one concise line.
Verified conditions outrank personality dialogue. Ambient lines may
occasionally use uncommon English/Latin phrasing, but translations stay brief
and the line must not imply a system fact that was not observed.

The Wiki route keeps the same shell and typography. Category tabs form a
compact sub-navigation row, article titles form a narrow index, and Markdown
blocks render as native Eww labels, lists, code surfaces, tables, and internal
navigation buttons. It is documentation inside Insights, not a browser clone.

The Notifications route uses a compact history ledger rather than imitating
transient popup cards. Each entry keeps application, urgency, age, title, and
bounded body hierarchy readable; critical state uses semantic colour without
turning ordinary notifications into alarms. Provider, DND, retention, privacy,
empty, and capture-not-connected states remain visible. Clearing history is a
two-step action.

## Motion

Use motion only to explain:

- panel opening and closing;
- active-section switching;
- loading becoming ready;
- confirmed action progress.

Keep transitions subtle and short. Avoid glow pulses, constant animation, and
decorative movement.

## Adaptive and touch layouts

SenomyOS uses one visual identity across input modes, but density may change.
Surface windows are sized from focused-monitor logical geometry when opened.
Responsive behavior means reflowing navigation, grids, controls, and text into
fewer columns; it does not mean scaling the complete desktop layout down until
it becomes unreadable. Narrow profiles retain a practical text and touch-target
floor, while standard profiles preserve the approved desktop proportions.

Appearance accents are semantic palettes rather than isolated text colors.
Each palette supplies one base accent, bright foreground, soft background,
medium border, and strong indicator color. Those roles are shared by the rail,
headers, navigation, cards, controls, sliders, graphs, flyouts, and identity
surfaces. Warning, critical, destructive, and success colors remain fixed so a
theme cannot conceal system meaning.

Gradient strength is independent from palette choice. Off removes decorative
background images, Subtle uses low-opacity palette stops, and Strong increases
the same palette stops without changing layout or semantic status colors.

Pointer-dense mode:

- compact bar;
- smaller gaps;
- tooltips on hover;
- precise scroll and click behavior.

Touch-oriented mode:

- 44–48px primary targets;
- more space between destructive and safe controls;
- visible labels for ambiguous icons;
- no hover-only content;
- scrollable sections with comfortable edge padding;
- drag and swipe only as optional shortcuts;
- on-screen keyboard awareness;
- panels constrained above system gesture or keyboard areas where known.

Narrow portrait mode should prioritize:

1. time, power, network, and navigation;
2. Senomy status;
3. abbreviated telemetry;
4. overflow access to secondary controls.

The Performance Dashboard may change from three columns to stacked sections on
narrow or portrait displays. It must not merely shrink desktop typography until
it becomes unreadable.
