# SenomyOS project state

This is the single current runtime, delivery, acceptance and next-work ledger.
Updated 18 November 2026. Facts below distinguish fresh read-only observations
from dated publication or user-attested evidence. Documentation cleanup did not
restart the shell, change a device, apply a draft or accept a release.

## Verified runtime — 17 November 2026

| Fact | Scoped observation |
| --- | --- |
| Development source | `/home/Duku/SenomyOS`, branch `feature/display-workspace-orchestration`; extensive pre-existing modified/untracked/deleted work preserved |
| Running shell | `/usr/bin/qs --path /home/Duku/SenomyOS/shell/quickshell --no-color` |
| Shell service | `senomy-quickshell.service` active/running, MainPID 1522, NRestarts 0 |
| Calendar | Independent `senomy-calendar.service` active/running, MainPID 1646, NRestarts 0 |
| Notifications | D-Bus notification owner PID 1522, matching the shell |
| Compositor | Running Hyprland 0.57.2; `hyprctl configerrors` returned no errors |
| Displays/Rails | eDP-1 currently connected at 1920×1080, scale 1; one 1920×72 `senomy-v2-rail` and 72px bottom reserve. Earlier two-output observations are dated evidence |
| Delivery root | Observed shell still loads the development checkout; no versioned-release activation is established by this check |

These are reference-host observations, not portable defaults. PID/output state
can change. Recheck the affected fact before a runtime operation. Read-only UI entry/lifecycle checks are scoped in the motion receipt. No real
device mutation, physical hotplug or authentication was exercised.
Source/live compositor parity was not asserted or synchronized.

## Product and documentation decisions

The normal resizable
Settings window and compact Control Centre reuse one workspace. Performance and
Insights remain separate. One transient popover may coexist with a primary;
required reviews and dirty forms remain protected. Automatic idle locking stays
disabled by user policy; undocked lid behaviour is a distinct unresolved issue.

On 15 November the owner authorized seven core documents and focused references,
then explicitly requested removal of the deprecated checkout, retired code and mixed
archives. Those bodies and snapshots are deleted. Git metadata was relocated to
`~/.local/share/senomyos/repository.git`, preserving active HEAD and dirty state.
Current native runtime and authentication/release recovery remain separate.

Historical delivery summaries below are retained context. Deleted receipts cannot
be independently inspected; they are not newly verified acceptance.

## Recent delivery evidence

Owner-authorized native motion overhaul applied 17 Nov. Exact changes, preimages,
source hashes, native captures, validation and publication/live-health records:
`~/.local/state/senomyos/development/motion-complete-20261116/REVIEW.md`.
The 16 Nov foundation is retained as stage evidence, superseded for delivery status.
Shared completion-driven motion now covers quick panels, Lens/island, primary
hosts and toasts; primary navigation, retained directory/inbox rows, Calendar,
Session and local disclosures use scoped feedback. Settings prepares its preferred/
remembered size before mapping and gates content on matching native geometry.
Native inert tests cover actual host transitions, remembered sizing, maximize/
restore, protected reviews, rapid replacements/reopen and reduced motion. Local
body/provider/keyboard/guard suites and whole-shell lint pass; the obsolete
remaining-surfaces aggregate and contextual-views fixture are not counted as passing.

After source-watch application and the native-focus correction, 101 read-only live
checks cover Settings, three primaries and all eight non-Lens quick panels. Six
installed-helper/canonical Lens cycles pass. Actual Settings is 1280×860; sampled
visible quick sizes stay fixed and native keyboard focus is observed. Audio's
initial missing native focus was caught live and corrected using the existing
Lens focus-first grab policy for all quick panels. App identities, notification
state/owner, provider hashes, Rail reserve and shell/calendar PIDs/restart counts
match before/after. No runtime type/binding errors were recorded; existing Qt
Wayland text-input, stack-order and optional appearance-file warnings remain.
Closed surfaces and the prior compact/overview route are restored.

