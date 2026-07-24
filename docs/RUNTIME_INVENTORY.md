# SenomyOS Runtime Inventory

Last read-only verification: 2026-07-24.

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
Eww:        0.5.0
Hyprland:   0.55.2
Monitor:    eDP-1, 1920x1080, approximately 60Hz, scale 1
Eww window: main-bar
```

At inspection:

- `hyprctl configerrors` returned no errors;
- `workspaces.service` was active;
- workspace state was `1 2 [3]`;
- the dual-battery JSON updated successfully;
- the Eww log file was empty.

## Hyprland compatibility baseline

The tracked and live Hyprland configs matched byte-for-byte at inspection.

SHA-256:

```text
e5fb0b065d36c29ae0621b14fa220ece28ebda593f52fd7882e630265f67c8e4
```

The uncommitted compatibility changes:

- remove obsolete `dwindle:pseudotile`;
- route Mod+J layout splitting through the new dispatcher;
- use `suppress_event` window-rule syntax;
- use `no_focus on` and `match:*` window-rule syntax.

There is also an unrelated-looking added space before an early comment.

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
```

Missing at inspection:

```text
gh
rg
less
checkupdates
yay
```

Use `git --no-pager`. Use `grep`/`find` when `rg` remains unavailable.

Installed relevant fonts:

- Symbols Nerd Font Mono
- JetBrainsMono Nerd Font

## Working components

### Workspace listener

`workspaces.service` runs:

```text
/home/Duku/.config/eww/scripts/workspaces.sh
```

It builds a stable `1 2 [3]` style string and only updates Eww when the value
changes.

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

It is not yet connected to Eww and has no live polling cost.

## Confirmed problems

### Deadlocked update loop

Hyprland starts `update-loop.sh`. That script runs the endless
`workspaces.sh` inside command substitution and never completes its first loop.

Inspection showed:

- the correct systemd-managed workspace listener;
- `update-loop.sh`;
- a second `workspaces.sh` child blocked under the update loop.

### Incomplete UI definitions

- `windows/battery-panel.yuck` is empty.
- `windows/clock-panel.yuck` is empty.
- `windows/actioncenter-panel.yuck` references undefined
  `actioncenter-main`, `volume-panel`, `wifi-panel`, and `battery-panel`
  widgets.
- the volume button opens an undefined `volume-popup`.

### Helper file modes

```text
scripts/battery.sh     755
scripts/workspaces.sh  755
scripts/volume.sh      644
scripts/wifi.sh        644
update-loop.sh         644
```

The volume and Wi-Fi helpers work when invoked through Bash, but fail when
executed directly.

### Duplication and portability

- Eww polls time and battery while the legacy update loop attempts to update
  them too.
- Hyprland starts both Hyprpaper and swww.
- The wallpaper path is hard-coded.
- Hyprland, the bar, and Action Centre use monitor/resolution-specific values.

## Shell syntax

At inspection, these passed `bash -n`:

- `scripts/battery.sh`
- `scripts/volume.sh`
- `scripts/wifi.sh`
- `scripts/workspaces.sh`
- `update-loop.sh`

Syntax validity does not make the update-loop architecture correct.
