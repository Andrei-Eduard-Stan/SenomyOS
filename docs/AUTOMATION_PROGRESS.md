# SenomyOS automation progress

Canonical user-approved roadmap (direct approval: 2026-10-05). Current facts
and authority rules: [PROJECT_STATE.md](PROJECT_STATE.md). Reconciliation:
[FORENSIC_AUDIT_2026-10-06.md](FORENSIC_AUDIT_2026-10-06.md).
Checked implementation items do not mean physical/manual acceptance passed.

Updated: 2026-10-06

This ledger uses the user-approved roadmap below. It replaces the former
six-item Settings Capabilities interpretation and its invalid terminal marker.
Commits `af9aebc` and `568a875` are not evidence that this roadmap is complete.

## Status summary

| Roadmap section | Classification | Current source position |
|---|---|---|
| 1. Physical acceptance | REQUIRES PHYSICAL ACCEPTANCE | Source fixtures and guarded providers exist; every listed item requires attended real-hardware/session acceptance. |
| 2. Idle and power policy | INCOMPLETE | Hypridle manifests, bounded editable timeouts, and a lock/none lid policy exist. Deployment and behavior acceptance are physical; automatic suspend remains blocked on recovery acceptance. |
| 3. Keyboard and accessibility | INCOMPLETE | Persistent layout, repeat, pointer, and touchpad controls exist. First-run locale selection, complete keyboard/focus coverage, and native Wayland OSK/input-method integration remain source gaps. |
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
- [ ] On-screen keyboard and input-method support. Optional Fcitx5 handoff exists; native Wayland OSK support remains open.
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

## Exact next stage

Section 3: continue the focus-order and complete keyboard-navigation audit with
the Control Centre's section navigation and route-change focus restoration.
Use an isolated fixture; repair only concrete unreachable, stale, or incorrectly
ordered focus behavior discovered there. Do not drive the live desktop.