The installed Lens helper and canonical production IPC are exercised separately
from physical Win+R/production Rail clicks. The original teleport remains
unreproduced; do not claim a confirmed cure. Sequential queued-frame profiles
record 20 Lens/island cycles per version, zero Qt coordinate corrections and
approximately 17ms candidate opening callback medians; these are not scanout FPS.
The island first-positive-frame proxy is slower (196ms vs 155ms in this run),
while its first active-frame proxy is earlier. Scripted-workload CPU increases
12.80s vs 11.74s over about 41s; peak child-tree RSS is about 348MiB for both.
This is not an established performance improvement. Physical touch/IME, fractional
scale, hotplug/VRR/other GPUs, GPU timing and long-duration allocation acceptance
remain open. Current source-watch publication requests no service restart,
compositor reload or real device/session action; exact live results belong in
that transaction’s receipt. Broad aesthetic/hardware acceptance is not inferred.

| Date | Published result and evidence | Remaining limit |
| --- | --- | --- |
| 18 Nov | Owner-approved sculpted native Thunar rebuild applied after explicit “Apply this rebuild”: chrome header/corners, folder/path hierarchy, steel Places selection, ruled native file table and real object inspector (wide dock/narrow popover). Installed CSS, artwork, pane frame, native module and layout profile match reviewed source; Home reopened at 935×982 and actual live capture inspected. Publication and exact deployment/layout rollback receipts: `~/.local/state/senomyos/design-examples/thunar-sculpted-20261117/PUBLICATION.json` | Hidden-file/sort/view/click preferences and bookmarks preserved; shell/calendar processes and restart counts, notification owner and Rail geometry preserved; compositor reports no config errors. Candidate resize, inspector/tab and exact rollback fixtures passed. Physical input, broad DPI, real file actions, timing and compositor first-buffer/motion acceptance remain separate |
| 17 Nov | SenomyOS × Metalheart material/state pass applied after the explicit request for blackened semi-transparency and restrained hover. Native damage-driven Cairo paints one clipped base/art/scrim surface through the gutters, preserving foreground opacity and authored geometry. Silver hover is translucent rather than white; checked, pressed, disabled and static keyboard-focus states remain distinct. Eight retained native sizes, manual widths, Places/search and refreshed touch/split/icon/menu states pass; settled focus-visible evidence resolves the review's capture gap. Fresh independent review: ship at native-fixture scope. Six installed payloads and loaded module verified; actual 1880×982 File System window captured and inspected. Receipts: `~/.local/state/senomyos/design-examples/thunar-metalheart-20261117/PUBLICATION.json` | Supersedes the preceding opaque material decision at the owner's request. Native preferences, bookmarks, folder/workspace/geometry preserved; shell/calendar PIDs 1522/1646, zero restarts, notification owner and Rail unchanged. Active workspace restored after inspection. Owner aesthetic, broad backdrop/physical input/DPI acceptance remain separate. No compositor blur or new packages; optional-module fallback source-reviewed; Places accelerator limitation remains |
| 17 Nov | Filled Thunar workspace reconstruction applied after the owner rejected hollow sides and the overall wide composition. Original frame contours now have continuous opaque backing; Island cover/crop material, native current-folder heading, stronger Places ground, larger metadata and bounded responsive Name keep related fields together. Eight retained native sizes include actual 1880×982 and short 935×360, with manual widths, focus/selection/visibility, Places/search and gutter-alpha assertions. Independent fresh review passes the native candidate; actual installed File System window captured and inspected. Seven installed payloads/module/native fixed=true verified; original folder/workspace/geometry and bookmarks preserved. Receipts: `~/.local/state/senomyos/design-examples/thunar-surface-20261117/PUBLICATION.json` | Supersedes the previous anchored-art/always-expanding-Name correction. Earlier explicit Apply/reopen authorization retained. Shell/calendar PIDs 1522/1646, zero restarts, notification owner and Rail preserved; active workspace restored after inspection. Owner aesthetic, physical column drag/touch, alternate scale and real file operations remain separate. Places still depends on a native accelerator; native menu fallback remains |
| 17 Nov | Resize correction installed after explicit Thunar-only close/reopen approval: quieter anchored artwork, tighter header, expandable Name with bounded initial metadata, visible native Places toggle, and minimal focused-row reveal after height reduction. One retained native window passes eight grow/shrink/restore states, manual width, Places and search retention; guarded layout transition/rollback and independent final review pass. Installed hashes, loaded module and fixed-columns=false verified; original Home/workspace/geometry restored. Deployment and layout receipts: `~/.local/state/senomyos/design-examples/thunar-resize-20261117/PUBLICATION.json` | Supersedes the later installed appearance rejected especially on resize. Shell/calendar PIDs 1522/1646, restart counts, notification owner and Rail retained; no compositor reload. Native render evidence is isolated GTK; inactive-workspace live pixels were not captured. Places depends on its registered shortcut; owner aesthetic, physical input/scale and real file-operation acceptance remain open |
| 17 Nov | Owner-selected native Thunar rebuild applied after “Closer—continue with this”. The production GTK3 module provides the actual Files heading, compact toolbar, scoped silver folders and consistent metadata across new windows/panes/remapping. Original material remains visible through the shared reading backing; native layout omits repetitive Type, and guarded Places merge removes only bare duplicate Home while adding existing Documents/Downloads/Projects. Native state matrix, module handoff, layout/bookmark rollback and 49px touch-row checks pass; independent full review plus its single touch verdict resolved at tested scope. Settled live Wayland window inspected, module load verified and daemon observed surviving launcher exit. Exact source/installed preimages and receipts: `~/.local/state/senomyos/design-examples/thunar-rework-20261117/NATIVE-PUBLICATION.json` | Direction selected by owner; final installed aesthetic, physical touch, screen-reader, fractional-scale and real file-operation acceptance remain separate. Shared GTK bookmarks retain labelled/remote entries. Existing sort/hidden/click/view and custom actions retained. No live shell/calendar/compositor restart; source/library drift outside this task unchanged |
| 17 Nov | Native Thunar revamp installed: original clipped Island frame/material, sans filenames, quiet native menus/active states and standard/touch density; explicit native layout exposes search/split/new tab, keeps custom toolbar actions, and embeds preview. Five bounded clipboard actions add names/file links/project paths alongside path/SHA-256. Source/installed exact preimages, two deployment receipts and native layout receipt are in `~/.local/state/senomyos/design-examples/thunar-revamp-20261117/`. A Thunar-only new POSIX session fixes daemon lifetime after its launcher exits; existing source/installed launcher differences preserved. Native matrix, action/merge/layout fixtures and disposable application-lifetime suite pass; final reviewer scored both material fixes resolved. Settled live Wayland workspace inspected; no live shell/service/compositor restart or file mutation | Owner rejected the appearance on 17 Nov (“looks awful” with screenshot). That installed appearance was rejected; the owner-selected native rebuild supersedes it. Rebuild evidence is in `~/.local/state/senomyos/design-examples/thunar-rework-20261117/`. The later native integration delivery below supersedes that visual publication; working file actions/lifetime were preserved. Real file operations, physical touch, screen readers and fractional scale remain separate. Existing native sort/hidden/click/view choices and user actions retained; opening Thunar can update its ordinary window geometry. Shared-native library drift left untouched |
| 16 Nov | Fullscreen/immersive shortcuts repaired for current Lua dispatch, exact-window targeting, direct mode switching and per-window normal/maximized restoration. Rail visibility uses the existing event-refreshed window inventory per output. Twenty Python and eleven native state tests plus 105 live checks on both connected displays pass; apps, layout, focus and shell service preserved. Receipt: `~/.local/state/senomyos/development/fullscreen-20261116/` | Existing-output fullscreen/move/simultaneous operation tested; physical cable hotplug, alternate layouts and other hardware remain separate |
| 15 Nov | Wiki now includes searchable/persistent personal emoticons, exact-text copy, favorites and a runtime Hyprland shortcut reference. Six checksum-pinned upstream fallback fonts installed per user; native and adapter checks in `~/.local/state/senomyos/development/wiki-revamp-20261115/` | Runtime keys/flags are authoritative; Lua labels follow current config/workspace policy. Recipient fonts and existing application caches may differ; physical input/scale acceptance remains scoped |
| 3 Nov | User-attested reference-laptop reboot/login and normal-account TTY/sudo access; historical participant observation | Distinct from final release activation, credential-loss recovery or broad app-survival acceptance |
| 10 Nov | Control Overview A, explicit scoped owner approval | Physical/narrow/multiple-output acceptance stays scoped |
| 14 Nov | Precision construction and Briefing/destination navigation published | Review coverage and remaining issues are in those receipts |
| 14 Nov, 21:39 | Reviewed 49-file UI-quality candidate and installed Lens helper applied; preimages in `~/.local/state/senomyos/development/ui-quality-publication-20261114-213922/` | Existing app/compositor preservation recorded for that operation; broad hardware/whole-shell acceptance not claimed |
| 14 Nov, 22:24 | Panel-layout reconstruction published; private evidence/preimages in `~/.local/state/senomyos/development/panel-layout-20261114/` and `panel-layout-publication-20261114-222451/` | Scoped composition/provider preservation, not whole-interface acceptance |
| 14 Nov, 23:49 | Network Island transfer published; private evidence/preimages in `~/.local/state/senomyos/development/network-island-20261114/` and `network-island-publication-20261114-234932/` | No real network/device operation accepted; expanded reference artwork preserved |
| 15 Nov | Apps-first native Command Lens, local successful-launch frequency with A–Z sorting, clear search and authored clipped transparent background published; receipt in `~/.local/state/senomyos/development/command-lens-apps-20261115/` | Native focus/render, inert real app handoff and isolated state/keyboard tests verified; broad physical touch/fractional-scale acceptance remains open |
| 15 Nov | Audio Island and owner-requested refinement published: equal mute controls, no pointer-hover outlines, improved Settings button and inline collapsible MPRIS player with overflow marquee; receipt `~/.local/state/senomyos/development/audio-media-20261115/` | Native Audio/media/seek/motion/guard fixtures and live no-player render verified; volume/mute/devices and app windows preserved. Actual player transport and broad physical touch remain separately unaccepted |
| 15 Nov | Owner-approved Network popup published: connection-first status, Details, local name/All/Saved filters, quiet network rows and Settings action; receipt `~/.local/state/senomyos/development/network-publication-20261115/` | Native fake-network and Audio/media suites passed; final live render checked. Naming collision corrected and shared Settings rows/reviews restored; radio/SSID/interface, app windows and shell process preserved. No real scan/authentication/device changes tested |
| 15 Nov | Owner-approved Battery popup published: charge/time first, disclosed pack details, equal quiet profile choices and Settings/session exits; receipt `~/.local/state/senomyos/development/battery-publication-20261115/` | Actual BatteryService/SelectionActions fake-device suite and pending-care cancellation passed; native production-type lint and final live render inspected. Shell process/restart count, two Rails, notifications, prior app windows and observed policy/thresholds preserved. Profile provider was unavailable on the live host; no real profile/threshold/session mutation or native keyboard/physical touch acceptance claimed |
| 15 Nov | Owner-approved unified application tray published: whole-row primary/context actions, touch/keyboard alternatives and matching inline app menus; receipt `~/.local/state/senomyos/development/tray-publication-20261115/` | Native fake-input and actual private-D-Bus SNI/menu checks passed with exactly-once action delivery; final live tray rendered/inspected without invoking real apps. Shell process/restart count, app windows, two Rails and notification owner preserved. Actual app behavior/physical touch remain separate |
| 15 Nov | Owner-approved Calendar popup revamp published: wide month/day panes, agenda-first narrow disclosure and inline event previews; receipt `~/.local/state/senomyos/development/calendar-publication-20261115/` | Native input/date and actual private calendar-service suites passed; live empty-day render inspected. Shell/calendar service processes and restart counts, prior app windows, two Rails and notification owner preserved. No real calendar/reminder writes, editor handoff or physical touch acceptance claimed |
| 15 Nov | Owner-approved Notifications inbox published: All/Unread/search, version-specific read/detail flow, quiet-mode status and guarded clear; receipt `~/.local/state/senomyos/development/notifications-publication-20261115/` | Native fake-input/real clear guard and private notification protocol suites passed; actual live inbox inspected without opening messages. Owner, saved/unread/active counts and DND matched before/after; app windows, Rails and service processes preserved. Real app actions and physical touch remain separate |
| 15 Nov | Owner-approved compact application tray published: icon/name grid, no per-app description lines, preserved native primary/context actions and styled menus; receipt `~/.local/state/senomyos/development/tray-compact-publication-20261115/` | Final native UI/private-SNI/menu tests passed; actual live two-app 256×200 tray inspected without app commands. Shell/calendar processes and restart counts, prior app identities, both 72px Rails, display reserves and notification owner preserved. Physical touch, screen-reader, fractional scale and real app command behavior remain separate |
| 15 Nov | Owner-approved compact Power panel published: five icon/label actions, Now/Schedule options, prepared confirmation and timer monitor in Island material; receipt `~/.local/state/senomyos/development/power-compact-publication-20261115/` | Reviewed native actual-PowerService/inert-helper and production-host checks passed; actual live 480×180 chooser inspected without action or timer requests. Power state/schedule, shell/calendar processes/restarts, prior app identities, Rails/reserves, notification owner and compact tray preserved. Scheduler/provider/shared fields unchanged; real session/auth/hardware/physical input acceptance remains separate |
| 15 Nov | Owner-approved Insights redesign published: scoped Island workspace, attention-first home and revised eight-route working/reading flows; receipt `~/.local/state/senomyos/development/insights-publication-20261115/` | Native input/state/real clear-guard, 17 request-policy and private actual-service adapter checks passed. All eight live routes opened read-only; Briefing/Console/Wiki visually inspected. Processes/restarts, app identities, Rails/reserves, notification counts/quiet/owner, power state/schedule and shared providers/Performance/Power/tray preserved. Existing Performance process-row keyboard test fails on unchanged baseline; real actions, physical input and broad hardware acceptance remain separate |

