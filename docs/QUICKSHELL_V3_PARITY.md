# Quickshell V3 functional parity ledger

Status: Milestone 3 entry audit, 2026-09-02.

This ledger compares the actively maintained Eww fallback with the live
Quickshell backend. `Migrated` means the function has a V2 implementation;
`Verified` means its real runtime behavior has passed the relevant acceptance
test. Neither column is satisfied by visual presence alone.

## Functional parity

| Feature | Current Eww behavior | Current Eww data/action source | Quickshell checkpoint status | V3 target | Migrated | Verified |
|---|---|---|---|---|---|---|
| Obsidian Rail | One bottom Rail with 64px reserve | `windows/main-bar.yuck`, frame assets, Eww layer shell | Native masked `PanelWindow` per screen | Preserve geometry; wire every visible control | Yes | Yes: layer/reserve |
| Workspace indicators | Active and occupied workspace islands | `workspaces.service`, `scripts/workspaces.sh` | Native Hyprland workspaces | Preserve active/occupied truth without polling | Yes | Partial: state only |
| Application indicators | Shows applications per workspace | Hyprland client snapshot normalized by `workspaces.sh` | Native workspace toplevels and icon lookup | Preserve multiple app indicators and fallbacks | Yes | Partial: visual |
| Workspace interaction | Activate workspace; bounded carousel | `hyprctl dispatch workspace`, Eww carousel state | Native activation and animated bounded viewport | Pointer, overflow arrows, active reveal, hotplug | Yes | Partial: manual input due |
| Audio summary | Volume/mute mark; volume flyout | PipeWire/Pulse listener and action scripts | Native default sink, volume, mute | Output/input, sliders, mute, default-node selection | Partial | Partial: mute/state |
| Network summary | SSID/signal/connectivity mark | NetworkManager event listener | Native `Quickshell.Networking` state | Shared state plus radio, scan/list, connect/disconnect | Partial | Yes: state only |
| Battery summary | Weighted aggregate and dual-pack detail | UPower collector and `battery.sh` | Native UPower aggregate | Shared aggregate/per-pack/AC/time/low state | Partial | Partial: aggregate |
| Dual battery | Energy-weighted BAT0/BAT1 behavior | `scripts/battery.sh`, UPower | Native device aggregation | Verify both present/absent and charging cases | Partial | No |
| Bluetooth | Adapter/devices, bounded scan, guarded actions | BlueZ through `bluetoothctl` scripts | Not represented | Native BlueZ model; scan only while page open | No | No |
| Media | Companion media summary | MPRIS through `playerctl` | Not represented | Native multi-player MPRIS state and controls | No | No |
| System tray | Inventory flyout and item actions | Eww tray/background-app collectors | Native StatusNotifier host and popup | Complete pointer/menu/nested/scroll/attention QA | Partial | Partial: lifecycle |
| CPU telemetry | Rail summary and dashboard history | `/proc/stat` scripts | In-process `/proc` reader every 2s | Share Level 1 value; bounded Level 2 history | Partial | Yes: Rail |
| RAM telemetry | Rail summary and dashboard history | `/proc/meminfo` scripts | In-process `/proc` reader every 2s | Share Level 1 value; bounded Level 2 history | Partial | Yes: Rail |
| Uptime | Rail summary | `/proc/uptime` script | In-process `/proc` reader every 2s | Shared readable duration | Yes | Yes |
| Clock/date | Live compact clock/date | `date` minute polls | Native `SystemClock` | Preserve live time/date and source-screen actions | Yes | Yes |
| Calendar | Anchored month popup and navigation | Eww flyout plus local calendar state | Native anchored popup/month model | Navigation, today, focus, outside/Escape, monitor QA | Partial | Partial |
| Notifications | SwayNC popups/count/history/actions | SwayNC DBus owner, client listener, private history hook | SwayNC remains sole owner; no V2 UI | Isolated native server, history, toast, actions, DND, rollback | No | No |
| Control Centre | Overview, Network, Audio, Power, Calendar, Input, Devices, Apps, Appearance, Settings | Conditional collectors and guarded action scripts | Not implemented | Native surface using shared services and bounded action adapters | No | No |
| Performance Dashboard | Overview, CPU, Memory, Storage, Network, Processes, Benchmarks | Conditional status/history/process scripts | Rail labels have no migrated dashboard | Native dashboard; Level 2 only while visible | No | No |
| Senomy companion | Closed/expanded/compact edge overlay, dock/pin, ambient state | Companion state/media/avatar scripts | Static Rail artwork/message only | Native overlay and central reactive `SenomyState` | No | No |
| Senomy Insights | Briefing, Notifications, Timeline, Updates, Diagnostics, Console, Reports, Wiki | Eww routes and bounded local scripts | Rail identity is non-functional | Native primary surface; retain useful bounded routes | No | No |
| Power/session panel | Guarded lock/suspend/logout/reboot/poweroff | Eww two-stage flyout/action coordinator | Allowlisted V2 backend only | Native two-stage UI; no automated destructive execution | Partial | Yes: dry-run backend |
| Popup dismissal | One flyout/primary owner with outside-dismiss layer | `surface-state.sh`, Eww dismiss window | Calendar/tray share a cancel-safe token/focus grab | Generalize to all V3 surfaces and source loss | Partial | Partial |
| Rail launcher actions | Applications opens Command Lens | Rofi wrapper/deployment | Direct `rofi -show drun` | Use verified Senomy Command Lens wrapper | Partial | No: manual input due |
| Command Lens | Bounded apps/files/actions UI in Rofi | `scripts/senomy-command-lens`, generated Rasi | External seam only | Keep external; launch through source-owned wrapper | Partial | Existing Eww-era contract |
| Legacy primary surfaces | Only one of control/performance/insights | Eww `active_surface` coordinator | Unavailable in Quickshell mode | Replace natively without opening Eww UI | No | No |
| Legacy compact surfaces | Volume, tray, calendar, notifications, power | Eww `active_flyout` coordinator | Calendar/tray only | Replace all natively | Partial | Partial |

