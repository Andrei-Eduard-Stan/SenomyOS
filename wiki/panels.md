---
title: Contextual Panels
category: Shell
category_order: 20
order: 10
summary: How the shared masthead and surface coordinator keep every primary panel consistent and mutually exclusive.
---

# Contextual panels

SenomyOS has primary surfaces and compact flyouts. The script
`scripts/surface-state.sh` is the only component allowed to coordinate their
window lifecycle.

All primary surfaces use the same Senomy Insights-derived masthead: eyebrow,
title, description, evidence chips, and visible close target. The character is
not repeated in mastheads or cards. Control Centre uses one stable wide
geometry so changing routes does not resize the window.

## Primary surfaces

1. Control Centre
2. Performance Dashboard
3. Senomy Insights

Only one primary surface can be active. Volume and tray are transient flyouts,
and they cannot overlap a primary surface or each other.

## Ambient companion

The companion is separate from this primary-surface coordinator. It can remain
beside a primary panel, uses one edge-snapped window, and has its own closed,
expanded, and compact lifecycle. It never reserves desktop space or opens the
full-screen dismiss layer.

## Useful checks

```bash
scripts/surface-state.sh status
scripts/companion-state.sh status
scripts/senomy-shellctl.sh doctor
```

Return to the [[welcome|Wiki introduction]] or continue to
[[companion|Senomy companion]].
