# SenomyOS production frame assets

This directory owns the reusable **Luminous Reliquary** frame system. The
approved PNG sheet is visual direction only; no production SVG embeds, crops,
traces, or stretches that raster artwork.

## Authoritative sources

- `frame-system.json` — tier metrics, safe zones, stretch rules, motif
  thresholds, anchors, states, validation sizes, and asset manifest.
- `templates/senomy-frame-module.svg.in` — tokenized standalone SVG wrapper.
- `../../tokens.json#/frame_system` — frame palette and glass-state tokens.
- `../../../scripts/frame_geometry.py` — separately authored Compact,
  Standard, and Large path geometry.
- `../../../scripts/generate-appearance.py` — deterministic asset projection.

Generated files live under `generated/` and must not be edited directly:

```text
generated/
  compact/   4 fixed corners + 4 neutral edges
  standard/  4 fixed corners + 4 neutral edges
  large/     4 fixed corners + 4 neutral edges
  motifs/    workspace, identity, telemetry, controls,
             clock-notification, power, diagnostic-tick, junction
  crests/    mini, medium, wide
```

The three optical tiers are related but not scaled copies. Consumers compose
fixed corners, fixed anchored motifs or crests, and only the neutral edge
segments required for the current width and height. Optional detail is hidden
when its manifest threshold is not met; it is never squashed.

The Rail uses only the Compact tier in this implementation. Standard and Large
exist for future migration but are not yet applied to other SenomyOS surfaces.

Build and verify with:

```bash
./scripts/generate-appearance.py build
python3 scripts/validate-frame-system.py \
  --artifacts-dir docs/design/frame-system/harness
```

The validator checks all 35 standalone SVGs, embedded-content restrictions,
manifest geometry, transparent content centres, fixed corner/motif pixels,
stable edge strokes, crest thresholds, adaptive workspace label bays, and the
required Compact, Standard, and Large size matrix.