## Milestone 3 acceptance states

Each row moves through:

1. `not-started`: no V3 implementation.
2. `implemented`: QML/service/action path exists and static validation passes.
3. `runtime`: live state and failure behavior are truthful.
4. `manual`: required real pointer/keyboard/touch acceptance is recorded.
5. `retirable`: Quickshell mode no longer needs the Eww component.

## Eww retirement ledger

| Old Eww component | Quickshell replacement | Legacy service still needed in Quickshell mode? | Verified? | Safe to retire? |
|---|---|---:|---:|---:|
| `main-bar` | `RailWindow.qml` | No | Yes | Quickshell mode only |
| `workspaces.service` and workspace widget | Native Hyprland workspace model | No | Partial | Not until manual workspace QA |
| Rail audio/network/battery/telemetry listeners | Shared native V3 services | No | Partial | Not until action/detail parity |
| Calendar flyout | Native `CalendarPopup.qml` | No | Partial | Not until dismissal/input QA |
| Tray flyout | Native StatusNotifier popup | No | Partial | Not until real menu QA |
| Volume flyout | Planned native audio popup | No | No | No |
| Notifications flyout and SwayNC listener | Planned native notification server/UI | SwayNC currently yes | No | No |
| Action Center / Control Centre | Planned native Control Centre | No after migration | No | No |
| Performance Dashboard | Planned native dashboard | No after migration | No | No |
| Senomy companion | Planned native companion overlay | No after migration | No | No |
| Senomy Insights | Planned native Insights primary surface | No after migration | No | No |
| Power flyout | Planned native guarded power popup | No after migration | No | No |
| Command Lens | Existing external Rofi product component | Not an Eww dependency | Existing contracts | Keep as external boundary |
| `scripts/start-eww.sh` and fallback adapter | Recovery-only Eww shell | Yes, recovery only | Yes | Do not retire in Milestone 3 |

At Milestone 3 entry, normal Quickshell use still lacks core surfaces but does
not load an Eww process. Eww remains necessary as the login-time and failure
fallback, and as the only functionally complete shell if the missing V3
surfaces are needed.
