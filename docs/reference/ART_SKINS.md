# Authored skin and asset contracts

Use DESIGN_SYSTEM for current accepted interaction/type/construction rules.
This reference owns manifest fields, original exports and bounded slicing.
Current status belongs in PROJECT_STATE. Superseded implementation/validation
archives were removed at the owner’s request.

## Replace an Illustrator export

1. Open `appearance/skins/default.json` and find `frames.workspace` (or another component).
2. Open the complete SVG named by `source` in Illustrator, or replace it with your own export.
3. Preserve its logical contract, or update `logicalSize`, `insets`, and `contentPadding` in the manifest.
4. Save the SVG or transparent PNG to that path. SVGs under `appearance/assets/` are editable originals: the appearance generator does not overwrite them.
5. From the repository root run `touch appearance/skins/default.json`. The manifest watcher reloads the assets with a new cache revision. No service restart is needed. A supervised shell restart also reloads them.
6. Workspace detection, live text, controls and dashboard state continue to be native.

`appearance/tokens.json` references the manifest through `skin.manifest`. Its colors,
typography, density and motion remain authoritative for native UI. `Theme.qml` remains
generated. `RailStyle.qml` is a compatibility adapter to the manifest; do not maintain
another set of artist settings there.

## Modes and fallback

Set `defaultMode` to `art` or `native`. Each component supports `mode: inherit`,
`art`, or `native`. Art is enabled by default with complete starter SVGs assembled
from the established native vector artwork. These starter exports are not a new
procedural artwork pipeline and do not require maintaining corners separately.

Native mode retains the previous frame composition. Senomy's native compact
instrument remains unframed. All modes share the same live content instances and
content padding; mode changes cannot reset interactions or message state.

Empty/unreadable/unsupported art falls back to the native frame. Invalid JSON or
invalid slice geometry keeps the last valid manifest, with a diagnostic in the shell
log. Missing art never makes a control disappear. Native fallback and new artwork
share the configured content padding.

## Manifest fields

- `source`: file path relative to the manifest, or a file URL. Prefer portable relative paths.
- `logicalSize`: source artboard expressed in logical pixels; the ratio is derived from these two values.
- `insets`: left/right/top/bottom fixed caps, in logical pixels, not export pixels.
- `contentPadding`: clear content margins, independently of the cap boundaries.
- `scaling`: `nine-slice`, `protected-bands`, or `fit`.
- `fixedCenterWidth` / `fixedCenterHeight`: optional additional central fixed bands. The remaining space between that band and the caps stretches symmetrically.
- `opacity`: artwork only, 0–1; never dims live text or changes hitboxes.
- `offset`: artwork-only x/y logical offset. Keep it within the allocated window; it does not expand the input region or reserve.
- `background`: `art` removes the native base fill; `native` retains glass behind a transparent frame (shared SenomyFrame consumers).
- `variants`: optional `normal`, `hover`, `active`, `warning`, `critical`, `disabled` asset paths. `source` is the default normal image. A missing state uses normal; an unreadable state also falls back to normal before native.
- `family`: artist grouping; frame geometry is specified explicitly, not inferred from the family name.

You do not need six state exports. One source is sufficient. Native focus/active
feedback remains functional even with no state images. All state assets must use
the same viewBox/aspect and logical contract. This avoids moving content on hover.
Currently warnings are selected by Senomy's health state; other surfaces expose
only states their native behavior actually knows. No warning state is invented.

## Single-file slicing and Illustrator rules

`ArtFrame.qml` loads one image at the source logical aspect ratio, with rasterization
scaled for the screen. Clipped image cells share the same cached source texture.
The renderer supports nine regions, or extra fixed center bands for crests. It does
not stretch the complete image across a frame. This deliberately avoids Qt
BorderImage's read-only sourceSize limitation while retaining cap-inset behavior.
The maximum source texture dimension is bounded at 4096 pixels.

For an ordinary nine-slice export:

