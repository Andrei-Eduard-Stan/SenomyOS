# SenomyOS automation progress

Canonical user-approved roadmap (direct approval: 2026-10-05). Current facts
and authority rules: [PROJECT_STATE.md](PROJECT_STATE.md). Reconciliation:
[FORENSIC_AUDIT_2026-10-06.md](FORENSIC_AUDIT_2026-10-06.md).
Checked implementation items do not mean physical/manual acceptance passed.

Updated: 2026-10-08

## Active autonomous scope — 2026-10-08

User instruction: finish the functional work listed through and including
Senomy Insights in the October 7 functional summary. This is an execution scope
within the canonical roadmap, not replacement milestone numbering.

In scope: session reliability, power policy, displays/devices, keyboard and
accessibility, networking, applications, desktop integration, performance
management and Senomy Insights. Preserve its eight routes, including update
discovery. Update installation, release packaging/installer work and visual
redesign remain outside this run. Existing styling/assets/layouts are preserved.

Continuation rules:

1. Read this scope and Exact next stage before editing; inspect HEAD/status and
   relevant diffs. Resume saved work only after checking it against current source.
2. Work on one explicit requirement at a time. Name its source, behavior, files,
   test and remaining acceptance before marking it complete.
3. Prepare watched-QML changes in an isolated copy; test fake providers before
   publication. Warn before publishing because source watching can reload the UI.
4. Keep code, automated checks, runtime observation and physical/manual acceptance
   separate. Failures/timeouts/unavailable providers must not count as success.
5. Checkpoint validated stages, preserving unrelated changes; never bulk stage or
   push. Record an exact next step and dependency before stopping or interruption.
6. Continue independent safe source work when physical acceptance blocks another
   item. No unattended reboot, suspend, lock, network disconnect, real-device
   mutation or destructive recovery test. Automatic suspend stays gated.
7. A lost session, dead laptop or absent tool result is not completion evidence.
   No persistent background execution or schedule is implied by this ledger.

| Functional scope | Source mapping | Current remaining outcome |
|---|---|---|
| Session reliability | §1; Desktop Alpha A07 | Attended fresh login/lock/suspend/fallback; safely test failure logic separately |
| Power policy | §2 | Deploy/accept idle policy; retain recovery gate on automatic suspend |
| Displays/devices | §1; Settings Capabilities | Source guards exist; physical docking, rollback, pairing and routing acceptance |
| Keyboard/accessibility | §3 | Section focus/navigation, full route/control reachability, input-method/OSK path |
| Networking | §5 | Saved-profile management, VPN/DNS/proxy handoffs, failure feedback, provider acceptance |
| Applications | §6 | Default applications and autostart management with validated native boundaries |
| Desktop integration | §6 | Portal status and native peripheral/file/screencast journeys |
| Performance management | §4 | Managed restart boundary, diagnostics/report coverage, accepted process flow |
| Senomy Insights | Product Spec; native route contract | Complete briefing/timeline/diagnostic/console/report/wiki contracts and truthful freshness; notification acceptance |

Interrupted-run check: HEAD is `e870369`; reflog has no later completed stage.
The large pre-existing working tree remains preserved. No later saved result
was established. Active staging copy:
`~/.local/state/senomyos/development/functional-20261008`.

Current bounded stage: Control Centre/shared dashboard section navigation and
route-change focus restoration. Source was validated in the isolated copy and
published on 2026-10-08. This does not close the full §3 accessibility audit.

### Durable checkpoint — shared route navigation, 2026-10-08

- Implementation: `DashboardNavigation.qml`, connected by the existing shared
  `DashboardWindow.qml`. Opening focuses the active route; Up/Down/Home/End move
  focus without activation; Return/Space activate; disabled routes are skipped;
  focus tracks scrolling and route changes after old content destruction.
  Inactive navigation must not steal focus. Tab/Shift-Tab can leave navigation.
- Automated: `bash scripts/validate-dashboard-navigation.sh` passes the actual
  shared component's isolated pointer/keyboard fixture, including narrow width,
  disabled rows, deferred focus, scrolling, close/content exit and reopening.
  Original production navigation reproduced missing initial selected-route focus.
  Bash syntax and whitespace pass; QML lint exits successfully with existing
  native-metadata/unqualified diagnostics, not warning-free.
