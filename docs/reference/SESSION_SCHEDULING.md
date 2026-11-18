# Session controls and system commitments

Current implementation: 2026-11-01. This supersedes the October 25 timing and
runtime-only absolute-schedule policy. Open the existing Session control at the
right end of the Rail.

Session uses two chambers: **ACTION** on the left and **EXECUTION** on the right.
The stable vertical list is Lock, Sleep, Log out, Restart, Shut down. Opening
without a pending instruction starts unselected in NOW, with one concise hint.
Selection populates the execution chamber and never dispatches an action.
The integrated **NOW | SCHEDULE** selector leads to either consequence review
and CONFIRM NOW, or **COUNTDOWN | DATE & TIME**, review and CONFIRM SCHEDULE. A replacement review names the existing instruction and offers
REPLACE SCHEDULE or Back. There is one pending instruction per user runtime.

Countdown fields accept direct hours/minutes/seconds editing, arrow keys and
visible increment/decrement controls. Valid duration: 1 second through 7 days.
Date/time accepts an actual local date and 24-hour HH:MM, from ten seconds ahead
through the next year. Nonexistent DST times are rejected; repeated hours require
an explicit first/second occurrence. The review shows date, timezone and offset.
The resolved epoch remains fixed if the device's timezone subsequently changes.

After creation, the right chamber becomes **03 / ACTIVE SCHEDULE**. It replaces
the editor with the instruction type, exact date/time, remaining duration,
depleting timeline and creation/execution endpoints. The left command list stays
in place. Missed or failed instructions use the same chamber for safe recovery. **EDIT**, **EXECUTE NOW**, **CANCEL**, **+10 MIN** and
**+30 MIN** manage it. Execute now always requires another consequence review;
postpone and cancellation are direct, non-destructive management operations.
Selecting another command opens a draft while the pending instruction remains
authoritative. The **ACTIVE SCHEDULE** return control restores its monitor; a
replacement requires explicit review. Editing an absolute instruction preserves
its type. Closing Session or pressing
Escape never cancels an existing instruction. Escape first backs out of a review
and then dismisses the popup, following the existing coordinator.

The default popup is 640 logical pixels wide (680 in touch density), clamped to
the owning output. The content divides approximately 36/64 with a 24px chamber
gap. At narrow widths or large text sizes the same chambers stack in order, with
focus-aware scrolling. A short wide work area also scrolls the command list when
necessary. Review controls remain fixed at the bottom. Short fades, hover
luminance and height transitions use the existing reduced-motion policy; the
authoritative progress line has no decorative animation.

[Dual-chamber implementation and validation](../PROJECT_STATE.md).
Scheduling, persistence, notifications, Rail and dispatch semantics below are
unchanged by this presentation redesign.

## One owner, three views

The Python scheduling layer owns identity, type, resolved deadline, timezone,
creation time, lifecycle and all operations. One PowerService observes its atomic
runtime receipt. Session, the Notifications/Insights shared notification renderer
and the existing 64px Rail session control read that same observable model.
There are no independent QML countdown timers and no per-second Notify calls.

A pending instruction is a **SYSTEM COMMITMENT**, separate from application history.
It stays pinned without a notification timeout or clear-all deletion. It provides
one-click Cancel and Open Session. Opening/closing Notifications never creates
another schedule. The Rail replaces only its existing Session logo with a compact
action/countdown and structural line; CPU/MEM/UP telemetry and island widths are
unchanged. This avoids competing with ownership of the Performance island.

The native thin structural rail depletes with the remaining fraction; the text
countdown is precise. Normal structure uses existing silver/graphite tokens.
At 10 minutes the urgency model becomes approaching, at five minutes it adds a
consequence warning, and at one minute the existing notification overlay shows a
critical countdown. DND suppresses that overlay until the last ten seconds; the
pinned commitment remains accessible throughout. The final ten-second overlay
bypasses DND with only the action, time and consequence. It never takes keyboard
focus. Its opaque backdrop preserves readability over other windows, and its
Cancel/Open Session footer remains fixed when the content must scroll.

## Execution and persistence

