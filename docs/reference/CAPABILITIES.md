# Capability and identifier reference

This catalog preserves the 20 domains and individual capability IDs/purposes
from the 25 October audit. It defines vocabulary and relationships, not current
support, a second backlog or authorization to implement optional features.
Current evidence, priorities and remaining acceptance live only in
[PROJECT_STATE](../PROJECT_STATE.md). Proposed standards and workflow expectations
are in [contracts](ACCEPTANCE_CONTRACTS.md) and [workflows](WORKFLOW_TESTS.md).

<a id="domain-01"></a>

## D01 — Obsidian Rail

**User entry:** Per-output Rail; workspace islands, persona, system controls, clock and session controls.

**Components:** [shell/quickshell/components/RailWindow.qml](../../shell/quickshell/components/RailWindow.qml), [shell/quickshell/components/WorkspaceRail.qml](../../shell/quickshell/components/WorkspaceRail.qml), [shell/quickshell/components/SystemControlsIsland.qml](../../shell/quickshell/components/SystemControlsIsland.qml), [shell/quickshell/config/RailStyle.qml](../../shell/quickshell/config/RailStyle.qml).

**Backend and dependencies:** Quickshell screens; native Hyprland, PipeWire, NetworkManager, UPower and StatusNotifier; shared services.

**Tests:** [scripts/validate-interactions.py](../../scripts/validate-interactions.py), [scripts/validate-rail-revision.sh](../../scripts/validate-rail-revision.sh), [scripts/validate-rail-tray.py](../../scripts/validate-rail-tray.py).

**Related:** D02, D09, D11, D16, D19, D20; G01, G07, G21.

| Capability ID / name | Intended purpose / operation |
| --- | --- |
| D01.01 Per-monitor creation and reservation | Enumerate screens; one Rail per screen; reserve work area |
| D01.02 Workspace display and paging | Native monitor-filtered workspaces, local labels, overflow paging, keyboard activation |
| D01.03 Quick controls and Settings | Open Lens, audio, network, Bluetooth, battery, calendar, tray, notifications, session and Settings |
| D01.04 Clock and telemetry indicators | Local clock; CPU/RAM/uptime; provider-owned status |
| D01.05 Tray integration | StatusNotifier items, activation, contextual menus and attention/passive states |
| D01.06 Visibility configuration | Per-output Rail visibility and external workspace indicator policy |
| D01.07 Ordering, module toggles and context editing | Fixed Rail composition and responsive thresholds |
| D01.08 Senomy and Insights access | Expanded Island and separate briefing routes; independent companion removed by owner |

<a id="domain-02"></a>

## D02 — Quick popovers and panel management

**User entry:** All Rail quick controls; ShellState; compact/full Settings.

**Components:** [shell/quickshell/services/ShellState.qml](../../shell/quickshell/services/ShellState.qml), [shell/quickshell/components/interaction/QuickPopoverWindow.qml](../../shell/quickshell/components/interaction/QuickPopoverWindow.qml), [shell/quickshell/components/DashboardWindow.qml](../../shell/quickshell/components/DashboardWindow.qml), [shell/quickshell/services/ScreenLifecycle.js](../../shell/quickshell/services/ScreenLifecycle.js).

**Backend and dependencies:** One shell-owned primary state and popup token/generation; Qt focus; native popup host and Hyprland focus grab.

**Tests:** [scripts/validate-interactions.py](../../scripts/validate-interactions.py), [scripts/validate-settings-host.py](../../scripts/validate-settings-host.py), [shell/quickshell/tests/tst_ControlNavigation.qml](../../shell/quickshell/tests/tst_ControlNavigation.qml), [shell/quickshell/tests/tst_ScreenLifecycle.qml](../../shell/quickshell/tests/tst_ScreenLifecycle.qml).

**Related:** D01, D19, D20; G07, G22, G36.

| Capability ID / name | Intended purpose / operation |
| --- | --- |
| D02.01 Open, toggle and switch | One primary; one transient token with opening lease; quick popup may coexist with primary |
| D02.02 Dismiss and keyboard priority | Escape innermost-first, outside dismissal, keyboard acquisition and trigger focus return |
| D02.03 Rapid input and stale callbacks | Generation checks, immediate replacement unmap, token-owned close |
| D02.04 Pending operation protection | Modal confirmations, dirty-draft deferred navigation, context invalidation |
| D02.05 Multi-monitor anchoring and removal | Screen-bound anchors and source-output reconciliation |
| D02.06 Nested tray and calendar menus | Shared popup hosting plus domain-specific inner menus |
| D02.07 Screenshot pause/recovery | Token-owned temporary unmap; ten-minute recovery timer |

<a id="domain-03"></a>

## D03 — Command Lens

**User entry:** Rail launcher; Super+R; Applications scopes.

**Components:** [shell/quickshell/components/lens/CommandLensPopup.qml](../../shell/quickshell/components/lens/CommandLensPopup.qml), [shell/quickshell/components/lens/LensProvider.qml](../../shell/quickshell/components/lens/LensProvider.qml), [shell/quickshell/components/lens/LensSearch.js](../../shell/quickshell/components/lens/LensSearch.js), [components/launcher/rofi/scripts/senomy-rofi-files](../../components/launcher/rofi/scripts/senomy-rofi-files), [components/launcher/rofi/scripts/senomy-rofi-actions](../../components/launcher/rofi/scripts/senomy-rofi-actions).

**Backend and dependencies:** Native DesktopEntries/Hyprland toplevels; bounded file cache and action helpers; fixed argv.

**Tests:** [scripts/validate-native-command-lens.py](../../scripts/validate-native-command-lens.py), [scripts/validate-command-lens-quality.py](../../scripts/validate-command-lens-quality.py), [scripts/validate-command-lens.sh](../../scripts/validate-command-lens.sh).

**Related:** D01, D02, D13, D19; G01, G08, G09.

| Capability ID / name | Intended purpose / operation |
| --- | --- |
| D03.01 App and window discovery | Native desktop-entry catalog; native toplevel title/class/workspace; direct window focus |
| D03.02 Search relevance | Exact/prefix/word/substring/token/fuzzy subsequence ranking; deduplication and category scopes |
| D03.03 Files and folders | Configured home-relative roots, bounded depth/results/time, open/reveal, permission and symlink checks |
| D03.04 Safe actions and deep links | Allowlisted actions and Settings task routes; no arbitrary shell query |
| D03.05 Keyboard and stable geometry | Selection, scope changes, activation; height independent of result count |
| D03.06 Index freshness and stale results | 30-second cache freshness, generation/session/revision guards and refresh |
| D03.07 Activation failure feedback | Apps/windows dismiss before execute; exceptions only logged |
| D03.08 Recent, favourite and history results | No synthetic recents; no persistent Lens favourites/history |
| D03.09 Existing app window reuse | Window results focus existing windows; app results launch desktop entry |

