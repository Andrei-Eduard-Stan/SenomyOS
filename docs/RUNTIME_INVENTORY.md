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
reload.

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

- The Control Centre shell exposes all nine approved sections, but their bodies
  remain honest planned placeholders.
- The battery control opens Power; the two-row clock opens Calendar.
- `windows/battery-panel.yuck` and `windows/clock-panel.yuck` remain empty
  legacy files and are not used by the current Control Centre.
- The CPU/MEM/UP group does not yet open the separate Performance Dashboard.
- Senomy Insights does not yet have its dedicated trigger or surface.

### Helper file modes

```text
scripts/battery.sh     755
scripts/start-eww.sh   755
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
- `scripts/start-eww.sh`
- `scripts/system-status.sh`
- `scripts/volume.sh`
- `scripts/wifi.sh`
- `scripts/workspaces.sh`
- `update-loop.sh`

Syntax validity does not make the update-loop architecture correct.
