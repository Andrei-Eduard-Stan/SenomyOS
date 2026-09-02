# SenomyOS Runtime Inventory

Last read-only verification: 2026-08-26.

Runtime facts can change. Recheck them before relying on them for a mutation.

The current T480 is the reference development machine, not the target hardware
specification for SenomyOS.

## Paths

```text
User/home:              /home/Duku
Live Eww repository:    /home/Duku/.config/eww
Current-session config: /home/Duku/.config/hypr/hyprland.lua
Reviewed Lua source:    /home/Duku/.config/eww/hyprland.lua
Live legacy config:     /home/Duku/.config/hypr/hyprland.conf
Legacy tracked mirror:  /home/Duku/.config/eww/hyprland.conf
Recovery snapshot:      /home/Duku/SenomyOS-recovery/20260719-170831
Out-of-scope clone:     /home/Duku/Projects/SenomyOS
```

## Git

```text
Remote:  https://github.com/andrei-eduard-stan/senomyos.git
Branch:  revival/live
Base:    main at da53f52
```

The branch was created while carrying one pre-existing uncommitted change:
`hyprland.conf`.

## Versions and live state

```text
Eww package: 0.6.0-1
Eww binary:  0.5.0 (d87c2fdbfdc012e76d229e4e9ea3325bc0f23e89)
Hyprland:    0.56.2
Monitor:    eDP-1, 1920x1080, approximately 60Hz, scale 1
Eww window: main-bar
```

The package and binary lines are not evidence of a stale install. Commit
`d87c2fdbfdc012e76d229e4e9ea3325bc0f23e89` is upstream tag `v0.6.0`, whose
Cargo manifest still embeds version `0.5.0`; `pacman -Qkk eww` reports no
altered package files.

At inspection:

- `hyprctl configerrors` returned no errors;
- `workspaces.service` was active;
- positive workspace 2 was active and occupied; the special workspace was
  correctly excluded from the Rail;
- the dual-battery JSON updated successfully;
- the tracked and live Hyprland configs matched;
- one Eww daemon owned the 64px `main-bar`;
- Hyprland reported the bar layer at `y=1016`, height `64` on the 1080px
  display; the styled visible islands are 56px high with a small safe inset;
- the standard Rail exposes only real positive workspace IDs plus the active
  positive workspace; empty destroyed workspaces do not remain as anchors;
- one event-driven notification listener and one
  `swaync-client --subscribe` process published a real count of 6 with DND
  false.

The installed Eww package metadata and binary self-reported version disagree.
The current AUR package builds the displayed binary commit, so SenomyOS treats
the binary behavior as the compatibility target until packaging is corrected.

## Hyprland compatibility baseline

The tracked and live Hyprland configs matched byte-for-byte at inspection.

SHA-256:

```text
006798c93570efc32fc8182dda649679429d660525d81127733d3a26677287c3
```

The compatibility changes were committed as `f9e1402`:

- remove obsolete `dwindle:pseudotile`;
- route Mod+J layout splitting through the new dispatcher;
- use `suppress_event` window-rule syntax;
- use `no_focus on` and `match:*` window-rule syntax.

The legacy update-loop autostart was removed as `547bab3`. The tracked and live
files matched and Hyprland reported no errors after both commits.

The 2026-07-25 runtime repair also:

- removed the obsolete manual 40px bottom reservation;
- imports the Hyprland session environment before restarting
  `workspaces.service`;
- starts Eww through `scripts/start-eww.sh`, which waits for the daemon IPC
  socket before opening `main-bar`.

## Verified tools

Present:

```text
git
eww
hyprctl
jq
upower
pamixer
nmcli
pactl
wpctl
paru
pacman
notify-send
systemctl
journalctl
ps
free
uptime
fc-match
rg
less
```

Missing at inspection:

```text
gh
checkupdates
yay
```

Use `git --no-pager`. Prefer `rg` for repository searches.

Installed relevant fonts:

- Symbols Nerd Font Mono
- JetBrainsMono Nerd Font

## Working components

### Workspace listener

`workspaces.service` runs:

```text
/home/Duku/.config/eww/scripts/workspaces.sh
```

It listens to Hyprland's `.socket2.sock` through `socat`. Relevant workspace,
window, and monitor events trigger a short debounce followed by one
authoritative snapshot from `workspaces`, `activeworkspace`, and `clients`.
The listener publishes both the legacy `1 2 [3]` string and structured
workspace/application JSON.

At startup, the listener validates its inherited Hyprland signature against
the expected socket. If the service manager did not receive the session
environment yet, it discovers the newest valid runtime through
`hyprctl instances -j` and exports the recovered instance and Wayland socket.
The user unit uses a two-second failure retry with start limiting disabled, so
an early login race cannot permanently strand workspace state at `loading`.

Semantic change detection compares only the normalized `data` object, excluding
the changing observation timestamp. A 10-second cached heartbeat restores state
after an Eww restart, and a 30-second full snapshot protects against missed
events or icon-map edits. Every publish still requires a successful `eww ping`,
so the listener cannot create a competing daemon while the shell is
intentionally restarting. A closed event socket exits the script and lets
systemd reconnect it. Application icon names are resolved once against standard
XDG icon and pixmap locations and passed to Eww as image paths because the
installed Eww 0.5.0 build does not reliably paint theme-icon names.

Standard and compact normalization now retains a stable floor of five visible
workspace slots while preserving every real workspace above that floor.
Narrow mode keeps active and occupied slots; phone mode keeps the active slot.
No placeholder application is fabricated for an empty workspace.

### Dual-battery collector

`scripts/battery.sh` uses UPower and `jq`. It detected two batteries and
generated valid compact JSON.

The detailed Power collector observed two present ThinkPad packs:

- BAT0: LGC `01AV420`, Li-poly, 23.94 Wh design, 21.35 Wh full,
  approximately 89.2% health, 19 cycles;
- BAT1: SANYO `01AV425`, Li-ion, 48.84 Wh design, 40.64 Wh full,
  approximately 83.2% health, 28 cycles.

Both expose UPower charge-threshold support at 75/80. Neither exposes a battery
temperature field through the current sysfs driver. TLP 1.10.2 is active with
automatic switching, performance configured for AC, balanced configured for
battery, Intel P-state, and a current `balance_power` energy preference.
`pkexec`, polkitd, and the installed `polkit-gnome` authentication agent are
available. Hyprland starts the agent from its absolute `/usr/lib` path at
login; the current session runs it as the transient
`senomy-polkit-agent.service`. Power profile actions are therefore unlocked
behind their confirmation and graphical authorization flow.

### Basic sources

- `pamixer` returned a numeric volume and mute state.
- `nmcli` returned the active Wi-Fi connection.
- Eww time polling worked.

### Portable system summary

`scripts/performance-live.sh` now owns the persistent system sample. It passed:

- `bash -n`;
- successful live JSON validation;
- total and eight-core CPU delta validation;
- memory, root NVMe, active Wi-Fi, PSI, temperature, fan, and i915 discovery;
- explicit availability fields for optional sources.

It is connected to Eww as `system_status` and currently polls every two seconds
for the bar telemetry through `scripts/performance-history.sh sample`.

### Portable audio summary

`scripts/audio-status.sh` was added after the initial inspection. It passed:

- `bash -n`;
- successful JSON schema/type assertions against the live PipeWire server;
- default output/input normalization;
- monitor-source exclusion;
- unavailable-audio-server error validation;
- missing-dependency error validation.

It is read-only and connected to Eww only while the volume flyout or Audio
section is visible. Live verification found one default output at 55% and one
default input. `scripts/volume.sh` is a separate allowlisted action helper.

### Performance Dashboard sources

The six-route read-only Performance Dashboard is connected:

- `performance-live.sh` supplies synchronized two-second current CPU,
  per-core, memory, pressure, root-disk, active-network, frequency, thermal,
  fan, and optional GPU values;
- `performance-processes.sh` supplies at most twelve instantaneous process rows
  every three seconds only on the Processes page;
- `performance-status.sh` supplies host, topology, package, service, socket,
  thermal, GPU, network, filesystem, and block-device inventory every 15
  seconds while Performance is open;
- `performance-history.sh` retains one multidomain point at most every five
  seconds in a rolling five-minute runtime cache.

Live verification observed Arch Linux, kernel `7.1.4-arch1-1`, 797 packages,
eight logical Intel i5-8250U threads, ten temperature sensors, one ThinkPad fan,
Intel i915 graphics, the root NVMe device, active Wi-Fi, both service managers,
aggregate socket state, and valid root-filesystem usage.

Live follow-up verification on 2026-07-28 observed 47 retained samples, a
mode-0600 cache at
`/run/user/1000/senomyos/performance-history.json`, and the same older
timestamps after Performance was closed, Eww was restarted, and Performance
was reopened. The replacement vertical bars grow upward from the baseline.
Rate charts retain real current values and use a disclosed dynamic scale.

Isolated and live visual verification covered Overview, CPU + GPU, Memory,
Storage, Network, and Processes at 1920x1080. The process sampler consistently
returned 12 rows in approximately 0.43–0.45 seconds. After leaving Processes,
one already-scheduled sample completed and the timestamp then remained fixed
across the next interval, confirming that the collector stopped. Detailed power
controls remain intentionally absent from Performance pending the Control
Centre Power implementation.

