# Expanded Senomy background corner fix — 2026-10-09

The source PNG is 850x350 with transparent cut corners. PersonaBackground uses
PreserveAspectCrop. At the expanded panel's different aspect ratio, horizontal
cropping removes the source transparency, exposing a rectangular image behind
the chamfered border. The source image and skin settings remain unchanged.

Apply a post-crop alpha mask only to the expanded PersonaBackground. Its 14px
cut corresponds to the existing 28px corner artwork's half-width diagonal,
and remains fixed as the panel changes aspect ratio. Reuse the project's
MultiEffect mask pattern, with a Shape silhouette and cached layer textures.
Missing-image backing behavior, frame artwork, content and controls are preserved.

Validation: qmllint and the existing expanded-panel fixture passed with the
OpenGL RHI backend: wide/narrow/empty renders, playback/seek/disabled seek,
navigation, reduced motion, telemetry lifecycle and disk-counter checks.
Rendered wide/narrow PNGs were visually inspected. Wide corner samples at
(11,11), (888,11), (11,408), (888,408) changed from alpha approximately
0.70/0.70/0.62/0.62 before to 0 after. All four sampled narrow corners also have
alpha 0. The original source corner is transparent. Renders and before-source
copy remain in the private development checkpoint expanded-corners-20261009.

The component is part of the preserved untracked baseline. Only this fix's
patch and before/after hashes are committed, preserving its unrelated content.
This is a current-renderer clipping correction, not a new design direction.
