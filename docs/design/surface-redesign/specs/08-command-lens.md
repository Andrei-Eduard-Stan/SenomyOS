# Command Lens

| Contract | Specification |
| --- | --- |
| Renderer | Rofi / Rasi |
| Opens | Super+R, Rail Applications and bounded handoffs |
| Geometry | 720px wide upper-centre reference; responsive width cap |
| Frame | Standard token projection |
| Scopes | Applications, Files, Windows, Actions |

## Composition

Strong input line, four keyboard-readable scope tabs, icon/name/description result ledger, and shortcut footer. The Standard frame should be expressed with Rasi-supported border/background features or approved static assets; do not assume Eww's SVG frame widgets can be reused.

## Interaction

Preserve native Rofi selection, filtering, Ctrl+Tab scope switching, Enter action, Escape close, bounded Files provider, and allowlisted Actions provider. Selection uses one local violet signal rather than a broad glow.

## Acceptance

All four modes remain available, long results truncate safely, keyboard focus is unmistakable, touch density remains optional, and unavailable provider states are honest.
