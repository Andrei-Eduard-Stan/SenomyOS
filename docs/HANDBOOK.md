# SenomyOS Handbook

## What this handbook is

This is the practical operating manual for reviving and developing SenomyOS.
It explains what the project is, what has already happened, how to work safely
on the live desktop, and how the project grows into a deployable system.

Detailed specifications live in the other documents under `docs/`. This
handbook is the place to begin a working session.

## Project in one paragraph

SenomyOS is currently a custom Arch Linux desktop shell using Hyprland and Eww.
It is being redesigned around a compact bottom bar, a unified Control Centre, a
separate Performance Dashboard, and a separate Senomy Insights briefing. The
Rail also owns one optional ambient Senomy companion overlay; it is not a fifth
primary surface. The
long-term target is a reproducibly deployable Arch-based system that adapts to
supported laptops, desktops, mini PCs, touchscreens, and compatible tablet or
phone-sized Linux devices.

## The four surfaces and companion

### Main bar

The persistent Obsidian Rail surface:

- workspaces;
- one Senomy avatar companion trigger and adjacent Insights briefing trigger;
- CPU/MEM/UP telemetry;
- system controls;
- clock and dual-battery state.

### Control Centre

A compact panel for:

- Overview;
- Network;
- Audio;
- Power;
- Calendar;
- Input;
- Device Management;
- Applications;
- Settings.

Performance does not belong here.

### Performance Dashboard

The expanded Cathedral Deck surface opened by CPU/MEM/UP:

- live metrics and history;
- processes and services;
- hardware health;
- reports;
- curated diagnostics;
- confirmed terminate/restart actions.

The mini console is an allowlisted task runner, not a general shell.

### Senomy Insights

A separate evidence-based system briefing opened from the Senomy identity:

- retained local notification history;
- updates;
- maintenance;
- battery observations;
- resource observations;
- verified warnings;
- recommended actions;
- unavailable/planned states.

Insights never invents a diagnosis or result.

### Senomy companion

The single Rail avatar opens a non-primary edge overlay. Expanded mode shows a
large evidence-driven character and observation; compact mode keeps a mostly
transparent avatar form. It can coexist with one primary surface, does not
reserve work area, and exposes left/right snap, session pin, minimize/expand,
and close controls.

## Repository map

```text
/home/Duku/.config/eww
├── AGENTS.md
├── README.MD
├── docs/
├── eww.yuck
├── eww.scss
├── windows/
├── widgets/
├── scripts/
├── systemd/
└── hyprland.conf
```

The actual live Hyprland file is:

```text
/home/Duku/.config/hypr/hyprland.conf
```

Changing the tracked copy does not change the live copy. Changing the live copy
may cause Hyprland to reload its configuration automatically.

Do not use the secondary clone:

```text
/home/Duku/Projects/SenomyOS
```

## Start every session here

```bash
cd /home/Duku/.config/eww
pwd
git rev-parse --show-toplevel
git branch --show-current
git status --short --branch
git --no-pager log -5 --oneline --decorate
git --no-pager diff
```

What these commands answer:

- Am I in the live repository?
- Which branch am I changing?
- What work is already uncommitted?
- What happened recently?
- Would my next change overlap existing work?

The revival branch is:

```text
revival/live
```

## Safety rules for the live desktop

- Do not reload Eww casually.
- Do not stop the workspace service while testing unrelated changes.
- Do not edit the live Hyprland file without showing the intended change.
- Do not assume a blank bar will repair itself.
- Do not stage every file with `git add .` when unrelated changes exist.
- Do not use destructive Git commands.
- Do not push directly to `main`.
- Warn before any action that could hide the bar, interrupt networking, stop a
  process, change audio devices, or end the session.

## What has been completed

- The repository and live paths were confirmed.
- The live and tracked Hyprland configs were confirmed identical.
- Hyprland 0.55.2 compatibility fixes were identified and validated.
- Eww 0.5.0 was confirmed running `main-bar`.
- The workspace service and dual-battery collector were confirmed working.
- The Action Centre's undefined widgets and empty panels were confirmed.
- The volume and Wi-Fi helper permission problem was confirmed.
- The duplicate, deadlocked update loop was confirmed in the process tree.
- Hyprland 0.55 compatibility was committed as `f9e1402`.
- The deadlocked update-loop autostart was removed in `547bab3`; the old
  current-session process is intentionally left for logout/reboot.
- Obsidian Rail was selected for the main shell.
- Cathedral Deck was reassigned to a separate Performance Dashboard.
- Device Management replaced Performance in the Control Centre.
- Senomy Insights was confirmed as a first-class surface.
- Project documentation was established on `revival/live`.
- Deployable-system, portability, and touch goals were added.
- The first portable `system-status.sh` collector was added and validated
  without connecting it to the live bar.
