---
title: Shell recovery
category: Shell
category_order: 20
order: 30
summary: Inspect the Quickshell service and use independent recovery when necessary.
---

# Shell recovery


`senomy-shell status` and `senomy-shell doctor` are read-only; `senomy-shell logs`
shows the bounded service journal. Inspect the error and correct the source
before explicitly restarting with `senomy-shell restart`. Restarting briefly
removes the Rail and panels and starts a new in-memory telemetry epoch.

If the desktop cannot be used, use a normal-account TTY with administrator
access. The optional Senomy Recovery login is a separately authenticated
password-reset convenience; credential-loss recovery needs its own acceptance.
Restore only a reviewed current native preimage after checking later edits.
Never reset unrelated work or treat a successful restart as data recovery.
