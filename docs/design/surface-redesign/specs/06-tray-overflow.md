# Tray overflow

| Contract | Specification |
| --- | --- |
| Opens | Rail tray control |
| Geometry | Bottom-right above its Rail anchor; content-bounded with a maximum height |
| Frame | Standard |
| Motif | controls or junction |
| Interaction | Level 1 native registry and handoff |

## Composition

Use a concise app ledger: application identity, registration/running state, native-menu hint, and existing activation semantics. Keep the Applications deep link in a clear footer. Collapse the empty state instead of retaining a large void.

## States

Provider unavailable, no items, loading, one item, overflow/scroll, native menu open, focus, hover, selected.

## Acceptance

Do not reinterpret native tray item actions or inject untrusted labels into commands. Preserve outside-dismiss and the handoff to Control Centre Applications.