<a id="domain-04"></a>

## D04 — Network and Wi-Fi

**User entry:** Network quick popup; Settings network/wifi, saved, advanced.

**Components:** [shell/quickshell/services/NetworkService.qml](../../shell/quickshell/services/NetworkService.qml), [shell/quickshell/services/NetworkActions.qml](../../shell/quickshell/services/NetworkActions.qml), [shell/quickshell/services/ConnectionAttempt.qml](../../shell/quickshell/services/ConnectionAttempt.qml), [shell/quickshell/services/NetworkProfiles.qml](../../shell/quickshell/services/NetworkProfiles.qml), [shell/quickshell/scripts/network-profiles.py](../../shell/quickshell/scripts/network-profiles.py), [shell/quickshell/components/NetworkProfilesView.qml](../../shell/quickshell/components/NetworkProfilesView.qml).

**Backend and dependencies:** Native Quickshell NetworkManager; nmcli; nm-connection-editor; Kitty credential TTY; NM VPN plugins.

**Tests:** [shell/quickshell/tests/tst_NetworkActions.qml](../../shell/quickshell/tests/tst_NetworkActions.qml), [shell/quickshell/tests/tst_ConnectionAttempt.qml](../../shell/quickshell/tests/tst_ConnectionAttempt.qml), [shell/quickshell/tests/test_network_profiles.py](../../shell/quickshell/tests/test_network_profiles.py), [shell/quickshell/tests/tst_ProfileActions.qml](../../shell/quickshell/tests/tst_ProfileActions.qml).

**Related:** D02, D13, D19; G10, G11, G12.

| Capability ID / name | Intended purpose / operation |
| --- | --- |
| D04.01 Detection and connectivity | Managed wired/Wi-Fi adapters, radio/hardware state, link and connectivity classification |
| D04.02 Wi-Fi scan | Explicit ten-second scanner ownership and release on route/radio loss |
| D04.03 Connect and authentication | Saved/open activation; secured unknown network handed to nmcli --ask in Kitty |
| D04.04 Disable and disconnect | Exact-target preview, revalidation, observed completion and timeout |
| D04.05 Saved profile management | List wired/Wi-Fi/VPN/WireGuard; forget inactive, disconnect, toggle autoconnect |
| D04.06 Advanced configuration | Delegate profile edits, VPN setup, DNS, IPv4/6, static/DHCP and PAC to native editor |
| D04.07 VPN daily activation | Catalog and native VPN editor; no direct profile activation verb |
| D04.08 Captive portal and proxy feedback | Connectivity enum surfaced; editor describes PAC/application-wide limits |
| D04.09 Airplane mode and restart | Wi-Fi radio gate plus separate Bluetooth controls; no unified airplane or NM restart UI |

<a id="domain-05"></a>

## D05 — Bluetooth

**User entry:** Bluetooth quick popup; Settings devices/bluetooth; Overview/Manage/Details inspector.

**Components:** [shell/quickshell/services/BluetoothService.qml](../../shell/quickshell/services/BluetoothService.qml), [shell/quickshell/services/BluetoothActions.qml](../../shell/quickshell/services/BluetoothActions.qml), [shell/quickshell/scripts/bluetooth-controller.py](../../shell/quickshell/scripts/bluetooth-controller.py), [shell/quickshell/scripts/bluetooth_model.py](../../shell/quickshell/scripts/bluetooth_model.py), [shell/quickshell/components/bluetooth/BluetoothInspector.qml](../../shell/quickshell/components/bluetooth/BluetoothInspector.qml).

**Backend and dependencies:** One private Gio system-bus connection; BlueZ ObjectManager, Adapter1, Device1, Agent1 and optional Battery1.

**Tests:** [shell/quickshell/tests/test_bluetooth_model.py](../../shell/quickshell/tests/test_bluetooth_model.py), [shell/quickshell/tests/test_bluetooth_dbus.py](../../shell/quickshell/tests/test_bluetooth_dbus.py), [scripts/validate-bluetooth.py](../../scripts/validate-bluetooth.py).

**Related:** D04, D06, D12, D20; G13, G14.

| Capability ID / name | Intended purpose / operation |
| --- | --- |
| D05.01 Adapters and bounded discovery | Select/power adapter; own 30-second scan; stop own discovery |
| D05.02 Pairing and authentication | KeyboardDisplay agent, PIN/passkey/confirmation prompts, rejection and timeout |
| D05.03 Connect/disconnect/retry | Per-device operations with native error details and observed state |
| D05.04 Cancellation and recovery | Cancel Pair via CancelPairing; cancel Connect via Disconnect; bounded cleanup/deadlines |
| D05.05 Trust/block/alias/removal | Reviewed trust/untrust/block/unblock/rename/reset/forget/unpaired cache removal |
| D05.06 Wake and discoverability | Capability-gated WakeAllowed and bounded pairable/discoverable timeouts |
| D05.07 Battery, services and diagnostics | Optional battery, services/properties/search, redacted report and remote disconnect reason |
| D05.08 Audio handoff | Link matching Bluetooth card to audio routes/profiles when available |
| D05.09 Resume and real device reliability | Owner-change reconciliation exists; no new physical suspend/reconnect test |

<a id="domain-06"></a>

## D06 — Audio and media

**User entry:** Audio quick popup; full Audio overview/mixer/devices/media/diagnostics; Bluetooth inspector handoff.

**Components:** [shell/quickshell/services/AudioService.qml](../../shell/quickshell/services/AudioService.qml), [shell/quickshell/services/AudioGraphActions.qml](../../shell/quickshell/services/AudioGraphActions.qml), [shell/quickshell/scripts/audio-graph.py](../../shell/quickshell/scripts/audio-graph.py), [shell/quickshell/scripts/audio-preferences.py](../../shell/quickshell/scripts/audio-preferences.py), [shell/quickshell/services/MediaService.qml](../../shell/quickshell/services/MediaService.qml), [shell/quickshell/components/audio/AudioMixerPage.qml](../../shell/quickshell/components/audio/AudioMixerPage.qml).

**Backend and dependencies:** Native PipeWire nodes/links; WirePlumber default policy; pw-dump watch, wpctl, pw-metadata; MPRIS.

**Tests:** [shell/quickshell/tests/test_audio_graph.py](../../shell/quickshell/tests/test_audio_graph.py), [shell/quickshell/tests/tst_AudioGraphActions.qml](../../shell/quickshell/tests/tst_AudioGraphActions.qml), [shell/quickshell/tests/tst_SelectionActions.qml](../../shell/quickshell/tests/tst_SelectionActions.qml), [scripts/validate-audio-revamp.py](../../scripts/validate-audio-revamp.py).

