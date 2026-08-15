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
