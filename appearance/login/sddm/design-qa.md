# SDDM frame-system design QA

final result: passed

- Source visual truth: `docs/design/frame-system/live/rail-frame-system-dynamic-workspace-created-crop.png` (1920x120), plus the current-login baseline `preview-final.png` (1920x1080).
- Rendered implementation: native `sddm-greeter-qt6 --test-mode` captures `preview-frame-system.png` (1920x1080, desktop) and `preview-frame-system-narrow.png` (600x900, narrow), device scale 1.
- State: first login, empty password, standard Hyprland selected, UK/US selectors available.
- Full-view evidence: `qa-full-old-new.png` compares the former monolithic rail with the five-instrument implementation.
- Focused evidence: `qa-focus-rail-login.png` puts the live Obsidian Rail and the rendered login instruments in one equal-width comparison.

## Findings

No actionable P0, P1, or P2 mismatch remains. The implementation uses the same
fixed silver/violet corners, neutral stretched edges, centred motifs, black
glass, monospace hierarchy, restrained accent state, and independent-island
rhythm as the live Rail. The authentication instruments are intentionally
taller than the 44px desktop Rail because they contain password and recovery
controls; their optical corner and motif sizes remain fixed.

Typography, spacing, tokens, source-vector sharpness, and copy were checked at
both viewports. The static privacy-safe background and empty-password disabled
button are intentional truthful login-state differences. No decorative source
asset was replaced with generated or hand-drawn artwork.

## Comparison history

- Earlier P1: the login was one flat enclosing rail with divider lines, unlike
  the source's independent framed instruments. Fixed by composing five
  Standard-tier `FrameSurface` instances with exact shared modules.
- Earlier P0 functional defect: normal authentication could submit the Recovery
  session. Fixed by excluding Recovery from preference, cycling, and final
  pre-login validation. The native desktop preview shows `HYPRLAND` selected.
- Post-fix evidence: both native captures render without QML warnings; static,
  generator, deploy-contract, and session-confinement validation passes.
