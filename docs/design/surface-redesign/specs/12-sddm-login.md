# SDDM login

| Contract | Specification |
| --- | --- |
| Renderer | SDDM QML |
| Opens | Pre-session display manager |
| Composition | Approved lower authentication rail |
| Frame | Large authentication projection with Compact utility cells |
| Motifs | identity and power |

## Composition

Preserve privacy-safe background, identity/avatar, user/password, session selector, time/layout, accessibility, power, restart, recovery, and confirmation states. Use QML-native lines/assets to project Luminous Reliquary; do not port Eww code.

## Interaction and security

Keyboard-first login, visible focus, error/success feedback, session choice, password privacy, and explicit confirmation are mandatory. Utility actions must never be mistaken for authentication submission.

## Acceptance

Validate normal, first login, wrong password, locked/disabled control, session selection, accessibility, power/restart confirmation, recovery handoff, narrow scaling, and missing asset fallback in the real SDDM renderer.