- keep corners and endcaps entirely inside the fixed cap rectangles;
- place only neutral, safely stretchable edges between caps;
- keep the content safe rectangle clear of opaque decoration;
- remember that a fixed cap is NOT permission to draw over its content-safe portion;
- use `fit` for circles, portraits and directional arrow artwork.

For a centered crest, select `protected-bands` and specify its fixed band width.
The whole vertical band remains fixed in width; left and right neutral intervals
absorb width changes. A corresponding fixed horizontal band is also supported.
This protects a crest without a second image. Artwork requiring multiple arbitrary
fixed islands needs another composition/variant; this version supports one central
fixed band per axis. Repeating/tiled edge textures are not implemented: use neutral
stretchable edges, or an aspect-preserved independent texture layer.

SVG: the viewBox and its aspect ratio define the artwork. A 54×52 or 216×208
viewBox works if it describes the same composition and `logicalSize` remains
[54,52]. Set explicit SVG width/height with the same ratio. Export paths and
compatible fills; outline decorative lettering. Do not bake live labels or metric
values into the art. Qt SVG has a subset of Illustrator/browser effects; use a
transparent PNG for complex effects that do not render faithfully.

PNG: export at 2× or 4× the logical size below with alpha. The renderer maps export
pixels to logical insets automatically. A 4× export does not imply 4×-thick corners.
Large-panel PNGs usually need only 2×; SVG is preferable to enormous 4× bitmaps.
JPEG may be used for opaque backgrounds but has no transparent frame centre.
Other image formats require the installed Qt image plugin; a failed decode falls
back to native. The initial supported authoring workflow is static SVG and PNG.

## Per-component artboards

Every table value below is sourced from the shipped manifest. Caps and safe margins
are L/R/T/B in logical pixels. Illustrator artboards are 4×; 2× PNG dimensions are
half that column. Target sizes are reference compositions, not fixed runtime boxes.
Compact Rail frames paint 52px inside a 64px native allocation; Senomy uses its full
64px allocation. The Rail reserves 72px. Content margins remain relative to the
native allocation, preserving existing baseline layout.

