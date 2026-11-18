# SenomyOS repository instructions

## Start and authority

Develop SenomyOS in `/home/Duku/SenomyOS`, using Quickshell and Hyprland. Never use, modify,
delete or synchronize `/home/Duku/Projects/SenomyOS` without an explicit request.

Start with [README](README.MD) and [PROJECT_STATE](docs/PROJECT_STATE.md).
Before structural work, read the relevant owner:

- [PRODUCT_SPEC](docs/PRODUCT_SPEC.md): scope and portable hardware requirements.
- [ARCHITECTURE](docs/ARCHITECTURE.md): ownership, state and action boundaries.
- [DESIGN_SYSTEM](docs/DESIGN_SYSTEM.md): accepted visual and interaction rules.
- [DEVELOPMENT](docs/DEVELOPMENT.md): checks, publication and recovery.

[Reference contracts](docs/reference/README.md) are task-specific. Historical Git records are not operating instructions or standing authorization. Explicit current user instructions take precedence over local
guidelines. Preserve the scope of evidenced prior user decisions.

## Safety workflow

1. Inspect the repository root, branch, Git status and relevant diffs before edits.
2. Use `quickshell-v2` or a later feature branch; never push directly to `main`.
3. Preserve unrelated modified, deleted and untracked work. Do not bulk stage,
   clean, reset, reinitialize, clone or overwrite the working baseline.
4. Explain file scope and visible effect before editing.
5. Warn before publishing watched QML, reloading the compositor, restarting a
   service, stopping a process, or changing live device/session configuration.
   State whether the Rail or desktop could briefly disappear.
6. Inspection alone does not authorize reloads, restarts or device changes.
7. Show the diff and validation before any commit. Keep commits recoverable and
   focused. Never push unless the user explicitly asks.

Quickshell watches its source. Prepare coordinated runtime edits in an isolated
copy with inert providers; source edits can reload the shell without a service
restart. Never exercise real device mutations in tests. Quarantined nested
compositor runners remain disabled; do not rerun them as routine validation.

The tracked `hyprland.lua` and live `~/.config/hypr/hyprland.lua` are separate.
Compare before deliberate synchronization. `.conf` files are compatibility
history, not the active provider. Preserve current native transaction preimages unless the owner explicitly requests their removal.

## Product invariants

The [product contract](docs/PRODUCT_SPEC.md) owns surface roles and stable routes.
Preserve one primary state (`none|control|performance|insights`), shared compact/
full Control Centre content and edit guards, one transient quick popover that
may coexist with the primary, protected modal reviews and the independent
companion. Performance opens from telemetry; Insights opens from the adjacent
identity dialogue. Do not add a Performance tab to Control Centre or duplicate
character artwork in primary headers.

Use capability detection and profiles. Keep fixed usernames, home paths, monitor
IDs, battery/interface names and reference-machine geometry out of portable
runtime defaults. Support pointer, keyboard and touch; retain visible alternatives
to gestures. Do not claim universal hardware support.

## UI work

Read and apply [senomy-design-director](.agents/skills/senomy-design-director/SKILL.md)
before planning, implementing or refining native UI. Inspect relevant
[curated evidence](docs/design/design-intelligence/INDEX.md): study → compose →
critique → implement → capture → compare → refine. Inspect and critique the actual
changed native component before claiming visual completion. Missing renders stay
unverified. Preserve QML architecture, semantic roles, authored frames and guards.
Agent critique or a candidate render cannot grant user approval.
[Design-workflow usage](docs/DESIGN_INTELLIGENCE_GUIDE.md) remains available.

## Implementation and data

- Keep presentation, collection and system actions separate and modular.
- Keep the Rail usable through optional dependency/provider failure. Distinguish
  loading, empty, unavailable, stale, warning, running, succeeded and failed.
- Give icon controls useful targets, labels/tooltips and visible keyboard focus.
  Bound artwork decoding and use context-sized animated avatar assets.
- New shell scripts deliberately use Bash and `#!/usr/bin/env bash`; run `bash -n`.
  Prefer structured JSON from `jq`; validate changed collectors with `jq -e`.
- Return explicit availability/errors; never fabricate telemetry or action success.
  Use events and view-scoped expensive work; avoid duplicate samplers/polling.
- Never store Wi-Fi passwords, credentials, tokens, private environment values
  or unrestricted logs in shell state. Never interpolate widget text into commands.
- Preserve working dual-battery collection and known-good compositor compatibility
  unless a focused change has a clear reason and targeted verification.

Informational reads can run directly. Process/service termination or restart,
network disconnection, package installation, device changes and session/power
actions require explicit confirmation. Prefer graceful termination. Diagnostics
are allowlisted with bounded arguments/output; arbitrary work belongs in a real
terminal. Verify observed outcomes separately from accepted requests.

## Validation and documentation

Run checks appropriate to the change: `git diff --check`, changed Bash/JSON
validation, isolated native QML/fixture checks, then authorized runtime health.
After compositor edits check `hyprctl configerrors` and intended source/live byte
parity. After runtime publication verify service/IPC/notification ownership,
visible Rails and surface coordination. Do not run a broad live harness for a
documentation-only change.

Update the fact's single owner. PROJECT_STATE owns current delivery, runtime and
open acceptance; architecture/product/design owners carry current rules and short
rationale. Keep dated evidence in its receipt. Do not create parallel roadmaps,
append obsolete instructions below a correction, or treat archive checkboxes as
current completion. Maintain links and document-selection tooling when relocating
files. Preserve stable domain/contract/workflow IDs and source provenance.
