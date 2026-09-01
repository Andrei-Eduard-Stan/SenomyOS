# Surface redesign specs

These are concise visual contracts for the discovered SenomyOS surface families. They do not authorize implementation and do not replace the functional contracts in the repository.

Read [`../SURFACE_AUDIT.md`](../SURFACE_AUDIT.md) for evidence and rationale, then [`../DESIGN_MATRIX.md`](../DESIGN_MATRIX.md) for tier, reuse, priority, and implementation gates.

The specs deliberately preserve:

- `active_surface=none|control|performance|insights`;
- `active_flyout=none|volume|tray`;
- companion `closed|expanded|compact`, dock, pin, and timed collapse;
- all current routes, data sources, actions, confirmations, scripts, listeners, polls, and security boundaries.
