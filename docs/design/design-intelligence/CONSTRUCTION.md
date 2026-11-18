# SenomyOS visual construction

These are extracted rules with source owners, not new runtime tokens. Values are
the inspected 9 November baseline; re-read their owners after a drift report.
Current dated overrides take priority over older sections in the same document.

## Composition families

| Family | Composition | Reference / boundary |
| --- | --- | --- |
| Persistent Rail | Sparse instrument groups anchored across one baseline; identity/machine instrument supplies the focal exception | A03/A04; preserve adaptive allocation and live workspace/tray behavior |
| Quick operation | Current target + direct action first; secondary channel/state quieter; optional inventory disclosed | P01/R01; Audio's opaque ground is scoped to Audio, not a global opacity migration |
| Dense workspace | Navigation beside an aligned reading/data plane; relationships determine columns and rules | A02/P02; retain full Settings/compact workspace identity and existing reports |
| Authentication | Identity, credential and primary action form one task group; utilities are subordinate | R02 and current authentication refinement; never infer PAM/login success from a preview |

Do not force all four into the same card grid. Develop the reading order before
selecting containers. Space between related elements should be smaller than the
space separating tasks. Make values align so numbers can be compared without
re-reading labels. A large panel is justified by its evidence and actions, not by
stretching a small panel until it fills the screen.

## Owners and projections

| Concern | Authoritative source / native consumer |
| --- | --- |
| Palette, common type roles, density, motion, Rail metrics | `appearance/tokens.json` → `scripts/generate-appearance.py` → generated `shell/quickshell/config/Theme.qml` and toolkit projections |
| Operational heading/body/data/value roles, text scale and contrast | `shell/quickshell/config/DirectoryStyle.qml` |
| Opt-in functional quick-control roles | `shell/quickshell/config/QuickPanelStyle.qml` (composes existing roles; Audio adoption is scoped) |
| Artwork source, modes, logical dimensions, caps and content padding | `appearance/skins/default.json` → `config/Skin.qml`, `SkinSchema.js`, `components/ArtFrame.qml` |
| Current large perimeter | `components/ShellSurfaceFrame.qml`, `SurfaceOutline.qml` and four original Island corner SVGs |
| Generated modular frame family | `appearance/shared/frames/frame-system.json`, `scripts/frame_geometry.py`, SVG templates and generated assets |
| Shared motion | `config/Motion.qml`; timing roles from Theme plus existing component-specific finite transitions |
| Button feedback | `components/ButtonHoverFrame.qml` plus the target shared control; 9 November overrides apply |

Do not edit generated Theme or generated SVG modules. Do not run the appearance
generator in the live tree as a supposedly harmless preview: its outputs are
watched runtime inputs. Build/check in an isolated candidate when changing them.
Native QML, GTK/Rofi, SDDM and Hyprlock retain distinct projections; CSS advice is

## Typography and density

- **Bruno Ace SC** identifies short headings; **Audiowide** anchors important values;
  **sans-serif** carries body/control text; **JetBrainsMono Nerd Font** carries
  metadata and technical data. Use DirectoryStyle/QuickPanelStyle roles rather
  than hardcoding these families again. `Symbols Nerd Font Mono` is icon fallback.
- DirectoryStyle body is 14px standard / 16px touch and detail 13px / 14px,
  multiplied by its existing text scale. Compact metadata exceptions are not a
  license to make all operational copy 11px. Audio refinement gives small Audio
  metadata a 12px minimum even though the original style role starts at 11px.
- Use size, face, alignment and spacing to separate value, label and explanation.
  Neither all-display text nor all-monospace text reproduces the current hierarchy.
  Keep long endpoint/route names in the readable body role; wrap within their
  column while protecting aligned values and controls.
- Reuse existing spacing roles: QuickPanelStyle's 4px unit, 12px control gap,
  20px group gap and 24px inset are a measured example, not a new universal grid.
  Touch raises targets through existing profiles (commonly 48px); preserve the
  actual target component's keyboard/touch geometry rather than shrinking its art.
- Inspect at normal scale. Enlarged screenshot crops hide poor reading size.
  A font file being present does not establish installation or redistributability;
  inspect current packaging before adding fonts. No new fonts are needed here.

## Authored frames and Illustrator

The master `assets/mockups/senomyui/senomy [Recovered].ai` is PDF 1.6 compatible,
one 1920×1080pt page, created with Illustrator 27.5. Its PNG companion is 8000×4505.
The master and SVG exports are construction evidence, not fixed production screen
coordinates. The rendered master and companion broadly agree; no source edit or
full editable-layer equivalence is claimed.

Existing production artwork lives in `appearance/assets/` and
`assets/senomy_island_expanded/SVG/`. Identify the actual consumer first:

- **ArtFrame:** inspect the manifest's `logicalSize`, `insets`, `contentPadding`,
  `scaling`, optional fixed centre bands and mode. ArtFrame shares a source texture
  across clipped cells and caps the raster dimension at 4096. A 4× export changes
  pixel resolution, not logical corner thickness. Content margins and caps differ.
