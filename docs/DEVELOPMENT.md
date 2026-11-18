# SenomyOS development

## Begin a session

Work in the native source tree and read [AGENTS](../AGENTS.md). Inspect existing
work before choosing a change; use the current feature branch rather than
replaying a historical revival tutorial.

```bash
pwd
git rev-parse --show-toplevel
git branch --show-current
git status --short --branch
git diff
```

Read [PROJECT_STATE](PROJECT_STATE.md) and the relevant product, architecture,
design or [reference contract](reference/README.md). Explain file scope, effect
and verification. Preserve unrelated modified/untracked/deleted files. Never use
destructive Git cleanup or synchronize the historical/secondary checkout.

## Implement safely

Quickshell watches native source; coordinated runtime work belongs in an isolated
copy first. Use inert providers, private bus/XDG state and software/offscreen
hosting as appropriate. Never test real device mutations or attach quarantined
nested compositor runners to the desktop. Warn before watched publication,
reload/restart, process termination or live compositor changes.

Keep collector, presentation and mutation boundaries separate. Validate optional
providers and malformed/unavailable states. Use literal argv, exact identities,
bounded output, reviewed operations and observed postconditions. Arbitrary shell
work belongs in a terminal; secrets never pass through shell state.

## Validate the affected stage

| Change | Relevant verification |
| --- | --- |
| Any | `git diff --check`; inspect the actual task diff against its starting bytes |
| Bash | `bash -n` for every changed script |
| JSON collector/schema | `jq -e .` on actual output; error/absence cases where relevant |
| Native UI/service | Targeted existing fixtures, QML compile/lint and actual changed-component renders |
| Appearance | `python3 scripts/generate-appearance.py check` and applicable native projection/contract checks |
| Settings | Existing settings-host, routes, search, draft and provider fixtures |
| Telemetry | Existing session-telemetry checks; units, timestamps, gaps and single sampler ownership |
| Docs/Wiki | Relative links/anchors, existing Wiki parser, accurate commands and ownership |
| Deployment inventory | Existing isolated release tests and payload document selection |

The maintained broader aggregate is `bash scripts/validate-shell.sh`; `--live`
adds read-only shell health. Use it when the affected scope warrants it. It is
not required for a simple documentation edit.

UI work uses the [design-director workflow](DESIGN_INTELLIGENCE_GUIDE.md). Its
checker is `python3 .agents/skills/senomy-design-director/scripts/check_library.py`.
Keep provenance hashes honest: source drift requires review, not an automatic
approval/rebaseline. Keep new native publication preimages scoped.

## Review and publication

Inspect the task-specific diff and checks before a commit. Keep changes focused;
do not stage the entire dirty tree. No push without an explicit request.

Runtime publication needs the existing authorization and a warning about possible
Rail interruption. Verify the accepted source/patch, preimages, modes, installed
copies and application-lifetime guard before the action. Source-watching and a
service restart are different effects. Do not substitute either for the requested
operation. Check service, IPC, Rail count/reserve and notification ownership after
approved publication, and restore ordinary surface state after scoped UI checks.

Read-only diagnosis:

```bash
scripts/senomy-shell status
scripts/senomy-shell doctor
systemctl --user show senomy-quickshell.service -p ActiveState -p SubState -p MainPID
hyprctl configerrors
```



## Deployment and compositor configuration

Use existing plan/receipt-based tools; read the actual tool's help and
[deployment guide](../deploy/README.md) before a transaction. User config, root
system projection, release install/activation, process lifecycle and boot-path
activation are separate operations. Preserve exact preimages and reject later
source/target drift. Checksums identify bytes, not trusted authorship.

The tracked `hyprland.lua` and deployed `~/.config/hypr/hyprland.lua` must be
compared explicitly. The active provider is Lua; legacy monitor keywords/.conf
instructions are not substitutes. After an authorized change verify
`hyprctl configerrors` and intended byte parity. Do not edit either just to make
a documentation claim true. Read [display contracts](reference/DISPLAY_WORKSPACE_IMPLEMENTATION.md)
before output/workspace changes and [boot boundaries](reference/BOOT_SEQUENCE.md)
before bootloader, splash or greeter activation.

[Release and preference contracts](reference/RELEASE_DEPLOYMENT.md) retain
verified payload ownership, explicit migrations, CAS/atomic writes and separate
rollback meanings. The snapshot tool packages core and reference docs; moving
those files requires checking document selection. A staged clean root is not
cold-boot/installer acceptance.

## Recovery

Diagnose first using the read-only shell commands. An explicitly authorized
`scripts/senomy-shell restart` briefly removes Rails/panels and resets in-memory
history; retain the application-lifetime guard and exact installed-root checks.
Do not infer app survival from successful reboot/login or offscreen fixtures.

Normal-account TTY/administrator access, optional independent password recovery,
source rollback, deployed-file rollback and release rollback solve different
problems. Preserve existing recovery accounts/guards/preimages. Do not remove or
change authentication as documentation cleanup. See [recovery contracts](reference/RECOVERY.md).

## Keep documentation small

- README navigates; AGENTS sets work rules. The five core docs under `docs/`
  own product, architecture, design, workflow and current project state.
- Update the fact's owner. PROJECT_STATE is the sole progress/runtime/acceptance
  ledger; evidence stays in dated receipts, not copied into several plans.
- Technical references describe contracts, not another execution roadmap. Stable
  D/C/G/W IDs survive consolidation. Local component guides remain concise.
- When a rule changes, replace current guidance and retain necessary rationale in
  the owner. Archive superseded narratives; do not prepend corrections above
  executable obsolete instructions. Do not create another mandatory read list.
- Update links, the Wiki, skill references and release selection after relocation.
  Generate inventories when needed instead of maintaining parallel inventories.
