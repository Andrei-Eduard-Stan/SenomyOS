# SenomyOS Runtime Inventory

Last read-only verification: 2026-07-25.

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

At inspection:

- `hyprctl configerrors` returned no errors;
- `workspaces.service` was active;
- workspace state was `1 [2] 3`;
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
f7f802835432375c9afe8dc7e6e33cd4426cda3c8c97549c76e5a8077b86f7c1
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

It builds a stable `1 2 [3]` style string, updates Eww when the value changes,
and periodically republishes the current value so it recovers after an Eww
restart. It now requires a successful `eww ping` before publishing, so a
periodic workspace update cannot create a competing daemon while the shell is
intentionally restarting.

### Dual-battery collector

`scripts/battery.sh` uses UPower and `jq`. It detected two batteries and
generated valid compact JSON.

### Basic sources

- `pamixer` returned a numeric volume and mute state.
- `nmcli` returned the active Wi-Fi connection.
- Eww time polling worked.

### Portable system summary

`scripts/system-status.sh` was added after the initial inspection. It passed:

- `bash -n`;
- successful JSON schema/type assertions;
- missing-procfs error validation;
- invalid-sample-delay error validation;
- missing-`jq` error validation.

It is connected to Eww as `system_status` and currently polls every two seconds
for the bar telemetry.

### Portable audio summary

`scripts/audio-status.sh` was added after the initial inspection. It passed:

- `bash -n`;
- successful JSON schema/type assertions against the live PipeWire server;
- default output/input normalization;
- monitor-source exclusion;
- unavailable-audio-server error validation;
- missing-dependency error validation.

It is read-only, is not connected to Eww, and changed no audio setting.

### Portable network summary

`scripts/network-status.sh` was added after the initial inspection. It passed:

- `bash -n`;
- successful JSON schema/type assertions against NetworkManager;
- primary non-loopback connection selection;
- connected Wi-Fi and disconnected Ethernet normalization;
- unavailable-NetworkManager error validation;
- missing-dependency error validation.

It is read-only, performs no Wi-Fi scan, reads no saved credentials, is not
connected to Eww, and changed no network setting.

## Confirmed problems

### Resolved startup races

The legacy `update-loop.sh` is no longer running. Only the systemd-managed
`scripts/workspaces.sh` process remains.

The workspace service previously started before Hyprland and missed
`HYPRLAND_INSTANCE_SIGNATURE`. The Hyprland startup command now imports the
session environment and restarts the already-enabled service in one ordered
command.

Eww previously started `daemon` in the background immediately before `open`,
which could split the daemon and visible bar into disconnected processes.
`scripts/start-eww.sh` now waits for `eww ping` before opening the bar.

### Planned UI content

- The Control Centre shell exposes all nine approved sections. Applications is
  implemented; the remaining section bodies stay honest planned placeholders.
- Applications is now the first implemented Control Centre section. The
  persistent Rail owns Eww's native StatusNotifier tray host, while the section
  shows registry-backed managed application cards.
- Flameshot 14.0.0 is installed, enabled through the linked
  `flameshot.service` user unit, and verified as `Type=dbus` with
  `org.flameshot.Flameshot`.
- Live verification on 2026-07-27 observed Flameshot as systemd-active,
  D-Bus-ready, and registered in Eww's tray watcher. The Applications poll
  reported one running managed application and one native tray item.
- Flameshot actions are fixed inside `scripts/background-apps-action.sh`.
  Capture, launcher, configuration, and start are immediate explicit actions;
  stop uses an Eww confirmation state that clears when the panel closes or the
  selected section changes.
- The battery control opens Power; the two-row clock opens Calendar.
- The bar has a temporary Senomy identity mark and live status sentence.
- Ambient personality lines come from a versioned dialogue catalog, remain
  stable for 15-minute slots, and occasionally select an uncommon English/Latin
  line. Verified low-power and unavailable-source messages take priority.
- Senomy Insights opens as a separate surface with live procfs and UPower
  observations plus an explicitly planned maintenance record.
- Insights and the Control Centre follow the one-primary-surface rule.
- Bar triggers and panel close buttons now route through
  `scripts/surface-state.sh`. It validates section names, serializes
  transitions, and reconciles window instances with `active_surface`.
- `scripts/reload-eww.sh` is the supported state-preserving reload command.
  It closes the old window set, stops the daemon, starts exactly `main-bar`
  plus the remembered surface in one `eww open-many` process, verifies those
  windows, and restores validated state. Raw `eww reload` is unsupported.
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
- Final Senomy chibi and full-avatar artwork is being developed separately;
  current text marks are replaceable placeholders.
- `windows/battery-panel.yuck` and `windows/clock-panel.yuck` remain empty
  legacy files and are not used by the current Control Centre.
- The CPU/MEM/UP group does not yet open the separate Performance Dashboard.

### Helper file modes

```text
scripts/battery.sh     755
scripts/background-apps-action.sh 755
scripts/background-apps-status.sh 755
scripts/diagnostics-status.sh 755
scripts/reload-eww.sh  755
scripts/senomy-dialogue.sh 755
scripts/start-eww.sh   755
scripts/surface-state.sh 755
scripts/system-status.sh 755
scripts/timeline-status.sh 755
scripts/update-status.sh 755
scripts/workspaces.sh  755
scripts/volume.sh      644
scripts/wifi.sh        644
update-loop.sh         644
```

The volume and Wi-Fi helpers work when invoked through Bash, but fail when
executed directly.

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
