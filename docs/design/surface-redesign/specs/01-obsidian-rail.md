# Obsidian Rail

| Contract | Specification |
| --- | --- |
| Opens | Always visible; exclusive bottom shell layer |
| Geometry | 100% x 64 reference; 20px visual edge insets; 22px between island groups |
| Frame | Compact |
| Motifs | workspace, identity, telemetry, controls, clock-notification, power |
| Interaction | Level 2 shell navigation/control |

## Composition

Keep the current horizontal sequence: workspace cells → Senomy avatar/dialogue → CPU/MEM/UP telemetry → applications/audio/network/battery/tray → clock/notifications → power. Preserve the avatar as a separate control immediately beside the dialogue so the pair reads as one identity unit.

## Visual rules

- The Rail is the reference implementation of the family.
- Silver structure remains quiet; violet marks active workspace, active route, focus, and notification attention locally.
- No cyan/green compositor line should compete directly above it.
- Icon-only controls retain tooltips and gain obvious focus marks.
- Compact safe insets do not reduce primary targets below 36px desktop or 48px touch.

## Responsive proof

Mock up wide, laptop, narrow, portrait, phone, and touch modes before changing overflow behavior. Capability and priority rules replace model-name checks.

## Acceptance

Workspaces remain truthful; all current open/toggle targets remain; failed listeners do not collapse the Rail; every active state is unambiguous without relying on colour alone.