- **Protected bands:** central crests stay fixed; neutral intervals absorb size
  changes. Do not stretch complete frames, portraits, circles, finials or lettering.
  Use `fit` for circular/portrait assets. At invalid geometry retain the native
  fallback rather than crushing artwork into a too-small allocation.
- **SurfaceOutline:** `Asset 51.svg` top-left, `Asset 50.svg` top-right,
  `Asset 52.svg` bottom-right, `Asset 54.svg` bottom-left. Fixed/aspect-preserved
  corners join one-pixel neutral rules; default allocation is 24px. Do not substitute
  a generic rounded rectangle or add another perimeter around this one.
- **Generated modular grammar:** Compact/Standard/Large have independently authored
  16/32/48px corners and 9/16/24px horizontal safe margins. These are separate
  optical families, not one asset enlarged. The historical Compact optical height
  of 44px is not today's 72px Rail reserve or 64px instrument allocation.
- **Current Rail artwork:** the manifest can paint a 52px optical frame inside
  a 64px allocation; inspect the specific skin and current component. Preserve the
  72px reserve, 20px screen inset and 22px island-gap roles from Theme. Component
  internal dimensions can differ and adaptive code can override allocations.
- **Exports:** keep SVG viewBox/aspect, compatible paths/fills and safe content
  regions. Never bake live labels, metrics or dynamic workspace IDs into art.
  Outline decorative lettering only. Complex Illustrator effects may require a
  bounded transparent PNG when Qt SVG cannot reproduce them. Validate actual Qt
  rendering and decode-failure fallback, not just XML parsing.

`docs/reference/ART_SKINS.md` is useful for field semantics, but its old component size table,
Read the live manifest and consumer. Touching a watched manifest is publication.
Canonical OS mark geometry is `appearance/shared/brand/senomyos-mark.svg.in`;
do not trace an approximation from a screenshot. Keep character art in its established
Rail/companion/identity contexts; do not reserve portraits in every panel header.

## Interaction and motion are part of the composition

`ShellState` owns one primary (`none/control/performance/insights`; empty string
encodes none), compact/full Control Centre mode, and a transient popup lease.
Current quick popovers may coexist with a primary; opening/focusing a primary
dismisses the transient. Preserve modal and dirty-edit guards and innermost Escape
priority. Full Settings reuses the existing Control Centre workspace; it is not a
new primary. The companion remains separate ambient state. Read current contracts
flyout” behavior.

Latest button rules are A05. Outside the Rail, resting action buttons are plain;
the shared fine inset angular outline provides finite centre-out hover, real
selection and keyboard focus. No click wash or second square focus border.
Pointer focus does not imply persistent selection. Workspace active state uses
brightness, the centre Senomy instrument has its own exception, and Power uses
its existing frame halo. These are deliberate exceptions, not inconsistent bugs.
Keep input boundaries, checkbox/radio marks, drag feedback and semantic calendar
indicators. Route text/current markers must still carry meaning without color.

Use `Motion.duration(...)` and existing policy. Shared hover is 180ms entry /
120ms return; Power is 160ms and Audio opening 120ms. Reduced motion is immediate.
Decoration settles when held and releases when idle; do not add an always-running
timer for atmosphere. Changing hover paint must not resize targets, steal events,
intercept pointer input or delay functional feedback. Closing motion retains its
owning screen/anchor until unmap; state clearing must not teleport the window.

## AI interface failure patterns to challenge

| Temptation | SenomyOS-specific critique and correction |
| --- | --- |
| Equal cards for every datum | Obscures output/primary action; compose label/value/control groups before containers (P01/R01) |
| More glass means more identity | Background text defeats reading; functional ground must pass actual busy-background inspection (R01) |
| Cyberpunk ornaments and new accent palettes | Existing frame grammar and restrained semantic color already provide identity; Cathedral garnet is not a second brand (A02) |
| Generic “premium” rounded rectangles | Discards authored caps and creates a parallel construction system (A03) |
| Brand/mascot in every header | Duplicates the Rail/companion focal role and reduces evidence space (A02/A04) |
| Tiny mono everywhere | Copies old concepts while erasing today's display/body/value roles (A03/R02) |
| Endless sheen, scaling, animated glow | Conflicts with finite settled feedback, fixed targets and reduced motion (A05) |
| One flat navigation grid for every panel | Makes unlike tasks equal and ignores compact/full directory navigation (P02/E02) |
| A successful compiler or pretty mockup proves completion | Neither proves the actual implementation, narrow readiness, native placement or input behavior |
| New invented numbers/healthy status to fill space | Provider availability and observed outcomes determine content; empty/error are designed states |
| A copied web recipe | React/Tailwind/Framer/browser checks cannot validate native QML; translate the principle, retain native ownership |

None of these forbids a deliberate new direction requested by the user. Such a
direction needs an explicit scoped decision and evidence, not silent token drift.