**Related:** D05, D11, D13, D17; G14, G15, G16.

| Capability ID / name | Intended purpose / operation |
| --- | --- |
| D06.01 Output/input gain and mute | Default device and per-node gain/mute; bounded amplification preference |
| D06.02 Default endpoint switching | Reviewed output/input selection with live membership and observed default |
| D06.03 Playback and recording streams | Discover active streams; app search, per-stream volume/mute; recording activity |
| D06.04 Stream routing | Reviewed stream move with provider cookie/serial/revision and observed links |
| D06.05 Profiles, ports and stereo balance | Capability-derived card profile/route selection and native channel balance |
| D06.06 Remembered application routes | Persist/forget up to 32 explicit endpoint-name hints and reviewed USE SAVED ROUTE |
| D06.07 Hotplug and provider errors | Native node tracking; graph watch only on relevant surfaces; retry by reopen |
| D06.08 Media session controls | MPRIS player selection, transport, seek, shuffle and loop capability gates |
| D06.09 Default restoration and Bluetooth audio | WirePlumber preferred default; Bluetooth card matching and Settings route |

<a id="domain-07"></a>

## D07 — Power, battery and session controls

**User entry:** Battery popup; Settings power; session popup Now/In/At; Settings idle.

**Components:** [shell/quickshell/services/BatteryService.qml](../../shell/quickshell/services/BatteryService.qml), [shell/quickshell/services/PowerService.qml](../../shell/quickshell/services/PowerService.qml), [shell/quickshell/scripts/session-scheduler.py](../../shell/quickshell/scripts/session-scheduler.py), [shell/quickshell/scripts/session-policy.py](../../shell/quickshell/scripts/session-policy.py), [scripts/senomy-session-action](../../scripts/senomy-session-action), [components/idle/hypridle.conf](../../components/idle/hypridle.conf).

**Backend and dependencies:** native UPower; shared EnergyService/Gio adapter to existing TLP or an already-owned compatible profile API; logind; existing session scheduler/manual actions; optional Hypridle remains inactive by user policy.

**Tests:** [shell/quickshell/tests/test_session_scheduler.py](../../shell/quickshell/tests/test_session_scheduler.py), [shell/quickshell/tests/test_session_policy.py](../../shell/quickshell/tests/test_session_policy.py), [shell/quickshell/tests/tst_SelectionActions.qml](../../shell/quickshell/tests/tst_SelectionActions.qml), [scripts/validate-session-scheduler.py](../../scripts/validate-session-scheduler.py).

**Related:** D05, D14, D18; G02, G03, G17, G18, G19.

| Capability ID / name | Intended purpose / operation |
| --- | --- |
| D07.01 Dual-battery status | Shared UPower energy-weighted estimate and independent pack state |
| D07.02 Health and thresholds | Per-pack drafts, reviewed TLP Apply/Restore, runtime/persistent settings and source diagnostics |
| D07.03 Power profiles | Reviewed TLP/compatible D-Bus profile operation with readback |
| D07.04 Session Now/In/At | Review lock/suspend/logout/reboot/poweroff; schedule/cancel/replace via durable one-shot receipts |
| D07.05 Inhibitors and policy | Bounded scoped logind inhibitor inspection in full Power Settings |
| D07.06 Hibernate/hybrid sleep | No unsupported controls exposed |
| D07.07 Automatic idle lock/display off | Optional future policy proposal, activation separate |
| D07.08 Lid policy | Actual logind/compositor/input ownership |
| D07.09 Suspend/resume and failure recovery | Capability checks, lock-before-sleep config and service restarts |

<a id="domain-08"></a>

## D08 — Displays and multi-monitor management

**User entry:** Settings devices/displays, projection, profiles, recovery and identify.

**Components:** [shell/quickshell/components/DisplaySettings.qml](../../shell/quickshell/components/DisplaySettings.qml), [shell/quickshell/components/DisplayCanvas.qml](../../shell/quickshell/components/DisplayCanvas.qml), [shell/quickshell/services/DisplayDraft.qml](../../shell/quickshell/services/DisplayDraft.qml), [shell/quickshell/services/DisplayActions.qml](../../shell/quickshell/services/DisplayActions.qml), [shell/quickshell/scripts/display_core.py](../../shell/quickshell/scripts/display_core.py).

**Backend and dependencies:** Hyprland 0.56.2 Lua eval; display identity store and topology journal; independent watchdog; native monitor readback.

**Tests:** [shell/quickshell/tests/test_display_action.py](../../shell/quickshell/tests/test_display_action.py), [shell/quickshell/tests/tst_DisplayActions.qml](../../shell/quickshell/tests/tst_DisplayActions.qml), [shell/quickshell/tests/tst_DisplayCanvas.qml](../../shell/quickshell/tests/tst_DisplayCanvas.qml), [scripts/validate-display-auto-recovery.py](../../scripts/validate-display-auto-recovery.py).

**Related:** D01, D02, D09, D18; G04, G20, G23.

| Capability ID / name | Intended purpose / operation |
| --- | --- |
| D08.01 Detection and identity | All connected/disabled outputs, stable key/number, strong identity where available |
| D08.02 Identify and primary policy | Identify overlays and preferred primary/workspace home |
| D08.03 Arrangement and logical geometry | Whole-topology draft; drag/select/numeric coordinates; centres, negative/gapped layouts, rotation and scaling |
| D08.04 Projection | Extend, native duplicate/mirror, PC-only and chosen external group only |
| D08.05 Apply/preview/revert | Arm independent recovery before mutation, serialize, read back topology, token/deadline Keep/Revert |
| D08.06 Profiles and persistent intent | Named profiles, saved layout, identity matching, editor draft and bounded startup restore |
| D08.07 Fallback recovery | Opt-in autoRecovery, severe low-mode detection, debounce/cooldown/caps, confirmed layout only |
| D08.08 HDR/VRR/colour and bandwidth | No universal advanced control panel; requested modes must be advertised and accepted |
| D08.09 Docking and last-known-good recovery | Event refresh, bounded restore and independent compensating rollback |

<a id="domain-09"></a>

## D09 — Workspaces and window management

**User entry:** Rail workspace islands; display workspace page; compositor shortcuts.

**Components:** [shell/quickshell/components/WorkspaceRail.qml](../../shell/quickshell/components/WorkspaceRail.qml), [shell/quickshell/components/WorkspaceChip.qml](../../shell/quickshell/components/WorkspaceChip.qml), [shell/quickshell/components/DisplayWorkspaces.qml](../../shell/quickshell/components/DisplayWorkspaces.qml), [shell/quickshell/services/DeviceInventory.qml](../../shell/quickshell/services/DeviceInventory.qml), [shell/quickshell/scripts/display_core.py](../../shell/quickshell/scripts/display_core.py), [hyprland.lua](../../hyprland.lua).

