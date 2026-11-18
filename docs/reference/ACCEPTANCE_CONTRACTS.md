# Operational acceptance contracts

C01–C20 preserve proposed domain acceptance requirements from the 25 October
functional audit, with stable IDs. Apply requirements to their actual supported
scope: optional or unsupported capabilities do not become mandatory features.
Current explicit product/user decisions take precedence. These standards neither
authorize mutations nor assert whole-domain acceptance. Current implementation,
release decisions and evidence limits belong in [PROJECT_STATE](../PROJECT_STATE.md).

Read-only status does not require invented undo/cancellation. Distinguish review
cancel, backend cancel and compensation. Evidence names source/payload hash,
provider versions, environment, verification level and exclusions. A fixture pass
establishes only the exercised path. Automatic idle lock remains disabled by policy.

## C01 — Obsidian Rail

Scope and source ownership: [inventory D01](CAPABILITIES.md#domain-01). Required operational outcomes:

- Each attached enabled independent output has exactly one correctly reserved Rail; hiding one cannot remove all access to Settings/recovery.
- External provider changes converge to status without opening a panel; unavailable providers never render invented success.
- Workspace rendering is observational and empty external landing workspaces stay quiet under the chosen policy.
- Every visible control has a keyboard/pointer path, accessible name and narrow-layout alternative; tray actions preserve their owning application.
- The supported configuration scope is explicit; unsupported module reorder is not represented as saved configuration.

| Lifecycle | Required behavior / applicable boundary |
|---|---|
| Discovery | Native screens and provider objects; no fixed output index |
| Availability | Per-module provider readiness and visible narrow-layout entry |
| Activation | Keyboard/pointer action routes through ShellState |
| Progress | Current status, busy and disabled states remain truthful |
| Completion | Rail operation only succeeds when intended route/model is observed |
| Failure | Failed provider affects its module, not launcher or recovery |
| Cancellation | Cancel reviews via owning action; status display has no cancellation |
| Retry | Reopen/retry owner once, not duplicate listener creation |
| Persistence | Per-output visibility/profile intent; transient pages need not persist |
| External changes | Native events update active/occupied/status without opening panels |
| Lifecycle | Hotplug/fullscreen/reload rebuild correct instances; apps survive |
| Integration | One primary and one popup; Insights remains first-class |
| Security | No module action bypasses its service confirmation/privilege checks |
| Diagnostics | Bounded provider/freshness and visible unavailable reason |
| Performance | One session sampler/provider; no per-Rail duplicate collection |

**Acceptance suite:** W01.01–W01.06 plus cited unit/integration tests. **Current evidence:** see [PROJECT_STATE](../PROJECT_STATE.md). **Dependencies:** D02, D09, D11, D16, D19, D20; G01, G07, G21.

## C02 — Quick popovers and panel management

Scope and source ownership: [inventory D02](CAPABILITIES.md#domain-02). Required operational outcomes:

- Opening another quick control replaces the old transient immediately and preserves the active primary; opening/focusing a primary dismisses the transient.
- Repeated activation closes the same popup; stale close/focus callbacks cannot dismiss a newer generation.
- Escape cancels a review without confirming; required reviews and dirty drafts cannot be silently lost through outside clicks.
- Native Settings remains one reusable resizable page tree; closing and mode switching preserve the agreed edit lifecycle.
- Physical focus restoration, nested-menu dismissal and hotplug anchoring must pass on at least two outputs and touch density.

| Lifecycle | Required behavior / applicable boundary |
|---|---|
| Discovery | Available screens/trigger identity and valid routes |
| Availability | Host mapped/readiness, current lease and modal state |
| Activation | One token/generation controls open/toggle/direct switch |
| Progress | Pending review and dirty-draft state clearly protected |
| Completion | Expected single visible transient plus preserved primary readback |
| Failure | Invalid route/stale callback/focus transport loss does not apply action |
| Cancellation | Escape cancels innermost review; explicit Keep/Revert for display |
| Retry | New activation uses a new lease; no stuck grab after failure |
| Persistence | Primary edit state as specified; popup open-state need not survive restart |
| External changes | Screen/window/focus changes reconcile only current generation |
| Lifecycle | Renderer reload/output removal cannot lose independently owned operation |
| Integration | Compact/full reuse page object; quick links use same providers |
| Security | No outside-click auto-confirm; required modal protection |
| Diagnostics | IPC interactionState plus scoped host/token failures |
| Performance | No hidden window per old generation or duplicate focus subscription |

**Acceptance suite:** W02.01–W02.06 plus cited unit/integration tests. **Current evidence:** see [PROJECT_STATE](../PROJECT_STATE.md). **Dependencies:** D01, D19, D20; G07, G22, G36.

## C03 — Command Lens

Scope and source ownership: [inventory D03](CAPABILITIES.md#domain-03). Required operational outcomes:

- Catalog actual installed apps, permitted local files, existing windows and allowlisted actions independently; one provider failing must not block others.
- Rank exact and prefix matches ahead of fuzzy matches; keep stable result IDs and keyboard selection.
- Keep outer geometry stable while query/results/loading change, bounded only by screen/input profile.
- Open/reveal only revalidated permitted paths using argv; report launch failures visibly without pretending a process start proves app readiness.
- Preserve application life across shell restart; discard stale provider replies; expose index bounds and refresh failure.

| Lifecycle | Required behavior / applicable boundary |
|---|---|
| Discovery | DesktopEntries/toplevels and permitted file catalogs independently |
| Availability | Provider loading/error and path/entry membership revalidation |
| Activation | Activate current stable result identity via fixed argv/desktop semantics |
| Progress | Provider refresh/activation state and bounded partial-index notice |
| Completion | Launch request/handoff distinguished from real window/route outcome |
| Failure | Missing executable/provider/path stays visible and retryable |
| Cancellation | Stale search results ignored; cancel refresh only if backend supports it |
| Retry | Explicit index refresh and retry valid result without shell restart |
| Persistence | Configured roots/pins if provided; query history optional/privacy scoped |
| External changes | Entry/window/file changes reflected after documented refresh |
| Lifecycle | New opening/session generation rejects delayed callbacks |
| Integration | Settings actions route through shared owner and fixed geometry |
| Security | No arbitrary shell query, unsafe desktop Exec parser or root escape |
| Diagnostics | Bounded provider identity/error without private query/file dumps |
| Performance | No subprocess per keystroke; bounded catalog/rank latency measured |

**Acceptance suite:** W03.01–W03.06 plus cited unit/integration tests. **Current evidence:** see [PROJECT_STATE](../PROJECT_STATE.md). **Dependencies:** D01, D02, D13, D19; G01, G08, G09.

**WP01 evidence, 2026-10-25:** the C03 application-lifetime/shared-launch boundary passes isolated service restart/reload/crash/stop, helper cleanup, GIO desktop/URI/default association, Terminal and D-Bus instance reuse checks. Lens uses asynchronous accepted/failed/unverified feedback and does not replay missing receipts. See [WP01](../PROJECT_STATE.md). C03 as a whole is not accepted: native Wayland/focus and real-session migration acceptance, along with other baseline requirements, remain open. This is also partial evidence for C01/C13/C16/C18/C19/C20, not whole-domain certification.

## C04 — Network and Wi-Fi

Scope and source ownership: [inventory D04](CAPABILITIES.md#domain-04). Required operational outcomes:

- Represent link, radio/hardware block and internet connectivity separately across multiple adapters; never equate Wi-Fi enabled with internet available.
- Scan on request with bounded ownership, connect open/saved/secured networks, and recover from auth failure without exposing secrets.
- Confirm disconnect/radio-disable/forget exact profile; stale state and service loss refuse execution and report uncertain completion.
- Support ordinary wired use and documented advanced native handoffs for hidden/enterprise, VPN, DNS and IPv4/6; disclose required plugins.
- Reconcile external nmcli/editor changes; preserve intended autoconnect in NM, not a second shell profile store.

| Lifecycle | Required behavior / applicable boundary |
|---|---|
| Discovery | NM device/radio/profile/connection objects; optional editor/plugins |
| Availability | Hardware block, managed state, auth/editor availability separate |
| Activation | Scan/connect or reviewed disconnect/disable/profile operation |
| Progress | Connection/scan phases with deadline and authentication handoff |
| Completion | Actual link/profile state plus connectivity; not process exit alone |
| Failure | Native error class and auth refusal without secret output |
| Cancellation | Cancel shell review; NM in-flight cancellation only when supported |
| Retry | Failed attempt allows bounded retry and native profile review |
| Persistence | NM owns profile/autoconnect/DNS; shell does not duplicate secrets |
| External changes | NM subscriptions and refreshed profile catalog follow external editor |
| Lifecycle | Radio/service/hotplug/resume invalidate stale targets/generations |
| Integration | Rail, quick panel and full network reflect same connection state |
| Security | Credentials in NM-owned TTY; disrupt/forget requires exact review |
| Diagnostics | Redacted interface/state/reason and source freshness |
| Performance | Event-driven devices; explicit bounded scan; no busy-loop nmcli |

**Acceptance suite:** W04.01–W04.06 plus cited unit/integration tests. **Current evidence:** see [PROJECT_STATE](../PROJECT_STATE.md). **Dependencies:** D02, D13, D19; G10, G11, G12.

## C05 — Bluetooth

Scope and source ownership: [inventory D05](CAPABILITIES.md#domain-05). Required operational outcomes:

- Discover adapters/devices, select one adapter and own only the discovery lease requested by SenomyOS.
- Pair with real agent prompts and reject/cancel safely; bound connect/pair/cleanup, preserve exact device generation and report native errors.
- Offer disconnect, retry, trust, block, alias reset and reviewed forget/cache removal; absent properties remain unavailable.
- Treat Connected, ServicesResolved, audio endpoint existence, default routing and audible output as separate milestones.
- Pass the CMF workflow without deleting pairing by default; survive provider restart/resume and show useful redacted diagnostics.

| Lifecycle | Required behavior / applicable boundary |
|---|---|
| Discovery | BlueZ ObjectManager adapters/devices and optional properties |
| Availability | Powered/blocked/paired/bearer/provider generation capability gates |
| Activation | Explicit Connect/Pair; exact review for disruptive/metadata changes |
| Progress | Per-device request ID, native phase, prompt and remaining deadline |
| Completion | Observe paired/connected/services milestones; audio is separate |
| Failure | Native error name/detail bounded and remote reason retained |
| Cancellation | Pair→CancelPairing; Connect→Disconnect; confirm cleanup or uncertainty |
| Retry | Retry after terminal state/cleanup, never automatic pairing deletion |
| Persistence | BlueZ owns bond/trust/alias; selection/operation state is session scoped |
| External changes | Properties/owner changes refresh snapshot with token invalidation |
| Lifecycle | Suspend/owner loss/hotplug reconcile active operations and scans |
| Integration | Audio card/profile/route link must be separately observable |
| Security | Agent prompt tied to current pair request/device; fixed bus methods |
| Diagnostics | Optional redacted report, no raw address unless explicit user choice |
| Performance | Single transport; bounded operations/discovery ticks and history |

**Acceptance suite:** W05.01–W05.06 plus cited unit/integration tests. **Current evidence:** see [PROJECT_STATE](../PROJECT_STATE.md). **Dependencies:** D04, D06, D12, D20; G13, G14.

## C06 — Audio and media

Scope and source ownership: [inventory D06](CAPABILITIES.md#domain-06). Required operational outcomes:

- Quick audio exposes dependable output/input level and mute plus current/default endpoints; full Settings owns app mixer, profiles, ports and diagnostics.
- Discover streams and hotplug endpoints with stable provider identity; revalidate before reviewed routing/default/profile changes.
- Confirm observed default/link/profile state and report timeout/provider disappearance truthfully; mute/volume remain responsive.
- Document whether remembered routes are hints or automatically enforced and test persistence accordingly; never silently move a call on discovery.
- Verify Bluetooth playback and capture independently, plus USB/HDMI hotplug, provider restart and session restoration.

| Lifecycle | Required behavior / applicable boundary |
|---|---|
| Discovery | Native nodes/links and bounded card/profile/route graph |
| Availability | PipeWire ready, current serial/cookie and supported profile/port |
| Activation | Routine level/mute; reviewed default/stream/profile/port mutation |
| Progress | One locked action, pending/running and actual route/meter state |
| Completion | Observe default node/link/profile/route, then physical sound/capture |
| Failure | Provider loss/timeout cannot claim changed stream or restored audio |
| Cancellation | Cancel pending review; submitted routing may finish, report uncertainty |
| Retry | Reconnect failed graph subscription without closing whole shell |
| Persistence | WirePlumber default and explicit saved-route hints; no hidden auto-move |
| External changes | Native node/link notifications follow wpctl/other applications |
| Lifecycle | Endpoint churn and PipeWire/WirePlumber restart discard stale identity |
| Integration | Bluetooth connection distinct from audio card, output, app and mic |
| Security | No arbitrary metadata keys/commands; direction and target revalidated |
| Diagnostics | Graph source generation + supported fixed diagnostic/service actions |
| Performance | Native volume immediate; graph watch only relevant views; bounded data |

**Acceptance suite:** W06.01–W06.06 plus cited unit/integration tests. **Current evidence:** see [PROJECT_STATE](../PROJECT_STATE.md). **Dependencies:** D05, D11, D13, D17; G14, G15, G16.

## C07 — Power, battery and session controls

Scope and source ownership: [inventory D07](CAPABILITIES.md#domain-07). Required operational outcomes:

- Aggregate zero/one/multiple batteries from real energy/state, distinguish AC/full/charging/pending and mark absent estimates unknown.
- Use one authoritative installed power-policy provider; update its availability on service changes and hide unsupported hibernate modes.
- Session actions require exact review, authorization and authoritative outcomes; scheduled actions retain identity, expiry, cancellation and one-shot dispatch.
- Preserve the explicitly chosen inactive automatic-idle policy. Do not classify it as broken or require activation for acceptance. Any future idle/display-off/lid installation is separately chosen; configured proposals and actual runtime remain distinct. Manual lock/sleep and inhibitors retain separate attended acceptance.
- Test lid/lock/unlock and resume only under separate authorization. Threshold editing requires authoritative vendor ranges, safe authorized persistence/readback/restoration; read-only detection alone does not advertise editing.

| Lifecycle | Required behavior / applicable boundary |
|---|---|
| Discovery | UPower packs, AC, logind actions, policy providers and receipt owner |
| Availability | Actual service/running/enforced state distinct from installed/configured |
| Activation | Reviewed session/profile/schedule changes; no unsupported power actions |
| Progress | Pack states, review token and scheduled deadline/remaining state |
| Completion | Observed profile/timer/session state; lock needs actual secure surface |
| Failure | Permission/inhibitor/provider/timer/rollback errors are explicit |
| Cancellation | Cancel review or exact scheduled timer; no cancel after session exit |
| Retry | Revalidate capabilities/session before retry; never force inhibitors |
| Persistence | Preferences and timer receipt policy explicit across login/boot |
| External changes | AC/pack/provider/schedule changes reconcile without opening popup |
| Lifecycle | Sleep/resume/lid/new login cannot dispatch stale-session timer |
| Integration | User-selected optional locking, existing manual session controls, notifications and shared battery/profile diagnostics coherent |
| Security | System authorization, exact confirmations and no unsupported hibernate |
| Diagnostics | Provider, policy enforcement, inhibitors and bounded outcome receipt |
| Performance | UPower native; receipts watched; active-only capability refresh |

**Acceptance suite:** W07.01–W07.06 plus cited unit/integration tests. **Current evidence:** see [PROJECT_STATE](../PROJECT_STATE.md). **Dependencies:** D05, D14, D18; G02, G03, G17, G18, G19.

## C08 — Displays and multi-monitor management

Scope and source ownership: [inventory D08](CAPABILITIES.md#domain-08). Required operational outcomes:

- Represent all detected outputs and stable identities without hardcoded connector/index assumptions; disclose weak/ambiguous matches.
- Use one whole-topology draft, correct logical preview dimensions and numeric/keyboard alternatives to dragging.
- Accept arbitrary valid negative/gapped/centred layouts, including internal display centred beneath two externals; reject overlap/mirror cycles/last usable output loss.
- Arm recovery before writes, serialize operations, verify actual mode/scale/position/mirror and migrate workspaces safely before Keep.
- Persist confirmed intent separately from draft/observed fallback; test cold login, hotplug, watchdog and bounded opt-in recovery physically.

| Lifecycle | Required behavior / applicable boundary |
|---|---|
| Discovery | All outputs incl disabled and strong/weak identity metadata |
| Availability | Advertised modes and actual accepted geometry, usable physical destination |
| Activation | Whole draft→review→independent recovery armed→apply |
| Progress | Transaction token/deadline, dirty/conflict/preview state |
| Completion | Native mode/position/scale/transform/mirror readback before Keep |
| Failure | Rejected mode/partial apply/missing output triggers bounded compensation |
| Cancellation | Discard draft/review; timed/manual revert applies to preview, not drag |
| Retry | Explicit rebase/retry after terminal verified recovery; bounded auto policy |
| Persistence | Only confirmed layout persisted; draft and fallback observation separate |
| External changes | Monitor/raw events detect drift without overwriting dirty draft |
| Lifecycle | Docking/cold start/renderer death/watchdog/rollback with safe fallback |
| Integration | Workspace migration/primary/Rails operate on one observed topology |
| Security | Never disable last usable output; strict Lua serialization and locks |
| Diagnostics | Redacted topology/journal/readback; weak identity and bandwidth limits |
| Performance | Debounce events; single inventory owner; bounded cooldown/attempts |

**Acceptance suite:** W08.01–W08.06 plus cited unit/integration tests. **Current evidence:** see [PROJECT_STATE](../PROJECT_STATE.md). **Dependencies:** D01, D02, D09, D18; G04, G20, G23.

## C09 — Workspaces and window management

Scope and source ownership: [inventory D09](CAPABILITIES.md#domain-09). Required operational outcomes:

- Native global IDs are unique; local Workspace 1 on two outputs is independent in labels, shortcuts and state.
- Rendering must never create/focus/pin workspaces; initial empty external groups stay quiet and occupied groups never disappear.
- Explicit switch/create/move/rename requests revalidate identities and confirm compositor outcomes.
- Preserve user windows through projection/removal; avoid pulling temporary guest groups home without policy.
- Document named/special/persistent scope and test external compositor operations, docking and fresh login.

| Lifecycle | Required behavior / applicable boundary |
|---|---|
| Discovery | Native workspace/client IDs and monitor identity |
| Availability | Validate monitor/current source/window PID before mutation |
| Activation | Explicit create/switch/move/rename/persist operation only |
| Progress | Current active/occupied/member state and action review |
| Completion | Observe actual workspace and window membership/local labels |
| Failure | Reject vanished/reused target; preserve all surviving windows |
| Cancellation | Cancel review only; ordinary switch has no persistent cancellation |
| Retry | Refresh actual groups before new move; do not duplicate empty groups |
| Persistence | Only intended metadata/persistence; native session IDs cannot be assumed stable |
| External changes | Compositor external dispatches reconcile labels and occupied indicators |
| Lifecycle | Monitor removal/relogin preserve guest/home policy and no eager allocation |
| Integration | Rail and display workspace editor share registry/native authority |
| Security | Window address plus PID/source workspace checked; no injected dispatch |
| Diagnostics | Local label↔global ID mapping and actual monitor provenance |
| Performance | No rendering-side compositor calls; debounced shared inventory |

**Acceptance suite:** W09.01–W09.06 plus cited unit/integration tests. **Current evidence:** see [PROJECT_STATE](../PROJECT_STATE.md). **Dependencies:** D01, D08, D18; G04, G20, G24.

## C10 — Calendar, events, notes and reminders

Scope and source ownership: [inventory D10](CAPABILITIES.md#domain-10). Required operational outcomes:

- Quick calendar owns navigation/selected-day agenda and deep links; full Calendar owns edits, sources, transfer and conflict management.
- CRUD/recurrence/timezone/all-day/notes must roundtrip canonical ICS with revision checks, idempotent requests and recoverable drafts.
- Preview destructive/import/export/sync operations, validate destination/source and never overwrite unrelated state on stale review.
- Keep reminders independent of UI visibility, persist snooze/dismiss/uncertain states and avoid duplicate deliveries across owner changes.
- Support local data without remote accounts; real CalDAV is accepted separately with secret-service credentials, conflict tests and explicit provider limits.

| Lifecycle | Required behavior / applicable boundary |
|---|---|
| Discovery | Calendar daemon/socket, sources, stored ICS and optional remote provider |
| Availability | Same-UID access, read-only source, revision and remote capability |
| Activation | CRUD/save/delete/import/export/sync through typed reviewed requests |
| Progress | Query/save/sync/reminder pending and validation state |
| Completion | Committed revision/idempotent receipt and exact event/alarm result |
| Failure | Conflict/invalid field/socket loss/server denial preserve data/draft |
| Cancellation | Cancel preview/draft; uncertain committed save/sync not blindly resent |
| Retry | Retry same save request id only per idempotency; review sync conflict |
| Persistence | SQLite/ICS/draft/snooze data durable; no schema downgrade trick |
| External changes | Shared revision invalidation refreshes independent popup/full ranges |
| Lifecycle | Daemon/renderer restart, clock/DST/resume and notification owner change |
| Integration | One quick/full calendar owner; reminders reach native notifications |
| Security | Socket UID/mode, HTTPS/ETag, secrets in Secret Service/TTY only |
| Diagnostics | Bounded health/error/uncertain delivery without private event dump |
| Performance | Bound queries/rows/ICS; 30s reminders separate from UI and remote sync |

**Acceptance suite:** W10.01–W10.06 plus cited unit/integration tests. **Current evidence:** see [PROJECT_STATE](../PROJECT_STATE.md). **Dependencies:** D02, D11, D14, D19; G25, G26, G27.

## C11 — Notifications

Scope and source ownership: [inventory D11](CAPABILITIES.md#domain-11). Required operational outcomes:

- Own exactly one notification server; represent ownership loss and replacement IDs without duplicates/stale actions.
- Retain bounded private history across ordinary UI transitions/restart; per-record/read-all updates must be explicit.
- Invoke actions only on live matching notification generation; distinguish retained history from actionable remote objects.
- Bulk deletion requires exact review and reports persistence failure; transient/critical timeout and DND semantics must be documented and tested.
- Provide a deliberate primary/focused-output toast policy and scoped app preferences; never infer application authenticity solely from appName.

| Lifecycle | Required behavior / applicable boundary |
|---|---|
| Discovery | Notification bus owner, live tracked objects and retained ledger |
| Availability | Owner PID and writable private store, live action generation |
| Activation | Receive/dismiss/invoke/read; exact bulk-clear review |
| Progress | Active/unread/history counts plus clear save state |
| Completion | Native close/action observation and persisted history save signal |
| Failure | Owner or save failure explicit; old history may return after save failure |
| Cancellation | Cancel pending bulk clear; delivered app action is not reversible |
| Retry | Retry save/refresh safely; do not replay expired remote action |
| Persistence | Bounded nontransient ledger/DND; live objects/actions intentionally not serialized |
| External changes | Replacement IDs/action generations and bus ownership events reconcile |
| Lifecycle | UI transitions retain history; server restart disables stale actions |
| Integration | DND/critical/reminder/toast output policy coherent across Settings/Insights |
| Security | Private store, exact reviewed deletion; attribution is not authentication |
| Diagnostics | Owner/freshness/save errors without unrestricted body/log exports |
| Performance | At most 120 saved records; bounded toast/model objects and subscriptions |

**Acceptance suite:** W11.01–W11.06 plus cited unit/integration tests. **Current evidence:** see [PROJECT_STATE](../PROJECT_STATE.md). **Dependencies:** D01, D02, D10, D19; G28, G29.

## C12 — Input and devices

Scope and source ownership: [inventory D12](CAPABILITIES.md#domain-12). Required operational outcomes:

- Discover input capabilities from actual compositor/hardware and preserve keyboard access during every setting transaction.
- Apply the active provider API, require acknowledgement plus observed readback, and persist only verified changes; reconcile external changes.
- Distinguish global defaults from per-device overrides; validate locale/layout against system catalog rather than fixed country defaults.
- WP02 changes use an expiring compositor-owned preview before explicit Keep/save; rejected, stale, partial, rollback and persistence failures remain distinct. Global readback must not be presented as physical/per-device driver verification.
- Store only confirmed verified owned fields; legacy G03-era intent never auto-restores. An absent loaded reload hook means temporary runtime state and no save. Preserve external runtime changes until the documented reload precedence takes effect.
- OSK startup/signals/automatic mode must be owner-bound and capability-gated; test actual text, modifiers, touch, avoidance and hardware keyboard coexistence.
- Expose optional IME/peripheral handoffs truthfully; absence of provider is not universal hardware incompatibility.

| Lifecycle | Required behavior / applicable boundary |
|---|---|
| Discovery | Compositor devices/XKB, optional IME and actual OSK protocols |
| Availability | Provider compatibility, installed build and actual input readiness |
| Activation | Validated reviewed input apply; OSK owner-bound start/stop |
| Progress | Pending apply/provider startup/visibility/geometry distinctly reported |
| Completion | Typed compositor readback and actual text/modifier delivery |
| Failure | Zero-exit refusal/partial apply/rollback failures never false success |
| Cancellation | Cancel draft/review; no nonsensical undo of ordinary keypress |
| Retry | Recover keyboard safely and retry supported capability only |
| Persistence | Verified preferences in XDG store; OSK process lifetime is session scoped |
| External changes | getoption/device/layout events reconcile external state and prefs |
| Lifecycle | Hotplug/resume/reload/physical keyboard must not leave modifiers/grabs stuck |
| Integration | OSK avoids Settings/review and Caps Lock follows supported physical input |
| Security | No arbitrary provider executable/signals; no password/key event logging |
| Diagnostics | Capability/readback errors without collected raw keys or webcam streams |
| Performance | Debounced geometry, one provider owner, bounded detection/subscriptions |

**Acceptance suite:** W12.01–W12.06 plus cited unit/integration tests. **Current evidence:** see [PROJECT_STATE](../PROJECT_STATE.md). **Dependencies:** D05, D06, D08, D14, D20; G03, G30, G31.

## C13 — Applications and desktop integration

Scope and source ownership: [inventory D13](CAPABILITIES.md#domain-13). Required operational outcomes:

- Launch installed desktop entries with correct Exec semantics and app scopes independent of shell restart; report handoff versus observed result.
- List/edit supported MIME defaults and autostart via authoritative XDG/GIO stores with review, identity checks and readback.
- Open/reveal permitted files safely; validate actual default app, Thunar, removable-media and portal journeys in representative native applications.
- Respect per-application window/notification/tray ownership; no arbitrary Exec parsing or wholesale portal permissions.
- Delegate installation/removal to maintained system tooling unless a clear product contract is approved.

| Lifecycle | Required behavior / applicable boundary |
|---|---|
| Discovery | Desktop entries, supported MIME roles, autostart precedence and portals |
| Availability | Revalidate app/path/handler and native provider readiness |
| Activation | Launch/open/reveal or reviewed defaults/autostart changes |
| Progress | Launch handoff distinct from app/task/portal permission completion |
| Completion | Actual handler/default readback, next-login start and app-owned result |
| Failure | Missing app/provider/permission denial visible and non-destructive |
| Cancellation | Cancel pending review/dialog; normal launched app is app-owned |
| Retry | Retry valid entry/provider without restarting shell or bypassing portal |
| Persistence | XDG MIME/autostart overrides; app settings remain application-owned |
| External changes | Catalog/portal/default changes refreshed through proper authority |
| Lifecycle | App survives shell restart; startup and hotplug respect system owners |
| Integration | Notifications/tray/portal/native windows coexist with shell surfaces |
| Security | Preserve Exec argument expansion; no arbitrary replay or blanket permissions |
| Diagnostics | Bounded app/provider/task outcome, no private file metadata dump |
| Performance | One catalog/shared services; user app resources outside shell accounting |

**Acceptance suite:** W13.01–W13.06 plus cited unit/integration tests. **Current evidence:** see [PROJECT_STATE](../PROJECT_STATE.md). **Dependencies:** D03, D11, D14, D17; G01, G32, G33.

## C14 — Accounts, authentication and security

Scope and source ownership: [inventory D14](CAPABILITIES.md#domain-14). Required operational outcomes:

- Show ordinary account/provider/session facts without shadow data; missing or incomplete provider disables unsafe administration.
- Create standard users, edit name/avatar, lock/type and remove through system authorization with exact identity and real readback.
- Protect active/signed-in account, last viable admin and home data; revalidate authoritative state after authorization where needed.
- Passwords remain in established passwd/PAM authorization flow; never store/log plaintext secrets in shell state.
- Prove new account login, denied/cancelled authorization, manual lock/unlock and separately authenticated recovery in disposable system tests.

| Lifecycle | Required behavior / applicable boundary |
|---|---|
| Discovery | Bounded NSS accounts, AccountsService and login1 sessions |
| Availability | Complete authorized provider/current user/quorum and valid PNG |
| Activation | Exact reviewed allowlisted system account action; secure passwd handoff |
| Progress | Pending polkit/PAM interaction separate from backend completion |
| Completion | Authoritative NSS/AccountsService readback and actual login/unlock |
| Failure | Denied/cancelled/provider-loss reports failure or unverified, not success |
| Cancellation | Cancel review or system auth dialog; no fake cancellation after account commit |
| Retry | Refresh identity/quorum and start new auth review; no secret reuse |
| Persistence | System account/PAM state; saved avatar digest and home retention |
| External changes | Account/session changes during review/auth must be revalidated |
| Lifecycle | Provider restart and greeter/login/lock/recovery roles remain isolated |
| Integration | New account must authenticate into correct session and own prefs |
| Security | No custom auth shortcut/plaintext storage; active/last-admin/home safeguards |
| Diagnostics | Bounded authorization/error reason; authpriv log scope only if authorized |
| Performance | Bound accounts/requests; avoid long per-account unbounded provider stalls |

**Acceptance suite:** W14.01–W14.06 plus cited unit/integration tests. **Current evidence:** see [PROJECT_STATE](../PROJECT_STATE.md). **Dependencies:** D07, D12, D18, D20; G02, G34, G35.

## C15 — Personalisation and appearance configuration

Scope and source ownership: [inventory D15](CAPABILITIES.md#domain-15). Required operational outcomes:

- Keep approved visual identity as defaults; expose real supported background/motion/text/contrast preferences with preview/save/discard.
- Validate before atomic writes, retain unrelated fields and actual previous usable configuration on failure.
- Assign each preference one owner and document source-generated tokens versus user preferences and wallpaper scope.
- External preference changes must not overwrite dirty drafts silently; define import/export/reset and schema migration before promising them.
- Test readable/focusable high-contrast, reduced-motion and large-text states on narrow/mixed-scale screens; no cosmetic redesign is required here.

| Lifecycle | Required behavior / applicable boundary |
|---|---|
| Discovery | Validated default skin/tokens, writable user override and image availability |
| Availability | Schema/mode/image limits and user-store writability |
| Activation | Preview supported changes→Save/Discard; no source mutation on hover |
| Progress | Dirty/save/failure/fallback status visible |
| Completion | Atomic valid override readback and effective shared preference |
| Failure | Invalid image/manifest/write failure keeps usable previous/native fallback |
| Cancellation | Discard unapplied draft; do not undo external unrelated preferences |
| Retry | Fix path/validation and retry without restarting whole shell |
| Persistence | User override separate from release defaults; explicit migration/reset |
| External changes | External change preserves dirty draft/conflict and unrelated fields |
| Lifecycle | Reload/update/read-only payload retain user values and recovery |
| Integration | Wallpaper/skin/profile scopes explicit; text/motion across supported surfaces |
| Security | Bound file sources/schema; no executable theme injection or secrets export |
| Diagnostics | Bounded validation source/revision/save error |
| Performance | Cached bounded artwork; no unbounded image decode/animation or per-view writers |

**Acceptance suite:** W15.01–W15.06 plus cited unit/integration tests. **Current evidence:** see [PROJECT_STATE](../PROJECT_STATE.md). **Dependencies:** D01, D02, D20; G07, G21, G36, G37.

## C16 — Performance, telemetry and Senomy Insights

Scope and source ownership: [inventory D16](CAPABILITIES.md#domain-16). Required operational outcomes:

- Keep one lightweight timestamped session sampler independent of UI; expensive inventory/process/diagnostic work is view-scoped or explicit.
- Bound all histories and output; use unavailable/null and reset baselines across suspend/counter/clock changes without fabricated samples.
- Trace graphs to source units and sample timestamps; distinguish utilization, throughput, disk active time and per-application attribution.
- Confirm process identity/owner and supported service invocation before disruptive operations; report observed results and retain diagnostic evidence.
- Measure qs plus owned helpers separately from launched apps under controlled idle/interaction and 8h soak; define budgets before visual expansion.

| Lifecycle | Required behavior / applicable boundary |
|---|---|
| Discovery | procfs/sysfs/sensors and supported process/service/task sources |
| Availability | Per-field units/readiness/freshness/null; actual helper availability |
| Activation | Background sampler; explicit page queries/diagnostics/benchmark/actions |
| Progress | Timestamps, selected window/range, task progress and action receipt |
| Completion | Delta/units cross-check, observed process/service result, report file receipt |
| Failure | Counter reset/missing sensor/stale PID/timeout never fabricated zero/success |
| Cancellation | Stop finite benchmark safely; cancel review; read-only sample needs no undo |
| Retry | Fresh PID/provider identity and explicit task retry |
| Persistence | Bounded RAM-only 15-minute epoch; report retention separately documented |
| External changes | External service/process/provider changes invalidate action selection |
| Lifecycle | Suspend/time jumps/reset/reload show honest gaps/new epoch |
| Integration | Performance/Insights share sampler/tasks; battery diagnosis limited to evidence |
| Security | Allowlisted console/tasks; owned PID+start ticks; reviewed service restarts |
| Diagnostics | Redacted source-specific result/freshness and private exports |
| Performance | Single owner, 900 samples; view-scoped heavy work; measured PID/helper budget |

**Acceptance suite:** W16.01–W16.06 plus cited unit/integration tests. **Current evidence:** see [PROJECT_STATE](../PROJECT_STATE.md). **Dependencies:** D03, D07, D17, D18, D20; G01, G18, G38, G39.

## C17 — Maintenance and recovery

Scope and source ownership: [inventory D17](CAPABILITIES.md#domain-17). Required operational outcomes:

- Show real system/provider/storage facts with scoped freshness and unavailable states; keep storage mutation outside shell unless specifically scoped.
- Separate update discovery from installation; retain safe maintained package manager handoff, transaction result, reboot guidance and recovery limits.
- All diagnostic/console tasks are allowlisted with time/output bounds and privacy-reviewed exports, never arbitrary shell text.
- Deploy immutable versioned payloads with owned-path validation, receipts, preferences migrations and tested rollback independent of watched development source.
- Prove clean-VM install/cold boot/invalid-config recovery; do not confuse configuration backup with whole-system rollback.

| Lifecycle | Required behavior / applicable boundary |
|---|---|
| Discovery | OS/storage/update sources, services, releases and restore receipts |
| Availability | Distinguish installed tool, advertised interface, accepted task and recoverable payload |
| Activation | Read-only inventory/checks; explicit reviewed package/deploy/restore handoff |
| Progress | Progress/result/reboot requirement per actual transaction owner |
| Completion | Verified output/source version and bootable recovery acceptance |
| Failure | Invalid config/disk-full/transaction failure keeps prior usable state |
| Cancellation | Cancel review; package cancellation only through maintained transaction owner |
| Retry | Retry after actual-state diagnosis; never repeat destructive restore blindly |
| Persistence | Versioned payload/preferences/receipts with separate OS rollback strategy |
| External changes | External package/service/config changes update freshness/provenance |
| Lifecycle | Cold boot/failed update/config error has independent recovery entry |
| Integration | Settings/Insights/package terminal share status without duplicate managers |
| Security | Owned paths/allowlists/privilege/secret-redaction at each boundary |
| Diagnostics | Bounded diagnostics, error provenance, support bundle retention/export consent |
| Performance | On-demand heavy work, cached update checks, bounded files/log output |

**Acceptance suite:** W17.01–W17.06 plus cited unit/integration tests. **Current evidence:** see [PROJECT_STATE](../PROJECT_STATE.md). **Dependencies:** D14, D16, D18; G04, G05, G06, G40.

## C18 — Login, boot and session lifecycle

Scope and source ownership: [inventory D18](CAPABILITIES.md#domain-18). Required operational outcomes:

- Document actual bootloader/greeter/provider/session owners and keep normal and independent recovery authentication isolated.
- Start one shell and notification owner after valid compositor environment; detect failures without repeated session termination.
- Separate shell-owned helper lifetime from ordinary launched apps; shell service restart/crash must preserve app processes and work.
- Activate only capability-supported session policies and reconcile service owner changes; no bootloader changes for routine UI work.
- Pass clean cold boot, login/logout, lock/unlock, suspend/resume, shell crash and independent recovery with a safe separate test environment.

| Lifecycle | Required behavior / applicable boundary |
|---|---|
| Discovery | Actual firmware/bootloader/greeter/compositor/session/service owners |
| Availability | Current authenticated session/Wayland env and ready providers |
| Activation | Login/start after compositor readiness; explicit session exit/recovery |
| Progress | Greeter authenticating/session-starting and service starting/restarting states |
| Completion | Usable authenticated desktop and one notification/Rail owner |
| Failure | Startup race/shell crash invalid source leads bounded restart/recovery |
| Cancellation | Cancel auth/review; never cancel session teardown by half-restoring desktop |
| Retry | Bound retries; recover via independently authenticated TTY/session |
| Persistence | User prefs confirmed startup intent; no universal app-state restore promise |
| External changes | Provider changes after startup update capabilities, not frozen env facts |
| Lifecycle | Cold boot/login/logout/lock/unlock/suspend/crash/dock are tested separately |
| Integration | Shell helpers cleaned; apps remain independently owned; calendar/wallpaper coherent; inactive automatic idle policy is preserved |
| Security | System PAM/SDDM/polkit and recovery caller boundaries remain intact |
| Diagnostics | Scoped startup/service receipt and exact source/deployed hashes |
| Performance | Bound restart loop; idle-policy/session overhead measured independently |

**Acceptance suite:** W18.01–W18.06 plus cited unit/integration tests. **Current evidence:** see [PROJECT_STATE](../PROJECT_STATE.md). **Dependencies:** D01, D07, D08, D09, D14, D17; G01, G02, G04, G05, G35.

## C19 — Full Settings and Control Centre integration

Scope and source ownership: [inventory D19](CAPABILITIES.md#domain-19). Required operational outcomes:

- Every setting has one authoritative backend and documented scope/persistence, shared by quick, compact and full interfaces.
- Reuse one native Settings instance and page identity; deep links/search select real reachable controls and respect dirty/modal state.
- Provide keyboard back/forward and accessible target focus; invalid routes are rejected and stale dynamic items refresh.
- Define immediate versus draft versus preview operations consistently, including close/mode/output-change handling.
- Represent provider availability, authorization, handoff, completion and unverified results distinctly; verify across physical output changes.

| Lifecycle | Required behavior / applicable boundary |
|---|---|
| Discovery | One route/catalog/page/provider model plus valid native Settings instance |
| Availability | Real control/provider/permission availability for each link |
| Activation | Quick/compact/full navigate same owners and target actual controls |
| Progress | Dirty/apply/pending/handed-off/result states distinguished |
| Completion | Observe selected route/page identity and authoritative setting result |
| Failure | Invalid/stale/unavailable route has useful recovery and no lost draft |
| Cancellation | Back/close/mode change respects draft/review cancellation |
| Retry | Retry provider/control safely; no duplicate native window |
| Persistence | Per-setting scope explicit; transient navigation max 64 need not persist |
| External changes | All interfaces refresh from authoritative external source |
| Lifecycle | Output removal/reload retains durable drafts and reuses surviving workspace |
| Integration | No duplicated backend logic across three interfaces |
| Security | Navigation never bypasses confirmation/auth and no unsafe task-string execution |
| Diagnostics | Control source/route/scope/freshness and meaningful permission error |
| Performance | Single page tree/shared service; bounded search/history and no duplicate poller |

**Acceptance suite:** W19.01–W19.06 plus cited unit/integration tests. **Current evidence:** see [PROJECT_STATE](../PROJECT_STATE.md). **Dependencies:** D02, D03, D04–D15, D20; G03, G22, G36, G41.

## C20 — Accessibility and reliability

Scope and source ownership: [inventory D20](CAPABILITIES.md#domain-20). Required operational outcomes:

- All core workflows work without a pointer; focus is visible, logical and restored; modal Escape never confirms.
- Primary tasks remain reachable at supported narrow/portrait/mixed-scale and touch densities with measured targets/text/contrast.
- Validate spoken names/roles/state and navigation with real AT-SPI/Orca, not just source metadata; document language limits.
- Survive provider loss/hotplug/resume and renderer reload without duplicate subscriptions, stale success or lost application processes.
- Bound memory/history/output and verify controlled idle plus 8h/24h stability; isolate every destructive/device/lifecycle test from the live desktop.

| Lifecycle | Required behavior / applicable boundary |
|---|---|
| Discovery | Actual supported devices/profiles/providers/assistive tools |
| Availability | Document supported languages/input modes and capability gaps |
| Activation | Core tasks available by keyboard/pointer/touch and spoken metadata |
| Progress | Focus/loading/error/progress perceivable without colour/motion alone |
| Completion | Real task success, spoken name/order and usable scaled layout |
| Failure | Provider/log/malformed data failure remains accessible/recoverable |
| Cancellation | Escape/review cancellation accessible; no accidental confirmation |
| Retry | Recovery accessible through supported input without shell restart |
| Persistence | Accessibility preferences saved with portable user override |
| External changes | External focus/provider/device changes reconciled without lost access |
| Lifecycle | 8h/24h soak, reload/resume/hotplug and safe test-environment isolation |
| Integration | Common controls/owners make same task consistent across surfaces |
| Security | No credential/key-event capture; test harness cannot resolve live mutations |
| Diagnostics | Bounded useful user error and redacted reproducible failure record |
| Performance | Budgeted CPU/PSS/GPU/power and no unbounded handlers/history/window instances |

**Acceptance suite:** W20.01–W20.06 plus cited unit/integration tests. **Current evidence:** see [PROJECT_STATE](../PROJECT_STATE.md). **Dependencies:** All domains; G01, G02, G20, G30, G36, G38, G42.
