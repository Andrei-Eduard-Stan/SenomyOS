# Recovery UI

| Contract | Specification |
| --- | --- |
| Renderer | GTK in restricted recovery session |
| Opens | Explicit authentication/recovery path |
| Geometry | Fullscreen session with about 700x560 centred task panel |
| Frame | Large native projection |
| Motifs | diagnostic-tick and identity |

## Composition

One task only: explanation, identity/context, two password fields, exact status, Reset action, Return action. Keep credential fields and error text inside an undecorated safe reading zone.

## Interaction and security

Preserve the helper/sudoers boundary, password validation, explicit submit, error/success state, and return path. Recovery must remain usable without the normal Eww shell.

## Acceptance

Validate keyboard-only operation, wrong/mismatched password, helper unavailable, success, return, resolution scaling, theme/asset fallback, and restricted-session containment.
