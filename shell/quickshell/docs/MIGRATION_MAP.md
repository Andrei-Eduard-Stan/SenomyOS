# SenomyOS Eww → Quickshell Migration Map

Status reflects the real live tree audited on 2026-09-01. “Keep” means Eww
remains authoritative until an explicit later acceptance gate; it does not mean
the module is permanent.

| Current component | Purpose | Current files | Current data source | Current state mechanism | Quickshell/native equivalent | Decision | Migration risk |
|---|---|---|---|---|---|---|---|
| Rail window | Persistent bottom shell and exclusive zone | `windows/main-bar.yuck`, `eww.scss` | Eww widget tree | One active `main-bar`, namespace `senomy-rail`, 64 px exclusive zone | One masked transparent `PanelWindow` per screen | Ported in V2; Eww stays default | Medium: layer-shell, mask, blur, and multi-monitor differences |
| Workspaces | Active/occupied workspace controls | `scripts/workspaces.sh`, `workspaces.service`, `widgets/workspace-widget.yuck` | Hyprland socket2 + `hyprctl -j` snapshots | Long-running service publishes JSON into Eww | `Quickshell.Hyprland` monitor/workspace objects | Replace in V2; keep service only for Eww | Medium: special workspaces, monitor moves, compositor API changes |
| Workspace carousel | Keep a bounded workspace island | `scripts/workspace-carousel.sh`, workspace widget | Workspace JSON + selected range | Eww variables and action script | `ScriptModel`, bounded viewport, animated offset | Ported foundation; refine edge cases | Medium: overflow and focus must never move other islands |
| Application indicators | Show apps belonging to each workspace | class normalization in `workspaces.sh`, workspace widget | Hyprland clients | Apps embedded in published workspace JSON | Native workspace `toplevels`, icon-theme lookup | Ported foundation | Medium: class/app-id aliases and icon fallbacks |
| Senomy status island | Identity, dialogue, entry to Insights and companion | `widgets/senomy-status.yuck`, avatar/dialogue scripts, assets | Local catalog/state scripts | Eww variables + poll/listen scripts | Future Senomy state singleton | Visual-only compatibility in V2; keep behavior on Eww | High: product semantics and primary-surface ownership |
| CPU/MEM/uptime | Low-cost Rail telemetry | `scripts/rail-system-status.sh`, performance widget | `/proc/stat`, `/proc/meminfo`, `/proc/uptime` | One `defpoll` every 2 s running a script | Shared `FileView` readers and one timer | Replaced in V2; no subprocess | Low |
| Performance Dashboard | Expanded system-management surface | performance window, sections, scripts | `/proc`, `ps`, network/storage tools, allowlisted actions | Conditional polls under `active_surface == performance` | Later dashboard-only service tier | **Keep; do not migrate in Milestone 2** | High: expensive data, actions, safety confirmations |
| Rail audio | Default output, volume, mute | `bar-audio-listener.sh`, `volume-widget.yuck` | Pulse compatibility commands over PipeWire | `pactl subscribe` listener + shell parsing | `Quickshell.Services.Pipewire` graph/default sink | Replaced natively in V2 | Medium: default-node replacement and channel aggregation |
| Detailed audio | Devices, ports, profiles, actions | `audio-status.sh`, `audio-action.sh`, control Audio section | PipeWire/Pulse tools and system inventory | Conditional 1 s/500 ms polls | Native PipeWire model plus guarded action service | Keep on Eww for now | High: device routing and action failure states |
| Dual battery | Aggregate two laptop packs | `battery.sh`, battery widget | UPower CLI + `jq` | `defpoll` every 10 s | `Quickshell.Services.UPower` device model | Replaced natively in V2 | Medium: absent packs and energy-weighted aggregation |
| Network/Wi-Fi | Connection and signal state | `bar-network-listener.sh`, `network-status.sh`, Wi-Fi widget | NetworkManager via `nmcli` | long-running listener plus conditional polls | `Quickshell.Networking` NetworkManager backend | Native shared V2 state complete; broad control UI remains on Eww | High: secrets, portals, device churn, action UX |
| Bluetooth | Controller/device inventory and actions | `bluetooth-status.sh`, `bluetooth-action.sh`, Device Management | BlueZ via command-line tooling | Conditional 2 s poll | BlueZ D-Bus model | Keep on Eww until safe native service exists | High: pairing agents and confirmation flows |
| Media/MPRIS | Companion playback context | `companion-media.sh`, companion widgets | Playerctl/MPRIS availability | 3 s poll | `Quickshell.Services.Mpris` players | Replace later; not needed for Rail proof | Medium: player selection and metadata artwork |
| Clock/date | Local time and compact date | `eww.yuck`, `clock-widget.yuck` | `date` | Two minute `defpoll`s | `SystemClock` | Replaced natively in V2 | Low |
| Calendar | Month view anchored to clock | `calendar-flyout.yuck`, `control-status.sh` | Local date/calendar generation | `active_flyout`, separate Eww overlay, dismiss surface | `PopupWindow`, native JS month model, `HyprlandFocusGrab` | Ported in V2 | Medium: keyboard/touch dismissal and per-screen anchoring |
| Notifications | Bell state, flyout, retained history | SwayNC listener, notification scripts, notification/Insights widgets | `swaync-client`, local history | persistent listener + conditional polls | Quickshell notification server + bounded native history | Keep SwayNC as sole owner now; final V2 ownership accepted and gated | High: replacement IDs, actions, privacy, DND, rollback |
| System tray | StatusNotifier items and flyout | `system-tray.yuck`, `tray-flyout.yuck`, background-app script | StatusNotifier inventory | Eww widget plus conditional 2 s poll | `Quickshell.Services.SystemTray` + `QsMenuAnchor` | Native lifecycle, activation, status, scroll, and menu foundation complete | Medium: pointer menu acceptance and item-specific behavior |
| Control Centre | Contextual settings and Device Management | action center window, control sections and scripts | Multiple guarded system sources | `active_surface == control` + `control_section` | Future QML routes with shared surface state | Keep entirely on Eww | High: broad actions and responsive layouts |
| Senomy Insights | First-class briefing surface | Insights window/sections and dialogue/event scripts | notifications, updates, diagnostics, reports, wiki | `active_surface == insights` + route variables | Future dedicated QML surface and services | Keep entirely on Eww | High: product identity and substantial data contracts |
| Companion overlay | Session-scoped Senomy edge overlay | `companion.yuck`, companion state/media scripts | local state and MPRIS | separate companion mode/pin variables | Future non-primary `PanelWindow`/overlay | Keep entirely on Eww | High: coexistence with primary surfaces and timers |
| Power/session | Power profile, brightness, logout/reboot/shutdown | power flyout/control section and action scripts | UPower, brightness, systemd/logind | guarded polls and explicit confirmation state | allowlisted action script + pending/confirm service state | Backend foundation complete; keep power UI on Eww | Critical: destructive actions |
| Application launcher | Open Command Lens | main bar/system controls and deployment wrapper | Rofi wrapper | click action starts external launcher | Future typed action interface | Temporary direct Rofi compatibility seam | Medium: deployed wrapper and focus behavior |
| Primary surface ownership | Enforce one of none/control/performance/insights | `surface-state.sh`, Eww variables, surface windows | Eww IPC and active-window checks | one `active_surface` plus one `active_flyout` | One shared shell-state singleton | Keep on Eww; V2 must not duplicate primary surfaces | Critical: overlapping windows and unsafe actions |
| Popup positioning/click-away | Anchor flyouts and dismiss outside interaction | flyout windows, `surface-dismiss.yuck`, geometry values | monitor/layout script + Eww window state | separate overlay windows and action script | anchored `PopupWindow` + compositor focus grab | Calendar/tray share one global token and cancel-safe timing | High: pointer/key acceptance and future primary surfaces |
| Appearance/tokens/frames | Shared product language and scalable ornament | `eww.scss`, `appearance/`, generated frame SVGs, generator | appearance profile/tokens | generated assets + Eww classes/listener | generated QML singleton + shared SVG modules | Generator and repository-relative canonical assets complete | Low: component-specific layout remains native |
| Exclusive zones/input regions | Reserve screen edge without blocking gaps | `main-bar` geometry/exclusive flag | Eww layer-shell window | full-width Eww window | masked full-width `PanelWindow` | Ported in V2 | Medium: compositor/version behavior |
| Multi-monitor/layout profiles | Adapt to monitor width and density | `bar-layout.sh`, profile status, Eww screen choice | `hyprctl -j monitors`, profile JSON | 15 s layout poll + startup-selected screen | `Quickshell.screens`, per-screen variants, width breakpoints | Virtual hotplug, integer/fractional, narrow landscape, and portrait passed | High: physical hotplug/touch still needs evidence |
| Startup/recovery | Start one stable shell and preserve fallback | Hyprland Lua, `start-eww.sh`, `senomy-shellctl.sh` | compositor startup and Eww IPC | detached daemon, readiness checks, main-bar open | non-enabled user units + verified selector + OnFailure fallback | Live switching complete; Eww remains login default | Critical: login ownership change remains gated |

