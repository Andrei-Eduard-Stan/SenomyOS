# SenomyOS forensic audit — 2026-10-06

## Executive brief

SenomyOS is an operational Quickshell desktop prototype on Arch/Hyprland,
with substantial legacy and deployment infrastructure. Shell migration exists;
product acceptance and reproducible release engineering do not yet follow from
it. Current informational ownership and several native providers were verified.
Most interactive behavior remains implemented with acceptance pending.

Since the September 2 checkpoint, `804e55d` promoted login ownership,
`350fd18` introduced visual/motion foundations, and `a6629ba` added persistent
timeout backend/tests. `af9aebc` and `568a875` are ledger-only commits. The
former declared completion by mapping an automation to historical Stages 1–6;
direct user correction on October 4 explicitly rejects that scope. Current
working-tree AUTOMATION_PROGRESS already replaces it with the October 5
user-approved nine-domain roadmap. Do not undo that correction.

Extensive uncommitted work adds authored skins/backgrounds, expanded Senomy,
Cathedral panels, action guards, display/input configuration and tests. Presence
and documentation are evidence of implementation, not authorship, approval or
current manual acceptance. Most later decision entries are themselves uncommitted.

## Audit method and limits

Initial audit used only reads: Git, repository-wide document/content discovery,
source/service inspection, package queries, compositor queries, bounded journals
and read-only shell IPC. No branch change, fetch, reload, restart, installation,
device action or source edit occurred before the executive report.

No conversation connector was exposed, but local Codex JSONL session files
were available. Direct user records were extracted separately from injected
environment text and approval-review transcripts. September 3 explicitly requests
permanent Quickshell replacement; October 4 corrects automation numbering;
October 5 confirms the nine-domain roadmap. September 27/October 2 requests
establish bespoke panel changes, persistent expanded history, editable fills and
removal of the extra activity island. These supersede older visuals where exact
requirements overlap. This is not a claim to have exhaustively reviewed every
conversation or every source line. Prior attached briefs are discoverable but
were not all opened; unresolved intentions remain qualified.

Evidence source identifiers: local session beginning
`rollout-2026-09-01T07-58-50` (promotion),
`rollout-2026-09-07T13-16-36` (visual work),
`rollout-2026-10-02T22-41-11` (functional/visual direction), and
`rollout-2026-10-04T17-46-08` (scope correction and roadmap approval).
Private transcripts and notification content are not copied into this report.

Discovery covers Markdown plus other textual planning candidates by filename
and content, including wiki, appearance, deploy, shell docs and design reports.
[AUDIT_DOCUMENT_INVENTORY.md](AUDIT_DOCUMENT_INVENTORY.md) enumerates candidates
with Git introduction/latest-content-change evidence. Git dates establish
committed provenance, not the date of uncommitted material changes. Per-document
completion is qualified by the matrix below; individual subjective visual claims
were not reaccepted. Asset reachability, every historical checkbox, SDDM installed
file parity and all bootstrap paths were not independently exhaustively verified.

## Git evidence

Root `/home/Duku/SenomyOS`; branch `quickshell-v2`; initial HEAD
`a6629ba19e258a435bb9a0487332ded372fb1eae`. No staged changes initially.
79 modified tracked files; 511 untracked files, including code, tests and assets.
Tracked diff at entry: 3,854 insertions and 1,013 deletions across 79 files.

Worktrees: development at `a6629ba`; Eww detached at `d8850ff`.
Local branches: main `da53f52`, revival/live `d8850ff`, quickshell-v2 `a6629ba`.
Remote-tracking refs: origin/main `da53f52`, origin/revival/live `ea861bd`,
origin/quickshell-v2 `6d81cba`. Development is five commits ahead of its cached
remote ref. No fetch occurred; this does not establish present server state.
Remote origin: `https://github.com/andrei-eduard-stan/senomyos.git`.
Tags: `eww-v0-baseline-2026-09-01`, `milestone-2-quickshell-foundation`.
`git stash list` returned no entries.

