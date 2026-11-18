# Provider and command contracts

## Shared rules

Services own observed state; adapters own narrow provider operations; widgets
present projections. Missing optional commands/devices produce explicit
availability/errors and null fields. Do not impose one invented JSON envelope
on native QML objects: retain the existing schema/version of each adapter.
Shell collectors that use an envelope keep `schema_version`, availability,
source/observation time, data and bounded error explicit.

Never interpolate user/widget/network/file text into a shell command. Pass
literal argv and exact identifiers. Do not collect passwords, private environment,
unrestricted logs or saved Wi-Fi secrets. A request accepted, terminal opened or
profile name written is not evidence of a completed device operation.

| Domain | Authoritative provider / adapter ownership |
| --- | --- |
| CPU/RAM/network history | SystemMetrics/TelemetryHistory, bounded procfs counters and native connectivity |
| Expensive performance inventory/processes | PerformanceService and existing bounded script collectors, view-scoped |
| Audio | PipeWire/WirePlumber via AudioService/graph adapter and reviewed selection/graph actions |
| Power | UPower for pack facts; EnergyService/energy-provider and existing TLP owner; narrow protected battery-care helper |
| Network | NetworkManager native/profile/action interfaces; provider-owned secret agent/editor |
| Bluetooth | BlueZ native objects and controller/agent with exact object/owner lifetime |
| Displays/workspaces | Native Hyprland Lua API, display_core, shared DeviceInventory/draft/transaction services |
| Input | Native device inventory, typed Lua apply/readback/preview; separate XKB/IME/owned OSK capabilities |
| Media | Selected MPRIS player's reported metadata and advertised action/seek capabilities |
| Accounts | NSS metadata, optional AccountsService and login1 presence; normal polkit/PAM/passwd |
| Calendar | Independent same-UID private socket service, SQLite/iCalendar model and separately optional remote providers |
| Notifications | One observed native Quickshell server, bounded explicit serialized fields and reviewed bulk clear |
| Applications | Existing bounded catalogs, desktop-entry/GIO identity and independent launch-lifetime boundary |
| Diagnostics/reports | Allowlisted task/profile catalogs, bounded/redacted output and private destinations |
| Wiki | Bounded local Markdown parser, internal article IDs and explicit root selection |

## Action lifetime

Confirm exact target/context where required. Revalidate after provider replacement,
authentication delay or external changes. Preserve operation generations, bounded
deadlines, postcondition readback and stale-reply rejection. Cancellation of review,
backend cancellation and compensating rollback are different outcomes. Do not
blindly retry a mutation or claim timeout means cancellation.

Audio default selection waits for the observed PipeWire default node; stream/profile/
port operations retain exact identities and shared guards. Energy state comes from
the current TLP-backed owner rather than historical assumptions about PowerProfiles.
Profiles, charge thresholds and source changes remain separate facts. Network
association, credential availability and internet access are distinct.

Notification clear snapshots the retained ledger and active objects before review;
external membership changes require review again. Invoke/dismiss checks the current
object/action version. Storage success and in-memory-only failure are distinct.
Do not wake SwayNC/Dunst via a diagnostic read while Quickshell owns the server.

Package checks expose actual source/time/failure. No silent AUR network query or
installation. Reports preserve source/age, manifest/privacy and reviewed deletion.
Unrestricted command work uses a real PTY, never a generic shell field in a widget.

## Cost and privacy

Use native events, one session sampler and view-scoped detailed work. Bound history,
command output, file count/bytes and retry/backoff. Release obsolete observers on
provider/page/session lifetime as appropriate. Keep private stores 0700/0600;
never report a synthetic healthy zero when a collector is unavailable.
Current state/acceptance lives in [PROJECT_STATE](../PROJECT_STATE.md). The original
long source/command inventory is preserved in the [archive](../PROJECT_STATE.md).
