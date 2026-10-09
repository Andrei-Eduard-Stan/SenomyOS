# Expanded foreground and bottom keyboard resize — 2026-10-09

Expanded Senomy uses the Overlay layer regardless of keyboard float mode, keeping it above ordinary application windows. Other primary panels retain their existing float-mode layer policy. Overlay peers still follow compositor stacking order; this does not override security/lock surfaces.

The native keyboard layout now reserves 24 px at both top and bottom. Previously the last key row occupied the bottom resize strip and covered its grip. All layouts use the reduced content rectangle.

Validation: pinned native provider rebuilt successfully; resize/shortcut unit tests (2), capability/provider/Caps helper tests (9/13/4), Qt controller tests (18), adapter fixtures, and actual private-compositor panel placement/layer fixture passed. Actual pointer dragging grew height 128→188 then shrank to 148, keeping y=50. Screenshot inspected: visible bottom grip separated from keys. Panel fixture has missing staged artwork warnings; layer/geometry assertions passed. No input was injected into user applications.

Consumer patch records the change against the existing untracked expanded-panel baseline; the surrounding dirty baseline is preserved. This is not a clean-checkout release claim.