| Commit | Evidence and qualification |
|---|---|
| d8850ff | Eww checkpoint; large prior implementation/design history enters preserved baseline |
| 4e39c63 | Quickshell architecture proof |
| a48cdf4 | Shared native service state |
| 571121d | Interactive surface migration |
| 426b5bc | Native notification ownership |
| 6d81cba | Runtime/automated milestone checks; QA explicitly leaves manual input acceptance open |
| 804e55d | Quickshell login promotion; user-approved before complete acceptance |
| 350fd18 | Visual and motion foundation; does not accept later artwork |
| af9aebc | Only AUTOMATION_PROGRESS changed; no functional implementation |
| 568a875 | Only ledger push-status documentation; no functional implementation |
| a6629ba | Session-policy backend and tests; working-tree controls/manifests are additional dependencies |

## Actual architecture

Hyprland Lua imports session environment and starts the guarded selector.
`senomy-quickshell.service` runs the checkout through a linked launcher;
`RestartMode=direct` retries transient failure; start-limit failure requests
`senomy-shell-fallback.service`, which restores the legacy adapter, workspace
publisher and SwayNC. The selector verifies Rail reserve and notification owner.
Development symlinks are not independently installable versioned artifacts.

`shell/quickshell/shell.qml` owns shared native services and instantiates
`RailWindow` per screen. `ShellState.qml` owns one primary token and one popup
token, plus independent companion state. Its inactive primary representation is
the empty string (semantic none), rather than the literal `none` in Eww docs.
Native Hyprland objects own workspaces/toplevels. ScreenLifecycle clears removed
output ownership. Actual multi-output behavior was not exercised in this audit.

Audio uses PipeWire; network uses native NetworkManager, with terminal-owned
secure prompting; batteries use native UPower; Bluetooth uses native BlueZ with
shared discovery/actions; media uses MPRIS; tray uses StatusNotifier/native menus;
calendar uses native time/month state. Notifications use Quickshell's server and
private bounded FileView history. Read-only metadata returned without exposing
bodies. Detailed metrics/processes and Insights use bounded source-owned adapters
conditionally. Legacy helper existence does not prove native action coverage.

Ten-route Control Centre is connected to shared services. Performance has seven
routes and process detail/SIGTERM plus benchmark paths. Insights has eight routes
with cached update discovery, bounded diagnostics/console/report/wiki adapters.
Normal operation does not require Eww or SwayNC. Legacy collectors/Yuck remain
intentional recovery paths, not duplicates to delete automatically.

Appearance: tokens.json and generator own semantic toolkit projections;
frame-system.json owns generated vectors; skins/default.json and authored assets
own configurable artwork/backgrounds; Theme.qml is generated; RailStyle adapts
the skin authority. Cathedral components and reflection shaders add a later
visual layer with hard-coded stylistic colors/font choices requiring coverage
review. Multiple layers are legitimate, but generated token authority does not
prove all surfaces consume every preference consistently.

Rofi Command Lens and scoped Thunar remain native app integrations. GTK 3
namespaced themes are distinct from global GTK and GTK 4. Hyprland owns native
window decoration/fullscreen. Separate tracked SDDM sources/system transactions,
session guards, Hyprlock configuration/launcher and restricted recovery helpers
cover login/lock/recovery. User switching/authentication and real recovery boot
are not accepted by source existence. Boot sources are staged projections;
activation remains blocked on disposable-machine boot proof.

User/system deployment manifests, package/service manifests, profiles and
bootstrap implement guarded configuration installation with receipts/backups.
They do not implement whole-system rollback, release packages, migrations,
update installation or bootable media. Preferences/state use XDG files; display
defaults are user-owned; notification storage is private. Journals, selector
doctor, diagnostic/report helpers and validators provide evidence tooling.

## Detailed requirement and completion matrix

V = VERIFIED currently; I = IMPLEMENTED, ACCEPTANCE PENDING;
P = PARTIAL; D = DOCUMENTATION ONLY; S = STALE; B = BLOCKED; U = UNKNOWN.
Verification applies only to the exact evidence stated, not the entire feature.
WT means uncommitted working-tree evidence; confidence describes classification.