**Backend and dependencies:** Native Hyprland global workspace IDs; persisted monitor-local slot metadata; event reconciliation and Lua dispatcher results.

**Tests:** [shell/quickshell/tests/test_display_action.py](../../shell/quickshell/tests/test_display_action.py), [shell/quickshell/tests/tst_DisplayCanvas.qml](../../shell/quickshell/tests/tst_DisplayCanvas.qml), [shell/quickshell/tests/tst_ScreenLifecycle.qml](../../shell/quickshell/tests/tst_ScreenLifecycle.qml).

**Related:** D01, D08, D18; G04, G20, G24.

| Capability ID / name | Intended purpose / operation |
| --- | --- |
| D09.01 Dynamic create/destroy | Explicit create/switch; compositor removes empty groups; render snapshots update metadata only |
| D09.02 Independent local numbering | Separate native IDs per monitor with monitor-local labels and shortcuts |
| D09.03 Active/occupied and Rail synchronization | Native monitor active workspace, occupancy and debounced raw events |
| D09.04 Persistence, names and placement | Saved slot metadata, explicit persistent rules, rename, main/home policy |
| D09.05 Move workspaces/windows | Exact identity/source checks; Lua move/focus and observed readback |
| D09.06 Floating/fullscreen and application rules | Native compositor shortcuts/rules plus fullscreen wrapper |
| D09.07 Monitor removal and guest policy | Preserve surviving groups; avoid recreating old empty active workspaces |
| D09.08 Named/special workspace visibility | Rail filters id > 0 |

<a id="domain-10"></a>

## D10 — Calendar, events, notes and reminders

**User entry:** Clock quick calendar; full Calendar month/week/day/agenda/briefing/accounts/transfer/reminders.

**Components:** [components/calendar/senomy_calendar/engine.py](../../components/calendar/senomy_calendar/engine.py), [components/calendar/senomy_calendar/store.py](../../components/calendar/senomy_calendar/store.py), [components/calendar/senomy_calendar/reminders.py](../../components/calendar/senomy_calendar/reminders.py), [components/calendar/senomy_calendar/remote.py](../../components/calendar/senomy_calendar/remote.py), [components/calendar/senomy_calendar/daemon.py](../../components/calendar/senomy_calendar/daemon.py), [shell/quickshell/services/calendar/CalendarService.qml](../../shell/quickshell/services/calendar/CalendarService.qml), [shell/quickshell/components/control/ControlCalendarPage.qml](../../shell/quickshell/components/control/ControlCalendarPage.qml).

**Backend and dependencies:** Private same-UID socket; SQLite/WAL; canonical ICS; recurrence library; native notifications; optional HTTPS CalDAV and Secret Service.

**Tests:** [components/calendar/tests/test_engine.py](../../components/calendar/tests/test_engine.py), [components/calendar/tests/test_bulk_notes.py](../../components/calendar/tests/test_bulk_notes.py), [components/calendar/tests/test_remote.py](../../components/calendar/tests/test_remote.py), [components/calendar/tests/test_reminders.py](../../components/calendar/tests/test_reminders.py), [scripts/validate-calendar-organizer.py](../../scripts/validate-calendar-organizer.py).

**Related:** D02, D11, D14, D19; G25, G26, G27.

| Capability ID / name | Intended purpose / operation |
| --- | --- |
| D10.01 Date navigation and views | Month/week/day, selected-day popup, Today, bounded agenda and 7/30/90-day briefing |
| D10.02 Event CRUD and notes | Create/edit/delete, dated plain-text notes, reviewed delete and revision conflict checks |
| D10.03 Recurrence/timezones/all day | Daily/weekly/monthly/yearly; occurrence exceptions, DST validation, exclusive ICS end |
| D10.04 Import/export and bulk add | Reviewed ICS files and atomic CSV/TSV/paste batches; stable UID deduplication |
| D10.05 Persistence and draft recovery | Private schema-1 SQLite, receipts, backups, optimistic revision and durable draft |
| D10.06 Reminders | Thirty-second independent scheduler, DISPLAY alarms, snooze/dismiss and uncertain delivery persistence |
| D10.07 CalDAV manual sync | Explicit collection URL, reviewed two-way conditional writes, conflicts/offline queue and secret-tool |
| D10.08 Account discovery/OAuth/invitations | No automatic sync, collection discovery, OAuth or RSVP service |
| D10.09 System timezone/NTP | Calendar display-zone preference only |

<a id="domain-11"></a>

## D11 — Notifications

**User entry:** Notification quick centre; Insights notifications; Settings DND.

**Components:** [shell/quickshell/services/NotificationService.qml](../../shell/quickshell/services/NotificationService.qml), [shell/quickshell/services/NotificationClearActions.qml](../../shell/quickshell/services/NotificationClearActions.qml), [shell/quickshell/scripts/notification-owner.py](../../shell/quickshell/scripts/notification-owner.py), [shell/quickshell/components/NotificationCenter.qml](../../shell/quickshell/components/NotificationCenter.qml), [shell/quickshell/components/notifications/NotificationList.qml](../../shell/quickshell/components/notifications/NotificationList.qml).

**Backend and dependencies:** One native org.freedesktop.Notifications owner; private bounded JSON history; native tracked actions and timers.

**Tests:** [scripts/validate-quickshell-notifications.sh](../../scripts/validate-quickshell-notifications.sh), [shell/quickshell/tests/tst_NotificationClearActions.qml](../../shell/quickshell/tests/tst_NotificationClearActions.qml), [scripts/validate-notification-selection.py](../../scripts/validate-notification-selection.py).

**Related:** D01, D02, D10, D19; G28, G29.

| Capability ID / name | Intended purpose / operation |
| --- | --- |
| D11.01 Reception and ownership | Native server with owner-PID observer; replacement/supersession handling |
| D11.02 History and read state | Up to 120 persisted nontransient records, unread per version and Read all |
| D11.03 Dismiss and reviewed bulk clear | Individual dismissal; exact history/active snapshot review; save success/failure distinction |
| D11.04 Actions and attribution | Only live current-object actions; stale retained actions unavailable; app/title/urgency |
| D11.05 DND and expiration | Persisted global toast suppression; critical notifications do not expire automatically |
| D11.06 Per-application rules, sound and grouping | No provider-owned per-app preference/group/archive-search model |
| D11.07 Multi-monitor toast targeting | Toast instance tied to first Quickshell screen |
| D11.08 Restart retention of application actions | Saved records intentionally omit live action objects |

<a id="domain-12"></a>