- The read-only `audio-status.sh` collector was added and validated against
  PipeWire without changing volume or routes.
- The read-only `network-status.sh` collector was added and validated without
  scanning, reconnecting, or reading saved credentials.

## Stage 1 tutorial: preserve and stabilize Hyprland

This tutorial is intentionally manual. Read a whole step before running it.

### Step 1 — Inspect the current change

```bash
cd /home/Duku/.config/eww
git branch --show-current
git status --short --branch
git --no-pager diff -- hyprland.conf
```

Expected branch:

```text
revival/live
```

Expected existing file change:

```text
M hyprland.conf
```

The meaningful changes are:

- obsolete `pseudotile` option removed;
- Mod+J routed through the Hyprland 0.55 dispatcher;
- `suppress_event` rule syntax updated;
- `no_focus` rule syntax updated.

There is also an accidental leading space before the comment near line 9.

### Step 2 — Open both Hyprland files

```bash
code /home/Duku/.config/eww/hyprland.conf \
  /home/Duku/.config/hypr/hyprland.conf
```

In both files, change:

```text
 # This is an example Hyprland config file.
```

to:

```text
# This is an example Hyprland config file.
```

Save both files.

This is a comment-only cleanup. Saving the live file may trigger Hyprland's
normal config reload, but it should not restart Eww or hide the bar.

### Step 3 — Verify the two files

```bash
cmp -s /home/Duku/.config/eww/hyprland.conf \
  /home/Duku/.config/hypr/hyprland.conf
echo $?
```

Exit code `0` means the files match. Any other value means stop and compare
them before continuing.

Then check:

```bash
hyprctl configerrors
git diff --check
git --no-pager diff -- hyprland.conf
```

Expected Hyprland result: no error text.

### Step 4 — Commit only the compatibility baseline

Stage exactly one file:

```bash
git add hyprland.conf
git status --short
git --no-pager diff --cached --check
git --no-pager diff --cached
```

Confirm that the staged diff contains only the Hyprland compatibility changes.
The live file is outside Git and will not appear in the staged diff.

Commit:

```bash
git commit -m "fix(hyprland): update config for 0.55"
```

Do not push.

### Step 5 — Remove the deadlocked autostart

Open both Hyprland files again and remove this exact line:

```text
exec-once = sleep 1 && bash ~/.config/eww/update-loop.sh &
```

Preserve the workspace service, but start it only after importing the current
Hyprland session environment:

```text
exec-once = systemctl --user import-environment XDG_RUNTIME_DIR HYPRLAND_INSTANCE_SIGNATURE WAYLAND_DISPLAY DISPLAY && systemctl --user restart workspaces.service
```

The ordered restart matters because the enabled user service may already be
running from `default.target`; a plain `start` would leave it with a stale or
missing Hyprland instance signature.

Eww startup must also wait for the daemon IPC socket:

```text
exec-once = ~/.config/eww/scripts/start-eww.sh
```

`scripts/start-eww.sh` starts one daemon, waits until `eww ping` succeeds, and
only then opens `main-bar`. Do not replace it with a backgrounded `eww daemon`
followed immediately by `eww open`; that can leave the visible bar disconnected
from the daemon receiving updates.

Removing an `exec-once` line does not stop an already-running process. It only
prevents the legacy loop from starting in a future session.

### Step 6 — Validate the runtime cleanup

```bash
cmp -s /home/Duku/.config/eww/hyprland.conf \
  /home/Duku/.config/hypr/hyprland.conf
echo $?
hyprctl configerrors
git diff --check
git --no-pager diff -- hyprland.conf
```

Expected:

- comparison exit code `0`;
- no Hyprland error text;
- a focused diff deleting only the update-loop autostart.

### Step 7 — Commit the runtime cleanup

```bash
git add hyprland.conf
git --no-pager diff --cached --check
git --no-pager diff --cached
git commit -m "fix(runtime): remove deadlocked update loop"
```

Again, do not push.

### Step 8 — Deal with the old process safely

The safest option is to leave the already-running stuck tree alone until the
next logout or reboot. It will disappear with the session, and the removed
autostart line will prevent it returning.

To inspect without changing anything:

```bash
systemctl --user status workspaces.service --no-pager
ps -eo pid,ppid,pgid,stat,etime,cmd --sort=pid \
  | grep -E 'update-loop|workspaces\.sh' \
  | grep -v grep
```

The systemd service's main PID is the workspace listener to preserve. The
second workspace listener beneath `update-loop.sh` is the redundant one.

Never reuse PIDs from old notes; PIDs change. If immediate termination is
desired, re-identify the exact tree and show it before sending `SIGTERM`.

## Git habits

Use narrow staging:

```bash
git add path/to/file
```

Avoid:

```text
git add .
```

when unrelated work exists.

Before a commit:

