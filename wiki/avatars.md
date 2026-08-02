---
title: Avatar States
category: Senomy
category_order: 30
order: 10
summary: Replace artwork once, then let independent context domains select appropriate states.
---

# Avatar states

The central registry is `data/senomy-avatars.json`. Every state has a chibi
asset for compact contexts and a portrait asset for larger contexts.

## Switch the ambient state

```bash
scripts/senomy-avatar.sh list
scripts/senomy-avatar.sh set thinking
scripts/senomy-avatar.sh reset
```

This manual state controls the `ambient` domain used by the bar. It does not
override battery, performance, or Insights avatars.

## Independent domains

Each use of `senomy-avatar` declares a domain:

| Domain | Evidence | Current locations |
| --- | --- | --- |
| ambient | Manual `chibi_state` | Main bar |
| battery | UPower state and combined percentage | Control Centre Power |
| performance | CPU, memory, and failed-service observations | Performance observer |
| insights-header | Fixed `browsing` identity | Insights header |
| insights | Current Insights route | Future Insights subsection avatars |

The domains resolve independently. A low battery can therefore show
`warning` in Power while the bar remains `idle` and Insights remains
`focused`. The resolver lives in `widgets/senomy-avatar.yuck`; panels provide
only their domain and presentation context.

## Replace artwork

1. Put the new image under `assets/senomy/`.
2. Change that state's `chibi` or `portrait` path in the manifest.
3. Keep paths relative to the Eww configuration directory.
4. Wait for the five-second catalog refresh, or use the controlled Eww reload.

| State | Intended use |
| --- | --- |
| idle | Calm observation |
| focused | Active work |
| thinking | Analysis or discovery |
| happy | Successful completion |
| warning | Verified attention state |
| busy | Bounded operation in progress |
| sleeping | Quiet or idle mode |

See [[panels|Contextual panels]] for the shared interaction model.