| Key | Source under appearance/assets (unless noted) | Logical size | Illustrator 4× | Ratio | Caps L/R/T/B | Safe L/R/T/B |
|---|---|---|---|---|---|---|
| workspace | `rail/workspace-frame.svg` | 54×52 | 216×208 | 27:26 | 16/16/16/16 | 9/9/7/7 |
| context | `rail/context-frame.svg` | 230×52 | 920×208 | 115:26 | 16/16/16/16 | 9/9/7/7 |
| performance | `rail/performance-frame.svg` | 360×64 | 1440×256 | 45:8 | 16/16/16/16 | 18/18/4/4 |
| performance-compact | `rail/performance-compact.svg` | 178×64 | 712×256 | 89:32 | 16/16/16/16 | 8/8/4/4 |
| control | `rail/control-frame.svg` | 338×52 | 1352×208 | 13:2 | 16/16/16/16 | 9/9/7/7 |
| control-compact | `rail/control-compact.svg` | 48×52 | 192×208 | 12:13 | 16/16/16/16 | 4/4/7/7 |
| clock | `rail/clock-frame.svg` | 162×52 | 648×208 | 81:26 | 16/16/16/16 | 9/9/7/7 |
| calendar | `panels/calendar.svg` | 430×470 | 1720×1880 | 43:47 | 32/32/32/32 | 16/16/14/14 |
| volume | `panels/volume.svg` | 420×122 | 1680×488 | 210:61 | 32/32/32/32 | 16/16/14/14 |
| tray | `panels/tray.svg` | 330×126 | 1320×504 | 55:21 | 32/32/32/32 | 16/16/14/14 |
| power | `panels/power.svg` | 430×250 | 1720×1000 | 43:25 | 32/32/32/32 | 16/16/14/14 |
| notifications | `panels/notifications.svg` | 470×610 | 1880×2440 | 47:61 | 32/32/32/32 | 16/16/14/14 |
| notification-toast | `panels/notification-toast.svg` | 430×170 | 1720×680 | 43:17 | 32/32/32/32 | 16/16/14/14 |
| control-center | `panels/control-center.svg` | 980×760 | 3920×3040 | 49:38 | 48/48/48/48 | 24/24/22/22 |
| dashboard | `panels/dashboard.svg` | 1480×760 | 5920×3040 | 37:19 | 48/48/48/48 | 24/24/22/22 |
| insights | `panels/insights.svg` | 1040×760 | 4160×3040 | 26:19 | 48/48/48/48 | 24/24/22/22 |
| senomy-context | `panels/senomy-context.svg` | 900×260 | 3600×1040 | 45:13 | 32/32/32/32 | 16/16/14/14 |
| senomy-context-compact | `panels/senomy-context-compact.svg` | 600×340 | 2400×1360 | 30:17 | 32/32/32/32 | 16/16/14/14 |
| companion (retired source art) | `panels/companion.svg` | 390×680 | 1560×2720 | 39:68 | 32/32/32/32 | 16/16/14/14 |
| companion-compact (retired source art) | `panels/companion-compact.svg` | 190×280 | 760×1120 | 19:28 | 16/16/16/16 | 9/9/7/7 |
| card | `controls/card.svg` | 210×112 | 840×448 | 15:8 | 10/10/10/10 | 16/16/16/16 |
| button | `controls/button.svg` | 148×48 | 592×192 | 37:12 | 10/10/10/10 | 13/13/8/8 |
| chart | `controls/chart-frame.svg` | 320×160 | 1280×640 | 2:1 | 10/10/10/10 | 12/12/12/12 |
| sos | `../../assets/icons/bar/session-sos.png (existing asset)` | 60×60 | 240×240 | 1:1 | 0/0/0/0 | 0/0/0/0 |

The expanded Rail context uses these reference artboards at 310px high (390px in
narrow mode) to reserve the explicit Dashboard/Insights action row.
The Power panel stretches from 250 to 350px for its confirmation state.

Workspace frame art is repeated per live workspace chip, currently 54/58px wide;
there is no fixed screenshot-sized artwork around the entire carousel. Counts,
active reveal, overflow arrows and monitor ownership remain native.
Performance's main frame spans the 360/238px presentations; its compact asset
covers 178/138px. At 138px the portrait and relevant message take precedence over
secondary metrics. Control has a separate 48px micro frame. Clock spans
162/150/112px. These are bounds of current layouts, not universal hardware claims.

### Portrait and navigation

`persona.ring`: optional square ring; recommended 180×180 logical / 720×720
Illustrator artboard, 1:1. Leave the central 62% clear for the separate portrait.
The compact portrait uses 36px (28px in the smallest instrument); expanded portraits
can use the same vector master. `persona.portrait` and `persona.fallback` are
configurable. `persona.rotate` and `rotationMs` rotate only the ring, with a minimum
four-second revolution. Empty/failed rings retain the medallion fallback.

Workspace arrows: 24×34 logical, 96×136 Illustrator, 12:17. Keep two logical pixels
clear around the silhouette. Existing previous/next files are referenced through
`navigation`; use `mode: art` for its SVGs. Existing PNGs remain the native fallback.
SOS: 60×60 logical, 240×240 Illustrator, 1:1. Keep its principal symbol inside the
central 48×48. No cap slicing is applied to either arrows or SOS.

## Native versus decorative graphics

Art mode removes modular frame corners/edges/motifs, workspace ornamental rules,
and Senomy connector shapes. Artwork does not receive mouse or keyboard events.
Real progress fills/tracks, history plots, radial gauges, selection indicators,
focus feedback, information separators, text, icons and native controls remain.

