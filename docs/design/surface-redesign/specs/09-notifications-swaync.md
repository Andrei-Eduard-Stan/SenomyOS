# SwayNC notification surfaces

| Contract | Specification |
| --- | --- |
| Renderer | SwayNC / GTK CSS |
| Opens | Provider event for popup; client command for centre |
| Geometry | 500px popup/centre width; centre 500x600 top-right today |
| Frame | Standard native projection |
| Motif | clock-notification |

## Composition

Popup: app, urgency, time, title/body, bounded action row, close. Centre: provider title, DND, clear action, grouped notification ledger and empty state. Keep it visually secondary to Senomy Insights Notifications and do not add another Rail primary entry.

## Interaction and privacy

Preserve grouping, keyboard shortcuts, DND, clear, provider actions, timeouts, body-image bounds, and history capture. Notification prose stays local and may contain private material. Remove machine-specific paths only as a separate portability stage.

## Acceptance

No generic rounded-grey default remains; actions and dismiss are distinct; urgent state is local; the centre does not masquerade as a fourth primary Senomy surface.