Owner-directed Performance redesign and retained searchable-tree refinement published
15 Nov; receipt `~/.local/state/senomyos/development/performance-publication-20261115/`.
All twelve live routes opened read-only; native Overview/CPU/Processes captures were
inspected. Tree/search/keyboard/narrow checks, combined Insights/Performance contract,
seventeen request-policy and fourteen QML unit cases pass; prior read-only telemetry
continuity also passed. The old per-row Tab assertion was a fixture assumption:
baseline arrow navigation reaches every row. A distinct sort readback race and an
inventory-loading label error were fixed. Services/restarts, prior app identities,
Rails/reserves, notifications/owner and power state/schedule preserved; no new QML
errors after correction. Real process/service/workload actions and physical/hardware
acceptance remain separate. P12 records the scoped tree/content direction.

Owner-approved Control Centre redesign published 15 Nov; receipt
`~/.local/state/senomyos/development/control-centre-publication-20261115/`. Direct
audio/connection/power controls, compact destinations, searchable tree in both modes,
scoped command styling and native Settings lifecycle are retained in case P13.
Twenty-four coordinator cases, all nested route/search/focus/dirty/modal guards,
three close/geometry rounds, native quality and hidden-host checks passed. The first
live reload retained the old configuration after an inline-component type error;
equivalent standard QML declarations fixed it without a service restart. Eleven live
sections then opened read-only; new 1120×800 compact and 1280×860 native Settings
views were inspected, and compact-mode round trip passed. Apps/services/restarts,
Rails/reserves, notification state/owner, audio levels/routes/mutes, network/radio,
power schedule/policy and protected providers/Performance/Insights were preserved.
No new QML errors after correction; real actions and physical/hardware acceptance
remain separate. A06 is historical; P13 owns the current Control Centre composition.