The final live Eww restart hydrated samples older than the replacement daemon
from the same rolling cache. The cache was 24,352 bytes with mode 0600 at
inspection. One Eww process owned exactly `main-bar` and `performance`, and the
live collector exposed root NVMe, `wlp3s0`, PSI, Intel P-state, coretemp,
ThinkPad fan, and i915 data without a source error.

### Portable network summary

`scripts/network-status.sh` was added after the initial inspection. It passed:

- `bash -n`;
- successful JSON schema/type assertions against NetworkManager;
- primary non-loopback connection selection;
- connected Wi-Fi and disconnected Ethernet normalization;
- unavailable-NetworkManager error validation;
- missing-dependency error validation.

The collector is read-only, never triggers a Wi-Fi scan, and reads no saved
credentials. Eww polls it every four seconds only while Control Centre Network
is visible.

Live completion verification on 2026-07-30 observed:

- 13 visible SSIDs grouped from the cached AP inventory;
- seven hidden access points reported only as a count;
- the active dual-band SSID joined to its saved UUID and autoconnect state;
- four saved Wi-Fi profiles without authentication material;
- a clean isolated Eww parse and GTK-safe stylesheet;
- the live panel rendering nearby networks, signal tracks, saved/security
  badges, manual scan, hidden-network entry, profile management, and confirmed
  destructive controls;
- no connectivity mutation during validation;
- final live state restored to `main-bar`, `active_surface=none`, and
  `active_flyout=none`.

## Confirmed problems

### Resolved startup races

The legacy `update-loop.sh` is no longer running. Only the systemd-managed
`scripts/workspaces.sh` process remains.

The workspace service previously started before Hyprland, missed
`HYPRLAND_INSTANCE_SIGNATURE`, retried five times in roughly one second, and
became permanently blocked by `start-limit-hit`. The listener now discovers a
valid runtime instance itself, the unit retries at a bounded cadence without a
start-limit lockout, and the Hyprland startup command imports the session
environment, clears any prior failed state, and restarts the enabled service in
one ordered command.

Live verification on 2026-07-29 started the listener with its Hyprland
variables removed, produced a valid workspace/application snapshot, and then
restored the installed service. A workspace 1 to 2 to 1 round trip updated Eww
on each event and returned workspace 1 with the Visual Studio Code icon path.
The service remained active with one `socat` connection afterward.

Eww previously started `daemon` in the background immediately before `open`,
which could split the daemon and visible bar into disconnected processes.
`scripts/start-eww.sh` now waits for `eww ping` before opening the bar.

### Control Centre content

- All ten approved Control Centre routes have connected content. Network,
  Audio, Power, Applications, and Settings expose bounded allowlisted actions;
  Overview, Calendar, Input, and Device Management provide truthful live or
  read-only inventory. Unavailable capabilities remain explicit rather than
  fabricated.
- Appearance remains a separate tenth route under decisions D058 and D072. It
  owns bounded presentation preferences while Settings owns runtime and shell
  maintenance.
- Applications is now the first implemented Control Centre section. The Rail
  exposes an overflow arrow; its flyout owns the single native StatusNotifier
  host, while the section shows registry-backed managed application cards.
- Flameshot 14.0.0 is installed, enabled through the linked
  `flameshot.service` user unit, and verified as `Type=dbus` with
  `org.flameshot.Flameshot`.
- Live verification on 2026-07-27 observed Flameshot as systemd-active,
  D-Bus-ready, and registered in Eww's tray watcher. The Applications poll
  reported one running managed application and one native tray item.
- Live verification on 2026-07-28 moved Flameshot out of the Rail and into the
  tray overflow. Closing and reopening the flyout preserved the running service
  and restored one registered native item. Menus remain owned by the native
  tray item rather than being reimplemented by SenomyOS.
- The class-and-initial-title Hyprland rule was tested with the live Performance
  panel open. `Capture Launcher` floated at 940x995 while VS Code remained
  1876x991 and tiled; closing the test launcher left `flameshot.service` active.
- Flameshot actions are fixed inside `scripts/background-apps-action.sh`.
  Capture, launcher, configuration, and start are immediate explicit actions;
  stop uses an Eww confirmation state that clears when the panel closes or the
  selected section changes.
- The battery control opens Power; the two-row clock opens Calendar.
- The rail displays one combined battery summary instead of placing both
  physical batteries inline. Dual-battery detail remains in tooltips and the
  future Control Centre Power implementation; Performance keeps only a compact
  two-battery snapshot.
- Volume opens a compact mute/slider flyout with a route to the full Audio
  section.
- CPU/MEM/UP opens the separate six-route Performance Dashboard.
- The bar, Insights header, and Performance observer share the
  manifest-driven `senomy-avatar` widget. Seven code-native placeholder states
  are available while final chibi and portrait artwork is developed.
- Ambient personality lines come from a versioned dialogue catalog, remain
  stable for 15-minute slots, and occasionally select an uncommon English/Latin
  line. Verified low-power and unavailable-source messages take priority.
- Senomy Insights opens as a separate surface with live procfs and UPower
  observations plus an explicitly planned maintenance record.
- Insights and the Control Centre follow the one-primary-surface rule.
- Performance participates in the same primary-surface rule, and
  `active_flyout` prevents the volume and tray flyouts from overlapping each
  other or any primary surface.
- Bar triggers and panel close buttons now route through
  `scripts/surface-state.sh`. It validates section names, serializes
  transitions, and reconciles window instances with `active_surface`.
- Every primary surface and flyout now opens with one transparent
  `surface-dismiss` event layer. Live compositor geometry placed it over the
  1920x1035 usable area, below the `overlay` panel and exactly above the 45px
  exclusive bar. Outside click and Escape use the same `dismiss` action, while
  another bar trigger replaces the old contextual window.
- `scripts/reload-eww.sh` is the supported state-preserving reload command.
  It closes the old window set, stops the daemon, opens and verifies `main-bar`,
  then restores the dismiss layer and remembered surface at responsive size.
  It verifies those windows and restores validated state. Raw `eww reload` is
  unsupported.
- The tracked Hyprland mirror contains one non-consuming Escape binding that
  routes known SenomyOS windows through `surface-state.sh dismiss`. The live
  config is byte-identical to the tracked mirror, Hyprland reports no config
  errors, and the registered binding reports `non_consuming=true`.
- Live transition validation on 2026-07-29 exercised Control Centre Network,
  volume flyout, Insights Diagnostics, Performance, and dismiss in sequence.
  Every intermediate state contained exactly one contextual window plus the
  shared dismiss layer and main bar; the final state contained only `main-bar`.
- Eww 0.5.0 accepts a Boolean `:focusable` window value rather than the
  string-form layer-shell value described by newer documentation. Isolated
  validation caught this before live reload. The same pass replaced an invalid
  numeric Applications icon preset with GTK's supported `large-toolbar`
  preset.
- Isolated reproduction on 2026-07-29 proved that a focusable Eww overlay
  causes `flameshot gui` to enter Hyprland as a 931x991 tiled client beside VS
  Code. With no contextual window it enters as the expected 1920x1080
  fullscreen client. Tray, volume, and Performance therefore use
  `:focusable false`; the screenshot action dismisses coordinated context
  windows and allows one compositor repaint before capture. A live guarded
  capture reached 1920x1080 fullscreen but revealed that a fullscreen-only
  fallback could still resize the underlying tile; the exact capture rule now
  floats before fullscreen to prevent tiling insertion.
- The reference CPU is an Intel i5-8250U with four physical cores and two
  threads per core. Linux exposes eight logical CPUs numbered zero through
  seven. Performance labels them as logical threads and displays human-facing
  thread numbers one through eight while retaining each Linux CPU ID.
- Eww 0.5.0 evaluates expressions inside hidden Updates error rows. Directly
  indexing nullable `error` objects caused the application response channel to
  fail while opening Insights. Those labels now use optional access and
  fallbacks, and unsupported `wrap-mode`, `truncate`, and `sensitive`
  attributes were removed.
- Eww's automatic source watcher can still reset `defvar` values to defaults
  while retaining an existing window instance. This was reproduced while
  compacting Diagnostics and then reconciled through
  `scripts/surface-state.sh`. The supported explicit full restart preserves
  state; persistence across an unsolicited watch reload remains a separate
  limitation.
- A direct `eww open` issued during an IPC transition can bootstrap a competing
  daemon against the same config path. This occurred during follow-up visual
  QA, produced two stacked bars, and was recovered by terminating only the
  older stale PID. The coordinator now runs ordinary Eww calls with
  `--no-daemonize` under a three-second timeout and reserves auto-start for its
  verified reload path. A post-fix tray transition retained one reachable
  daemon and one bar.
- Live coordinator validation on 2026-07-26 preserved
  `active_surface=insights`, `control_section=network`,
  `insights_section=updates`, `timeline_source=kernel`, and
  `timeline_follow=false` across the supported restart. The final runtime had
  one Eww process, one 1920x44 bar layer, and one 750x700 Insights layer.
  Cross-surface switching, same-section close, the panel close action, and the
  bar Insights toggle all preserved the one-primary-surface invariant.