## D12 — Input and devices

**User entry:** Settings input pointer/keyboard/methods; device inventory; OSK shortcut.

**Components:** [shell/quickshell/services/InputSettings.qml](../../shell/quickshell/services/InputSettings.qml), [shell/quickshell/scripts/input-settings.py](../../shell/quickshell/scripts/input-settings.py), [shell/quickshell/services/OskController.qml](../../shell/quickshell/services/OskController.qml), [shell/quickshell/services/OskAdapter.qml](../../shell/quickshell/services/OskAdapter.qml), [shell/quickshell/scripts/osk-capabilities.py](../../shell/quickshell/scripts/osk-capabilities.py), [shell/quickshell/scripts/native-input-tools.py](../../shell/quickshell/scripts/native-input-tools.py), [shell/quickshell/scripts/device-inventory.py](../../shell/quickshell/scripts/device-inventory.py), [components/input/osk/README.md](../../components/input/osk/README.md).

**Backend and dependencies:** Hyprland input options/XKB catalog; optional Fcitx5; supported wvkbd build and compositor protocol/plugin; sysfs/native inventory.

**Tests:** [shell/quickshell/tests/test_input_settings.py](../../shell/quickshell/tests/test_input_settings.py), [shell/quickshell/tests/test_osk_capabilities.py](../../shell/quickshell/tests/test_osk_capabilities.py), [shell/quickshell/tests/tst_OskController.qml](../../shell/quickshell/tests/tst_OskController.qml), [shell/quickshell/tests/test_native_input_tools.py](../../shell/quickshell/tests/test_native_input_tools.py).

**Related:** D05, D06, D08, D14, D20; G03, G30, G31.

| Capability ID / name | Intended purpose / operation |
| --- | --- |
| D12.01 Device detection | Keyboard/pointer/touch/tablet/switch inventory with bounded names/layouts |
| D12.02 Layout, repeat and pointer apply | Typed global preview/confirm, layout/variant/fallback/repeat/pointer/touchpad preferences |
| D12.03 Input external-state reconciliation | Observe runtime separately from draft/saved intent; invalidate stale requests |
| D12.04 OSK manual management | Capability discovery, fixed provider exec, guarded signals, geometry/avoidance and Caps Lock sync |
| D12.05 Automatic OSK | Optional compositor text-focus integration and policy |
| D12.06 IME handoff | Optional fixed Fcitx5 settings launch |
| D12.07 Per-device acceleration/gestures/remapping | Some compositor defaults and shortcuts exist; no full native editor |
| D12.08 Camera/mic/USB/printer/scanner | Audio owns mic; four video device nodes observed; general device UI limited |

<a id="domain-13"></a>

## D13 — Applications and desktop integration

**User entry:** Lens; Settings apps defaults/autostart; tray; Thunar; desktop capability cards.

**Components:** [shell/quickshell/scripts/desktop-settings.py](../../shell/quickshell/scripts/desktop-settings.py), [shell/quickshell/services/DesktopSettings.qml](../../shell/quickshell/services/DesktopSettings.qml), [shell/quickshell/components/DesktopPreferencesView.qml](../../shell/quickshell/components/DesktopPreferencesView.qml), [shell/quickshell/scripts/desktop-capabilities.py](../../shell/quickshell/scripts/desktop-capabilities.py), [components/file-manager/thunar/scripts/senomy-file-workspace](../../components/file-manager/thunar/scripts/senomy-file-workspace), [components/launcher/rofi/scripts/senomy-command-lens](../../components/launcher/rofi/scripts/senomy-command-lens).

**Backend and dependencies:** DesktopEntries/GIO; XDG MIME and .desktop autostart; StatusNotifier; Thunar; desktop portals; optional Flatpak.

**Tests:** [shell/quickshell/tests/test_desktop_settings.py](../../shell/quickshell/tests/test_desktop_settings.py), [shell/quickshell/tests/test_desktop_capabilities.py](../../shell/quickshell/tests/test_desktop_capabilities.py), [scripts/validate-native-command-lens.py](../../scripts/validate-native-command-lens.py), [scripts/validate-native-entrypoints.py](../../scripts/validate-native-entrypoints.py).

**Related:** D03, D11, D14, D17; G01, G32, G33.

| Capability ID / name | Intended purpose / operation |
| --- | --- |
| D13.01 Discovery and launch | Native installed desktop entries and normal app-owned windows |
| D13.02 Default applications | Supported role/MIME handlers via GIO and reviewed selection/readback |
| D13.03 Autostart management | List inherited/user entries, add installed app, enable/disable with user overrides |
| D13.04 Files/folders and Thunar actions | Open/reveal, copy path/checksum and file-manager integration |
| D13.05 Recent files and per-app reuse | Bounded path search and explicit existing-window scope |
| D13.06 Portals and permissions | No-autostart capability introspection; optional providers; no blanket bypass |
| D13.07 Application install/remove and Flatpak permissions | Delegate package management; no native app permission editor |
| D13.08 Tray and app notifications | Native StatusNotifier and notification protocol integration |

<a id="domain-14"></a>

## D14 — Accounts, authentication and security

**User entry:** Settings Users & Accounts; SDDM; Hyprlock; independent recovery.

**Components:** [shell/quickshell/services/AccountService.qml](../../shell/quickshell/services/AccountService.qml), [shell/quickshell/scripts/account-settings.py](../../shell/quickshell/scripts/account-settings.py), [shell/quickshell/components/control/ControlAccountsPage.qml](../../shell/quickshell/components/control/ControlAccountsPage.qml), [components/lock/scripts/senomy-lock](../../components/lock/scripts/senomy-lock), [components/recovery/senomy-password-reset-helper](../../components/recovery/senomy-password-reset-helper), [appearance/login/sddm/senomyos/Main.qml](../../appearance/login/sddm/senomyos/Main.qml).

**Backend and dependencies:** NSS; AccountsService/Gio/polkit; passwd terminal/PAM; login1; SDDM; Hyprlock; explicitly provisioned recovery sudo helper.

**Tests:** [shell/quickshell/tests/test_account_settings.py](../../shell/quickshell/tests/test_account_settings.py), [shell/quickshell/tests/test_account_dbus.py](../../shell/quickshell/tests/test_account_dbus.py), [scripts/validate-account-page.py](../../scripts/validate-account-page.py), [scripts/validate-login-screens.py](../../scripts/validate-login-screens.py).

**Related:** D07, D12, D18, D20; G02, G34, G35.