```bash
git status --short
git diff --check
git --no-pager diff
git --no-pager diff --cached
```

After a commit:

```bash
git --no-pager show --stat --oneline HEAD
git status --short --branch
```

## Shell and JSON validation

Syntax:

```bash
bash -n scripts/example.sh
```

JSON:

```bash
bash scripts/example.sh | jq -e .
```

Do not run a mutating action script merely to test it. Use a documented
read-only or dry-run path.

## Eww change workflow

Before editing:

1. name the window/widget/script being changed;
2. explain whether the running bar reads it;
3. inspect current Eww state and logs;
4. keep the change small.

Before reload:

1. validate scripts and JSON;
2. inspect Yuck references and SCSS;
3. show the diff;
4. warn that a parse failure could briefly remove the bar.

The supported helper parses a copied tree through a separate windowless Eww
daemon before stopping the live one. You can run that parser gate alone:

```bash
scripts/validate-eww-config.sh
```

Run the supported state-preserving reload:

```bash
~/.config/eww/scripts/reload-eww.sh
```

After an approved reload:

```bash
eww active-windows
eww state
eww logs
```

Do not use raw `eww reload`. In Eww 0.5.0 it resets `defvar` values but may
retain visible window instances, leaving state and panels detached. The
supported helper closes the old window set, stops the daemon, starts exactly
one verified `main-bar`, then restores the dismiss layer and remembered primary
surface at responsive geometry before restoring validated state.

If a raw reload was run accidentally and IPC still responds, reconcile with:

```bash
~/.config/eww/scripts/surface-state.sh reconcile
```

If IPC does not respond, inspect the Eww process tree before recovery. Repeated
`eww open` attempts can auto-start a second daemon while an orphaned GTK
process still owns visible layers.

Use the shell doctor for the supported inspection and kill-switch path:

```bash
scripts/senomy-shellctl.sh doctor
scripts/senomy-shellctl.sh incident
scripts/senomy-shellctl.sh restart
```

`doctor` is read-only. `incident` writes a private bounded diagnostic snapshot.
`restart` first validates shell, SCSS, JSON, and avatar contracts, then records
an incident, closes the SenomyOS windows, stops only exact config-matched Eww
processes, restores exactly one Rail, and resynchronizes workspaces. This also
catches retained `eww open ...` processes that may own orphaned GTK layers but
remain invisible to the currently reachable daemon's `active-windows` output.
The Rail and
open panels disappear briefly, so warn before running it. Prefer `doctor` before
`restart` unless the UI is frozen or duplicated.

Then visually verify the bar and panel behavior.

## Primary-surface behavior to protect

```text
none
control
performance
insights
```

Opening one primary surface closes the previous one.

- System control → Control Centre and matching section.
- Same control again → close.
- Different control → switch section in the existing panel.
- CPU/MEM/UP → Performance Dashboard.
- Senomy dialogue → Senomy Insights.
- Adjacent Senomy avatar → independent companion overlay.

## Senomy avatar workflow

All visible Senomy artwork is selected in one place:

```text
data/senomy-avatars.json
```

Each state has two source paths:

- `chibi` for the compact Rail context;
- `portrait` for larger companion contexts.

Both paths are relative to the Eww configuration directory and must stay under
`assets/senomy/`. SVG, PNG, JPG/JPEG, and GIF are accepted. GIF sources are
limited by size, dimensions, and frame count and converted into context-sized
private cache variants because Eww 0.5 animates them at intrinsic size. Keep
the source artwork reasonably sized even though the catalog enforces bounds.
To inspect and switch the manual ambient state:

```bash
scripts/senomy-avatar.sh list
scripts/senomy-avatar.sh set thinking
scripts/senomy-avatar.sh show
scripts/senomy-avatar.sh reset
```

To replace artwork, put the file under `assets/senomy/`, then change only its
manifest path. The local catalog refresh updates the Rail and companion through
the shared widget. `chibi_state` remains a manual asset-test value; visible
automatic state is resolved centrally in `widgets/senomy-avatar.yuck`.

The visible `companion` domain uses this priority:

- verified combined UPower percentage at or below the warning threshold;
- active MPRIS playback reported by `playerctl`;
- the ordinary browsing identity.

Primary mastheads and content cards do not render duplicate character images.
The Rail avatar is still visually joined to the dialogue so it reads as its
profile image, even though the two controls open different destinations.

Companion lifecycle checks:

```bash
scripts/companion-state.sh status
scripts/companion-media.sh | jq .
```

To add a new state:

1. add its chibi and portrait assets;
2. add one unique lowercase state record to the manifest;
3. run `scripts/senomy-avatar.sh catalog | jq -e .`;
4. run `scripts/senomy-avatar.sh list`;
5. use the controlled Eww reload only if Yuck or SCSS also changed.

## Notifications history workflow