- Publication: source-watch refresh was warned in advance; no explicit service
  restart, compositor edit or device mutation. Service remains active/running,
  PID 1373 unchanged, compositor config errors empty. No full live pointer/UI
  acceptance was performed; health does not prove the new behavior was exercised.
- Existing shared window and its visual dependencies were already untracked.
  Preserve them; the integration diff and original-source checksum are retained
  under `docs/qa/navigation-20261008/` for recoverable review without bulk staging.
  A clean-checkout/release claim remains invalid until that baseline is reviewed.
- Next: exercise actual Control Centre route loading and focus in an isolated
  fake-provider fixture; audit content controls and confirmation focus. Then
  complete the native input-method/OSK boundary. Do not jump to visual redesign,
  update installation or release tooling because this one component passes.

### Durable checkpoint — focus remains visible, 2026-10-08

- Concrete regression: the actual Input route focused a button at y=777 beyond
  an 820px viewport without scrolling, clipping the focused control. Source
  fixtures demonstrated this before the repair; it was not inferred from a TODO.
- `FocusScrollArea.qml` keeps descendant keyboard focus vertically visible.
  Existing scrolling routes use it; Applications/Settings receive scroll wrappers
  around their unchanged content; Appearance uses the same behavior. No visual
  redesign or provider/action contract changed.
- `python3 scripts/validate-control-routes.py` passes actual ten-route content at
  1120x820 and 720x500 in idle and pending-action states. It checks selected-route
  focus and 45 Tab steps per route/scenario; fake-provider mutation count is zero.
  The window/compositor host is substituted, not accepted; lists with real devices,
  every locale/long label and real pointer/touch input remain separate acceptance.
- Publication was warned. The journal subsequently reports configuration reload
  and loaded; service remains running at PID 1373. Existing stacking warning
  remains; compositor configuration errors are empty. No explicit restart.
- Recoverable integration patches and source hashes are in
  `docs/qa/navigation-20261008/`; original files are retained in the private staging
  directory. Existing unrelated source changes are preserved, not bulk committed.
- Next: pending confirmation should receive safe keyboard focus, with cancel/
  dismissal and route replacement tested; then audit the remaining input-method
  boundary. This is still partial §3, not whole-scope completion.

This ledger uses the user-approved roadmap below. It replaces the former
six-item Settings Capabilities interpretation and its invalid terminal marker.
Commits `af9aebc` and `568a875` are not evidence that this roadmap is complete.

### Durable checkpoint — safe confirmation focus, 2026-10-08

- `ConfirmationFocus.qml` defaults newly pending selection/network previews to
  Cancel and restores prior focus after dismissal. Deferred callbacks recheck
  visibility/state; hidden contexts and rapid dismissal must not steal focus.
- `bash scripts/validate-confirmation-focus.sh` passes fake-provider keyboard
  cases for both review components. The original selection review failed the
  initial Cancel-focus assertion. Existing selection/network guard validators
  also pass, and the actual Control Centre route fixture still passes.
- Confirmation activation requires deliberate movement to Confirm. These checks
  invoke no real device mutations and do not accept other confirmation families.
- Publication was warned; service remains running with no compositor config
  errors. Qt focus/lint and existing stacking diagnostics remain recorded rather
  than described as warning-free. Manual acceptance remains pending.
- Integration patches preserve the pre-existing untracked review components.
  See `docs/qa/navigation-20261008/`; clean-checkout reproducibility remains open.


## Status summary