## Shared state and service architecture

V2 separates compositor/system sources from presentation. Hyprland, UPower,
PipeWire, NetworkManager, and System Tray are subscribed to once through
Quickshell services.
The only fixed-rate sampler reads `/proc/stat`, `/proc/meminfo`, and
`/proc/uptime` once every two seconds without forking. Each screen gets a Rail
window, while all screen instances share the same service objects.

The next architectural seam should be a single shell-state service owning
`none|control|performance|insights` and the active flyout. Until it exists and
can coordinate with Eww, V2 must not open duplicate primary surfaces.

## Frame and asset boundary

V2 uses repository-relative links to canonical icons, Senomy artwork, and
generated frame modules. `SenomyFrame.qml` retains corner and motif dimensions
and stretches only neutral edges. The existing appearance generator emits the
QML singleton, so tokens remain aligned with Eww, Rofi, application, lock,
login, boot, and recovery projections.

## Confirmed cleanup candidates (not removed)

- `windows/clock-panel.yuck` and `windows/battery-panel.yuck` are tracked,
  zero-byte legacy includes and define no live surface.
- `config.yuck` is a 59-byte historical fragment and is not the loaded Eww
  entrypoint.
- `update-loop.sh` is the retired two-second update loop; no active startup
  path runs it.
- `backups/` contains historical copies rather than runtime modules.

Removal belongs in a separate, recoverable Eww cleanup commit after V2 has no
need for comparison against those paths.

## Acceptance gates before default-shell consideration

1. Quickshell package and API version are pinned reproducibly.
2. Rail renders correctly on the reference T480 and physical narrow and
   multi-monitor profiles; virtual scale/hotplug evidence is already present.
3. Workspace activation, creation/removal, app movement, overflow, focus, and
   fullscreen behavior pass manual QA.
4. UPower dual-pack changes and PipeWire sink replacement update without
   polling helpers or stale values.
5. Calendar opens from the correct screen, receives keyboard focus, dismisses
   on outside click/touch and Escape, and never overlaps another primary state.
6. Idle/startup/resource benchmarks meet or improve on the Eww baseline.
7. A supervised start, health check, kill switch, and Eww rollback path exist.
   This gate passed in Milestone 2.
8. Hyprland startup changes are reviewed separately and approved explicitly.