| Capability ID / name | Intended purpose / operation |
| --- | --- |
| D14.01 Account inventory | Bounded ordinary NSS accounts plus AccountsService/admin/lock/session data |
| D14.02 Create/edit/lock/type/remove | Reviewed allowlisted AccountsService calls; readback and retained home files |
| D14.03 Password workflow | Current passwd or authorized pkexec passwd in terminal; no QML password capture |
| D14.04 Avatar | Bounded PNG validation and digest-based provider-copy readback |
| D14.05 Active/last administrator protection | Complete inventory, signed-in/current guards and viable-admin quorum |
| D14.06 User switching and sessions | login1 sessions read; SDDM owns login; no complete fast-switch workflow |
| D14.07 Lock/unlock and authorization | Hyprlock launcher/PAM; installed system polkit agent |
| D14.08 Independent recovery credential reset | Dedicated recovery caller/configuration and root-owned fixed target; chpasswd stdin |

<a id="domain-15"></a>

## D15 — Personalisation and appearance configuration

**User entry:** Settings Appearance; skin manifest; wallpaper helper and profiles.

**Components:** [shell/quickshell/components/AppearanceSettings.qml](../../shell/quickshell/components/AppearanceSettings.qml), [shell/quickshell/config/Skin.qml](../../shell/quickshell/config/Skin.qml), [shell/quickshell/config/SkinPreferences.js](../../shell/quickshell/config/SkinPreferences.js), [shell/quickshell/config/Motion.qml](../../shell/quickshell/config/Motion.qml), [components/desktop/scripts/senomy-wallpaper-watch.py](../../components/desktop/scripts/senomy-wallpaper-watch.py), [appearance/skins/default.json](../../appearance/skins/default.json), [appearance/tokens.json](../../appearance/tokens.json).

**Backend and dependencies:** Validated atomic skin preferences; shared token projections; independent wallpaper owner and user wallpaper JSON; profile system.

**Tests:** [shell/quickshell/tests/tst_SkinPreferences.qml](../../shell/quickshell/tests/tst_SkinPreferences.qml), [scripts/validate-control-settings.sh](../../scripts/validate-control-settings.sh), [scripts/validate-art-skins.py](../../scripts/validate-art-skins.py), [scripts/validate-wallpaper.py](../../scripts/validate-wallpaper.py).

**Related:** D01, D02, D20; G07, G21, G36, G37.

| Capability ID / name | Intended purpose / operation |
| --- | --- |
| D15.01 Surface backgrounds | Choose image/path, crop/fit, image opacity and scrim with preview/save/discard |
| D15.02 Reduced motion and text/contrast | Persisted persona reduced motion/hover, Rail text 10–16px, UI text 100–150%, high contrast |
| D15.03 Skin/token/font/icon configuration | Maintained token/manifest art and generated toolkit projections |
| D15.04 Desktop wallpaper | Single watcher validates schema/source/mode, debounces, retains prior image on failure |
| D15.05 Per-monitor wallpapers | Global wallpaper selection currently feeds swaybg |
| D15.06 Import/export, profiles and reset | Deployment/profile validators; empty source restores fill; no universal preference export/reset |
| D15.07 Rail/module/window customization | Art-specific RailStyle and compositor rules; fixed composition |
| D15.08 Invalid configuration recovery | Validation, atomic merge and image fallback |

<a id="domain-16"></a>

## D16 — Performance, telemetry and Senomy Insights

**User entry:** Rail telemetry/persona; separate Performance; all eight Insights routes.

**Components:** [shell/quickshell/services/SystemMetrics.qml](../../shell/quickshell/services/SystemMetrics.qml), [shell/quickshell/services/TelemetryHistory.qml](../../shell/quickshell/services/TelemetryHistory.qml), [shell/quickshell/services/DiskActivity.qml](../../shell/quickshell/services/DiskActivity.qml), [shell/quickshell/services/TemperatureService.qml](../../shell/quickshell/services/TemperatureService.qml), [shell/quickshell/services/PerformanceService.qml](../../shell/quickshell/services/PerformanceService.qml), [shell/quickshell/services/InsightsRequests.qml](../../shell/quickshell/services/InsightsRequests.qml), [scripts/performance-live.sh](../../scripts/performance-live.sh), [scripts/performance-status.sh](../../scripts/performance-status.sh), [scripts/diagnostics-status.sh](../../scripts/diagnostics-status.sh), [scripts/performance-report.sh](../../scripts/performance-report.sh).

**Backend and dependencies:** One session procfs sampler; thermal/sysfs; view-scoped process/hardware helpers; bounded graphs; allowlisted diagnostic/export tasks.

**Tests:** [scripts/validate-session-telemetry.py](../../scripts/validate-session-telemetry.py), [shell/quickshell/tests/tst_DirectoryData.qml](../../shell/quickshell/tests/tst_DirectoryData.qml), [shell/quickshell/tests/tst_InsightsRequests.qml](../../shell/quickshell/tests/tst_InsightsRequests.qml), [scripts/validate-performance-processes.sh](../../scripts/validate-performance-processes.sh).

**Related:** D03, D07, D17, D18, D20; G01, G18, G38, G39.

| Capability ID / name | Intended purpose / operation |
| --- | --- |
| D16.01 Continuous core metrics | CPU/per-core, RAM/swap, net totals; frequency/pressure 5s, thermal 10s, disk busy 2s |
| D16.02 Bounded history and gaps | At most 900 timestamped samples; elapsed windows; null missing data; resume/reset handling |
| D16.03 Processes and safe termination | Bounded process table/filters, PID+start ticks+owner revalidation and reviewed SIGTERM |
| D16.04 User-service restart | Only PipeWire/Pulse/WirePlumber allowlist, reviewed invocation identity and new active-instance check |
| D16.05 GPU and disk throughput coverage | Legacy performance-live supports optional gpu_busy_percent; native ring has disk busy but no GPU series |
| D16.06 Insights routes and shared tasks | Briefing/Notifications/Timeline/Updates/Diagnostics/Console/Reports/Wiki; task allowlists and per-route freshness |
| D16.07 Benchmarks and reports | Finite reviewed workloads, stop path, bounded private report/export/open |
| D16.08 Resource cost and retention | 30s qs PID sample ~4.60% of one core, RSS ~527 MiB; no controlled idle/soak |
| D16.09 Alerts and drain diagnosis | Senomy threshold health priority; limited power/process attribution |

<a id="domain-17"></a>

## D17 — Maintenance and recovery

**User entry:** Settings about/integration; Insights updates/diagnostics/console/reports/wiki; CLI deploy/recovery.

