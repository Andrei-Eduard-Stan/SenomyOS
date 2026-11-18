# Performance and Insights contracts

PerformanceDashboard and InsightsPanel retain separate identities and one shared
primary coordinator. Performance uses PerformanceWorkspaceWindow/Navigation with
the preserved searchable DirectoryModel tree; Insights uses its scoped
InsightsWorkspaceWindow/Navigation. Both use the Island frame.
Both reuse native appearance roles and existing placement/OSK, focus, modal and
export ownership. Insights retains attention-first Briefing, route-local filters,
exact task/result identity, explicit Run, report scope choices and narrow
list/detail reading. Performance has comparable overview histories, local resource
views and a roving process table with pinned narrow inspection/review. Search
retains ancestor paths; folder disclosure and exact resource leaves remain distinct.
Tabs and tree share view identity, and sidebar/drawer share query/expansion.
A process-view generation discards obsolete query results after preference changes;
reads wait for preference writes. Existing action/provider protocols remain owned
by their services.
The approved Overview and expanded Senomy artwork remain scoped references.

## Routes and data

Performance currently exposes Overview, CPU, GPU, Memory, Storage, Network,
Processes, Services, Diagnostics, Console, Reports and Benchmarks. Stable Insights
routes are Briefing, Notifications, Timeline, Updates, Diagnostics, Console,
Reports and Wiki. Detailed Power policy remains in Control Centre/Settings.

Use the shared session sampler/history and actual observation timestamps.
Performance projects 60s/5m/15m windows; source absence and gaps remain null, with
no joining across missing epochs. Frequency is GHz where projected as such;
disk active-time utilization is not transfer throughput. Inventory/process reads
retain separate ages and view-scoped cost. Sensor/device support is capability-
dependent; CPU TjMax display is not an invented safety threshold.

Briefing separates local assessment/attention from update-source evidence age.
Opening it never performs a repository check or installs packages. Keep meaningful
location, quiet selection and deliberate keyboard focus distinct. Charts/details
must remain readable at text scaling and constrained width with a visible
navigation drawer/close path. Unsupported GPU/DNS/SMART leaves report their limits
rather than fabricated zeroes or a generic healthy state.

## Actions and exports

Retain allowlisted process/service/diagnostic/benchmark and notification-clear
reviews. Services/process identity and ownership are rechecked before action.
Arbitrary commands run in a real PTY. Package discovery is an explicit read;
installation is a separately confirmed supported terminal/provider operation.

ComponentReportMenu exports the displayed bounded component payload: plain text,
clipboard via wl-copy, or native component snapshot. Destinations are private XDG
state, names/payload sizes/action IDs constrained, directory 0700/files 0600.
Missing clipboard or failed PNG/export is a visible failure. Close the menu before
grabbing the component. Exports preserve units, timestamps and unknowns; no upload
or unrestricted log collection occurs. Insights' broader evidence report service
retains its separate profile/manifest/privacy/deletion contract.

## Verification

Use the existing directory, Insights, Performance, navigation and export fixtures
with inert providers and isolated hosting. Actual native route content and export
boundaries matter more than mirrored implementation tests. Isolated rendering,
clipboard mocks and scope checks do not establish production grabs/focus, physical
input, output placement or hardware. Keep current evidence in
[PROJECT_STATE](../PROJECT_STATE.md), detailed receipts under `docs/qa/` and private
publication state. Earlier card-heavy Cathedral compositions are archived history.