Cards, buttons and history-chart frames now have optional central artwork entries.
Progress-track artwork, arbitrary decorative overlays and repeatable textures are
future extensions; no functional graph or progress fill has been rasterized.
projections; this skin renderer does not silently modify those consumers.

## Image backgrounds and contextual Rail preview

Senomy's flat background is now independent of its optional frame. Configure
`persona.backgrounds.rail` and `persona.backgrounds.expanded` in the skin manifest:

```json
"backgrounds": {
  "rail": {
    "source": "../assets/persona/rail-background.png",
    "color": "#080a0c",
    "opacity": 0.96,
    "imageOpacity": 1,
    "scaling": "crop",
    "scrimOpacity": 0
  },
  "expanded": {
    "source": "../assets/persona/expanded-background.png",
    "color": "#080a0c",
    "opacity": 0.96,
    "imageOpacity": 1,
    "scaling": "crop",
    "scrimOpacity": 0
  }
}
```

The shipped sources are empty, so both states have the same dark backing and no
border. Add SVG/PNG assets at the paths above to customize them. Empty or failed
images retain the native fill. `opacity` changes the fill, `imageOpacity` changes
the artwork, and optional `scrimOpacity` adds black over a bright image for contrast.
`crop` fills the surface while preserving aspect ratio and cropping excess artwork;
`fit` shows the complete image with dark space around it when aspect ratios differ.
This is background artwork, not nine-slice frame artwork.

Recommended sources: Rail 360×64 logical / 1440×256 Illustrator (45:8); expanded
900×310 logical / 3600×1240 Illustrator (90:31). Narrow expanded layouts render
around 600×390 (20:13), so keep essential artwork near the center or choose `fit`.
PNG exports at 2× or 4× are suitable. SVG viewBox ratio governs composition.
Save the asset, then `touch appearance/skins/default.json` from the root to refresh.

Rail presentation now derives from `expanded || performanceOpen`: while either
is true, it shows the resolved system message instead of the avatar/metrics layout.
Opening Performance collapses temporary context but retains the message preview.
Closing Performance, or collapsing without Performance open, restores the default
layout. The underlying health message and priority resolver remain alive in all
states; a new higher-priority condition can still update the displayed message.
This supersedes the earlier always-visible minimized composition during expansion.

## Image fills for current shell surfaces

`backgrounds` in `appearance/skins/default.json` is the central image-fill registry.
See [the background folder guide](../../appearance/assets/backgrounds/README.md) for
all current keys and a copyable example. Empty paths preserve the current artwork.
The existing `persona.backgrounds` entries remain compatible; a nonempty
`backgrounds.senomy-rail` or `backgrounds.senomy-expanded` source takes precedence.
Fill artwork is independent of frame artwork. General fills are inset to preserve
borders; the inner-ring fill uses a circular GPU mask beneath the rings and avatar.

The Rail avatar now disappears during expanded context and returns when context
closes, including when Performance remains open. This supersedes the older
`expanded || performanceOpen` presentation rule above. The duplicate message-mode
portrait is removed. The chevron is replaced by a small labelled Expand/Close
control, retaining visible pointer, touch and keyboard access alongside hover.
The expanded media section appears only when the selected MPRIS player reports
playing; this indicates playback state, not measured audible output. MEM is cyan,
DISK amber, and disk retains its dashed line.


### Senomy expansion cues

The labelled Expand/Close control is superseded by three white upward chevrons on
each edge. They reveal on hover (or keyboard focus), pulse bottom-to-top, remain
animated during expanded context and fade out on departure. Clicking/tapping an
edge still toggles expansion; Up toggles and Escape collapses from Rail focus.
Reduced motion keeps the chevrons static. Hidden cues stop animating.


The expanded media slot now preserves its separator at all times. Controls remain
visible for any available MPRIS session, including paused/stopped playback. With no
session, `backgrounds.senomy-media-empty` supplies an optional image; an empty or
failed source leaves the slot empty. This supersedes the playing-only rule above.