- The surface-state fixture covers ordering, cross-surface switching,
  same-section close, full restart restoration, failed window queries, a
  missing Performance window, and rejected non-allowlisted input.
- Timeline can display up to 40 sanitized events from the user journal, system
  journal, kernel journal, or current Eww log. Continued polling runs only for
  the selected source while Timeline is visible and Follow is enabled.
- Updates reads a local cache only while its tab is visible. Official and AUR
  checks are separate manual actions; neither path installs packages.
- `checkupdates` remains unavailable, so the verified official fallback is
  `pacman -Qun` against the local sync databases. On 2026-07-26 that fallback
  completed successfully with zero recorded updates; the newest local database
  timestamp was 2026-07-25 00:30 local time.
- During live panel verification on 2026-07-26, the dedicated AUR and official
  actions were activated in sequence. The AUR query completed at 20:31:55 and
  the official local-database query at 20:31:57; both returned zero updates.
  The AUR result records the disclosed `aur.archlinux.org` query, and no
  package-check process remained afterward.
- Fixture validation additionally covered successful non-empty, malformed,
  failed, partial, and truncated package result states without further network
  disclosure.
- Diagnostics exposes six read-only tasks from one internal catalog: failed
  user units, the workspace listener, recent user warnings, memory pressure,
  persistent filesystems, and the UPower inventory. The result poll reads only
  `${XDG_CACHE_HOME:-$HOME/.cache}/senomyos/diagnostics.json`; tasks run only
  after their dedicated button is activated.
- The Diagnostics fixture covers exact argument forwarding, task-ID injection
  rejection, mode-0600 cache writes, home-path normalization, credential-line
  redaction, output truncation, missing dependencies, nonzero exits, timeout,
  malformed cache input, and concurrent-run locking.
- Live Diagnostics verification on 2026-07-26 ran the allowlisted
  `workspace-service` task successfully. Eww consumed a `COMPLETE`, exit-0,
  `systemctl-user` result containing 12 sanitized lines; the home path appeared
  only as `$HOME`. The cache was mode `0600`, no task process remained, the
  compact catalog left the terminal header and command visible in the initial
  viewport, and the runtime retained one Eww process with one 1920x44 bar and
  one 750x700 Insights layer.
- Insights includes a sixth Wiki route. Isolated Eww validation loaded three
  local Markdown articles into Start, Shell, and Senomy categories, rendered
  headings, lists, code, tables, quotes, and internal links, and changed all
  visible avatars through one `chibi_state` update.
- Final live validation on 2026-07-29 exercised tray repeated-close, volume
  repeated-close, flyout-to-Control switching, Control-to-flyout switching,
  shared dismissal, Performance repeated-close, and Insights repeated-close
  under a strict error-stopping harness. Eww returned `EAGAIN` during heavy
  window construction, so read queries now retry and mutations are accepted
  only after their window/state postconditions are observed. The final matrix
  completed with `active_surface=none`, `active_flyout=none`, and only
  `main-bar`.
- The final guarded Flameshot regression test started with the live volume
  flyout open. Capture dismissed every contextual Eww layer, produced one
  floating 1920x1080 fullscreen-mode-2 Flameshot client at 0,0, and left VS
  Code unchanged at 1876x991. Closing only the capture client left
  `flameshot.service` active.
- That dismiss-before-capture workaround was superseded on 2026-08-31 by the
  frozen-frame handoff in D111. Live proof started with Insights / Briefing
  mapped, waited for the exact fullscreen Flameshot client, suspended the real
  Insights and dismiss layers while preserving `active_surface=insights`, and
  captured the Flameshot UI visibly containing the complete Insights panel.
  Closing only the capture client restored Insights / Briefing and its shared
  dismiss layer; the shell then returned to idle. The isolated lifecycle test
  also proves that capture calls suspend/restore and never calls `dismiss`.
- Live avatar and Wiki validation switched the shared avatar to `thinking`,
  navigated an internal link to category `shell` / article `panels`, verified
  the catalog title `Contextual Panels`, then restored `idle` and
  `start` / `welcome`.
- `windows/battery-panel.yuck` and `windows/clock-panel.yuck` remain empty
  legacy files and are not used by the current Control Centre.

### Obsidian Rail completion validation — 2026-07-31

- Workspace 1→2 event publication was observed in 462ms and restored to 1.
- PipeWire mute state reached Eww in 76ms and was restored to unmuted.
- Volume open/close improved from 9979/8569ms to 814/264ms after correcting
  explicit postcondition success; same-section switching measured 48ms.
- The UX-freeze regression harness now passes twelve exact widget-path
  transitions. A generation-tokened asynchronous dismiss guard reduced cached
  Volume to 242–266ms open and 190–233ms close; complex primary surfaces remain
  approximately 0.9–1.6s and require further widget-construction profiling.
- Permanent Rail telemetry now uses a 33–54ms procfs collector after bootstrap.
  The former approximately 482ms synchronized sampler is gated to Performance;
  its timestamp remains frozen while idle and retained history survives panel
  close/reopen. Appearance and avatar recovery scans run every 60 seconds while
  explicit Appearance changes still publish immediately.
- Tray, Volume, Applications, Network, Power, Calendar, Insights, and
  Performance each opened their expected state/window. Network and Power were
  rechecked through retry-safe coordinator status after direct Eww reads
  transiently returned `EAGAIN` while constructing the heavy section.
- Same-trigger close and Insights→Performance replacement preserved the
  one-context invariant. Final state was `active_surface=none`,
  `active_flyout=none`, `dismiss_armed=false`, and only `main-bar` open.
- Runtime contained one Eww daemon, one Hyprland workspace subscriber, one
  `pactl subscribe`, and one `nmcli monitor`. Workspace and Flameshot user
  services were active; tracked/live Hyprland configs matched byte-for-byte;
  `hyprctl configerrors` was empty.
- All shared windows now omit static monitor IDs. Bar-only reload and restored
  Control Centre reload succeeded through focused-monitor `eww open --screen`.
- Every primary surface and flyout passed the exact registered Escape command;
  tray and volume also expose 36px X controls. A close-response race was fixed
  by requiring actual contextual-window disappearance before dismissal returns.
- Insights Reports generated a 40-line, 1241-byte mode-0600 runtime artifact
  with a 34-line preview and no username, home path, or environment dump.
- Overview and Device Management collector routing was corrected and live-
  validated with full internet, one audio card, three network devices, one
  monitor, and five keyboards.

### August 1 production-hardening evidence

- `scripts/validate-shell.sh` passes 18 static contracts; live mode adds daemon,
  single-main-bar, and surface-state checks,
  including SCSS compilation, JSON/catalog validation, responsive monitor
  fixtures, one main bar, daemon reachability, and surface-state validity.
- `scripts/validate-interactions.sh` passes 12 repeat-close, switch, route,
  Escape-equivalent dismiss, and idle-restoration transitions. The August 1
  live run completed all measured transitions in under one second.
- Idle rail telemetry is supplied by `scripts/rail-system-status.sh`; one
  bounded ten-second history sampler remains active while the shell runs so
  Dashboard close/reopen cycles retain a continuous five-minute graph.
- Network and discrete Audio actions expose sanitized operation state in
  `${XDG_RUNTIME_DIR}/senomyos/*-operation.json`. Identifiers and credentials
  are excluded, and NetworkManager/PipeWire telemetry remains authoritative.
- Guarded Eww reloads preflight SCSS and definitions before daemon replacement,
  then store a mode-0600 checksummed full-runtime archive after restoration.
  `scripts/recovery-status.sh` reports integrity without extraction, while
  `scripts/recovery-restore.sh` can verify, list, or stage the archive into a
  new directory and cannot overwrite the live tree.
- Static validation now exercises 15 collector contracts, 15 isolated Insights
  task paths plus the host Bluetooth task, five report profile lifecycles, all
  appearance preference categories, and five state-action rejection paths.
- GTK runtime compatibility rejects CSS custom-property color interpolation
  and nullable booleans in Yuck ternaries. Dedicated static gates now prevent
  both regressions. A mocked startup contract verifies healthy cold start and
  explicit rejection of a pingable daemon with no `main-bar` definition.
- Screenshot QA at 1920x1080 confirmed one shared dark/amber visual language
  across the rail, Control Centre, Senomy Insights, Performance Dashboard,
  volume flyout, and tray overflow after runtime parser correction.
- Responsive fixtures include a 390x844 phone viewport. At phone width the rail
  and panel navigation reflow without removing Applications access.
- Host audio currently has one ALSA card but no available PipeWire card profile;
  only `auto_null` is exposed. The Audio panel labels this `DEGRADED` and must
  not describe it as physical signal flow.
- CMF Buds Pro 2 pairing was verified through BlueZ on 2026-08-02. A direct
  connection succeeded while the accessory answered pages; a later reconnect
  truthfully failed with `br-connection-page-timeout`, indicating that the
  remote device did not answer rather than a successful local connection.
- Performance benchmark artifacts are retained privately under
  `${XDG_STATE_HOME:-$HOME/.local/state}/senomyos/benchmarks` as Markdown, PDF,
  status JSON, and a bounded current log.

### August 10 recovery, Notifications, avatar, and benchmark worktree

- Static shell validation passes 21 checks and the collector suite passes 20
  contracts. The new checks use temporary roots and do not run a stress
  workload or mutate the live notification daemon.