Owner-approved remaining-panel redesigns published 15 Nov; receipt
`~/.local/state/senomyos/development/remaining-panels-publication-20261115/`.
Bluetooth local search/filters/inline details, bounded notification toasts, OSK
controls, deeper display/mixer/account/input editors and workspace focus/overflow
are applied. At the owner's explicit request the independent companion is deleted,
including its window, state/IPC, dead launch signals, duplicate media helper and
current help entries. Original expanded Island composition/art and Insights remain.
ScheduleRail was assessed and retained. Case P14 records the scoped acceptance.
Native primary/deeper-editor, current Control Centre, Rail/popup interaction and
hidden-host checks pass; eight screen-lifecycle cases and full-shell lint pass.
The old route-test host fails the same overview-focus check on the unchanged
baseline and candidate; it is not counted as passing. Live Bluetooth, six Settings
routes, full Settings and both other primaries opened read-only; captures inspected.
Shell/calendar processes and restarts, app identities, both 72px Rails/reserves,
notifications/owner, power schedule/policy, audio routes/levels/mutes, network/radio,
Bluetooth power/discovery/connections and display draft/transaction are preserved.
No new QML errors; deletion-scanner and existing hot-reload/optional-file warnings
are recorded separately. Tracked compositor matching no longer names the removed
companion; live compositor configuration was not synchronized or reloaded. Real
device/authentication/session actions, physical input and broad hardware acceptance
remain separate. Authored source art and historical evidence are retained.