| Requirement | Source | Implementation / commit | Status | Evidence / remaining work | Confidence |
|---|---|---|---|---|---|
| Quickshell login/shell ownership | D121, V3 QA | selector, units, shell.qml / 804e55d | V | Running PID 1414, one Rail, 72px reserve; fresh-login attended acceptance open | High |
| Native notifications | V3 parity, product | NotificationService / 426b5bc, WT clear guard | V/I | Bus owner PID 1414, server enabled; current protocol/mutation/manual acceptance separate | High |
| Eww fallback/recovery | architecture, foundation | fallback unit, senomy-eww-legacy / d8850ff, 804e55d | I | Installed unit, detached source and recovery logic; no handoff/crash test this audit | High |
| Workspace/carousel/app icons | product, Rail docs | WorkspaceRail, WorkspaceChip, AppIndicator / 571121d, WT | I | Native connected paths, historical fixture evidence; physical navigation/churn open | High |
| Multi-monitor/hotplug | platform, V3 QA, A08 | Variants, ScreenLifecycle, display helpers / WT | I | One real output currently; virtual evidence dated; dock/scale/hotplug open | High |
| One primary/popup and companion | product, D118 | ShellState, RailWindow, DashboardWindow / a48cdf4, WT | I | Central tokens; idle IPC empty; no interaction transitions performed now | High |
| Ten Control Centre routes | product, A06 | ControlCentre / 571121d, WT | I | Connected source, historical loads; per-control states/focus acceptance open | High |
| Audio inventory | data sources | AudioService / a48cdf4, WT | V | Current one output/two inputs, real volume/mute metadata | High |
| Audio endpoint mutation | D145, A05 | SelectionActions, AudioService / WT | I | Fake-provider evidence documented; physical routes/failures open | High |
| Network status/connect | D143, roadmap §5 | NetworkService, NetworkActions / WT | P | Native paths/guards exist; saved profiles, VPN/DNS/proxy and failure UX missing | High |
| Bluetooth inventory/actions | D142, D146 | BluetoothService/Actions/Discovery / WT | V/I | Provider available, enabled, discovery false; pairing/discovery/route acceptance open | High |
| Dual battery/power profiles | product, D145 | BatteryService / a48cdf4, WT | V/P | Two real packs and weighted charge; profile unavailable; startup-gated availability limitation | High |
| Calendar/time | product, roadmap | ClockIsland, CalendarPopup / 571121d, WT | I | Connected native clock/month navigation; input/locale acceptance open; timezone editor unspecified | Medium |
| Tray/media | V3 QA, product | TrayPopup, MediaService / 571121d, WT | I/U | Native paths; no player currently; real menus/playback open | High |
| Guarded session power | D009, A07 | PowerService, senomy-session-action / 4e39c63 | I | Confirmation source/historical cancel proof; lock/recovery/suspend open | High |
| Idle editable timeouts/lid policy | roadmap §2 | session-policy.py, SessionPolicy, idle config / a6629ba + WT | P | Backend exists; hypridle absent; live lid binding absent; physical lock/DPMS open | High |
| Automatic suspend | roadmap §2 | no accepted activation | B | Recovery acceptance explicitly required first | High |
| Keyboard first-run/repeat/pointer | roadmap §3 | InputSettings, input-settings.py / WT | I | Catalog/firstRun/repeat source and dated tests; physical settings acceptance open | High |
| Complete keyboard/OSK/accessibility | roadmap §3, product | Dashboard controls, optional Fcitx handoff / WT | P | Primitive fixture only; full focus restoration, native Wayland OSK, touch/portrait open | High |
| Performance metrics/history | roadmap §4, Cathedral doc | PerformanceService, SystemMetrics, history / WT | I | Connected bounded collectors/charts; freshness/parity/current resource acceptance open | Medium |
| Process sort/details/terminate | roadmap §4, D163 | PerformanceService, process helpers / WT | I | Exact start identity and owner checks; dated disposable test; physical selection open | High |
| Managed restart/service boundary | roadmap §4 | legacy performance-action helper; native UI absent | P | Legacy restart is not connected native functionality; allowlist/observed result needed | High |
| Diagnostics/reports/benchmarks | roadmap §4, product | InsightsService, performance-report, benchmark-action | P | Bounded paths exist; full profile/history/deletion/report parity incomplete; no workload now | High |
| Eight Insights routes | product, roadmap | InsightsPanel/Service / 571121d, WT | I | Connected routes; evidence/freshness behavior and input acceptance open | High |
| Update discovery | roadmap §7 | update-status, InsightsService | I | Cached official/AUR paths; no network check run now; checkbox denotes baseline only | High |
| Reviewed update install/lifecycle | roadmap §7 | no connected install UI | D | Plan exists; install/progress/failure/reboot/recovery absent | High |
| Launcher/files/native integration | roadmap §6, launcher spec | Rofi/Thunar wrappers, GTK themes / d8850ff, WT | I/P | Guarded source and dated QA; defaults/autostart/portals/peripherals open | High |
| SDDM/Hyprlock/user switching | boot/login specs, A07 | appearance/login, lock, session guards | I/U | Installed packages/source; actual installed projection parity/auth/session not reverified | Medium |
| Appearance tokens/frames/skins | design system, D127+ | generator, tokens, skin components / 350fd18, WT | I/P | Generated foundation and authored machinery; hard-coded coverage and final design open | High |
| Custom visuals/phone layouts | user requests, design proposals | artwork, skins, mockups / WT | B/I | Authored elements present; unresolved final art and approved narrow/touch compositions | High |
| Bootstrap/transactional deploy | platform Phase B, deploy README | deployers/bootstrap/manifests / d8850ff, WT | I | Source/dated isolated tests; clean VM and actual end-to-end acceptance open | High |
| Versioned packages/migrations | roadmap §8, platform Phase C | no release package/migration artifact found | D | Development links/receipts are insufficient | High |
| Boot projections/activation | boot sequence, D089 | appearance/boot, senomy-bootctl | P/B | Staging exists; activation gated on boot/recovery proof | High |
| Installer/recovery image/hardware matrix | roadmap §8, platform | specifications only | D | Media and tested compatibility release evidence absent | High |
| Current budgets/licenses/lint/source review | roadmap §9, A02/A10/A11 | benchmark/validators, asset manifests | P | Old samples predate visual build; warnings and dependency/license audit open | High |
| Historical Stage 1–6 blanket completion | af9aebc | documentation only | S | Rejected mapping; cannot count toward present roadmap | High |