- SwayNotificationCenter 0.12.6 is the active notification provider. The
  narrow Senomy receive hook is installed in the user config and SwayNC loaded
  that path after one user-service restart. A visible SenomyOS test popup was
  captured as one private retained entry; actions/hints remain excluded.
- The avatar catalog accepts MIME-validated SVG, PNG, JPG/JPEG, and GIF. Eww's
  installed runtime can animate GIFs but does not reliably scale their
  intrinsic size, so context-sized animated variants are cached privately.
- Performance KPI labels no longer request ellipsis/width limiting. Live visual
  verification at 1920x1080 showed full `CPU`, `MEM`, `I/O`, and `NET` labels.
- `scripts/senomy-shellctl.sh` provides read-only doctor/preflight/incident
  paths and an explicit full restart. Both it and `scripts/start-eww.sh` enforce
  one exact config-matched Eww process and one main bar. Its restart path was
  exercised during the parser incident and restored the healthy invariant.
- A live reload exposed Eww 0.5's unsafe graph-swap behavior when a Yuck parse
  fails. Recovery retained three incident reports and restored one healthy
  daemon/Rail. The old live `eww reload` preflight was replaced by
  `scripts/validate-eww-config.sh`, which parsed a copied tree through a
  separate windowless daemon while the healthy Rail remained untouched.
- The reported duplicate-Rail/frozen-Performance failure was reproduced with
  two exact-config processes: PID 603150 was the reachable explicit daemon and
  owned the correct Rail plus orphaned Performance/dismiss layers, while PID
  604970 retained an `eww open ... performance` command and owned a second Rail.
  Ordinary Eww clients now use `--no-daemonize`, and process cleanup includes
  every exact-config Eww command. After recovery, opening and X-closing
  Performance retained one PID (642359); Hyprland showed one 1920x44 Rail at
  y=1036, the expected Performance/dismiss layers only while open, and only the
  Rail again after close. Eww state returned to `active_surface=none`.
- Benchmark schema 2 defines a roughly 70-second Quick profile and roughly
  210-second Standard profile, sustained CPU/memory/compression load, bounded
  256/512 MiB storage evidence, thermal/low-power/low-memory stops, safe
  cancellation, and private rich Markdown/PDF/checksum reports. Only read-only
  plan/status contracts have been run; no benchmark workload has been started.
- ImageMagick, OpenSSL, gzip, zstd, sensors, lspci, and lsusb are available.
  `stress-ng`, `sysbench`, `fio`, `smartctl`, `nvme`, `dmidecode`, and
  `inotify-tools` remain optional and were not installed automatically.

### August 13 shared masthead and Control Centre geometry

- Control Centre, Performance Dashboard, and Senomy Insights now use one
  shared primary-surface masthead. Live captures at 1920x1080 confirmed the
  same avatar block, eyebrow/title/subtitle hierarchy, status-chip row, close
  target, padding, and spacing while preserving each surface's own identity.
- Control Centre has ten distinct routes: Overview, Network, Audio, Power,
  Calendar, Input, Device Management, Applications, Appearance, and Settings.
  Appearance remains a separate route so it can grow independently.
- Every Control Centre route was opened in the live compositor and measured at
  `888x700`. A direct Overview-to-Power in-place switch retained that geometry,
  removing the earlier Power-only width expansion.
- The Insights Wiki catalog currently renders seven bounded Markdown articles
  across four categories with no catalog warnings or errors. It documents the
  three primary surfaces, ten Control Centre routes, notification retention,
  benchmark schema 2, avatars, and guarded shell recovery.
- A guarded shell restart briefly returned a false-negative IPC timeout while
  the daemon was becoming reachable. Immediate doctor checks confirmed one Eww
  process, one Obsidian Rail, a healthy workspace listener, and no Hyprland
  configuration errors. The incident report is retained at
  `${XDG_STATE_HOME:-$HOME/.local/state}/senomyos/recovery/incidents/shell-20260813-073929.txt`.

### August 16 user deployment foundation

- `deploy/manifest.json` is the repository-owned component allowlist. Eww is
  explicitly managed in place, Hyprland and Rofi are ready complete-file user
  components, the Thunar workspace/action layer is a ready mixed
  replace-and-merge component, GTK 3 is a ready namespaced component, and the
  user manifest routes privileged SDDM/recovery work to a separate system
  manifest. At this August 16 checkpoint Plymouth and GRUB still reported
  planned reasons; their later inert staging state is recorded below.
- `scripts/senomy-deploy.sh` provides read-only component listing, planning,
  and receipt history. Confirmed apply and rollback are limited to regular
  non-symlink files beneath allowlisted XDG roots inside the user's home.
- Deployment receipts and backups are private under
  `${XDG_STATE_HOME:-$HOME/.local/state}/senomyos/deployments`. Checksums,
  modes, previous existence, and lifecycle status support verified restoration;
  unrecorded post-deployment drift blocks manual rollback.
- The isolated deployment contract passed plan, guarded Thunar merge,
  update/create apply, private receipt, history, drift refusal, automatic and
  manual rollback, planned-component refusal, and target traversal rejection
  without touching live user configuration.

### August 16 Command Lens repository prototype

- Rofi 2.0 accepts the repository-owned Command Lens config and theme through
  dump-only parser paths. The standard theme is 800px wide, anchored 72px from
  the focused-window monitor's top edge, and shows eight rows. The wrapper
  reduces width, offset, and row count below 900 logical pixels and can apply a
  larger explicit touch density. Rofi media rules are not used for this because
  the first live capture showed them expanding the base 800px window to a
  monitor percentage.
- `senomy-command-lens` registers native Applications and Windows scopes plus
  bounded Files and allowlisted Actions scopes. The wrapper exposes only a
  validated mode selector and asks Rofi for monitor `-4`, the monitor containing
  the focused window.
- The Files fixture passed spaces, quotes, a leading dash, non-ASCII text,
  hidden-file exclusion, exact workspace-wrapper argument preservation, and
  rejection of a real path outside its configured home-relative root.
- The Actions fixture passed fixed surface, screenshot, and Thunar dispatch
  with unavailable-state behavior and no destructive session catalog entries.
- The `rofi` deployment component contains five complete-file entries for XDG
  config/theme and user-bin adapters. Recorded deployments produced the
  reviewed live state; the shared-token alignment updated only the theme under
  receipt `20260816-113850-rofi-323735`.
- The adapter update that routes file opens and reveals through
  `senomy-file-workspace` is recorded by receipt
  `20260816-115354-rofi-389909`.
- Manual APPS, FILES, WINDOWS, and ACTIONS launches passed on the focused
  monitor. The captures confirmed the corrected explicit width, dark theme,
  selected-row accent, scope tabs, counts, and fixed action surface. Test Rofi
  processes exited without selecting an action.
- A later standalone APPS capture confirmed that the canonical `#9892e8`
  accent and shared surface/text values did not regress geometry, hierarchy,
  counts, selection, or footer readability.
- The tracked and live Hyprland configurations route `Super+R` to Command Lens
  and `Super+E` to the file workspace under receipt
  `20260816-122506-hyprland-505291`.

### August 16 Thunar workspace and action layer

- Thunar 4.20.9 owns mode-0600
  `${XDG_CONFIG_HOME:-$HOME/.config}/Thunar/uca.xml`. The unrelated Open
  Terminal Here action is preserved and the deployed merge adds Copy Path and
  Copy SHA-256. `accels.scm` is mode 0644 and remains untouched.
- Read-only Xfconf inventory found detailed-list view, preview enabled, tree
  side pane, hidden files visible, modified-descending sort, and a toolbar that
  includes the existing custom action. These preferences are preserved rather
  than imported into portable defaults.
- `components/file-manager/thunar/actions.json` registers only Copy Path and
  Copy SHA-256. `senomy-thunar-action` implements the two fixed verbs with
  bounded absolute-path validation; no arbitrary command route exists.
- `scripts/thunar-uca-merge.py` builds a deterministic candidate, preserves
  unrelated user actions, replaces only known SenomyOS unique IDs, and omits
  actions with missing dependencies. The candidate passed XML validation and
  preserves the current Open Terminal Here command.
- The live action merge is recorded by receipt
  `20260816-114804-thunar-368055`. The final workspace wrapper is recorded by
  `20260816-120054-thunar-415991` after live acceptance exposed and eliminated
  a duplicate-window path.
- `senomy-file-workspace` applies the installed theme only to a fresh daemon,
  started through a collected transient user service with a detached `nohup`
  fallback. It waits for the owned D-Bus name before explicitly opening one
  window or using GIO plus `org.freedesktop.FileManager1.ShowItems` for safe
  file reveal. An existing Thunar process is reused unchanged. The installed
  Thunar command line has no `--select` option.
- The isolated Thunar and deployment fixtures passed idempotent merge, user
  action preservation, capability detection, path safety, process blocking,
  FileManager1 argument preservation, single-window selection, receipt
  verification, and exact rollback. Live visual acceptance showed one themed
  window and the SenomyOS submenu containing both managed actions; closing
  Thunar left the deployed XML checksum unchanged.

### August 16 portable theme and GTK 3 prototype

