# Hyprland window decoration and motion

| State | Proposed treatment |
| --- | --- |
| Active tiled | 2px luminous silver edge, 4–6px rounding, no or minimal shadow |
| Inactive tiled | low-contrast cool-grey edge |
| Active floating | same edge, 6–8px rounding, restrained low-opacity shadow |
| Modal | centred, parent dim, clear focus, native privilege identity |
| Urgent | static local violet edge/title marker; no pulse |
| Fullscreen | no border, gap, rounding or shadow |

## Motion

Replace `popin 87%` with a subtle 98–100% resolve plus fade, or fade-only. Primary Eww layer motion and Hyprland layer animation must not animate the same transform. Reduced motion disables spatial transitions.

## Blur and opacity

Use blur only behind approved translucent floating fields. Dense reading/data planes remain approximately 92–97% opaque. Test performance before extending blur beyond the Rail.

## Gaps

Regularize outer gaps around 12–16px and coordinate the bottom with the Rail exclusive area. Floating and fullscreen exceptions remain explicit.

## Acceptance

Tracked and live Lua/config mirrors are deliberately synchronized, `hyprctl configerrors` is clean, and tiled/floating/modal/urgent/fullscreen states are visually tested before commit.