A confirmed instruction starts a unique transient **systemd user service**. Only
while an instruction is pending, its small worker samples time once a second,
publishes a private runtime receipt and checks login identity at most every five
seconds (also rechecking immediately before dispatch). No always-running daemon,
enabled service, user lingering, wake alarm or system-wide power policy is added.
Quickshell may restart independently of this service.

- **Countdown:** authoritative private record under
  `$XDG_RUNTIME_DIR/senomyos/session-countdown.json`; Linux `CLOCK_BOOTTIME` is the
  suspend-aware deadline clock. Confirmation establishes the deadline, so time
  spent in review is not counted. Login/boot/compositor identity invalidates it
  after logout; a new runtime cannot restore it as pending.
- **Absolute:** authoritative private record at
  `${XDG_STATE_HOME:-$HOME/.local/state}/senomyos/session/absolute.json`. It stores
  the resolved epoch, original timezone, timezone-file fingerprint and lifecycle.
  A future pending instruction is re-armed when SenomyOS starts in a valid login.
  A past unavailable deadline is marked MISSED, never re-armed for immediate
  catch-up. Terminal records remain terminal across reboot.
- **Shared view:** `$XDG_RUNTIME_DIR/senomyos/session-schedule.json`, with one
  authoritative remaining-time/progress/urgency snapshot. Heartbeats are kept in
  tmpfs, not written to durable state each second. The runtime view omits login
  identity and internal review data. There are no credentials or unrestricted logs.

Persistent means the *instruction* survives logout/reboot. **Execution while
logged out is unsupported in this implementation.** The worker belongs to
`graphical-session.target`, requires a valid desktop login and does not wake the
machine. A powered-off machine cannot run an action. No permission to change
lingering or add privileged background execution is implied. The pending panel
and review state these limits.

The worker compares BOOTTIME, MONOTONIC and realtime samples. A deadline crossed
through suspension, a sampling gap over three seconds or an absolute clock jump
becomes MISSED. Resume before a deadline may continue normally. A continuously
available worker dispatches at the deadline without a second confirmation. The
three-second availability/jitter bound is deliberately conservative; a heavily
stalled scheduler can mark a commitment missed instead of surprising the user.
MISSED retains the instruction with Edit, Execute now and Cancel.

Calendar timer `Persistent=` catch-up does not satisfy the missed-deadline policy.
A supervised worker supplies continuity evidence, independently of the UI.
Relevant primary references: [systemd timers and suspend/catch-up](https://www.freedesktop.org/software/systemd/man/latest/systemd.timer.html),
[transient user services](https://www.freedesktop.org/software/systemd/man/latest/systemd-run.html),
[Python CLOCK_BOOTTIME](https://docs.python.org/3/library/time.html#time.CLOCK_BOOTTIME).

Every mutation, replacement and dispatch claim holds one private durable file
lock. A new identity invalidates an obsolete worker. Cancellation writes a
terminal record before stopping the worker; even a stop failure cannot authorise
its dispatch. EXECUTING/running cannot be cancelled/replaced. Dispatch is claimed
before invoking the unchanged `scripts/senomy-session-action run ACTION --confirm
ACTION` boundary. Results say “request sent,” not that a physical power transition
was observed. A lost result is unverified and never retried. Authentication and
inhibitors remain in force; no force switches are introduced.

## Validation and recovery

```bash
python3 scripts/validate-session-scheduler.py --out /tmp/senomy-session-qa
python3 scripts/validate-session-worker.py --out /tmp/senomy-session-worker-qa
SENOMY_SOURCE_ROOT="$PWD" bash scripts/validate-quickshell-notifications.sh
```

The first suite uses fake actions, private runtimes/state/stores and private
D-Bus sessions. Its native QML compilation opens no visible surfaces. The second
starts fixture-only transient user services whose only dispatcher calls the
existing handler's **dry-run** verb; all fixture units exit after their results.
Neither suite runs a real session/power action.

[Review, scoped diff, evidence and limitations](../PROJECT_STATE.md).
configuration. Recovery instructions and exact baseline hashes are recorded in
that review. No commit or push is part of this change.