- `appearance/tokens.json` is the schema-1 portable registry for the
  core Obsidian palette, fonts, geometry, and compact/standard/touch row sizes.
  `validate-theme-contract.sh` verifies the Eww, Rofi, and GTK 3 projections.
- `appearance/file-manager/gtk3/SenomyOS` is a namespaced GTK 3 source. It imports
  GTK's built-in Adwaita contained stylesheet, then applies SenomyOS surfaces,
  typography, borders, focus/selection, tree/list, sidebar, tab, menu,
  scrollbar, semantic, and Thunar-specific hierarchy states.
- GTK 3.24.52 loaded the full source through `Gtk.CssProvider` without a CSS
  parsing error. The headless run emits expected icon-screen diagnostics that
  are suppressed by the validator unless parsing fails.
- An isolated GTK 3 Network Connection Editor visual test used a temporary
  home and `GTK_THEME=SenomyOS`, made no saved network change, and closed its
  test process. It exposed light Adwaita action-bar and toolbutton states; both
  were corrected, and the final dark enabled/disabled control capture passed.
- Installed pavucontrol 6.2 links GTK 4, so it correctly remained unaffected by
  the GTK 3 theme. Isolated Thunar also passed the dark GTK 3 visual check.
- The namespaced theme is installed beneath the user data root under receipt
  `20260816-115058-gtk3-378659`. No global GTK preference was written;
  additional dialog, narrow-layout, and touch-density QA initially remained.
- Screenshot-led Preferences and Properties checks exposed white native stack
  pages behind pale text. Explicit dialog content planes and the separately
  namespaced 48px `SenomyOS-Touch` projection were deployed under receipt
  `20260816-122436-gtk3-502607`; both variants pass headless GTK parsing.
- Live first-launch QA on August 20 showed that ordinary D-Bus activation
  started `/usr/bin/Thunar --daemon` without the client `GTK_THEME`. The wrapper
  now starts the fresh daemon in a collected transient user service, and the
  deployed process was verified with `GTK_THEME=SenomyOS` under receipt
  `20260820-085707-thunar-96738`.
- Final notebook page/background selectors were deployed under GTK receipts
  `20260820-085705-gtk3-96749` and `20260820-085854-gtk3-103875`. Clean
  1120x760 main, 638x874 Preferences, 720x760 Properties, and 640x720 narrow
  captures remained fully dark and readable.
- Touch QA verified a clean daemon with `GTK_THEME=SenomyOS-Touch` and 48px
  primary workspace targets. The first Preferences capture was 654x1078 and
  exceeded the screen; bounded notebook-dialog content geometry reduced the
  clean result to 646x995 at y=21 with title and actions visible. The final
  touch source is deployed under receipt `20260820-090631-gtk3-123704`.
- Automatic touch density still reads only the bounded SenomyOS font-scale
  preference. The global GTK preference was rechecked as `Adwaita`, both live
  deployment plans are unchanged, and the disposable QA daemon was closed.
- Ordinary application-menu QA later showed Gio resolving the system
  `/usr/share/applications/thunar.desktop`: the desktop-session PATH excludes
  `~/.local/bin`, so `TryExec=senomy-file-workspace` made the user override
  ineligible. The corrected entry removes `TryExec` and invokes
  `~/.local/bin/senomy-file-workspace` through a validated shell command. It is
  deployed under receipt `20260820-092528-thunar-185130`; Gio now resolves the
  user entry, and an ordinary `gtk-launch thunar` produced a visible dark home
  window whose daemon carried `GTK_THEME=SenomyOS`.

### August 20 unified appearance, SDDM, lock, and recovery sources

- `appearance/` now owns the editable Eww, Rofi, GTK 3, SDDM, Hyprlock, and
  shared-background sources. `appearance/tokens.json` projects through one
  generator into each native styling language.
- SDDM 0.21.0 and its Qt 6 greeter are installed and enabled. The SenomyOS
  theme is installed and selected beneath `/usr/share/sddm/themes`, has been
  tested at the real greeter, and has not been restarted from the development
  session. The vertically centered input and generated blurred-background
  update is deployed under system receipt
  `20260820-175255-sddm-237550` for the next greeter start.
- Hyprlock 0.9.6 is installed and its user-level configuration and guarded
  launcher are deployed. The generated source uses `path = screenshot` with
  local blur and contains no command-launching click widget. Receipt
  `20260820-171259-hyprlock-99741` installs the SDDM-matched rail and shared
  projected icons. A nested 1920x1080 compositor test acquired the session-lock
  protocol and the screenshot comparison passed without locking the real
  session.
- `Super+L` is active for the deployed `senomy-lock` wrapper. It locks the
  current session rather than ending it. The current `.conf` source still runs
  this session, while parser-verified `hyprland.lua`, one `swaybg` launcher,
  and the generated project wallpaper are deployed for the next login under
  receipt `20260820-174952-hyprland-229205`. A nested runtime check reported no
  config errors and exposed the expected native Lua E/R/L binds.
- The moved Rofi and GTK shared-token projections were applied under receipts
  `20260820-103501-rofi-340452` and `20260820-103501-gtk3-340450`; both now
  plan as unchanged and neither operation restarted an application.
- `deploy/system-manifest.json` and `scripts/senomy-system-deploy.sh` provide
  confirmed root-owned SDDM/recovery apply and checksummed rollback without
  restarting SDDM, logging out, or rebooting.
- Recovery sources implement a separate authenticated system account,
  nologin shell, Wayland-only exact session guard, minimal verified Hyprland
  compositor, fixed GTK password UI, exact no-argument sudo rule, and bounded
  root helper. The file payload passed its root post-check and is deployed
  under receipt `20260820-175747-recovery-252803`. That run exposed a deployer
  defect: the restrictive umask created `/etc/senomyos` as mode 0700, so the
  recovery session cannot traverse it. The source now explicitly manages
  searchable directory modes, but the repair still needs one authenticated
  root apply. The independent account credential remains a separate
  interactive secret and is currently unprovisioned.

### August 20 profiles, bootstrap, and inert boot staging

- The selected portable profile is `automatic`, deployed under receipt
  `20260820-174950-profile-automatic-228993`. `desktop`, `touch`, and `narrow`
  variants share the same validated schema and remain explicit alternatives.
- `deploy/packages.json` currently has no missing required package on this
  machine. `deploy/services.json` currently has no required enablement gap.
  Eww remains an explicit AUR boundary; Plymouth is optional and is not
  installed on this host.
- `senomy-bootstrap.sh` exposes read-only audit/plan, confirmed package
  installation, transactional first boot, and interactive recovery
  provisioning. It does not reload Hyprland, restart SDDM, regenerate boot
  files, log out, or reboot.
- Clean acceptance applied the real user manifest into an empty temporary home
  and staged every ready system entry into an empty temporary root. QML, Lua,
  desktop, sudoers, Python, shell, XML, and generated-asset checks passed. This
  is clean-root evidence, not a VM cold boot.
- The GRUB theme is inertly staged under receipt
  `20260820-175751-grub-staged-251573`. The Plymouth theme files were staged
  under `20260820-175750-plymouth-staged-253596`, but the same corrected
  directory-mode defect leaves `/usr/share/plymouth` at mode 0700 until the
  pending root repair, and the optional Plymouth runtime is absent. GRUB status
  reports staged; Plymouth status truthfully reports not staged to the desktop
  user. Neither theme is selected and no initramfs or `grub.cfg` was
  regenerated. Activation remains blocked without disposable-machine cold-
  boot and recovery-boot evidence.

### August 21 explicit scale, bounded panels, and boot source registry

- The automatic profile now owns display scale 1. The current eDP-1 compositor
  state is 1920x1080 at scale 1 rather than the unintended 1280x720 logical
  work area produced by Hyprland's PPI-derived scale 1.5.
- The updated automatic profile, next-session Hyprland Lua, compact Command
  Lens, and Hyprlock layout indicator are deployed under user receipts
  `20260821-112019-profile-automatic-130404`,
  `20260821-112020-hyprland-130648`,
  `20260821-112022-rofi-131000`, and
  `20260821-112025-hyprlock-130402`.
- The live Eww daemon was replaced through the supported reload path after an
  isolated parse. Control Centre resolves to 888x700, Insights to 750x700, and
  Performance to 1480x760 on the reference display.
- Live compositor QA opened all seven Performance routes. Overview, CPU/GPU,
  Memory, Storage, Network, Processes, and Benchmarks each remained at x=220,
  y=264, 1480x760; long GPU/sensor strings no longer enlarge the layer.
- SDDM source now exposes selectable UK/US controls in desktop and narrow
  layouts. Hyprlock shows the active UK/US layout and the locked-session
  `Super+Space` switch. The SDDM source is installed under receipt
  `20260821-113143-sddm-193198`; SDDM has not been restarted.
- `appearance/boot/sequence.json`, a generated SenomyOS mark, GRUB/Plymouth
  projections, the unified `plan/apply boot` staging entry point, and
  `docs/BOOT_SEQUENCE.md` now centralize the owned boot appearance. Firmware
  and arbitrary boot-video playback remain explicitly unmanaged/unsupported;
  boot activation remains blocked. Updated GRUB and Plymouth sources are
  inertly staged under receipts `20260821-112451-grub-staged-146609` and
  `20260821-112458-plymouth-staged-144327`.