Owner-requested Rail backgrounds published 15 Nov; receipt
`~/.local/state/senomyos/development/rail-background-20261115/`. Workspace cells,
collapsed/message Senomy, system controls, clock/bell and Power share the expanded
Island artwork/transparency inside their existing compact chamfers. Gaps remain
transparent; high contrast is opaque. Eight background-only QML files changed;
original expanded panel, artwork, providers, layout and actions remain unchanged.
Native before/after/narrow/message/touch/contrast/fallback captures, corner-alpha
probes, lint, anchors and Rail/popup interaction checks pass. Both live Rails were
captured and inspected; apps/services/restarts, notifications, device settings,
72px reserves and closed surfaces are preserved. The last closed Settings route,
reset by reload, was restored read-only. No new QML errors, service restart or
compositor reload; incumbent stack-order/optional-file warnings remain. See P15;
physical input, scale and hardware acceptance remain separate.

SDDM and matching-lock redesign installed on 16 Nov after the owner said “it works”
and requested application with the chibi removed. Account identity now uses the full
login header width; lock labels are rebalanced without the portrait. The generated
ivory/black/silver metalheart wallpaper, credential Island, account search, explicit
session/layout choices, separate recovery and guarded power remain. All 46 SDDM plan
entries and the user lock deployment have matching installed content. Rollback receipts:
`/var/lib/senomyos/deployments/20261116-190012-sddm-17859/receipt.json` and
`~/.local/state/senomyos/deployments/20261116-190005-hyprlock-17860/receipt.json`.
Publication evidence is `~/.local/state/senomyos/development/auth-publication-20261116/`;
the earlier design/RHI review remains in
`~/.local/state/senomyos/design-examples/sddm-rebuild-20261115/`.

