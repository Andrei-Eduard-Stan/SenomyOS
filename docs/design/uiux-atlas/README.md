# SenomyOS UI/UX Design Atlas

Open **SenomyOS-UIUX-Design-Atlas.pptx** for the editable master workbook.
The current source worktree, including existing uncommitted work, is the baseline.
This folder contains documentation artifacts only. No runtime UI was published.

## Contents

- `SenomyOS-UIUX-Design-Atlas.pptx`: 16:9 editable visual workbook.
- `screenshots/full/`: original offscreen captures, grouped by owning area.
- `screenshots/crops/`: actual component crops used by the workbook.
- `inventory.json`: stable identifiers, ownership, verified source paths,
  capture state and method, image hashes, source hashes and slide references.
- `routes.json`: the current Settings navigation tree, including focus anchors.
- `preview/`: a PDF rendered from the PPTX, PNG slide previews, contact sheets
  and local validation results. The PDF is supplementary.
- `tools/`: repeatable capture, build, render and validation programs.

The exact counts are in `inventory.json` under `summary`. A subpage is not
necessarily a separate window. Focus anchors and reusable components have their
own kinds and are excluded from the surface count. Source-only smaller QML
definitions remain discoverable in `source_catalog`.

## Reading and editing

Sections A–F contain the master collages, current-state gallery, Before/After
worksheets, component anatomy, authentication layouts and planning trackers.
Source references also appear in slide notes. Native text, borders, numbered
annotations, colour swatches, tracker tables and worksheet fields stay editable.
Screenshots remain image objects.

Duplicate one of the three blank comparison slides for a new design. The
`ATLAS_COMPARISON` master supplies reusable Before and After placeholders.
Use PowerPoint's **Change Picture** or insert an image and preserve its aspect
ratio. Keep the baseline on the left. Add a proposal on the right, then record
review and implementation decisions in the native fields.

Image-level `slide_refs` identify slides that actually embed that image.
`deck_representation: additional_asset` means an extra responsive or interaction
capture is available in this folder without a repetitive gallery slide. The
owning item's `slide_refs` identify its gallery, comparisons and tracker entries.

## Capture boundaries

All new desktop and SDDM screenshots use **NATIVE PREVIEW**: actual current QML
and assets, controlled providers, offscreen Qt hosts and private D-Bus sessions.
Providers use synthetic account names, notifications, devices, processes, events
and network information. Calendar operations use a temporary database and daemon.
Session and battery-care transports are pre-existing inert fixtures.

No new live desktop screenshot was taken. No genuine employee, email, message,
credential or customer data was loaded. No remote rendering or publication was
used. Existing running applications and the live display draft were left alone.

Hyprlock images are explicitly **UNAVAILABLE / offline configuration projection**.
They parse current geometry, colours and asset bindings and substitute a static
background. They do not prove native Hyprlock rasterisation, PAM, unlocking or
error feedback. The native lock was never activated. The source preview helper
also reports a known Loader height-binding warning in that limited projection.

Other gaps are explicit inventory entries: physical monitor identification,
external system password/authorization handoffs, the native avatar file chooser,
Plymouth boot rendering and the GTK theme in a file-manager application. Physical
touch/OSK and compositor placement remain separate acceptance work. Current-source
SDDM may differ from the installed greeter. GRUB is deferred.

## Regenerating captures

Prerequisites: the project's existing `qs`, Qt 6 Quick/Test modules,
`dbus-run-session`, Python 3, ImageMagick and installed SenomyOS fonts/assets.
The calendar fixture additionally needs the existing private calendar Python
runtime under the user's XDG data directory.

Run from this repository, after reviewing the current source. Each job copies
QML into a temporary directory and changes only compositor hosting or providers.
It does not edit watched QML, open a live surface, deploy a theme or change hardware.

```bash
python -B docs/design/uiux-atlas/tools/capture.py --jobs control
python -B docs/design/uiux-atlas/tools/capture.py --jobs directories
python -B docs/design/uiux-atlas/tools/capture.py --jobs controls popups audio
python -B docs/design/uiux-atlas/tools/capture.py --jobs calendar-quick tray
python -B docs/design/uiux-atlas/tools/capture.py --jobs session session-popup session-surfaces
python -B docs/design/uiux-atlas/tools/capture.py --jobs bluetooth display auth calendar
python -B docs/design/uiux-atlas/tools/capture_extra.py
```

Read the job logs if a fixture fails. A new source change can require updating
an isolated provider schema. Do not replace missing evidence with a drawn mock.
Recapture after source changes before rebuilding a current-state atlas.

## Rebuilding the PowerPoint

The builder uses PptxGenJS 4.0.1 and Sharp 0.34.5. These run locally. Dependencies
may be installed in a temporary folder, with no system installation required:

```bash
ATLAS_DEPS="$(mktemp -d -t senomy-atlas-deps-XXXXXX)"
cp docs/design/uiux-atlas/tools/package*.json "$ATLAS_DEPS/"
npm ci --prefix "$ATLAS_DEPS" --no-audit --no-fund
ATLAS_DEPS="$ATLAS_DEPS" node docs/design/uiux-atlas/tools/build.mjs
python -B docs/design/uiux-atlas/tools/validate.py
```

On the original host the bundled Node executable is at
`/usr/lib/chatgpt/resources/cua_node/bin/node`; its npm entry point is
`/usr/lib/chatgpt/resources/cua_node/lib/node_modules/npm/bin/npm-cli.js`.
Use these only when ordinary `node` and `npm` are not on PATH.

The builder reads genuine captures, creates precise native component crops,
embeds images and native slide objects, rebuilds the inventory, and removes
orphan content-type declarations emitted by PptxGenJS 4.0.1. It does not alter
slide content during that package repair. Rebuilding replaces this generated
PPTX and its generated inventory, so save a separate copy of manual redesign
edits first. Capture/build scripts never modify application source.

## Rendering and verification

```bash
python -B docs/design/uiux-atlas/tools/render.py
```

Use an existing LibreOffice installation and Poppler, or supply a separately
extracted office runtime without installing it:

```bash
python -B docs/design/uiux-atlas/tools/render.py \
  --office-root /path/to/extracted/runtime
```

`render.py` opens the actual PPTX through LibreOffice, converts it to PDF and
renders slide PNGs in bounded batches. `--first` and `--last` render selected
pages. `--montage-only` rebuilds contact sheets from completed PNGs. PowerPoint
on another device may substitute unavailable fonts. Images are embedded, so
they do not depend on paths on this computer.

`validate.py` checks OOXML relationships, page bounds, embedded image proportions,
native editability, inventory references and source drift. It cannot replace a
visual review or claim Microsoft PowerPoint testing.
