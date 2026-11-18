# SenomyOS native shell

Quickshell is the only maintained SenomyOS desktop frontend and native notification
owner. `shell.qml` composes Rails, one compact/full Control Centre workspace,
Performance, Insights and quick controls.

Read the root [README](../../README.MD), [working rules](../../AGENTS.md),
[current architecture](../../docs/ARCHITECTURE.md) and
[project state](../../docs/PROJECT_STATE.md). Runtime requirements are declared in
`deploy/packages.json`; source presence is not deployment or hardware acceptance.

Quickshell watches source files. Prepare coordinated changes in an isolated copy,
use inert providers and warn before runtime publication. Do not manually launch a
second live shell or a competing notification server. Read-only health:

```bash
scripts/senomy-shell status
scripts/senomy-shell doctor
```

Run commands above from the repository root. The existing native validation and
publication workflow is in [DEVELOPMENT](../../docs/DEVELOPMENT.md).
Early migration/state/benchmark checkpoints are preserved in the
[historical archive](../../docs/PROJECT_STATE.md); they are not current operating
instructions or evidence of present resource/lifecycle behaviour.
