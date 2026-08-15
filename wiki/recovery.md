---
title: Shell Recovery
category: Shell
category_order: 20
order: 30
summary: Diagnose and safely reset a duplicated Rail, frozen panel, or disconnected Eww window graph.
---

# Shell recovery

Ordinary Eww clients use `--no-daemonize`, so an IPC failure cannot silently
bootstrap a second Rail. Startup and recovery count every Eww process tied to
this exact configuration, including a retained one-shot `open` command.

## Diagnose first

```bash
scripts/senomy-shellctl.sh doctor
scripts/surface-state.sh status
```

Use `scripts/surface-state.sh reconcile` when IPC works but visible windows and
state disagree.

## Full kill switch

```bash
scripts/senomy-shellctl.sh restart
```

Restart preflights Bash, SCSS, JSON, avatar, and isolated Eww definitions;
saves a bounded private incident report; stops only exact-config Eww processes;
restores one Rail; and resynchronizes workspaces. The Rail and panels disappear
briefly during this operation.

Raw `eww reload` is unsupported for this configuration because Eww 0.5 can
retain mapped windows while resetting state. Return to [[panels|Contextual
panels]] or inspect [[performance|Performance and benchmarks]].