### August 25 shared OS-mark foundation

- `appearance/shared/brand/senomyos-mark.svg.in` is the only editable OS-mark
  geometry and now defines the approved monochrome three-lancet motif.
- The appearance generator derives a token-resolved SVG plus deterministic
  64px, 128px, and 256px PNGs. The former boot SVG/PNG paths remain generated
  regular-file compatibility projections so the staged GRUB/Plymouth manifests
  and their rollback receipts do not change shape.
- No Eww, Rofi, SDDM, Hyprlock, or Thunar consumer was added in this foundation
  stage. Their native placements and deployment entries require separate visual
  and parser-level review before live application.

### August 26 dynamic broken-island Rail correction

- The 142px exclusive Eww window remains, but its visual background, enclosing
  border, radius, and shadow are transparent. Only unboxed workspace content
  and the five independent instrument islands are visible.
- `workspaces.service` remains the event-driven source. The normalized state now
  emits only sorted existing positive IDs plus the active positive ID. A live
  workspace-action check created workspace 6 and published `[2, 6]`; returning
  to workspace 2 destroyed the empty workspace and restored `[2]`.
- Workspace applications render below their owning number in centred
  two-column rows. The active capacity is four cells, inactive capacity is two,
  and overflow occupies the final same-size `+N` cell. An isolated fixture
  covers inactive three-app and active five-app cases.
- The individual Senomy, telemetry, system, calendar/notification, and Power
  instruments use lower-opacity surfaces, smaller radii, quieter borders, and
  deliberate transparent gaps. Power is a narrow dedicated final island.
- The guarded reload finished with one config-matched Eww daemon, one
  `main-bar`, active `workspaces.service`, idle primary/flyout state, no
  Hyprland configuration error, and all 30 static validation checks passing.

### August 26 compositor-glass Rail and workspace-overlay correction

- The final reviewed comparison supersedes the invisible-enclosure portion of
  the earlier same-day pass. The 1920x1080 standard Rail now has a subtle
  rounded outer glass enclosure, a five-anchor workspace floor, one joined
  Senomy identity island, and separately bounded telemetry, system,
  calendar/notification, and Power islands packed against the right edge.
- Eww publishes the bar as namespace `senomy-rail`. Hyprland 0.56.2 applies a
  selective `blur = true`, `ignore_alpha = 0.06`, `xray = false` layer rule.
  The global compositor blur remains the modest existing size 3/pass 1; no
  compositor plugin or additional runtime package was introduced.
- The tracked and live Lua configurations match at SHA-256
  `7af4bd6dc507b4f11cfe0a0c33cde674b6d4c876741e9e7e2a84b5f31b09233b`.
  `hyprctl configerrors` is empty and the live layer is 1920x142 at `y=938`.
- The selected wallpaper source is
  `appearance/shared/backgrounds/cathedral-reliquary-v1.png`; deterministic
  desktop and blurred projections were deployed under user appearance and
  Hyprland receipts. Exactly one `swaybg` process consumes the deployed
  `desktop.png`.
- The Rail avatar resolves to the existing browsing chibi. The generated Rail
  composition-study PNG remains in the repository but is no longer selected
  by `data/senomy-avatars.json`.
- Workspace anchors 1 through 5 remain visible and extend for higher real
  positive IDs. A live check opened `special:magic`, invoked the same guarded
  workspace action used by the Rail for workspace 2, and confirmed that the
  special overlay closed, workspace 2 became active, and Firefox became the
  visible focused application. Workspace 1 was restored after the check.
- The final normalized reference/live evidence is
  `docs/design/rail-pass/reference-vs-live-glass-v6.png`; the empty-workspace
  wallpaper evidence is `docs/design/rail-pass/live-cathedral-wallpaper-v2.png`.

### August 26 dynamic paddingless Rail correction

- The final user correction removes the top-level enclosing Rail frame and all
  of its horizontal margin/padding while retaining the compositor-blurred
  individual islands and their right-packed sequence.
- `workspaces.service` was restarted once to load the corrected listener. Live
  Eww state then contained only real workspace `[1]`; no five-slot floor was
  republished after the refresh.
- Senomy and system-control hover captures show no tooltip overlay, padded
  rectangle, or underline block. The comparison evidence is
  `docs/design/rail-pass/pre-vs-dynamic-paddingless-hover-v2.png`.

### August 27 compact workspace-island correction

- The exclusive `senomy-rail` layer is now `1920x104` at `y=976`, replacing
  the former 142px allocation. Visible islands are 80px high; the internal top
  reserve is 4px and the top-level bar has no horizontal padding or frame.
- Every published workspace is its own bordered glass island. A live action
  created workspace 2 and produced two separately bounded islands for IDs 1
  and 2; returning to workspace 1 destroyed the empty workspace and restored
  the truthful one-item state.
- Applications, volume, Wi-Fi, battery, and tray occupy five equal 64px
  columns inside the 320px system island. Existing hover fills remain owned by
  each full column without inter-control padding.
- One Eww daemon and one `main-bar` remained active after the guarded restart;
  `hyprctl configerrors` was empty. Normalized comparison evidence is
  `docs/design/rail-pass/reference-vs-compact-workspaces-final.png` and the
  two-workspace live evidence is
  `docs/design/rail-pass/compact-workspaces-two-live-rail.png`.

### August 27 44px ultra-compact Rail correction

- The live `senomy-rail` layer is `1920x56` at `y=1024`. Every instrument and
  workspace island is 44px high; its interactive children are 42px high and
  centered rather than preserving the former 78px content floor.
- Rail artwork now follows the compact allocation: 30px Senomy avatar source,
  16px system icons, 18px notification bell, 12px workspace application cells,
  12px clock time, and 7px clock metadata. Two occupied workspace islands and
  all five equal-width system controls remained visible without increasing the
  outer height.
- Clicking Notifications records the current event observation in the
  session-local `rail_notification_ack_at` state before opening Insights. The
  count remains truthful and provider-owned, but the badge stays hidden until
  the notification listener publishes a newer observation. A live six-count
  check confirmed the badge disappeared without clearing notifications.
- One Eww daemon and one `main-bar` remained active after the guarded restart;
  `hyprctl configerrors` was empty. Height evidence is
  `docs/design/rail-pass/ultracompact-80-vs-44.png`; badge evidence is
  `docs/design/rail-pass/ultracompact-44-notification-before-vs-after.png`.

### August 27 56px aligned-island correction

- The live `senomy-rail` layer is `1920x64` at `y=1016`; all workspace and
  instrument islands are 56px high. Their content remains proportionally
  compact and vertically centered.
- Standard island separation is 22px. Removing the telemetry edge's duplicate
  22px left margin corrected the former 44px Seno-to-performance gap. The two
  workspace islands use the same 22px separation.
- Rail content begins at x=20 and ends at x=1900, matching the compositor's
  20px left/right outer-gap line. The active tiled window retained its 20px
  top and side gaps.
- Hyprland `general.gaps_out` is now `20 20 6 20` in top/right/bottom/left
  order. On the 1080px reference monitor, the active window bottom moved from
  994 to 1008 while the Rail began at 1016, reducing the measured window-to-
  Rail separation from 22px to 8px.
- The running Hyprland provider is Lua. Repository and live `hyprland.lua`
  match byte-for-byte, as do the tracked and live compatibility `.conf` files.
  A config-only reload completed with no Hyprland errors; one Eww daemon and
  one `main-bar` remained active. Visual evidence is
  `docs/design/rail-pass/rail-56-spacing-before-vs-live.png`.

### August 27 live Gothic Rail-frame projection

- The standard-density Rail now draws token-generated, transparent-interior
  SVG ornaments at exact consumer widths: workspace/Power 68x44,
  Calendar/Notifications 188x44, system controls 320x44, telemetry 392x44,
  and Senomy 397x44. No production selector scales the 68x44, 200x44, or
  397x44 QA assets into a different width.
- The 44px vector artwork is centered inside the accepted 56px island
  allocation. The Eww layer remains `1920x64` at `y=1016`; layout width,
  22px island gaps, and 20px monitor-edge alignment are unchanged.
- A guarded reload returned one reachable Eww daemon and one `main-bar`.
  `hyprctl configerrors` remained empty. Resting before/after evidence is
  `docs/design/rail-frame-svg/live/frame-live-before-vs-first-apply.png`, and
  focused hover evidence is
  `docs/design/rail-frame-svg/live/frame-live-hover-evidence.png`.

### August 27 CSS-fluid Gothic Rail-frame composition

- D101's exact-width runtime selection has been replaced by four generated SVG
  modules: fixed left/right caps, one fixed centre jewel, and one stretchable
  straight-edge layer. Island width now comes directly from computed CSS; no
  width-specific selector or regenerated full-frame asset is needed.
- The composition is active for workspace, Senomy, telemetry, system controls,
  Calendar/Notifications, and Power in standard, compact, narrow, and phone
  Rail densities. The 44px optical art remains centered in the 56px standard
  control allocation.
- Validation renders the CSS-equivalent composition at 68x44, 200x44, and
  397x44 and reports pixel-identical fixed corner and edge samples. A guarded
  reload returned one Eww daemon and one `main-bar`; Hyprland config errors
  remained empty. Exact-versus-fluid live evidence is
  `docs/design/rail-frame-svg/live/frame-live-exact-vs-fluid-final.png`.

