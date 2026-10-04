# SenomyOS automation progress

Updated: 2026-10-04

## Fixed roadmap mapping

For this automation, milestones 1 through 6 map exactly to the six numbered
items under **Implementation order after Wi-Fi** in
`docs/SETTINGS_CAPABILITIES.md`. The historical stages in
`docs/IMPLEMENTATION_PLAN.md` are not the active automation roadmap. There is
no seventh item in scope.

## Milestone status

| Milestone | Classification | Source status | Physical acceptance still required |
|---|---|---|---|
| 1 — Notification bulk-clear confirmation | COMPLETE | Both bulk-clear routes use exact retained/active snapshots, explicit confirmation, persistence outcome reporting, and isolated controller/UI/private-bus tests. | Full live-view pointer and focus acceptance remains open. |
| 2 — Audio endpoint and power-profile guards | COMPLETE | Shared selection guards preview exact targets, revalidate readiness/membership/prior state, and wait for provider-observed outcomes. Isolated provider and shared-control tests pass. | Real endpoint routing and power-profile provider acceptance remains open. |
| 3 — Shared Bluetooth page ownership | COMPLETE | One route-scoped discovery owner and guarded adapter/device action controller are connected and fake-provider tested. | Physical multi-output, pairing, passkey, and device-outcome acceptance remains open. |
| 4 — Per-control parity and native process scope | COMPLETE | `docs/SETTINGS_CAPABILITIES.md` records per-control coverage and explicit gaps instead of broad parity. Native process scope is bounded inspection plus confirmed, identity- and ownership-checked SIGTERM; SIGKILL and service restart are unavailable, and narrower legacy Eww capabilities are recorded. | Physical selection and termination of a deliberately disposable user process remains open. |
| 5 — Display/input inventory and session reliability | COMPLETE | Shared read-only inventory, screen-loss reconciliation, isolated hotplug lifecycle coverage, guarded display configuration with independent rollback, saved defaults, topology, enable/disable, mirroring, and persistent input preferences are implemented and fake-provider tested. | Docking, hotplug, mirroring, rollback, fractional-scale, keyboard, pointer, and touch acceptance remains open. |
| 6 — Persistent preferences, native handoffs, and idle/session policy | INCOMPLETE | Existing source provides shell/input preferences, optional Fcitx5 handoff, Hypridle packaging, and a fixed lock/display-off policy. This run added validated persistent idle timeout preferences and deterministic Hypridle config generation without restarting the service. | Hypridle is absent on the reference runtime; fresh-login, lock, suspend/resume, authentication, recovery, and physical input acceptance remain open. |

## Current run

- Selected milestone: 6 — Persistent preferences, native handoffs, and
  idle/session policy.
- Completed stage: added an atomic mode-0600 preference store for whole-minute
  lock (1–60 minutes) and display-off (2–120 minutes) timeouts, requiring
  display-off to follow lock; generated only fixed allowlisted Hypridle
  directives; kept automatic suspend disabled; reported that activation is
  still required instead of restarting the service.
- Changed implementation:
  `shell/quickshell/scripts/session-policy.py`,
  `shell/quickshell/tests/test_session_policy.py`, and
  `scripts/validate-session-policy.sh`.
- Validation: `bash -n scripts/validate-session-policy.sh`; four isolated
  Python cases covering defaults, persistence/rendering/modes, invalid input,
  unknown operations, and corrupt state; Python compilation; targeted
  whitespace check. All passed. No live configuration or service changed.
- Commit: this focused milestone commit —
  `feat(settings): persist idle timeout policy`; its hash is reported by the
  automation run because a commit cannot contain its own stable hash.
- Push: not performed. The branch already contained four local commits beyond
  `origin/quickshell-v2` before this milestone commit, including the two
  incorrect-scope ledger commits. Publishing those unreviewed predecessors is
  outside this run's safe scope.
- Exact next stage: connect the validated lock/display-off preferences to the
  Control Centre through `SessionPolicy.qml`, with unavailable, saving,
  saved/restart-required, and error states. Because the authoritative QML tree
  is live-watched, publish that stage only with an explicit reload-risk warning
  and an isolated QML fixture prepared first. Lid policy remains a later bounded
  part of milestone 6; automatic suspend remains disabled pending physical
  acceptance.