| Roadmap section | Classification | Current source position |
|---|---|---|
| 1. Physical acceptance | REQUIRES PHYSICAL ACCEPTANCE | Source fixtures and guarded providers exist; every listed item requires attended real-hardware/session acceptance. |
| 2. Idle and power policy | INCOMPLETE | Hypridle manifests, bounded editable timeouts, and a lock/none lid policy exist. Deployment and behavior acceptance are physical; automatic suspend remains blocked on recovery acceptance. |
| 3. Keyboard and accessibility | INCOMPLETE | Persistent layout, repeat, pointer, and touchpad controls exist. First-run locale selection and detected Fcitx5 settings handoff exist; complete keyboard/focus coverage and native Wayland OSK integration remain open. |
| 4. Performance management | INCOMPLETE | Process sorting/details and confirmed ownership-checked SIGTERM exist. Guarded restart, service boundaries, and diagnostic/report parity remain incomplete. |
| 5. Networking | INCOMPLETE | Native status, bounded scan/refresh, guarded connect/disconnect, and terminal-owned credential entry exist. Saved-profile management, VPN/DNS/proxy, and richer failure feedback remain incomplete. |
| 6. Applications and desktop integration | INCOMPLETE | Launcher, tray, file-manager, and portal package foundations exist. Defaults, autostart, permission/portal status, and end-to-end peripheral/file integration remain incomplete. |
| 7. Updates | INCOMPLETE | Insights update support is discovery-only. Reviewed installation and complete progress/failure/reboot/rollback/recovery flows remain incomplete. |
| 8. Release engineering | INCOMPLETE | Bootstrap/manifests and deployment receipts exist. Versioned packages, migrations, VM/boot evidence, bootable media, and a hardware matrix remain incomplete. |
| 9. Quality and release evidence | INCOMPLETE | Some responsive fixtures and targeted checks exist. Full audits/measurements/licensing, QML diagnostic resolution, and reviewable working-tree organization remain incomplete. |

## Durable checklist

### 1. Physical acceptance — REQUIRES PHYSICAL ACCEPTANCE

- [ ] Real multi-monitor docking, hotplug, mirroring, rollback, fractional scaling, and output enable/disable.
- [ ] Real keyboard, pointer, touchpad, and touchscreen testing.
- [ ] Bluetooth pairing variants and audio-route changes.
- [ ] Suspend/resume, lock recovery, and fresh-login testing.

No unattended automation may perform these actions.

### 2. Idle and power policy — INCOMPLETE

- [ ] Install and deploy Hypridle through bootstrap. Source declarations are present; installation/deployment requires attended acceptance.
- [ ] Verify lock and DPMS behavior. Physical acceptance required.
- [x] Add editable timeouts. Source implementation and targeted automated validation are complete; runtime acceptance remains required.
- [x] Design lid-close policy. Source exposes capability-aware `lock`/`none`; physical acceptance remains required.
- [ ] Add automatic suspend only after recovery testing. BLOCKED on successful attended recovery testing; do not implement beforehand.

### 3. Keyboard and accessibility — INCOMPLETE

- [x] First-run keyboard locale selection. The backend derives a catalog-valid
  current layout without changing it, reports whether a saved preference
  exists, and the Input page presents an explicit first-run review state. Only
  the confirmation button applies and persists the selection. Physical
  keyboard acceptance remains required.
- [x] Keyboard repeat-rate and repeat-delay settings. Source implementation is complete; physical acceptance remains required.
- [ ] Focus-order and complete keyboard navigation audit.
- [ ] On-screen keyboard and input-method support. Detected Fcitx5 editor handoff now has mocked backend/UI coverage; engine/session/text-entry acceptance and native Wayland OSK support remain open.
- [ ] Touch-target and portrait-layout acceptance. Physical acceptance required; source fixes discovered by it remain in scope.

### 4. Performance management — INCOMPLETE

- [x] Process sorting and detail views.
- [ ] Guarded terminate/restart actions. Confirmed graceful user-process termination exists; restart remains unavailable.
- [ ] Better service-management boundaries.
- [ ] Expanded diagnostic and report parity.

### 5. Networking — INCOMPLETE

- [ ] Saved-network management.
- [ ] VPN, DNS, and proxy settings.
- [ ] Better connection failure feedback.
- [ ] Physical scan-freshness and credential-flow testing. Physical acceptance required.

### 6. Applications and desktop integration — INCOMPLETE

- [ ] Default applications.
- [ ] Autostart management.
- [ ] Permissions and portal status.
- [ ] Removable media, mounts, archives, shares, screencasting, and file-association acceptance.

### 7. Updates — INCOMPLETE