## Drift and damage register

1. Incorrect automation scope and terminal marker: proven by ledger-only Git
   diff and direct user correction. Corrected in WT; preserve that correction.
2. Parallel status authorities: CURRENT_STATE is mostly an Eww/Milestone 2
   snapshot despite its name; Handbook/Development retain obsolete current-path
   examples below newer headings; Implementation Plan uses historical stage IDs.
3. V3 parity says migrated but native report/process/settings coverage differs.
   Later qualification recognizes this; dated table measurements are not current.
4. Tracked/live Lua mismatch is precisely one lid binding. Do not deploy it
   silently to make a byte comparison pass.
5. Runtime docs' October 2 matching-config claim is stale now; settings ledger
   also incorrectly still lists first-run/timeouts/lid as open after later source.
6. Journal shows repeated QQuickItem stacking and portal registration warnings.
   Past compositor disconnects caused shell exit; one fallback enqueue failed
   during systemd shutdown. This alone does not prove normal crash recovery fails.
7. Native popup token can coexist with an active primary; primary opening clears
   popup. Distinguish requested tokens from mapped layers during animations.
   Verify intended exclusivity before calling the whole graph accepted.
8. Hard-coded Cathedral colors/fonts/geometry remain alongside generated tokens.
   Theme generation is not universal preference coverage. Audit licensing for
   Audiowide/Bruno Ace SC/Font Awesome and authored graphics.
9. Legacy force-kill/restart helpers do not imply native UI parity. Unused legacy
   clock/battery/config fragments are historical; preserve rather than delete.
