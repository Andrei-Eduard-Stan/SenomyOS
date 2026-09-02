---
title: Notification History
category: Senomy
category_order: 30
order: 20
summary: How Senomy Insights keeps a bounded private ledger after SwayNC popups disappear.
---

# Notification history

Senomy Insights retains sanitized SwayNotificationCenter entries after their
transient popup closes. This is a local history ledger, not a replacement
notification daemon.

## Privacy boundary

- Storage is local and mode 0600.
- The default retention cap is 120 entries.
- Application, title, bounded body, urgency, category, desktop entry,
  identifiers, and receive time may be retained.
- Actions and opaque hints are never retained.
- Nothing is uploaded automatically.
- Clearing requires a second confirmation click.

## Useful checks

```bash
scripts/swaync-history-integration.sh status | jq .
scripts/notification-history.sh read | jq .
```

If capture is unavailable, the panel shows the provider and integration state
instead of inventing history. See [[recovery|Shell recovery]] for UI lifecycle
problems.
