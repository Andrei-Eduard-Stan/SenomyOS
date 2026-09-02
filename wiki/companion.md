---
title: Senomy Companion
category: Senomy
category_order: 30
order: 5
summary: Use the single Rail avatar to open a bounded, reactive edge companion without duplicating Senomy across panels.
---

# Senomy companion

The avatar beside the Rail dialogue is Senomy's only persistent profile image.
It opens a large ambient companion while the adjacent dialogue continues to
open Senomy Insights. Primary headers and cards deliberately leave character
space out.

## Window modes

| Mode | Presentation |
| --- | --- |
| Expanded | Edge sidecar with large artwork, observation, source, and Insights route |
| Compact | Transparent avatar stage with a bounded observation strip |
| Closed | No companion window; the Rail avatar remains available |

The toolbar can snap the window left or right, pin the current session,
minimize or expand, and close. Edge snapping is deliberate: Eww layer windows
are not normal freely draggable desktop windows. The overlay does not reserve
work area, request keyboard focus, or block another primary surface.

## Reactions and evidence

Verified low battery from UPower has priority. Active music is accepted only
when `playerctl` reports an MPRIS session as playing. Otherwise Senomy uses the
normal browsing presentation. A missing player or missing metadata is shown as
unavailable and is never inferred from a browser or window title.

The pin is session-only. Without a pin, an expanded companion may collapse
after a bounded quiet period. Closing the window clears the current companion
session without changing Control Centre, Performance, or Insights.

## Useful checks

```bash
scripts/companion-state.sh status
scripts/companion-media.sh | jq .
scripts/senomy-avatar.sh list
```

Continue to [[avatars|Avatar states]] or return to
[[panels|Contextual panels]].
