# SenomyOS architecture

## Runtime and source ownership

Hyprland supplies the compositor and active Lua configuration. Quickshell is the
sole desktop shell and native notification owner. `shell/quickshell/shell.qml`
composes per-output Rails, one Control Centre workspace, Performance, Insights,
and quick popovers. The legacy checkout is historical recovery material, not a runtime.

The current worktree is `/home/Duku/SenomyOS`; installed helpers and tracked
configuration can differ from source. Runtime/source/deployment observations and
acceptance belong in [PROJECT_STATE](PROJECT_STATE.md). Keep portable defaults,
profiles and user state separate as specified in [PRODUCT_SPEC](PRODUCT_SPEC.md).

## Layers

| Layer | Owner |
| --- | --- |
| Presentation | Native components under `shell/quickshell/components/` |
| Session/lifecycle | `services/ShellState.qml`, native hosts, opening leases and IPC |
| Observed state | Native Quickshell services plus narrow adapters in `services/` and `scripts/` |
| Persistent organizer | `components/calendar/`, independent `senomy-calendar.service` |
| Appearance | Semantic `appearance/tokens.json`, authored skin/art sources and native projections |
| System integration | Components, bounded action helpers, deployment/package/service manifests |
| User data | XDG configuration/state and private runtime storage, separate from release defaults |
| Delivery | Existing user/system transactions and verified versioned-release tooling |

## Surface lifecycle

`ShellState.activePrimary` encodes none as an empty string, or control,
performance, insights. `controlMode` selects compact/full; one route/search
model, page tree and edit guard serve both. DashboardWindow transfers the same
Control Centre content into its native FloatingWindow for full Settings. Both
modes retain the searchable hierarchy and exact route identity. The overview uses
existing audio/network/power/notification owners; scoped ControlWorkspace controls
change presentation only. Shared draft/modal and native window lifecycle remain
in DashboardWindow, ControlCentre and ShellState.
Performance and Insights use scoped Island workspace windows owned by the same
primary coordinator. Performance retains its searchable system tree and direct
resource leaves; Insights uses compact destination navigation. Neither creates
a second collector, primary state or action coordinator.

One session-wide quick popover may coexist with a primary. ShellState and
QuickPopoverWindow own its kind/output token, opening lease, focus region and
immediate unmapping on replacement. Rails participate in the input region so
direct trigger switching is not lost to an outside click. Opening/focusing a
primary closes the quick popover. Delayed callbacks must validate their lease.
Required reviews and dirty forms are protected; Escape handles the innermost
cancelable review/overlay before its owner. A blocked close cannot report success.

Existing native hosts use shared visual retention.
`interaction/SurfaceMotion` retargets progress from its current value and signals
completion; it has no route, focus, provider or action authority. Quick popovers
retain pixels during dismissal with empty input and no grab, and drop retention
on replacement/capture/anchor loss. Every quick grab first admits only the popup;
Rails join after native Window.active, preserving direct switching without
letting a Rail take the initial keyboard focus. Same-token reopening reverses an unfinished
exit under a new opening lease. Authored island geometry stays at scale 1 inside
its existing native host. `NativePresentation` adds first-frame/content admission
and completion-driven retention inside existing primary/toast hosts, without
route, focus-grab or native-placement authority. DashboardWindow prepares the
Settings preferred/restored size before mapping, waits for matching actual
geometry before revealing content, then releases opening constraints. It keeps
shared content identity and native close/draft guards. Functional notification
dwell and Session deadlines retain their original owners. `ContentMotion` is
local visual feedback, never an input lock or data readiness claim. StableRows
reconciles directory/notification identities; it does not collect or persist data.
Verification/publication status belongs in PROJECT_STATE; the motion vocabulary
belongs in DESIGN_SYSTEM.


The expanded island's established window/artwork ownership remains. The independent
companion window, state and IPC were removed at the owner's request; identity
access stays with the expanded Island and Insights. Screenshot capture pauses/unmaps
presentation without discarding routes
or drafts; a bounded recovery timer restores it after failed capture clients.

## Providers and actions

Native objects own native state; presentation does not independently poll the
same source. UPower owns battery evidence, NetworkManager owns network profiles
and secrets, PipeWire/WirePlumber own endpoints and routing, BlueZ owns Bluetooth,
and MPRIS owns media identities/capabilities. TLP remains the existing energy
policy owner; confirmed narrow helpers do not become a general sysfs writer.

Actions use allowlisted operations and literal argv/identities. Review the exact
target and context; invalidate stale reviews on provider/target replacement.
Separate accepted requests from authoritative observed results. Missing fields
remain null/unavailable. Bound subprocess lifetime/output, retries and cancellation;
do not replay mutations blindly. Credentials and unrestricted logs never enter
shell state. Password input stays in the provider's terminal/PAM flow.

AccountsService integration retains active-account/last-viable-administrator,
retained-home and post-authentication identity safeguards. Missing or ambiguous
metadata disables unsafe operations. There is no alternate password database.

## Command Lens launch history

