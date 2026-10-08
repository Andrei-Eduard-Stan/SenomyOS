# SenomyOS current project state

Reconciled 2026-10-06. This is the current-state entry point. The canonical
roadmap is [AUTOMATION_PROGRESS.md](AUTOMATION_PROGRESS.md); dated evidence and
the requirement matrix are in [FORENSIC_AUDIT_2026-10-06.md](FORENSIC_AUDIT_2026-10-06.md).

## Product and authority

SenomyOS is a custom Arch/Hyprland desktop environment in development, with
Quickshell owning normal shell and notification operation and Eww/SwayNC kept
for recovery. The destination includes reproducible installation, first-run
configuration, safe updates, recovery and tested hardware tiers. It is not a
released operating-system distribution.

Intent follows evidenced user decisions, then explicitly superseding
specifications, then product/platform documentation. Implementation follows safe
runtime observations, connected source, installed configuration, Git evidence,
then documentation claims. Neither route migration nor a checkbox proves
functional parity or acceptance. Local direct-user session records confirm the
2026-09-03 Quickshell promotion and 2026-10-05 nine-section roadmap approval.
The current audit request authorizes reconciliation and bounded implementation;
historical automation scope restrictions are historical, not replacement goals.

## Current baseline

- Development: `/home/Duku/SenomyOS`, `quickshell-v2`, audited HEAD `a6629ba`.
- Recovery: detached `/home/Duku/.config/eww` at `d8850ff`; preserve it.
- Do not use `/home/Duku/Projects/SenomyOS`.
- Current runtime: Hyprland 0.56.2-3, Quickshell 0.3.1-1, one 1920x1080
  scale-1 output, one `senomy-v2-rail`, 72px bottom reservation.
- Quickshell active/running, notification bus owner matches its PID. Eww,
  workspace publication and SwayNC units inactive. This verifies ownership,
  not every UI action or successful fallback recovery.
- Tracked/live Lua differ: the tracked lid-switch binding is absent live.
  No synchronization was performed. Hyprland reports no configuration errors.
- Hypridle is not installed and its user unit is not loaded. Source policy
  and manifests do not prove deployed idle behavior.
- Audit baseline included 79 modified tracked files and 511 untracked files.
  Many runtime dependencies and evidence documents are uncommitted. Do not
  bulk stage, clean, overwrite or infer session authorship.

## Completion boundaries

The native Rail, ten Control routes, seven Performance routes, eight Insights
routes, flyouts, independent companion, service graph and generated appearance
foundation exist. Current read-only audio, two battery packs, Bluetooth and
notification metadata respond. Historical protocol, virtual-output and fixture
records provide useful dated evidence, not current physical sign-off.

Still open: complete keyboard/accessibility audit; physical provider and
multi-output acceptance; fresh login, lock, suspend and fallback recovery;
saved-network/VPN/DNS/proxy settings; managed service restart; diagnostic/report
parity; defaults/autostart/portal journeys; update installation; licensing and
current resource measurements; versioned artifacts/migrations; clean-VM/boot
acceptance, installer/recovery media and hardware matrix.

Automatic suspend and boot-theme activation remain blocked on their respective
recovery/boot acceptance gates. Bespoke artwork and unresolved visual direction
remain design-dependent. Do not manufacture new visuals to close functional work.

## Documentation discipline

This file owns current facts, blockers and evidence limits. AUTOMATION_PROGRESS
owns the user-approved backlog and next bounded step. ARCHITECTURE owns component
boundaries; PRODUCT_SPEC and PLATFORM_STRATEGY own product/deployment requirements;
DECISIONS owns dated decisions; RUNTIME_INVENTORY owns dated observations.
DESKTOP_ALPHA and QA documents are evidence ledgers. IMPLEMENTATION_PLAN and
migration milestones are historical sequencing, not competing execution roadmaps.
Visual proposals remain proposals unless a direct decision approves them.

Every completion update must give implementation path, validation command/date,
runtime evidence if any, and remaining manual acceptance. Keep code complete,
automated verification, runtime verification and manual acceptance separate.
Do not use an automation terminal marker as whole-product completion.

## Resumed bounded work

2026-10-08: the user authorizes autonomous functional development through and
including Senomy Insights, with visual redesign deferred. The exact bounded
scope, continuation rules and next step live in AUTOMATION_PROGRESS.md. Shared
Control Centre/Performance route navigation and deferred focus restoration now
have isolated regression coverage. Focus scrolling and selection/network review
Cancel-focus behavior also pass isolated fixtures. Bluetooth, notification clear,
display rollback and session preview focus are covered by extended fake-provider
fixtures (session compositor host substituted); full accessibility and physical acceptance
remain open. A detected Fcitx5 editor handoff now has mocked backend and UI
coverage; Fcitx5 is absent here, and OSK integration remains open. No schedule
or execution while the laptop is off is implied.

2026-10-06: selector informational commands now bypass runtime-directory creation
and handoff locking. `status`, `doctor` and `logs` must not create state or wait
behind a shell mutation. The isolated regression validator is
`bash scripts/validate-selector-readonly.sh`. This does not validate handoffs,
crash recovery or physical interaction. No QML publication, reload, service
restart, package installation or live compositor edit belongs to this stage.
