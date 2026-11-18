---
title: Notification History
category: Senomy
category_order: 30
order: 20
summary: Native Quickshell notifications and bounded private retained history.
---

# Notification history

Quickshell is the desktop notification owner. Notification Centre and Insights
share the bounded native history. Notifications can remain in the ledger after
their transient popup closes. Opening a list does not automatically read every
entry; reading, dismissing and clearing are distinct operations.

The retained history is local and capped at 120 entries. It stores the service's
explicit bounded metadata, text, timestamps and read/close state. Opaque provider
objects and executable actions are not serialized. Nothing uploads automatically.
A pending session commitment is a separate pinned category.

Clear history requires a review of the selected history/active notifications.
Changed membership requires review again. Storage failure is reported separately
from an in-memory change. Available actions must still belong to the current
live notification; closed/replaced items cannot invoke stale actions.

Use `senomy-shell status` or `senomy-shell doctor` for read-only ownership/health.
Do not start SwayNC/Dunst or use retired SwayNC integration commands to diagnose
this shell. Continue to [[recovery|Shell recovery]] for shell lifecycle problems.