The accepted desktop-launch receipt in `scripts/senomy_app_launch.py` records a
best-effort count through `senomy_app_usage.py`. Private, atomic, bounded history
lives at `$XDG_STATE_HOME/senomyos/app-usage/history.json` (normal XDG fallback).
It contains desktop IDs, counts and last-handoff timestamps, never launch
arguments or document paths. Failed/unverified handoffs do not count; history
failure cannot change the launch result. This is accepted-launch frequency,
not proof of app readiness, usage duration or a retrospective activity recorder.
The Lens reads it through an event-watched FileView and refreshes on opening.

## Native file workspace

Thunar owns file browsing/operations and its native search, tabs, split, views and
menus. `components/file-manager/thunar/native/senomy-thunar.c` supplies presentation
only: one authored heading per window, compact toolbar glyphs, existing process-local
icons and metadata roles through native lifecycle events. It has no provider,
polling or file-action engine. The bounded clipboard registry/helper remains separate.

`scripts/build-thunar-ui.py` builds the GTK3 shared object for the host ABI; the
existing Thunar deployment transaction installs it. The workspace wrapper appends
only the regular non-symlink installed module to GTK_MODULES for a fresh owned
daemon, preserving incumbent modules and existing-daemon environment. It changes
no desktop-wide GTK/icon preference. Missing integration retains native fallback.

The explicit layout helper owns reviewed xfconf preferences and the shared native
GTK bookmarks file, not Thunar operations or a private Places model. It adds existing
local destinations, removes only an unlabelled duplicate Home and preserves aliases,
remote entries and unrelated owner choices. Exact preference/bookmark preimages and
owner-edit guards govern layout rollback; installed-file rollback remains the
separate deployment transaction. Launching does not reapply layout. See the
[Thunar component guide](../components/file-manager/thunar/README.md).

## Telemetry and detailed surfaces

SystemMetrics and TelemetryHistory own continuous CPU/per-core, RAM and network
sampling and bounded in-memory history. PerformanceService projects selected
history windows instead of starting another session sampler. Current source
uses a 900-sample/15-minute bound; frequency/pressure, disk and thermal reads have
separate bounded cadences. Counter resets, clock/suspend gaps, missing sources
and a fresh epoch cannot create invented samples.

Detailed inventory/process work is view-scoped. Diagnostics, benchmarks, package
checks and report generation are explicit. Histories preserve timestamps, nulls,
units and observation age. Component exports are private bounded snapshots of
the displayed payload; arbitrary commands belong in a real PTY. See
[Performance/Insights](reference/PERFORMANCE_INSIGHTS.md).

## Calendar, notifications and knowledge

Calendar owns canonical iCalendar series and private SQLite state in an
independent user service. One CalendarService client uses a same-UID private
socket. Persistence, recurrence, presentation, remote operations and notification
submission remain separate. Forms have durable drafts and navigation review.
See the [Calendar component](../components/calendar/README.md).

NotificationService owns the one native notification server when observed bus
ownership permits it. Active actions stay attached to their live objects;
serialization uses the service's bounded explicit field set. The retained
history cap is 120. Session commitments remain a separate pinned category and
do not enter notification timeout/history clearing. Do not start a competing
SwayNC/Dunst owner. Clearing and provider loss have explicit reviewed outcomes.

Insights keeps eight routes. InsightsRequests invokes the bounded local
`scripts/wiki-status.py` parser; it defaults to source-root `wiki/`, with an
explicit SENOMY_WIKI_ROOT override. Markdown is data: no embedded commands/HTML
execution or automatic external navigation. Wiki articles are maintained product
content rather than disposable development notes.

## Displays, workspaces and input

DeviceInventory shares display identities, selection and draft state. Geometry
uses logical desktop coordinates; the editor camera does not mutate geometry.
DisplayActions and the narrow Python adapter serialize reviewed transactions,
check Lua outcomes and readback, and supervise independent preview recovery.
Mirroring creates clone groups. Globally unique workspace IDs remain native;
local labels/order/home policy are projections consumed by Rail and editor.
Preserve conflicted drafts and watchdog/revert lifetimes through hotplug.

Input changes use typed Lua/provider results, preview/readback and compensation.
OSK follows its explicit/manual policy and provider capabilities; automatic idle
locking remains disabled by user choice. TTY administration, optional independent
credential recovery and release rollback are distinct recovery paths. See
[display](reference/DISPLAY_WORKSPACE_IMPLEMENTATION.md),
[OSK](reference/OSK_PROVIDER_CONTRACT.md) and [recovery](reference/RECOVERY.md).

## Delivery and maintenance

User/system deployment and release preparation/installation/activation remain
separate transactions. Verify payload identity, tracked modes and target
ownership, preserve exact preimages, reject drift and recover interrupted writes.
Changing a selector does not imply a service restart or successful cold login.
Preserve independent ordinary-application lifetime across shell recovery.

The release inventory includes core docs and `docs/reference/*.md`; dated QA,
archive bundles and design-library maintenance evidence are outside that document
selection. This is a shell payload, not an OS image or bundled dependency set.
See [release contract](reference/RELEASE_DEPLOYMENT.md) and
[deployment guide](../deploy/README.md).

## Documentation ownership

Seven core files own orientation, working rules, product, architecture, design,
workflow and current state. Focused reference contracts retain stable identifiers.
PROJECT_STATE is the sole progress and acceptance ledger. Old source checkouts,
mixed QA archives and deprecated adapters were removed by explicit owner request
on 15 November 2026. Current native source and installed integrations own behaviour.
