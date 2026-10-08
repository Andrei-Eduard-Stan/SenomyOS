# Insights requests, shared views and report boundary — 2026-10-08

InsightsRequests queues route changes rather than dropping requests while busy.
Results/loading/errors/timestamps are stored by route. Old evidence remains
identified by its observation time; cache reads do not imply fresh update checks.
Explicit read-only actions require current route and allowlisted task/profile.
JSON failure is never promoted to success by a zero helper exit. Tasks must match
requested ID and finish after request. Reports must match profile/time; update
results must confirm the requested source. Console's silent run is followed by
its bounded cached-result read even when the surface closes. No action starts
from opening a route. Legacy Eww action publication is disabled.

Shared InsightsTaskView/InsightsReportsView serve actual Diagnostics/Console/
Reports in both primary surfaces. All eight Insights routes remain. Populated
notifications/timeline/update/wiki controls retain keyboard reachability; the
primary window reuses keyboard navigation with its existing SurfaceButton style.
Unavailable update evidence is not displayed as zero known updates. Source check
time/provenance is visible, distinct from collector refresh time.

`python3 scripts/validate-insights-contract.py`: 11 behavioral policy tests plus
setup/cleanup (13 Qt cases), eight actual routes at 1120x820/720x500 with 24-row
lists, last-task keyboard activation, actual native Process adapter with private
helpers, and shared Performance views/focus at wide/constrained sizes. No real
provider actions. Compositor/window hosts are substituted; physical focus and
native notification acceptance remain open.

Report generation bounds each collector to 8 seconds (validated 1–15 override),
redacts sensitive-looking lines and controls, and caps line width. Manifest/path/
owner/mode/symlink checks protect preview/open/deletion; directory mode is 0700.
`python3 scripts/validate-report-boundary.py`: all five private fixture profiles,
redaction/modes, real fixture-process timeout and invalid/missing/outside/symlink/
permission manifest rejection. No live reports/providers are altered.

Bash syntax and targeted QML lint exit zero; existing metadata/unqualified warnings
remain. Zero-context integration patches require git apply --unidiff-zero only
after hash checks. Pre-existing unrelated consumer changes remain separate.
