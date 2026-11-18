# Display and workspace contracts

## Source and geometry

The shared DeviceInventory/DisplayDraft/DisplayActions services and adjacent
`shell/quickshell/scripts/display_core.py` own identities, drafts, native Lua
transactions and readback. DisplayCanvas projects logical geometry through a
camera; zoom/fit/pan never mutate a layout. Use current mode pixels, odd-rotation
swap and scale. Physical dimensions remain diagnostic metadata, not desktop size.
Keep exact stable selection across refresh/reordering. Equal refresh preserves
drafts; external topology changes freeze their baseline and require Discard or
explicit Rebase. A recovered cross-session draft is never auto-applied.

## Review, preview and recovery

Stage the complete topology for PC only, Duplicate, Extend, external only or
Custom. Review all affected outputs before Confirm. Pin complete native geometry
in one Lua batch to prevent untouched auto-position rules drifting. Individually
advertised modes do not establish a valid combined dock/MST configuration.

Arm a separate supervised user recovery service before writes. Verify a physical
recovery destination before retiring sources; a closed-lid internal screen cannot
be the sole recovery route. Reject virtual-only/unsafe missing-physical metadata
setups. Reduce output load before increasing other links, then verify complete
readback. An exit-zero legacy parser refusal is not success.

Verified application starts the bounded 15-second preview. Independent Keep/
Revert overlays survive page/Rail closure; use boot time rather than wall-clock
countdown. Keep rechecks state and commits the last-known-good layout durably.
Rollback compensates owned persistent rules, restores connected originals and
workspace destinations or a verified survivor, and refuses stale session/drift.
It cannot restore disconnected hardware. Repeated failure becomes visible and
retryable rather than an infinite recovery loop.

## Workspace identity and dynamic policy

Hyprland IDs are globally unique. Independent mode maps each real ID to a stable
home display and local slot; identical local numbers remain distinct groups.
Global mode projects the native namespace. Preserve occupied native IDs/windows
when changing mode. Managed numeric switch/move shortcuts resolve the focused
output and allocate slots on demand. Never seed or pin 1–10 from inventory or
Rail rendering. Explicit user pins remain an advanced preference.

Nonpersistent records follow native workspace lifetime; new compositor sessions
clear stale transient IDs. Moving an occupied group preserves its home identity
and exposes it as an accessible guest. Empty external landing groups follow the
native lifecycle rather than a sticky previously-used record. Optional external
visibility affects presentation only. Positive-ID orchestration does not invent
handling for unsupported special/named negative-ID workspaces.

Workspace/window moves have explicit alternatives to drag, validate target and
membership again, and verify native destination. Reordering changes presentation
order only. Refuse removal of populated groups. Native mirrors are clone groups,
not separate workspace areas. Preferred primary is notification placement policy,
not an invented compositor-wide primary-output flag.

## Persistence and hotplug

Profiles store confirmed geometry, mirror/enabled state, scale/rotation, workspace
mapping/order/pins, Rail visibility and notification placement preference in the
private schema-2 display-manager store. Use hashed serial-backed identities; an
ambiguous/serial-less connector fallback is explicitly weaker. Do not emit raw
serial/EDID to QML or replay old settings silently.

Native hotplug owns immediate window migration. Reconnect does not disable
outputs or pull occupied guests home automatically; Restore Home Groups is
explicit. Keep persistent dirty drafts separate from saved confirmed layouts.
Startup restore waits for a bounded stable exact display set, validates advertised
capabilities, skips after user intervention and records a private bounded outcome.
A matching layout needs no write. Session IDs are never application restoration.

## Verification and limits

Current delivery/physical acceptance belong in [PROJECT_STATE](../PROJECT_STATE.md).
Historical tests and physically previewed layouts are scoped in `docs/qa/display-*`
and `docs/qa/workspace-reconstruction-20261016/`. Do not copy dated selected modes
into portable defaults or treat a connected output as hotplug/recovery acceptance.

Quarantined native compositor runners remain disabled after the isolation incident.
Use inert model/transport/offscreen tests. Reopening native testing requires a
separate containment review, private bus/session, short validated IPC paths,
verified explicit targets and owned-process-only cleanup. Never dispatch an exit
against an inherited compositor environment. Current cable/suspend/link failure,
physical touch, mixed-DPI and relogin require their own exact acceptance.
