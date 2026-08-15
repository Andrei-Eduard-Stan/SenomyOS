---
title: Avatar States
category: Senomy
category_order: 30
order: 10
summary: Use bounded SVG, PNG, JPG, or animated GIF artwork through one context-aware catalog.
---

# Avatar states

The central registry is `data/senomy-avatars.json`. Every state has a chibi
asset for compact contexts and a portrait asset for larger contexts. Sources
may be SVG, PNG, JPG/JPEG, or GIF.

## Inspect or test the catalog

```bash
scripts/senomy-avatar.sh list
scripts/senomy-avatar.sh set thinking
scripts/senomy-avatar.sh reset
```

The manual state remains useful for asset testing. The visible companion state
is evidence-driven and may override it when a verified low-battery condition
or active media session exists.

## One visible identity

The Rail has one avatar beside the Senomy Insights dialogue. Clicking the
avatar opens the companion; clicking the dialogue opens Insights. The avatar
still reads as the profile image for the adjacent line because the controls
share one joined visual container.

Primary panel headers and content cards do not render additional character
images. The same `companion` resolver supplies the Rail trigger and the large
companion presentation:

| Priority | Evidence | State |
| --- | --- | --- |
| 1 | Verified combined battery at or below the warning threshold | `warning` |
| 2 | An MPRIS session reported playing by `playerctl` | `music` |
| 3 | No higher-priority observation | `browsing` |

## Replace artwork

1. Put the new image under `assets/senomy/`.
2. Change that state's `chibi` or `portrait` path in the manifest.
3. Keep paths relative to the Eww configuration directory.
4. Keep animated GIFs below the documented size, dimensions, and frame limit.
5. Wait for the catalog refresh, or use the controlled shell restart.

GIF sources are decoded into private context-sized animated variants. This
avoids Eww 0.5 rendering the original animation at an unbounded intrinsic size.

| State | Intended use |
| --- | --- |
| idle | Calm observation |
| focused | Active work |
| thinking | Analysis or discovery |
| happy | Successful completion |
| warning | Verified attention state |
| busy | Bounded operation in progress |
| sleeping | Quiet or idle mode |
| browsing | Insights knowledge and research identity |
| music | Verified active MPRIS playback |

See [[companion|Senomy companion]] for its controls and evidence policy.