Native fake-auth, initial/retained/restored short-screen focus and offline lock
projection checks pass after portrait removal. The owner approved applying the
direction; real PAM/session start, native lock rendering and hardware acceptance were
not exercised by this publication. No SDDM/service restart, logout or live lock was
performed. Optional live compositor backdrop policy remains unapplied: both live-blur
capabilities are currently disabled, so the guarded launcher uses the screenshot-blur
fallback. Automatic idle policy and the desktop's existing character artwork are
unchanged. Earlier private headless SDDM test-mode did not complete; that result stays
unverified rather than establishing integration acceptance.

Private receipt paths are reference-host history, not portable source defaults. Earlier candidate wording in QA remains a stage snapshot; the publication receipt
owns whether that candidate was applied.

## Capability and acceptance ledger

Stable domain/contract/workflow IDs remain in the
[capability catalog](reference/CAPABILITIES.md),
[operational contracts](reference/ACCEPTANCE_CONTRACTS.md) and
[workflow reference](reference/WORKFLOW_TESTS.md). Those specify scope and expected
outcomes. Current priorities and acceptance limits are recorded here once.

| Scope | Retained implementation/evidence | Still unaccepted or unresolved |
| --- | --- | --- |
| D01–03 Rail, popovers, Lens | Native source, shared leases/guards, bounded catalogs and 14 Nov routing/publication work | Full physical focus/touch/fractional-scale and final-root ordinary-app lifecycle acceptance |
| D04 Network | Shared native/core profile/auth/recovery work and later native popup publication | Real credential/retry/VPN/plugin/traffic and adapter lifecycle journeys |
| D05–06 Bluetooth/audio | Native provider/controller, guarded actions, private-bus/model/transport fixtures and inventory recovery | Positively identified real headset pairing/reconnect, A2DP/microphone/profile/default/app routing and restoration |
| D07 Power/session | WP03 core/care-helper implementation; 1 Nov battery Balanced→Saver→Balanced round trip has bounded participant/readback evidence | Threshold Apply/Restore and charging/lifecycle acceptance, AC/Performance and undocked-lid policy mismatch; no automatic idle policy repair is implied |
| D08–09 Displays/workspaces | Shared logical geometry, identities, drafts, guarded preview/recovery and dynamic local slots | Actual populated-group unplug/replug, suspend/relogin and link-failure recovery; preserve current geometry and drafts |
| D10–11 Calendar/notifications | Persistent local organizer, activated provider, reminder/storage/socket fixtures and native notification owner | Actual desktop reminder presentation and longer lifecycle; remote providers separately optional |
| D12 Input/accessibility | Typed Lua/readback/rollback, OSK ownership/manual/conditional-auto and control fixtures | Exact preview expiry, Keep/readback, durable preference restoration and physical typing/touch/scale coverage |
| D13–14 Apps/accounts/login | Independent app launch architecture and account/polkit safeguards; scoped native/publication evidence | Disposable-account real authorized lifecycle, full password/login/permission journeys and recovery scope |
| D15–16 Appearance/Performance/Insights | Current authored role system, shared continuous telemetry, guarded exports and eight Insights routes | Full physical/accessibility/resource acceptance; GPU/DNS/SMART and optional telemetry stay capability-limited |
| D17–19 Deployment/recovery/Settings | Versioned payload transactions and isolated upgrade/rollback fixtures; one compact/full page tree | First controlled final-root activation, exact live rollback/recovery and durable preference/lifecycle checks |
| D20 Reliability | Existing focused suites, renders, resource snapshots and ordinary target-stack startup evidence | Sustained resource budgets, fresh-user/clean-VM installation/recovery and representative hardware coverage |