### August 28 Luminous Reliquary production frame system

- `appearance/shared/frames/frame-system.json` now owns three distinct optical
  families: Compact, Standard, and Large. `scripts/generate-appearance.py`
  emits 35 standalone native SVG modules under
  `appearance/shared/frames/generated/`; no asset embeds or traces the supplied
  PNG art direction.
- Only Compact is deployed. Workspaces, Senomy, telemetry, system controls,
  clock/notifications, and Power remain independent Rail islands with no
  enclosing frame. The workspace number is inside an adaptive open top-edge
  bay and the existing live 1/2/3/4 application grid plus icon-sized overflow
  remains driven by `workspaces.service`.
- A live creation/switch/removal test published workspace 4, rendered a fourth
  framed island, changed the compositor workspace, returned to workspace 1,
  and removed the now-empty workspace 4. The workspace row restored real IDs
  1, 2, and 3; no numeric floor or fixed workspace list was introduced.
- The canonical `senomy-appearance.sh apply shell` path rebuilt projections,
  passed the full appearance contract, and completed its guarded reload. It
  returned exactly one Eww daemon and one `main-bar`. The
  layer remains `1920x64` at `y=1016`; `workspaces.service` is active,
  `hyprctl configerrors` is empty, and telemetry/audio/network listeners report
  live state. Performance, Insights, Calendar/Control Centre, the Power section,
  and the Audio flyout opened through their existing Rail commands and closed
  without overlapping state. No destructive Power action was issued.
- During the source-watcher phase, GTK rejected one unsupported SCSS result
  (`min-width: 100%`) and briefly displayed fallback styling. The declaration
  was removed before the guarded reload. `validate-theme-contract.sh` now
  compiles root Eww SCSS and parses the complete result through GTK 3 so the
  same failure is caught offline.
- Resting before/after evidence is
  `docs/design/frame-system/live/rail-before-vs-frame-system.png`; the actual
  source/harness/live comparison is
  `docs/design/frame-system/reference-harness-live-comparison.png`; dynamic
  workspace evidence is
  `docs/design/frame-system/live/rail-frame-system-dynamic-workspace-created-crop.png`.

### August 28 bounded workspace carousel

- The standard workspace region now preserves the existing layout through four
  real workspaces and becomes a four-item viewport at five or more. Every
  workspace remains 68x56px with its original adaptive frame, number bay,
  application grid, active state, and 22px separation.
- Previous/next controls are 28x56px, remain allocated when disabled, and reuse
  repository-owned Rail icon/frame motifs. A two-page same-size GtkStack keeps
  slide animation clipped inside a stable viewport. Manual navigation and
  vertical/horizontal scroll input do not change the active workspace.
- `scripts/workspace-carousel.sh` serializes rapid actions with a runtime lock
  and reads the authoritative `workspace_state`; it contains no Hyprland call.
  The restarted `workspaces.service` reconciles active-item visibility and
  count changes after each successful snapshot publication.
- Live fixtures exercised counts 2, 4, 5, 7, and 8; rapid navigation clamped at
  offsets 0 and 4; switching from workspace 1 to 8 auto-followed to offset 4;
  removing workspace 8 clamped the seven-item viewport to offset 3; removing
  all temporary fixtures restored real IDs `[1, 2]` and offset 0. All temporary
  Kitty windows were terminated and no fixture workspace remained.
- The Senomy island retained the same x=446 start across exact-capacity,
  first-overflow, final-page, removal, and restored captures. Visual state
  evidence is
  `docs/design/workspace-carousel/live/workspace-carousel-state-matrix.png`;
  non-overflow regression evidence is
  `docs/design/workspace-carousel/live/workspace-carousel-nonoverflow-before-vs-after.png`.
- The canonical `senomy-appearance.sh apply shell` path rebuilt projections,
  passed appearance validation, and completed its guarded reload. Final health
  checks found one Eww daemon, one `main-bar`, Rail `1920x64` at `y=1016`,
  active `workspaces.service`, primary/flyout state `none`, truthful IDs `[1,2]`,
  offset 0, and no Hyprland configuration errors. Final resting evidence is
  `docs/design/workspace-carousel/live/workspace-carousel-canonical-final-rail.png`.

### Helper file modes

```text
scripts/battery.sh     755
scripts/bar-audio-listener.sh 755
scripts/bar-layout.sh 755
scripts/bar-network-listener.sh 755
scripts/rail-notification-ack.sh 755
scripts/bar-status.sh 755
scripts/background-apps-action.sh 755
scripts/background-apps-status.sh 755
scripts/benchmark-action.sh 755
scripts/benchmark-memory.py 755
scripts/benchmark-status.sh 755
scripts/diagnostics-status.sh 755
scripts/performance-history.sh 755
scripts/performance-process-detail.sh 755
scripts/performance-action.sh 755
scripts/performance-processes.sh 755
scripts/performance-report.sh 755
scripts/performance-status.sh 755
scripts/reload-eww.sh  755
scripts/screenshot-action.sh 755
scripts/senomy-deploy.sh 755
scripts/senomy-system-deploy.sh 755
scripts/senomy-bootstrap.sh 755
scripts/senomy-bootctl 755
scripts/senomy-stage-system-root.sh 755
scripts/profile-status.sh 755
scripts/generate-appearance.py 755
scripts/frame_geometry.py 644
scripts/thunar-uca-merge.py 755
scripts/senomy-avatar.sh 755
scripts/senomy-shellctl.sh 755
scripts/notification-history.sh 755
scripts/swaync-history-integration.sh 755
scripts/validate-eww-config.sh 755
scripts/validate-deployment.sh 755
scripts/validate-command-lens.sh 755
scripts/validate-thunar-contract.sh 755
scripts/validate-theme-contract.sh 755
scripts/validate-screenshot-contract.sh 755
scripts/validate-workspace-carousel.sh 755
scripts/validate-frame-system.py 755
scripts/validate-rail-frame-svg.py 755
scripts/validate-profile-contract.sh 755
scripts/validate-bootstrap.sh 755
scripts/validate-boot-themes.sh 755
scripts/senomy-dialogue.sh 755
scripts/markdown-to-pdf.py 755
scripts/start-eww.sh   755
scripts/surface-state.sh 755
scripts/system-status.sh 755
scripts/timeline-status.sh 755
scripts/update-status.sh 755
scripts/wiki-status.py 755
scripts/workspace-carousel.sh 755
scripts/workspaces.sh  755
scripts/volume.sh      755
scripts/wifi.sh        644
update-loop.sh         644
```

The volume helper is directly executable. The legacy Wi-Fi helper works when
invoked through a shell but remains non-executable.

### August 29 SDDM frame migration and login-loop correction

- SDDM now consumes the approved Standard Luminous Reliquary frame modules as
  five independent desktop instruments and one responsive narrow frame. Native
  test-mode captures are `appearance/login/sddm/preview-frame-system.png` at
  1920x1080 and `preview-frame-system-narrow.png` at 600x900.
- Journal and SDDM user-session logs proved that the reported loop was not a
  reboot: the greeter submitted `Senomy Recovery` for the normal `Duku` account,
  the correct recovery guard rejected it with exit 77, and SDDM returned to the
  greeter. The source now excludes Recovery from normal selection and cycling,
  falls back to the ordinary `Hyprland` session, and rechecks the selection
  immediately before authentication.
- `scripts/validate-sddm-contract.sh` verifies the session isolation logic,
  byte-identical shared/theme frame projections, QML parsing, and deploy
  manifest coverage. The system payload is installed under receipt
  `20260829-075233-sddm-153863`; the post-apply plan is fully unchanged and the
  installed QML matches source byte-for-byte. No live SDDM restart was run.

### August 29 Senomy Insights Large-frame migration

- The live Insights layer now resolves to 960x760 at x=480, y=244 on the
  1920x1080 scale-1 reference display, leaving a 12px gap above the Rail.
- The panel consumes canonical Large frame modules around the evidence chamber
  and Standard modules around its route index. All eight routes were captured
  at the live layer size; their contact sheet is
  `appearance/insights/qa/routes-contact-sheet.png`.
- The acceptance harness passed 36 routes and cross-surface transitions, then
  restored `active_surface=none`, `active_flyout=none`, and only `main-bar`.
- Eww's runtime SCSS compiler rejects `@charset`; the appearance projection is
  therefore ASCII-only and self-contained. Isolated Eww parsing, headless GTK
  CSS parsing, frame validation, profile geometry, and the live reload passed.

### August 29 Performance Dashboard Large-frame migration

- The live Performance layer resolves to 1480x760 at x=220, y=244 on the
  1920x1080 scale-1 reference display on every one of its seven routes.
- Overview no longer contains the Senomy Observer card. System State and Power
  Snapshot expand across the reclaimed row; telemetry and guarded actions are
  unchanged.
- Large/Standard frame, route, and live-state evidence is stored under
  `appearance/performance/qa/`. The 36-route acceptance harness passed and
  restored `active_surface=none`, `active_flyout=none`, and only `main-bar`.

### August 29 Control Centre Large-frame migration