**Components:** [scripts/update-status.sh](../../scripts/update-status.sh), [scripts/diagnostics-status.sh](../../scripts/diagnostics-status.sh), [scripts/console-status.sh](../../scripts/console-status.sh), [scripts/performance-report.sh](../../scripts/performance-report.sh), [scripts/recovery-status.sh](../../scripts/recovery-status.sh), [scripts/recovery-restore.sh](../../scripts/recovery-restore.sh), [scripts/senomy-v2-deploy](../../scripts/senomy-v2-deploy), [scripts/senomy-system-deploy.sh](../../scripts/senomy-system-deploy.sh), [scripts/senomy-bootstrap.sh](../../scripts/senomy-bootstrap.sh), [scripts/senomy-bootctl](../../scripts/senomy-bootctl), [shell/quickshell/scripts/disk-devices.py](../../shell/quickshell/scripts/disk-devices.py).

**Backend and dependencies:** pacman/checkupdates/AUR read adapters; systemd status; private receipt/report stores; staged-root deploy and separately gated system operations.

**Tests:** [scripts/validate-action-contracts.sh](../PROJECT_STATE.md), [scripts/validate-report-boundary.py](../../scripts/validate-report-boundary.py), [scripts/validate-deployment.sh](../../scripts/validate-deployment.sh), [scripts/validate-bootstrap.sh](../../scripts/validate-bootstrap.sh).

**Related:** D14, D16, D18; G04, G05, G06, G40.

| Capability ID / name | Intended purpose / operation |
| --- | --- |
| D17.01 System/storage inventory | OS/kernel/hardware, root usage, block/mount data and bounded service summaries |
| D17.02 Update discovery | Cached official/AUR checks with source-specific checked_at and errors |
| D17.03 Update installation lifecycle | No native reviewed install/progress/failure/reboot flow |
| D17.04 Curated console and diagnostics | Fixed task catalog, bounded command output/timeouts, error envelopes |
| D17.05 Report exports | Private source-bounded files, profile scope and launched viewer versus visible-open distinction |
| D17.06 Configuration deploy/rollback | Owned-link checks, receipts, backups and system payload staging |
| D17.07 Release/install/recovery media | Manifest/profile/bootstrap mechanisms exist; immutable release artifact and clean boot acceptance incomplete |
| D17.08 Error/crash reporting | Local error states/journals; no blanket remote upload |

<a id="domain-18"></a>

## D18 — Login, boot and session lifecycle

**User entry:** Firmware/GRUB→SDDM→Hyprland→Quickshell; Hyprlock; independent Senomy Recovery.

**Components:** [hyprland.lua](../../hyprland.lua), [systemd/senomy-quickshell.service](../../systemd/senomy-quickshell.service), [systemd/senomy-calendar.service](../../systemd/senomy-calendar.service), [scripts/senomy-shell](../../scripts/senomy-shell), [scripts/senomy-quickshell-run](../../scripts/senomy-quickshell-run), [appearance/login/sddm/senomyos/Main.qml](../../appearance/login/sddm/senomyos/Main.qml), [components/recovery/senomy-recovery-session](../../components/recovery/senomy-recovery-session), [docs/reference/BOOT_SEQUENCE.md](BOOT_SEQUENCE.md).

**Backend and dependencies:** Current GRUB EFI evidence; SDDM; systemd graphical-session/user service; Lua startup/environment; separate wallpaper/calendar/lock owners.

**Tests:** [scripts/validate-native-entrypoints.py](../../scripts/validate-native-entrypoints.py), [scripts/validate-notification-selection.py](../../scripts/validate-notification-selection.py), [scripts/validate-login-screens.py](../../scripts/validate-login-screens.py), [scripts/validate-session-policy.sh](../../scripts/validate-session-policy.sh).

**Related:** D01, D07, D08, D09, D14, D17; G01, G02, G04, G05, G35.

| Capability ID / name | Intended purpose / operation |
| --- | --- |
| D18.01 Actual startup and ownership | GRUB 2.13 current boot-loader report, SDDM active, Lua starts selector/environment/wallpaper/restore |
| D18.02 Boot splash | Staged Plymouth art/scripts; runtime package absent |
| D18.03 Supervision and recovery | Restart on failure with rate limits; separate recovery/TTY; no alternate shell backend |
| D18.04 Startup races | Imports session env, provider gates at process start, bounded display restore |
| D18.05 Login and lock multi-output | SDDM QML secondary-view fixes in source; native Hyprlock workflow |
| D18.06 Session restoration | Saved settings/profiles/drafts; RAM telemetry new epoch |
| D18.07 Service/cgroup application isolation | New launches use independent application scopes; shell helpers retain service ownership |
| D18.08 Cold boot, suspend and recovery entry | Separate source/boot assets and recovery user guard |

<a id="domain-19"></a>

## D19 — Full Settings and Control Centre integration

**User entry:** Rail Settings; Super+I / Super+Ctrl+I; Lens task routes; quick-panel links.

**Components:** [shell/quickshell/components/ControlCentre.qml](../../shell/quickshell/components/ControlCentre.qml), [shell/quickshell/components/ControlDirectory.js](../../shell/quickshell/components/ControlDirectory.js), [shell/quickshell/components/TaskIntents.js](../../shell/quickshell/components/TaskIntents.js), [shell/quickshell/components/DashboardWindow.qml](../../shell/quickshell/components/DashboardWindow.qml), [shell/quickshell/services/ShellState.qml](../../shell/quickshell/services/ShellState.qml), [components/settings/task-intents.json](../../components/settings/task-intents.json), [scripts/senomy-surface](../../scripts/senomy-surface).

**Backend and dependencies:** One ControlCentre page tree, compact/full native host; shared services/actions; route catalog and bounded history.

**Tests:** [scripts/validate-settings-host.py](../../scripts/validate-settings-host.py), [scripts/validate-control-routes.py](../../scripts/validate-control-routes.py), [shell/quickshell/tests/tst_ControlNavigation.qml](../../shell/quickshell/tests/tst_ControlNavigation.qml), [scripts/validate-native-entrypoints.py](../../scripts/validate-native-entrypoints.py).

**Related:** D02, D03, D04–D15, D20; G03, G22, G36, G41.

| Capability ID / name | Intended purpose / operation |
| --- | --- |
| D19.01 Shared compact/full pages | One reusable ControlCentre; native resizable Settings; no fifth primary |
| D19.02 Deep links and search | Validated routes, control target IDs, task intents and dynamic provider nodes |
| D19.03 Back/forward and reuse | 64-entry route history, dirty guard and existing native-window reuse |
| D19.04 Apply/cancel and drafts | Appearance/calendar dirty guards; display persistent draft and transaction; input immediate apply |
| D19.05 Authoritative service integration | Quick/full share Audio/Network/Bluetooth/Power/etc from shell.qml |
| D19.06 Provider and permission feedback | Capability gates and Settings integration status; system auth handoffs |
| D19.07 Hardware changes/window focus | Primary screen reconciliation and native host migration |
| D19.08 Settings coverage and documentation | Catalog includes real calendar/accounts/audio/app configuration |

