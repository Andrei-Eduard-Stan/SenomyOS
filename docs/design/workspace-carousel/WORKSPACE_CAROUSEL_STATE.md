# Workspace Carousel State

## Ownership

Hyprland remains the only workspace source. `workspaces.service` publishes the
sorted real positive workspace IDs and their application cells through
`workspace_state`. The carousel stores no workspace copy and never invokes
`hyprctl`.

## Presentation model

- standard/narrow capacity: four visible workspace islands;
- phone capacity: the active workspace only, without carousel controls;
- offset: index into the current filtered `workspace_state` array;
- previous offset: retained for the inactive animation page;
- slot: selected GtkStack page buffer, `0` or `1`;
- direction: `previous` or `next` for the native slide transition.

At four or fewer items, offset is zero and no navigation controls are rendered.
At five or more, both 28x56px controls are allocated around a four-chip
same-size viewport. The boundary direction is disabled rather than removed.

## Interaction contract

- Previous/next and vertical/horizontal scroll move the viewport by one item.
- Manual movement never changes the Hyprland workspace.
- Clicking a visible chip switches to that chip's real positive workspace ID.
- Listener reconciliation moves the minimum distance needed to reveal an
  active item outside the view.
- Runtime removal clamps an invalid end offset before publishing the next page.
- Returning to four or fewer items restores offset zero and the unchanged
  non-overflow layout.
- A runtime `flock` serializes rapid inputs so page-buffer state is updated as
  one tuple and cannot overscroll.

## Evidence

- Approved non-overflow before/after:
  `live/workspace-carousel-nonoverflow-before-vs-after.png`
- Exact capacity:
  `live/workspace-carousel-exact-capacity-rail.png`
- First overflow, settled:
  `live/workspace-carousel-first-overflow-settled-rail.png`
- Final page at eight workspaces:
  `live/workspace-carousel-many-end-rail.png`
- Active workspace outside the initial view:
  `live/workspace-carousel-active-outside-follow-rail.png`
- Runtime removal and restored non-overflow state:
  `live/workspace-carousel-runtime-removal-rail.png` and
  `live/workspace-carousel-restored-rail.png`
- Consolidated state comparison:
  `live/workspace-carousel-state-matrix.png`

The deterministic contract is `scripts/validate-workspace-carousel.sh` and is
also called by `scripts/validate-rail-contracts.sh`.