- The live Control Centre resolves to 960x760 at x=960, y=244 on the 1920x1080
  scale-1 reference display, leaving a 12px gap above the Rail.
- Its Large controls chamber, Standard route spine, connected summary buses,
  open ledgers, and guarded action docks preserve all ten existing routes and
  action boundaries.
- Live evidence is stored under `appearance/control/qa/`. The 36-route panel
  acceptance harness passed and restored only `main-bar` with both surface
  state variables set to `none`.

### August 30 shell glass and compositor corner unification

- Compact Rail fills remain translucent. Large Control, Performance, and
  Insights chambers now use a 0.68 obsidian base with restrained translucent
  gradients and a true 48px CSS clip. Standard frame consumers use a 32px clip;
  Compact remains 16px.
- Volume is a 420x96 Standard controls instrument at live x=1372, y=910. The
  background-application tray is 340x150 at x=1294, y=856. Both publish
  `senomy-flyout`; primary surfaces publish `senomy-control`,
  `senomy-performance`, and `senomy-insights`.
- Hyprland's live Lua and compatibility `.conf` sources match their repository
  copies. Live decoration reports 18px rounding, power 2.4, a silver-to-violet
  active border, muted inactive border, shadow range 14, and client opacity
  1.0. `hyprctl configerrors` is empty.
- Full and focused visual comparisons are
  `appearance/shell/qa/source-vs-live-full-and-rail-pass-1.png` and
  `appearance/shell/qa/source-vs-live-focused-pass-1.png`. All 33 shell checks
  and all 36 live surface routes/transitions passed, then restored one Eww
  daemon, only `main-bar`, `active_surface=none`, and `active_flyout=none`.

### August 30 dedicated Rail flyouts and true fullscreen

- Calendar is 430x470, Notifications is 480x560, and Power is 440x560 on the
  1920x1080 reference display. Each uses the canonical Standard frame and one
  `senomy-flyout` namespace; `active_flyout` prevents overlap with every primary
  surface and other flyout.
- The notification bell source path was optically recentered without changing
  its fixed 64px allocation or overlay badge. The dedicated notification view
  exposes truthful SwayNC counts, DND, live dismissal, and the private retained
  ledger. Power actions are script-allowlisted and require a second press.
- The deployed `senomy-fullscreen` helper measured the focused client at 0,0
  and 1920x1080 in fullscreen mode 2 with no
  Eww Rail window, then at 22,22 and 1876x986 with `main-bar` restored after
  exit. It is now bound to Super+F; Super+V restores toggle-floating. The
  Super+Shift+F immersive variant was measured at 0,0 and 1920x1080 with
  Hyprland fullscreen mode 2, client mode 0, and no Rail, preserving the
  application's own chrome. Both live Hyprland mirrors match the tracked
  sources and `hyprctl configerrors` is empty.
- The live interaction harness passed 16 focused state transitions and the
  full panel harness passed 42 routes/transitions, restoring only `main-bar`
  with `active_surface=none` and `active_flyout=none`.

### August 31 Thunar responsive frame pass

- The live Standard Thunar workspace uses 20px Hyprland rounding and the
  matching 20px GTK Reliquary projection. The compositor, GTK clip, and SVG
  edge meet without the former 48px/18px double-corner mismatch.
- Live checks passed at 933x988 tiled, 720x720 floating, and 520x620 floating.
  The toolbar degrades through GTK allocation, the status line truncates, and
  the 220px sidebar leaves the file view usable at the compact sizes.
- The deployed launcher clamps only stale fresh-daemon divider values; it does
  not rewrite the geometry of an existing Thunar session. Standard workspace
  indicators now resolve to 54x56px with 10px inter-indicator spacing.

### Remaining duplication and portability work

- The current already-running legacy `.conf` session still contains the former
  Hyprpaper/swww/Downloads startup lines. The deployed next-session Lua source
  does not; it uses one project-owned `swaybg` path.
- The bar and legacy Action Centre geometry still contain resolution-specific
  values that need profile and multi-scale QA.
- Disposable-VM cold boot, recovery boot, portrait/phone geometry, hot-plug,
  and representative non-T480 hardware evidence remain outstanding.

## Shell syntax

At inspection, these passed `bash -n`:

- `scripts/battery.sh`
- `scripts/background-apps-action.sh`
- `scripts/background-apps-status.sh`
- `scripts/diagnostics-status.sh`
- `scripts/performance-processes.sh`
- `scripts/performance-status.sh`
- `scripts/reload-eww.sh`
- `scripts/senomy-dialogue.sh`
- `scripts/start-eww.sh`
- `scripts/surface-state.sh`
- `scripts/system-status.sh`
- `scripts/timeline-status.sh`
- `scripts/update-status.sh`
- `scripts/volume.sh`
- `scripts/wifi.sh`
- `scripts/workspaces.sh`
- `update-loop.sh`

Syntax validity does not make the update-loop architecture correct.

## September 1 Quickshell V2 production foundation

- `/home/Duku/SenomyOS` is the `quickshell-v2` worktree and authoritative V2
  source. `/home/Duku/.config/eww` remains the detached tagged Eww fallback.
- Quickshell 0.3.1-1 from Arch runs as `senomy-quickshell.service` directly from
  `shell/quickshell/`. The unit, Eww adapter, and fallback unit are linked into
  the user manager but have no install target and are not login-enabled.
- `~/.config/senomyos/shell.json` records the migration selection and explicitly
  retains `login_default: eww`. Ephemeral locking/log state lives under
  `$XDG_RUNTIME_DIR/senomyos`.
- `senomy-shell` verified successful Eww→Quickshell, Quickshell→Eww, and
  Eww→Quickshell handoffs. Each final state had exactly one Rail namespace and
  one 64px bottom reserve; Eww-only `workspaces.service` was inactive in V2.
- A forced Quickshell start failure exhausted three direct retries, invoked the
  fallback unit, restored Eww and its reserve, and recorded
  `reason: systemd-fallback`. A SIGKILL of a healthy V2 PID restarted it with a
  new PID without invoking Eww.
- A temporary headless output verified one V2 Rail and reserve through hotplug,
  1280×720 at scale 1, 1280×720 at scale 1.25, and 800×1280 at scale 1.25. The
  640-logical-pixel portrait profile rendered one workspace chip plus the
  controls/tray/power group without overlap. The virtual output was removed.
- NetworkManager state, PipeWire, UPower, Hyprland, tray, and clock are native
  Quickshell integrations. The only persistent sampler reads `/proc` in-process
  every two seconds for CPU, memory, and uptime.
- SwayNC remains the sole notification DBus owner. No Quickshell notification
  server runs during this milestone. Both shell adapters want the existing
  SwayNC unit and keep the graphical-session target pinned during Rail handoff,
  so stopping Eww-only workspace publication cannot silently stop notification
  delivery. This dependency is migration-time only and changes no enabled unit.

## September 2 Quickshell V2 functional migration

- Runtime versions are Quickshell 0.3.1-1, Qt 6.11.2 and Hyprland 0.56.2 with
  the Lua configuration provider. The authoritative branch is
  `/home/Duku/SenomyOS` `quickshell-v2`; login default remains Eww.
- In the final observed development state, `senomy-quickshell.service` was
  active with one Rail. Eww, `workspaces.service` and SwayNC were inactive, and
  the Quickshell main PID was the sole notification owner. No Eww component is
  required during normal Quickshell operation.
- Shared native services now cover Hyprland workspaces/toplevels, PipeWire,
  NetworkManager, UPower, BlueZ, MPRIS, StatusNotifier and notifications. Ten
  Control routes, seven Performance routes, eight Insights routes, the
  companion and all five compact popups loaded live.
- The real state snapshot exposed one output sink, two input nodes, the active
  NetworkManager SSID/connectivity, two laptop batteries, an enabled Bluetooth
  adapter and four visible devices. No MPRIS player was active, so the shell
  truthfully showed an unavailable/idle media state.
- Quickshell notification ownership passed an isolated private-bus suite and a
  full live Eww -> Quickshell -> Eww -> Quickshell rollback cycle. The private
  store is bounded to 120 mode-0600 records. SwayNC remains Eww-mode recovery
  infrastructure only.
- Level 2 Performance remained capped at 60 samples after a 65-second run and
  stopped all collectors after closure. Level 3 plans/status loaded without
  starting a benchmark. All five power actions entered and cancelled the
  pending state; no destructive confirmation ran.
- Temporary headless outputs verified one Rail per output, source-screen
  Control/Calendar/Insights/companion/Performance placement, scale 1.25,
  864-logical-pixel portrait, side-by-side companion/primary presentation and
  complete state cleanup on hot-unplug. The outputs were removed.
- A 30-s idle resource sample measured median 0.978% CPU, 347,264 KiB RSS,
  195,291 KiB PSS and 163,060 KiB private memory with 18 threads, no child PID
  and -80 KiB end-to-start memory growth. Mean CPU was 1.323%; this and the
  roughly 14.7 MiB PSS increase from Milestone 2 remain soak watch items.
- Physical pointer/keyboard acceptance, real second-monitor/touch evidence,
  active-player MPRIS control, Bluetooth pairing and new secured-Wi-Fi prompt
  evidence remain outstanding. See `docs/QUICKSHELL_V3_QA.md`.
