# Managed user-service restart — 2026-10-08

Source: fixed allowlist of pipewire.service, pipewire-pulse.service and
wireplumber.service, user manager only. Snapshot hashes capture state, main PID,
invocation and state-change timestamp; confirmation rechecks before restarting.
Only a new active invocation produces succeeded; unchanged/failed state returns
unverified. Timeouts/errors never mean success. No arbitrary process argv replay.
Process restart is supported only for an owned allowlisted service main PID.
Unavailable, inactive, transitioning and non-startable/non-stoppable services are
read-only. Shell/compositor/network/system services cannot be restart targets.

Validation: `python3 scripts/validate-managed-services.py`: 11 mocked backend
cases, six restart-controller behaviors plus setup/cleanup (8 Qt cases), actual
Dashboard route fixture at 1580x820/900x600, and actual PerformanceService guards.
All twelve process rows are keyboard reachable. Service/terminate reviews focus
Cancel. Route closing/replacement invalidates process reviews; restart/terminate
reviews cannot overlap. No fake-provider mutations in route/focus tests.
Read-only native catalog reports PipeWire/WirePlumber active and Pulse inactive.
No real restart, process termination or benchmark performed.

Diagnostics/Console/Reports currently have explicit exclusive-primary handoffs
to the existing eight-route Insights runner. Shared inline runner/report parity
remains the next source stage, not claimed complete by these handoffs.
Physical provider/audio acceptance and portrait layout remain open. Existing
nonfatal QML lint warnings remain; lint exits zero. Integration patches preserve
pre-existing dirty consumer files; clean-checkout reproducibility remains open.

Warned source publication reports Configuration Loaded at 13:29:24.
Quickshell active/running PID1373; compositor configerrors empty; existing stacking
warning remains. This is runtime health evidence, not real action acceptance.

Integration patches use zero context; replay requires git apply --unidiff-zero
after checking before/after hashes. This avoids whitespace-only patch context.
