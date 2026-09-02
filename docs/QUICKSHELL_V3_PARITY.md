# Quickshell V3 functional parity and Eww retirement ledger

Status: Milestone 3 automated acceptance complete; physical input acceptance
pending, 2026-09-02.

`Migrated` means Quickshell owns the function in Quickshell mode. `Verified`
distinguishes automated/live evidence from interactions that still require a
person using real pointer or keyboard input. See `QUICKSHELL_V3_QA.md`.

## Functional parity

| Feature | Eww baseline | Quickshell implementation | Migrated | Verified |
|---|---|---|---:|---|
| Obsidian Rail | One 64px bottom Rail | One masked `RailWindow` per `Quickshell.screen`, same reserve | Yes | Live layer/reserve and virtual hotplug; physical click pass pending |
| Workspaces | Socket listener, JSON, Eww carousel | Native Hyprland monitor/workspace/toplevel objects, bounded animated viewport | Yes | Live state and overflow contract; physical activation/arrows pending |
| App indicators | Normalized client snapshot | Native toplevels, up to four icon-theme indicators per workspace | Yes | Live render; appear/remove/move manual pass pending |
| Audio | `pactl` listener and scripts | Shared native PipeWire sink/source graph, mute, sliders, default-device selection | Yes | Real source/sink state; physical slider/device pass pending |
| Network/Wi-Fi | NetworkManager listener and `nmcli` pages | Shared event-driven NetworkManager model, radio, scan, connect/disconnect | Yes | Real connected state/list; disruptive and secure-connect pass pending |
| Battery/dual pack | UPower shell JSON | Shared native UPower aggregate and per-pack model | Yes | Two real packs, energy-weighted 91.5% snapshot, AC/time/low state |
| Bluetooth | Conditional `bluetoothctl` collector | Shared native BlueZ adapter/devices; discovery only on Devices route | Yes | Real adapter/four visible devices and discovery shutdown; pair/connect pending |
| Media/MPRIS | `playerctl` companion snapshot | Shared multi-player native MPRIS state and controls | Yes | Truthful no-player state; playback controls need an active player |
| System tray | Eww host/flyout | Native StatusNotifier lifecycle, activation, secondary activation, scroll, attention and `QsMenuAnchor` menus | Yes | Model/lifecycle runtime; item, nested-menu and scroll manual pass pending |
| CPU/RAM/uptime/network rate | Script polls | Shared Level 1 in-process `/proc` reader | Yes | Live values; zero idle child PIDs |
| Clock/calendar | Minute polls and Eww flyout | `SystemClock` and native month popup/navigation | Yes | Standard/portrait/multi-output placement; outside/Escape/manual navigation pending |
| Notifications | SwayNC server/listener/history | Native Quickshell server, toast, bounded private history, actions, DND and dismissal | Yes | Isolated protocol suite and live ownership/rollback passed |
| Control Centre | Ten Eww routes | Ten native QML routes consuming shared services | Yes | Every route loaded live without warning; mutation/manual focus pass pending |
| Performance Dashboard | Conditional script dashboard | Seven native routes, bounded charts/processes and explicit benchmarks | Yes | Level 2 stop/cap and Level 3 plan/status passed; no benchmark executed |
| Senomy companion | Eww overlay and scripts | Native closed/compact/expanded overlay, dock/pin/timer and shared state | Yes | Live coexistence, side-by-side layout and source-loss cleanup; buttons pending |
| Senomy Insights | Eight Eww routes | Eight native routes with bounded source-owned adapters | Yes | All routes loaded; 16 allowlisted task contracts passed |
| Senomy reactive state | Domain-specific Eww variables | `SenomyState` derives shell, media, battery, network, health and notification attention | Yes | Real idle state observed; low/media/critical transitions need natural events |
| Power/session | Two-stage Eww panel | Native pending/cancel/confirm state over allowlisted session helper | Yes | All five actions requested/cancelled; destructive confirm deliberately not run |
| Popup/surface coordination | Eww `active_surface`/`active_flyout` | One `ShellState`: one primary, one popup, independent companion | Yes | Replacement, coexistence and hot-unplug passed; outside/Escape physical pass pending |
| Command Lens | External Rofi product surface | Source-owned external wrapper retained and launched from Applications | Yes | Contract passed; physical Rail launch pending |

## Eww retirement ledger

| Old Eww runtime component | Quickshell replacement | Needed during normal Quickshell use? | Retirement state |
|---|---|---:|---|
| `main-bar` and Rail widgets | `RailWindow.qml` and native islands | No | Replaced in Quickshell mode; preserve fallback source |
| `workspaces.service` and workspace widget | Native Hyprland objects | No | Service is stopped in Quickshell mode; manual interaction sign-off pending |
| Rail audio/network/battery/telemetry listeners | Shared native services | No | Replaced; legacy scripts remain for Eww recovery |
| Volume, tray, calendar, notification and power flyouts | Native popup components | No | Replaced; manual pointer details pending |
| Action/Control Centre | `ControlCentre.qml` | No | Replaced; no legacy window opens |
| Performance Dashboard | `PerformanceDashboard.qml` | No | Replaced; detailed scripts are bounded adapters, not Eww dependencies |
| Senomy companion and Insights | Native companion/Insights plus `SenomyState` | No | Replaced; existing assets and bounded data scripts retained |
| SwayNC notification ownership | `NotificationService.qml` in Quickshell mode | No | SwayNC is stopped in Quickshell mode and restored only with Eww |
| Command Lens | Existing Rofi wrapper | No | Intentionally external; it is not an Eww dependency |
| Eww daemon, startup script and fallback adapter | Recovery backend | Recovery only | Do not remove in Milestone 3 |

Normal Quickshell operation now has no Eww process, Eww user service,
`workspaces.service`, Eww listener, or SwayNC dependency. Eww remains the
unchanged login-time default and automatic recovery backend until a later,
explicit promotion milestone.
