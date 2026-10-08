# Final bounded functional regression — 2026-10-08

## Source corrections

Performance route flags/action context are owned once by shell.qml. Per-output
Dashboard instances only present state; creating/destroying an inactive peer
cannot overwrite the shared context. Service polling is limited to process/service
routes. Actual-view fixture creates/destroys a second output host and checks route/
output transitions. This substitutes the compositor host, not physical docking.

Report collectors use a forced deadline on their own read-only process group.
An initial TERM/grace implementation failed against a child that ignored TERM and
held its output pipe after the wrapper exited. The final fixed group kill passes
that regression. No unrelated/live process is targeted. Existing executable mode
is preserved. Actual Control Centre fixtures now include populated desktop views.

## Validation

All 12 combined suites passed, plus 6 Qt screen-lifecycle cases. Exact commands,
exit codes and result summaries are in validation.json. Backend mutations used
private XDG/report roots or fake providers. Managed OSK tests use disposable C
stubs, not real input. Existing session-policy/input checks retain their mocked
providers. No real signal, service restart, profile/default/autostart change,
terminal credential flow, lock, suspend, portal permission or OSK typing occurred.

Bash syntax and whole working-tree git diff --check pass. Source publication was
warned; Configuration Loaded 14:26:07, service active/running PID1373 unchanged,
Hyprland errors empty. Existing stackAfter and nonfatal metadata lint warnings
remain. Service health is not full live-action acceptance. The executable report
helper was checked after publication. No compositor file changes were made.

## Scope boundary

See ../../FUNCTIONAL_ACCEPTANCE_2026-10-08.md. Completed source work and these
fixtures do not certify a premium OS, all hardware or a deployable distribution.
Attended acceptance and prerequisite installation remain; automatic suspend stays
blocked on lock/recovery acceptance. Updates remain discovery-only. Visual work,
update installation and release tooling are outside this functional run.

Dirty existing consumers were preserved through zero-context patches and source
hashes; verify baseline hashes then use git apply --unidiff-zero. This is evidence
for this live tree, not clean-checkout reproducibility. No push was performed.