The capability reference preserves identifiers and intended scope. Historical
checkbox/test counts are not current product completion. Keep automated, native read-only,
participant-observed, physical and release-level evidence distinct.

## Next work and constraints

1. Preserve scoped completed implementation; do not restart a broad maturity
   audit or rebuild providers just because an old proposal lists them as missing.
2. For a future authorized release transition, review current payload/source/
   installed-entry ownership and TTY recovery first. Prepare the exact activation
   and receipt-specific rollback. A separate password-recovery login is optional
   credential-loss functionality, not a dependency of release activation.
3. Perform only the affected, specifically authorized lifecycle/input/hardware
   acceptance. Later 14 Nov publication recorded scoped app preservation; that
   does not certify every launch class or final release root. Input expiry/Keep/
   persistence needs its own state-preserving test and active restore hook.
4. Use a disposable/fresh environment for clean-install and recovery qualification.
   Keep optional-provider absence separate from broken supported workflows.

These are next-work constraints, not authorization to restart, activate a release,
change an input/output, install packages or alter credentials during this task.

## Known incidents and evidence limits

GitHub snapshot preparation on 18 November passed syntax checks for 63 Bash
scripts, 201 Python files and 44 JSON files, plus 20 README/gallery links.
The isolated shell aggregate passed lint, appearance/search projections, 33
account tests and 24 navigation-state cases, then stopped at the native
Control-directory fixture: `vertical focus clipped: devices`. The isolated
deployment fixture also stopped at its outdated three-action assertion; the
current Thunar action manifest plus the preserved fixture action produce six.
Neither aggregate is counted as passing. These checks did not publish runtime
source, restart services or exercise real device actions.

The 16 October unsafe nested-compositor cleanup and 14 November compositor loss
remain separate incidents. The latter initiating cause is unknown. Do not infer
causation from portal cleanup failures or treat applications/unsaved state as
recovered. Quarantined compositor runners stay disabled. Use inert offscreen
fixtures and retain exact private preimages.

The design-library checker retains existing native-source fingerprint drift.
Deleted documentary-source fingerprints were removed without adopting new visual
approval or changing hashes of surviving native sources.

## Updating this file

Replace the affected current row with dated, scoped evidence and its remaining
limit. Link the receipt; avoid prepending another full progress narrative. Reopen
only evidence affected by an actual source/provider change. Product rules belong
in PRODUCT_SPEC, technical ownership in ARCHITECTURE, design rules in DESIGN_SYSTEM
and operating procedures in DEVELOPMENT. Archive superseded detail.