<a id="domain-20"></a>

## D20 — Accessibility and reliability

**User entry:** All primary/quick/native surfaces, supported input profiles and system lifecycle.

**Components:** [shell/quickshell/components/interaction/QuickPopoverWindow.qml](../../shell/quickshell/components/interaction/QuickPopoverWindow.qml), [shell/quickshell/components/FocusScrollArea.qml](../../shell/quickshell/components/FocusScrollArea.qml), [shell/quickshell/config/Motion.qml](../../shell/quickshell/config/Motion.qml), [shell/quickshell/config/DirectoryStyle.qml](../../shell/quickshell/config/DirectoryStyle.qml), [shell/quickshell/services/ScreenLifecycle.js](../../shell/quickshell/services/ScreenLifecycle.js), [scripts/senomy-desktop-probe.py](../../scripts/senomy-desktop-probe.py).

**Backend and dependencies:** Qt focus/accessibility metadata; shared density/text/contrast/motion; system provider lifecycle and resource accounting.

**Tests:** [scripts/validate-interactions.py](../../scripts/validate-interactions.py), [scripts/validate-control-routes.py](../../scripts/validate-control-routes.py), [scripts/validate-session-telemetry.py](../../scripts/validate-session-telemetry.py), [shell/quickshell/tests/tst_ScreenLifecycle.qml](../../shell/quickshell/tests/tst_ScreenLifecycle.qml), [shell/quickshell/tests/tst_SkinPreferences.qml](../../shell/quickshell/tests/tst_SkinPreferences.qml).

**Related:** All domains; G01, G02, G20, G30, G36, G38, G42.

| Capability ID / name | Intended purpose / operation |
| --- | --- |
| D20.01 Keyboard and focus visibility | Accessible names/roles in controls; focus-scroll and Escape coordination |
| D20.02 Touch, text, contrast and reduced motion | Touch density, UI text scale/high contrast and shared Motion.duration policy |
| D20.03 Screen reader and assistive technology | Some Qt Accessible metadata; no complete Orca/AT-SPI acceptance |
| D20.04 Locale and language | System XKB catalog; local date/time; English UI/task phrases |
| D20.05 Hotplug/provider restart | Native subscriptions, object generations, error states and screen reconciliation |
| D20.06 Long-running memory and subscriptions | Bounded history and scoped graph/process collectors |
| D20.07 Safe test infrastructure | Private bus/mocked devices; inert host substitutions |
| D20.08 Recovery and diagnostics | Local bounded errors and independent recovery source |

## Historical gap identifiers

G IDs preserve cross-references to the original audit questions. A title is not
a current defect claim, approved feature, priority or outstanding task. Detailed
dated discussions remain in the archive; use PROJECT_STATE for current decisions.

<a id="g01"></a>

### G01 — Ordinary applications must survive shell service restart

<a id="g02"></a>

### G02 — Preserve user-selected inactive automatic idle policy

<a id="g03"></a>

### G03 — Input apply must reject Lua-provider command refusal

<a id="g04"></a>

### G04 — Verify lid-policy ownership without assuming source/live parity

<a id="g05"></a>

### G05 — Publish a reproducible shell payload independent of watched development source

<a id="g06"></a>

### G06 — Accept real lifecycle recovery beyond unit and render passes

<a id="g07"></a>

### G07 — Define supported Rail module visibility/order configuration

<a id="g08"></a>

### G08 — Keep a visible result when app/window activation throws

<a id="g09"></a>

### G09 — Offer optional user pins and recent-app results without fabricating history

<a id="g10"></a>

### G10 — Prove real Wi-Fi authentication and advanced editor outcome

<a id="g11"></a>

### G11 — Make VPN setup/activation responsibility explicit and observable

<a id="g12"></a>

### G12 — Guide captive portal and multiple-interface recovery without equating link with internet

<a id="g13"></a>

### G13 — Accept CMF Buds Pro 2 reconnect/cancel/retry on hardware

<a id="g14"></a>

### G14 — Prove Bluetooth and call audio routing independently of connection state

<a id="g15"></a>

### G15 — Preserve explicit saved-route semantics and assess optional restoration

<a id="g16"></a>

### G16 — Recover an audio graph subscription that exits while Settings remains open

<a id="g17"></a>

### G17 — Refresh power-profile capability after service owner changes

<a id="g18"></a>

### G18 — Expose supported battery health/threshold and bounded drain evidence

<a id="g19"></a>

### G19 — Do not add hibernate/hybrid-sleep controls on unsupported host

<a id="g20"></a>

### G20 — Close physical display/workspace lifecycle gates after current orchestration fixes

<a id="g21"></a>

### G21 — Resolve identity/persona activation specification drift

<a id="g22"></a>

### G22 — Accept actual focus, nested menu and popup geometry on hardware

<a id="g23"></a>

### G23 — Scope optional display colour/HDR/VRR controls by actual support

<a id="g24"></a>

### G24 — Document and test named/special workspace and guest-session semantics

<a id="g25"></a>

### G25 — Prove reminder delivery/snooze across actual shell/session transitions

<a id="g26"></a>

### G26 — Validate real CalDAV provider/Secret Service before claiming synchronized accounts

<a id="g27"></a>

### G27 — Distinguish calendar display zone from OS timezone/NTP configuration

<a id="g28"></a>

### G28 — Define critical notification versus DND behavior explicitly

<a id="g29"></a>

### G29 — Add bounded per-app notification policy and useful history search/grouping

<a id="g30"></a>

### G30 — Accept accessibility, OSK and supported language workflows with actual input

<a id="g31"></a>

### G31 — Provide useful capability-scoped peripheral/configuration handoffs

<a id="g32"></a>

### G32 — Prove native-app portal/file/notification integration end to end

<a id="g33"></a>

### G33 — Keep package/app management delegated unless product scope changes

<a id="g34"></a>

### G34 — Accept authorized account lifecycle and safe post-authentication revalidation

<a id="g35"></a>

### G35 — Prove independently authenticated recovery and greeter/lock accessibility

<a id="g36"></a>

### G36 — Separate writable appearance preferences from release/default source

<a id="g37"></a>

### G37 — Define optional per-monitor wallpaper and preference export/reset scope

<a id="g38"></a>

### G38 — Establish controlled sampler/shell budgets and soak evidence

<a id="g39"></a>

### G39 — Close native GPU/disk-throughput and drain diagnostic projection gaps selectively

<a id="g40"></a>

### G40 — Complete update review/handoff/failure/reboot/recovery journey

<a id="g41"></a>

### G41 — Keep one current capability ledger while preserving dated evidence

<a id="g42"></a>

### G42 — Document supported locale and assistive scope rather than universal accessibility