- [ ] Reviewed update installation.
- [ ] Progress, failure, reboot-required, rollback, and recovery flow.
- [x] Current Insights update support remains discovery-only; this describes the baseline and is not installation support.

### 8. Release engineering — INCOMPLETE

- [ ] Versioned installable packages.
- [ ] Preference and configuration migrations.
- [ ] Clean virtual-machine installation.
- [ ] Cold boot and recovery boot.
- [ ] Bootable installation/recovery image.
- [ ] Hardware compatibility matrix.

### 9. Quality and release evidence — INCOMPLETE

- [ ] Full accessibility and responsive-layout audit.
- [ ] Current idle CPU, memory, GPU, animation, and power measurements.
- [ ] Font, icon, artwork, and dependency licensing audit.
- [ ] Resolve existing nonfatal QML lint diagnostics.
- [ ] Organize the large working tree into reviewable commits.

## Latest durable work and validation

- 2026-10-05 bounded Section 3 stage: removed the implicit `gb` first-run
  assumption from the input backend. The read-only `get` contract now selects
  an existing `localectl` X11 layout only when it is in the system XKB catalog,
  falls back deterministically inside that catalog, and reports `firstRun`
  without invoking `hyprctl`. Five isolated Python tests, Bash syntax, Python
  compilation with a temporary bytecode directory, and targeted whitespace
  checks pass. No live input setting changed.
- 2026-10-05 first-run UI stage: `InputSettings.qml` now carries the backend's
  `firstRun` state and the existing Input page shows a truthful detected-layout
  review card plus a keyboard-accessible confirmation action. Page opening has
  no apply side effect. Five isolated Python tests and targeted `qmllint`
  completed successfully; lint emitted the repository's existing warning
  categories. Targeted whitespace checks pass. No preference was applied.
- 2026-10-06 bounded keyboard-navigation audit stage: extended the isolated
  styled-control fixture to verify ordered Tab focus, skipping disabled
  actions, Return/Space activation, pointer activation, and disabled action
  gating. `scripts/validate-control-settings.sh` now runs that fixture with an
  isolated runtime directory. The targeted validator passes: four skin
  preference cases, six screen lifecycle cases, the focus fixture, Bash
  syntax, QML lint, and whitespace checks. No production focus defect was found
  in this bounded primitive-level pass, so no runtime control was changed.
- Commit `a6629ba` (`feat(settings): persist idle timeout policy`) added the
  bounded persistent timeout backend and targeted tests.
- Additional shared-working-tree source for timeout controls and the lid policy
  passed six isolated Python tests, four offscreen QML/JavaScript tests, Bash
  syntax, Python compilation, manifest JSON validation, `qmllint` with existing
  warning categories, and targeted whitespace checks. It remains uncommitted
  because its dependency files overlap pre-existing shared changes.
- No live configuration, package, service, session, or physical device was
  changed by that work.
- Push remains withheld: `quickshell-v2` already contains unreviewed local
  commits ahead of `origin/quickshell-v2`, including the incorrect-scope ledger
  commits.

### Durable checkpoint — remaining confirmation focus, 2026-10-08

- Bluetooth reuses NetworkActionReview rather than keeping an untested duplicate.
  Notification clear and display previews use ConfirmationFocus. Temporary
  display approval focuses Revert now; session previews focus Cancel for all
  five actions. State adaptation keeps system-action controllers unchanged.
- The extended fixture includes naturally hiding review components: cancellation
  now returns focus even when the review disappears. Hidden pending contexts do
  not capture stale focus or steal focus after route replacement.
- `python3 scripts/validate-confirmation-families.py` passes fake-provider checks;
  its session popup uses a substituted Window host. Real compositor focus/grabs,
  physical display rollback and attended session actions remain unaccepted.
- Bluetooth action/discovery validators pass (13/6 Qt cases including setup and
  cleanup). Display validator passes nine Python cases and 15 Qt cases including
  setup/cleanup. The actual ten-route Control Centre fixture also passes.
- Source-watch publication was warned; Quickshell remains running, PID 1373;
  Hyprland config errors empty. QML lint exits successfully with native metadata/
  unqualified warnings; Qt focus diagnostics remain. No real device mutation.
