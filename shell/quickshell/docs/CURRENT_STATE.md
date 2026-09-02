# Audited Live SenomyOS Shell State

## Milestone 3 development state — 2026-09-02

The live development session is selected to Quickshell from the authoritative
`/home/Duku/SenomyOS` `quickshell-v2` worktree. One
`senomy-quickshell.service` process owns one `senomy-v2-rail` layer on the
physical display and is the sole `org.freedesktop.Notifications` owner. The
Eww adapter, Eww-only `workspaces.service`, and SwayNC are inactive. Login-time
ownership remains Eww.

The native Rail, workspace/toplevel model, volume/tray/calendar/notification/
power popups, ten-route Control Centre, seven-route Performance Dashboard,
eight-route Insights surface, and companion are implemented. Shared services
own PipeWire, NetworkManager, UPower, BlueZ, MPRIS, notifications, Level 1
metrics, conditional Level 2 metrics, explicit Level 3 work, and Senomy state.
No Quickshell surface opens a legacy Eww window.

Automated and virtual-display acceptance is recorded in
`../../../docs/QUICKSHELL_V3_QA.md`. Physical pointer/keyboard acceptance is
still pending, so this is not yet a Milestone 3 sign-off or permission to
promote the login default.

## Preserved Milestone 2 / Eww baseline audit

Audit date: 2026-09-01. This records the preserved baseline runtime state, not an assumption
from older documentation.

## Configuration and repository boundary

Milestone 2 update: the authoritative `quickshell-v2` worktree now lives at
`/home/Duku/SenomyOS`, and V2 moved to `shell/quickshell/`. The verified state
below remains the preserved Eww baseline at `/home/Duku/.config/eww`, which is
now a detached fallback checkout rather than the V2 development root. See
`docs/QUICKSHELL_V2_FOUNDATION.md` for the current selector and service model.

- The live repository and Eww configuration are both
  `/home/Duku/.config/eww`.
- The baseline repository state is preserved by `revival/live` and the
  `eww-v0-baseline-2026-09-01` tag. V2 integration remains on
  `quickshell-v2`; it is not merged into `main`.
- Hyprland 0.56.2 reports `configProvider: lua`; the active source is
  `/home/Duku/.config/hypr/hyprland.lua`.
- The tracked `hyprland.lua` mirror and live Lua file are byte-identical. The
  tracked and live legacy `.conf` files are also byte-identical, but `.conf` is
  not the active provider.
- Older notes describing the Hyprland 0.55.2 compatibility baseline remain
  historically important, but 0.56.2 is the current runtime fact.
- The out-of-scope secondary clone was not inspected or modified.

## Startup sequence

The active Hyprland Lua source imports the compositor environment into the user
manager, restarts `workspaces.service`, starts the PolicyKit agent, calls
`scripts/start-eww.sh`, and starts the Senomy wallpaper path. It contains no
Quickshell startup command.

`start-eww.sh` resolves the live configuration directory, removes duplicate or
stale config-matched Eww daemons when necessary, starts one detached foreground
daemon, waits for IPC and the `main-bar` definition, opens the Rail on the
focused monitor, and requests one workspace publication.

## Active windows and processes

- One Eww daemon was live as `/usr/bin/eww --debug --no-daemonize --config
  /home/Duku/.config/eww daemon`.
- `eww active-windows` reported only `main-bar: main-bar` at audit time.
- The Rail uses namespace `senomy-rail`, a full-width 64 px bottom geometry,
  foreground stacking, and an exclusive zone.
- `active_surface` and `active_flyout` were both `none`; Control Centre,
  Performance Dashboard, Insights, companion, and flyouts were not active.
- The stable workspace path was `workspaces.service` → `scripts/workspaces.sh`
  → Hyprland socket2/`hyprctl` → Eww JSON update.

The active user services relevant to the shell were PipeWire,
`pipewire-pulse`, WirePlumber, SwayNC, and `workspaces.service`; portal and
desktop support services were also running. There was no Quickshell service.

## Eww state and activity architecture

The live Rail combines Eww variables, `deflisten` processes, and `defpoll`
commands:

- persistent listeners for audio (`pactl subscribe`), NetworkManager state,
  SwayNC notification state, appearance state, and Senomy Rail messages;
- a 2 s Rail telemetry script;
- a 10 s UPower/`jq` battery script;
- minute-based `date` commands;
- a 15 s monitor/layout probe and a 60 s avatar catalog probe;
- many lower-frequency or conditional Control Centre, Performance, Insights,
  Device Management, flyout, operation-status, and history pollers guarded by
  `:run-while`.

Representative external dependencies are `hyprctl`, `socat`, `jq`, `pactl`,
`nmcli`, `upower`, `swaync-client`, `playerctl`, `/proc` readers, and project
action/status scripts. Conditional polling is preferable to unconditional
polling, but it still creates a large command-oriented state graph and process
churn.

## Presentation, assets, and behavior

- `eww.yuck` is the loaded state/data entrypoint; `windows/`, `widgets/`, and
  `sections/` hold the modular presentation tree.
- `eww.scss` is the live compiled styling source. The wider appearance system,
  generated frame SVGs, appearance profiles, and
  `scripts/generate-appearance.py` are the upstream design machinery.
- Live Senomy assets include state placeholders, browsing/listening artwork,
  low-battery artwork, and the Rail avatar. V2 reuses the Rail asset rather than
  inventing a replacement identity.
- Eww owns one primary-surface variable (`none|control|performance|insights`)
  and one flyout variable. `surface-state.sh` coordinates open/close behavior so
  primary surfaces do not overlap.
- Flyouts are separate non-exclusive overlay windows and use a dismissal
  surface/action path. The active Rail is one exclusive Eww window.
- Layout adaptation currently comes from `bar-layout.sh` and profile state;
  startup opens Eww on the focused monitor. Full portable multi-monitor shell
  ownership remains an architectural gap.

## Confirmed dead or historical paths

The zero-byte `windows/clock-panel.yuck` and `windows/battery-panel.yuck`, the
59-byte `config.yuck` fragment, the retired `update-loop.sh`, and historical
`backups/` content are not active runtime paths. They were not ported and were
not deleted.
