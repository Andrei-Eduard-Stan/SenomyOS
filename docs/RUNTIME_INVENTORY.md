# SenomyOS Runtime Inventory

Last read-only verification: 2026-07-28.

Runtime facts can change. Recheck them before relying on them for a mutation.

The current T480 is the reference development machine, not the target hardware
specification for SenomyOS.

## Paths

```text
User/home:              /home/Duku
Live Eww repository:    /home/Duku/.config/eww
Live Hyprland config:   /home/Duku/.config/hypr/hyprland.conf
Tracked Hyprland copy:  /home/Duku/.config/eww/hyprland.conf
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
Hyprland:    0.56.0
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
- workspaces 1 and 2 were occupied, with workspace 1 active;
- the dual-battery JSON updated successfully;
- the tracked and live Hyprland configs matched;
- one Eww daemon owned the 44px `main-bar`;
- Hyprland reported the bar at `y=1036` on the 1080px display with exactly
  44px reserved at the bottom.

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

### Planned UI content

- The Control Centre shell exposes all nine approved sections. Applications,
  Network, Audio, and Power are implemented; the remaining section bodies stay
  honest planned placeholders.
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

### Helper file modes

```text
scripts/battery.sh     755
scripts/bar-audio-listener.sh 755
scripts/bar-layout.sh 755
scripts/bar-network-listener.sh 755
scripts/bar-status.sh 755
scripts/background-apps-action.sh 755
scripts/background-apps-status.sh 755
scripts/benchmark-action.sh 755
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
scripts/senomy-avatar.sh 755
scripts/senomy-dialogue.sh 755
scripts/markdown-to-pdf.py 755
scripts/start-eww.sh   755
scripts/surface-state.sh 755
scripts/system-status.sh 755
scripts/timeline-status.sh 755
scripts/update-status.sh 755
scripts/wiki-status.py 755
scripts/workspaces.sh  755
scripts/volume.sh      755
scripts/wifi.sh        644
update-loop.sh         644
```

The volume helper is directly executable. The legacy Wi-Fi helper works when
invoked through a shell but remains non-executable.

### Remaining duplication and portability work

- Hyprland starts both Hyprpaper and swww.
- The wallpaper path is hard-coded.
- Hyprland, the bar, and Action Centre use monitor/resolution-specific values.

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
