# Volume flyout

| Contract | Specification |
| --- | --- |
| Opens | Rail volume control |
| Geometry | Bottom-right above its Rail anchor; about 380x88 desktop |
| Frame | Standard |
| Motif | controls |
| Interaction | Level 2 bounded audio control |

## Composition

One horizontal channel strip: mute/source mark, output identity, accessible volume fader and value, route/open-Audio action, close. Use no inner cards.

## States

Loading, unavailable, output missing, muted, suspended, active, operation pending, operation failed, focus, hover, touch.

## Acceptance

Preserve current volume/mute/route behavior and Audio deep link. Minimum desktop controls are 40–44px; touch controls are 48px. Opening it closes or coexists with other transients exactly as the current coordinator specifies.