10. Large uncommitted source/asset tree risks unreproducible checkpoint recovery.
    No exhaustive unused-asset deletion list is established; reference auditing
    remains open. No broad TODO/FIXME/HACK marker hit establishes completeness.
11. Selector informational paths created runtime directory/lock; repaired in
    the bounded follow-up, with mutating handoffs still serialized.

## Reconstructed roadmap

The existing AUTOMATION_PROGRESS is suitable as the roadmap because direct user
messages approve its nine sections. PROJECT_STATE is needed because existing
state documents combine dated snapshots and execution plans. Preserve IDs and
scope; use the following buckets as classifications, not replacement milestones.

**DONE:** shell ownership and native notification ownership currently observed;
historical migration foundation; normalized provider infrastructure; selector
read-only boundary after the regression check. Code completion of individual
guards/settings does not close their physical acceptance gates.

**VERIFY:** fresh login/fallback/lock/suspend; physical multi-monitor, rollback,
Bluetooth/audio/secured Wi-Fi; real keyboard/pointer/touch; tray and active MPRIS;
full current control behavior; resource budgets and installed integrations.

**NEXT:** finish §3 route navigation/focus restoration using isolated fixtures;
organize existing changes into dependency-aware review stages; reconcile per-control
capability claims; then managed user-service restart boundaries and native
diagnostic/report parity (§4), saved networking/failure UX (§5), defaults/autostart/
portal status (§6). Choose only sufficiently specified bounded behavior.

**LATER:** reviewed updates and recovery journey (§7); versioned packages,
configuration migrations, clean VM/boot/first-run, media and hardware matrix (§8);
broader touch/experimental device compatibility after evidence.

**DESIGN-DEPENDENT:** final Senomy artwork, frame/micrographic refinements,
cross-surface visual consistency, narrow/portrait/touch compositions, login/lock
visual acceptance. Do not substitute arbitrary artwork or delete placeholders.

**SUPERSEDED:** historical Eww normal-login architecture; Milestone 2 SwayNC
ownership in normal mode; old Rail heights/capacities and activity island;
October 4 Stage 1–6 completion scope. Eww fallback itself remains required.

## Completion assessment

Approximate functional-desktop maturity: 45–60%, low confidence as a numerical
estimate. This balances strong shell/provider implementation against incomplete
per-control functionality, device/session acceptance, accessibility and delivery.
It is not a count of migrated routes or checkboxes. Release readiness is below
25%: no versioned release, clean-machine boot proof, update/recovery lifecycle or
compatibility matrix is established. Bespoke visual completion is excluded from
the numerical assessment because final user design work is not measurable here.
Do not turn these rough planning estimates into automated progress counters.

## Documentation normalization and follow-up validation

PROJECT_STATE: current facts and blockers. AUTOMATION_PROGRESS: canonical backlog.
ARCHITECTURE: ownership/contracts, not completion. PRODUCT_SPEC/PLATFORM_STRATEGY:
desired capabilities. DECISIONS: supersession and rationale. RUNTIME_INVENTORY:
dated observations. DESKTOP_ALPHA/QA: dated verification and exclusions.
IMPLEMENTATION_PLAN/foundation/migration/design-pass documents: historical
sequence/evidence; add pointers, retain content, never silently rewrite history.
Design proposals remain separately marked, not automatically approved by code.

The resumed repair passes Bash syntax, selector read-only regression and
`git diff --check`. Code/automated verification complete for that boundary;
informational runtime provider reads completed; no live handoff/recovery or
manual UI acceptance claimed. Historical suites are not described as rerun.

Additional current isolated checks: six session-policy Python tests, five
input-settings Python tests, four skin-preference QtTest passes (including
lifecycle), six screen-lifecycle QtTest passes (including lifecycle), and the
styled-control pointer/ordered-keyboard/disabled-gating fixture pass. The control
validator's targeted QML lint completes successfully; it suppresses diagnostics
in its temporary log, so this is not a warning-free claim. A temporary copy
without the selector repair reproduces the mkdir failure, establishing that the
regression distinguishes prior behavior. Quickshell remains active and compositor
configuration errors remain empty afterward. Fixtures do not accept real devices.