- Recoverable integration patches/checksums: docs/qa/confirmation-20261008/.
  Existing uncommitted baseline and visual work remain preserved.

### Durable checkpoint — detected input-method handoff, 2026-10-08

- InputSettings refreshes optional editor/engine capability when its route becomes
  active. NativeInputToolsView shows independent installed-tool states, disables
  absent/busy activation and invokes only the fixed Fcitx5 editor handoff.
- The backend accepts only detect/open-ime with no user arguments; rechecks the
  executable at launch; returns unavailable/failed/started truthfully. Started
  means a child process was created, not that IME input works or settings changed.
- Six mocked Python tests cover absence, editor/engine independence, fixed argv,
  exec failure, removal after detection and rejected commands. The actual view's
  fake-provider fixture passes at 340/540px with keyboard activation and absent/
  busy gating. No real editor was launched. QML lint exits zero with diagnostics.
- Reference-machine read-only detection reports editorAvailable=false and
  engineInstalled=false. OSK integration is explicitly open, not inferred from
  a command being installed. No packages/environment/autostart were changed.
- Warned source publication reports Configuration Loaded; service active/running
  PID 1373 unchanged; compositor config errors empty; existing stacking warning
  persists. No manual application text-entry or touch acceptance was performed.
- Integration patches/hashes: docs/qa/native-input-20261008/. Fcitx editor reference:
  https://fcitx-im.org/wiki/Configtool_%28Fcitx_5%29/en . Existing baseline changes
  remain separate; clean-checkout reproducibility remains open.

### OSK investigation checkpoint — 2026-10-08

- Primary wvkbd documentation/source establish explicit manual show/hide and
  separate auto-input-method requirements. Proposed candidate and lifecycle/
  focus/acceptance contract: docs/OSK_PROVIDER_CONTRACT.md.
- Read-only lookup finds no wvkbd-mobintl, wvkbd-deskintl or wayland-info on the
  reference machine. Protocol support remains unknown. No provider was started,
  installed or represented as integrated. This is investigation, not delivery.

### Durable checkpoint — OSK probe and isolated controller, 2026-10-08

- Read-only OSK probe is connected to InputSettings route activation and the
  existing input-tools status card. Installed provider, advertised required
  protocols and unknown/incompatible results are separate. No provider is started
  or installed; integrated is always false. Fcitx status remains independent.
- Nine Python cases cover missing session/probe/provider, exact interface/version
  parsing, missing protocols, command errors/timeouts, malformed/oversized output
  and rejected actions. The schema fixture rejects invalid data and does not
  promote advertised protocols to accepted integration. Prior input handoff tests
  still pass; lint exits zero with existing metadata/unqualified diagnostics.
- OskController is an isolated prototype with an injected owned-provider adapter.
  Twelve behavioral cases plus setup/cleanup pass: guarded startup, ownership,
  duplicate requests, show/hide, cancellation/confirmed stop, failures, stale
  callbacks, capability loss, timeout and focus-release requests. No production
  adapter is connected; no real keyboard or desktop process was signalled.
- Reference-machine probe reports providerInstalled=false, protocolState=unknown
  because wayland-info is unavailable. No compatibility or touchscreen claim.
- Warned publication: Configuration Loaded observed; Quickshell active/running,
  PID 1373 unchanged; compositor config errors empty; existing stacking warning.
  Physical acceptance remains pending. Evidence: docs/qa/osk-20261008/.
- Managed Quickshell processes end with reload/shell exit; detaching loses direct
  child ownership. This remains the adapter's explicit unresolved boundary, not
  a reason to pretend the OSK feature is delivered.

## Exact next stage

Section 3: implement and test the production OSK adapter's owned-child lifecycle
and explicit show/hide/confirmed-stop UI. Resolve reload/shutdown policy against
OSK_PROVIDER_CONTRACT.md before launch hookup; route dismissal must preserve the
keyboard, and successful show requests must release primary focus. Use fake
providers for failures/races and unknown/missing tools; never activate or install
an unvalidated keyboard automatically. Physical IME/OSK/accessibility acceptance
and the later functional domains through Insights remain open.