Senomy Insights / Notifications reads a local history captured from SwayNC.
Inspect the integration without changing it:

```bash
scripts/swaync-history-integration.sh status | jq .
scripts/notification-history.sh read | jq .
```

Connect the receive hook once on a new installation:

```bash
scripts/swaync-history-integration.sh install
swaync-client --reload-config
```

Installation preserves the rest of SwayNC's JSON and creates a private backup
when a user config already exists. A reload may briefly interrupt notification
popups. New entries are stored locally under XDG state with mode 0600, newest
120 by default. Bodies may contain personal information; do not commit, upload,
or paste the history indiscriminately. Clear it from the confirmed Insights UI
or with `scripts/notification-history.sh clear`.

## Performance benchmark workflow

Inspect the exact bounded profiles without creating load:

```bash
scripts/benchmark-action.sh plan quick | jq .
scripts/benchmark-action.sh plan standard | jq .
```

Start through the Performance / Benchmarks confirmation UI. Quick targets
about 70 seconds and Standard about 210 seconds. Expect sustained CPU load,
heat, fan noise, up to 1 GiB of bounded memory allocation, and one private
temporary storage file up to 512 MiB. Connect power first. The runner refuses a
low discharging battery or dangerously low available memory and stops its
current workload at the configured thermal limit when a sensor is available.

The visible Stop action performs bounded cancellation. Completed private
Markdown, PDF, and checksum files live under XDG state and include results,
thermals, hardware/software inventory, methodology, and explicit limitations.
Do not treat one successful run as proof of perfect hardware health.

## Wiki authoring workflow

The Insights Wiki reads Markdown from:

```text
wiki/
```

Start an article with restricted front matter:

```markdown
---
title: Audio Architecture
category: Shell
category_order: 20
order: 30
summary: How PipeWire status and actions reach the Rail.
---
```

Then use headings, paragraphs, ordered or unordered lists, block quotes,
fenced code, horizontal rules, and pipe tables. Link articles with either:

```markdown
[Panel guide](panels.md)
[[panels|Panel guide]]
```

Paths are relative to the current article unless they begin with `/`. Internal
targets become navigation buttons and automatically switch category and
article. A missing target stays visible as `MISSING`; an external URL stays
visible as `EXTERNAL` but is not launched.

While Insights Wiki is open, the parser refreshes every three seconds. Validate
authoring directly with:

```bash
scripts/wiki-status.py catalog | jq -e .
```

The parser does not support executable code, HTML, embedded GTK/Yuck markup,
remote images, or a full CommonMark extension ecosystem. This is deliberate:
the Wiki remains a predictable local documentation surface.

## Screenshot capture workflow

Print Screen and the Applications capture action both route through:

```text
scripts/screenshot-action.sh capture
```

The helper serializes capture, dismisses any SenomyOS context layer, waits for
the compositor to repaint, ensures `flameshot.service` is active, and launches
`flameshot gui`. The exact capture client is floated before Hyprland forces it
fullscreen, so it cannot resize the underlying tile. Do not restore direct
`flameshot gui` bindings or broad Flameshot window rules.

## Destructive-action policy

Never execute directly from a first click:

- kill or restart process;
- restart service;
- disconnect network;
- change a hardware route;
- install updates;
- reboot;
- shut down.

The user must see the target, action, impact, and confirmation first.

## Portability rules

Ask these questions for every feature:

- Does it assume `/home/Duku`?
- Does it assume `eDP-1`, monitor `0`, or 1920x1080?
- Does it assume two batteries or a particular Wi-Fi interface?
- What happens without a battery, network, audio device, or physical keyboard?
- Can pointer, keyboard, and touch users perform the action?
- Does it fit narrow and portrait work areas?
- Is the value portable, discoverable, or a profile override?
- Will a future package/installer know about the dependency?

## Deployment path

The project evolves through:

1. stable portable live configuration;
2. normalized data and actions;
3. adaptive shell;
4. package and service manifests;
5. hardware/form-factor profiles;
6. repeatable bootstrap;
7. packaged SenomyOS components;
8. bootable installer/recovery;
9. tested compatibility tiers.

See `PLATFORM_STRATEGY.md`.

## Recovery

Recovery snapshot:

```text
/home/Duku/SenomyOS-recovery/20260719-170831
```

Treat it as read-only until a specific restore is approved. Compare exact files
before overwriting anything.

## When to update documentation

Update:

- `DECISIONS.md` when product or architecture ownership changes;
- `RUNTIME_INVENTORY.md` when verified machine/runtime facts change;
- `DATA_SOURCES.md` when adding commands or dependencies;
- `DESIGN_SYSTEM.md` when visual tokens or interaction density changes;
- `IMPLEMENTATION_PLAN.md` when stages are completed or reordered;
- this handbook when the practical workflow changes.
