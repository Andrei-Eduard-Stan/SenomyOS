---
title: Contextual Panels
category: Shell
category_order: 20
order: 10
summary: How the shared surface coordinator keeps panels and flyouts mutually exclusive.
---

# Contextual panels

SenomyOS has primary surfaces and compact flyouts. The script
`scripts/surface-state.sh` is the only component allowed to coordinate their
window lifecycle.

## Primary surfaces

1. Control Centre
2. Performance Dashboard
3. Senomy Insights

Only one primary surface can be active. Volume and tray are transient flyouts,
and they cannot overlap a primary surface or each other.

## Useful checks

```bash
scripts/surface-state.sh status
eww active-windows
```

Return to the [[welcome|Wiki introduction]] or continue to
[[avatars|Avatar states]].
