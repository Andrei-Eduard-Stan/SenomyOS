# Quickshell V2 production foundation

Status: Milestone 2 development foundation, 2026-09-01. Quickshell is a live
selectable backend, but Eww remains the login-time default and recovery shell.

## Source, runtime, and deployment boundaries

The authoritative Git worktree for V2 is `/home/Duku/SenomyOS` on
`quickshell-v2`. It preserves the existing repository history and contains the
legacy Eww product source plus `shell/quickshell/`; it is not a second copied
repository. The detached checkout at `/home/Duku/.config/eww` remains the live
Eww V0 fallback at the `eww-v0-baseline-2026-09-01` tag. It must not be deleted
or treated as the place to edit V2.

The current boundaries are:

| Kind | Location | Ownership |
|---|---|---|
| Authoritative source | `/home/Duku/SenomyOS` | Git; human-edited and generated source projections |
| Legacy live fallback | `~/.config/eww` | Detached, known-good Eww runtime/source snapshot |
| User preference | `~/.config/senomyos/shell.json` | Selected migration backend, source root, unchanged login default |
| Ephemeral selector state | `$XDG_RUNTIME_DIR/senomyos/` | Lock and Eww daemon log; never source or preference |
| Development commands | `~/.local/bin/senomy-*` | Explicit symlinks into the source worktree |
| User units | `~/.config/systemd/user/senomy-*.service` | Explicit symlinks into source; linked but not enabled |
| System deployment | `/etc`, `/usr/share`, `/usr/local` | Transactional manifests; root only where required |

`scripts/senomy-v2-deploy` creates only the exact development links listed by
its `plan` command. It refuses to replace an unmanaged target and does not
enable or start a service. Source edits are therefore visible on the next QML
reload or `senomy-dev restart` without copying files into an Eww directory.

The existing top-level `appearance/`, `assets/`, `deploy/`, `systemd/`,
`components/`, and `docs/` directories remain in place. A speculative full-tree
rename would add risk without improving the runtime boundary. The one required
ownership correction is complete: the V2 shell is under `shell/quickshell/`.

## Git and worktree model

- `main` remains the known-good historical baseline and is not the V2 target.
- `revival/live` and `eww-v0-baseline-2026-09-01` preserve the reviewed Eww
  revival state.
- `quickshell-v2` is the integration branch in `/home/Duku/SenomyOS`.
- The tagged Eww baseline is merged forward into `quickshell-v2`; V2 is never
  merged backward into the detached live fallback.
- `/home/Duku/Projects/SenomyOS` is unrelated and out of scope.

No Milestone 2 unit has an `[Install]` section. The current Hyprland Lua startup
still starts `workspaces.service` and `~/.config/eww/scripts/start-eww.sh`.
Logging out and back in therefore restores Eww regardless of the last live
selection.

## Live development and shell selection

Install or verify the non-enabled development links:

```bash
cd /home/Duku/SenomyOS
./scripts/senomy-v2-deploy plan
./scripts/senomy-v2-deploy apply
./scripts/senomy-v2-deploy check
```

Daily development commands are:

```bash
senomy-dev shell
senomy-dev restart
senomy-dev check

senomy-shell use quickshell
senomy-shell use eww
senomy-shell status
senomy-shell restart
senomy-shell logs 120
senomy-shell doctor
```

The selector serializes operations with `flock`, derives its source root from
its resolved script link rather than the caller's working directory, and writes
`shell.json` only after the requested Rail is ready. Readiness requires one
expected namespace per active monitor, no competing Rail namespace, and a
64-pixel bottom reserve on every monitor.

In Quickshell mode the adapter adopts and stops any live Eww daemon, stops the
Eww-only workspace publisher, starts `senomy-quickshell.service`, and waits for
the V2 reserve. In Eww mode it stops Quickshell, starts the stable workspace
publisher and Eww adapter, and waits for `senomy-rail` plus the reserve. A
bounded Eww IPC timeout prevents an unhealthy client channel from holding the
selector lock.

## User-service lifecycle and recovery

`senomy-quickshell.service` runs the source checkout directly and restarts on
failure. `RestartMode=direct` prevents Eww fallback during an ordinary single
crash recovery. Three failures inside the start-limit interval transition the
unit to failed and invoke `senomy-shell-fallback.service`, which restores Eww,
the workspace publisher, the reserve, and the recorded selected backend.

`senomy-eww-legacy.service` is an adapter around the existing verified
`start-eww.sh`; it does not duplicate the Eww startup implementation. Its
35-second cold-start bound reflects observed Eww 0.5 compilation time.

TTY recovery is:

```bash
systemctl --user unset-environment SENOMY_QS_BIN
systemctl --user stop senomy-quickshell.service
systemctl --user reset-failed senomy-quickshell.service
senomy-shell recover-eww
senomy-shell status
```

If the development links themselves are missing, run the live fallback
directly:

```bash
systemctl --user restart workspaces.service
~/.config/eww/scripts/start-eww.sh
```

## Appearance and shared assets

`appearance/tokens.json` and
`appearance/shared/frames/frame-system.json` remain the editable appearance
authority. `scripts/generate-appearance.py` now emits
`shell/quickshell/config/Theme.qml` alongside the Eww, Rofi, GTK, SDDM,
Hyprlock, wallpaper, brand, and frame projections. QML component behavior and
layout remain component-owned; semantic colors, typography, Rail dimensions,
touch target, frame corner, and popup timing are generated.

Quickshell uses repository-relative links to canonical icons, Senomy art, and
generated frame modules. The removed V2 copies were byte-identical duplicates.
SDDM and external toolkit deployments may still require generated regular-file
projections because their transactional deployers deliberately reject symlink
sources.

## SDDM boundary

The active system uses SDDM 0.21.0 with theme `senomyos`, configuration at
`/etc/sddm.conf.d/20-senomyos-theme.conf`, and deployed theme at
`/usr/share/sddm/themes/senomyos`. Source is tracked under
`appearance/login/sddm/`; root-owned session guards are tracked under
`components/login/sddm/`. The selected config matches source, but deployed
`Main.qml` and `FrameSurface.qml` predate the current tracked Compact-frame
source. This is documented drift, not a live failure.

No SDDM files were deployed and SDDM was not restarted in Milestone 2. A future
reviewed deployment is exactly:

```bash
cd /home/Duku/SenomyOS
./scripts/senomy-appearance.sh build
./scripts/senomy-system-deploy.sh plan sddm
sudo ./scripts/senomy-system-deploy.sh apply sddm
```

The deployer is transactional, validates the selected theme and guards, and
does not restart SDDM, log out, or reboot. The new theme appears at the next
natural greeter start.

## Native service architecture

Network state comes from `Quickshell.Networking` and its NetworkManager backend,
not `nmcli` polling. The shared service exposes backend availability, managed
devices, Wi-Fi hardware/software state, active device/connection, SSID, signal,
connection state, and connectivity state. NetworkManager does not expose a
separate global enabled property through this Quickshell API, so
`networkingEnabled` truthfully means that the backend is available and has at
least one managed device.

The tray uses Quickshell's StatusNotifier watcher/host. Registration and removal
flow through `SystemTray.items`; each item supports icon updates, passive and
attention state, primary and secondary activation, wheel events, tooltip data,
and a native `QsMenuAnchor` DBus menu. Empty and broken-icon states are explicit.

`PowerService.qml` separates requested, pending, running, succeeded, and failed
state. `scripts/senomy-session-action` allowlists lock, suspend, logout, reboot,
and poweroff and requires an exact `--confirm ACTION` token before execution.
Milestone tests call only `check` and `dry-run`; no session action is executed.

## Notification ownership decision

SwayNC currently owns `org.freedesktop.Notifications`; Eww consumes its
subscription and retained private history. Milestone 2 does not instantiate a
Quickshell `NotificationServer`, so there is no DBus conflict.

Both migration shell units explicitly want `graphical-session.target` and
`swaync.service`. The selector keeps that target pinned while handing the Rail
between backends. SwayNC is therefore a session service rather than an
accidental child of the Eww workspace listener. This does not enable SwayNC or
either shell unit at login; it only makes notification ownership deterministic
while a migration backend is selected. `senomy-shell status` and `doctor`
report both the service state and the DBus owner.

The live Eww → Quickshell → Eww → Quickshell regression retained the same
SwayNC PID and unique bus owner across every state. The final state had one
Quickshell Rail, no Eww Rail, and the Eww-only workspace listener stopped.

The accepted final V2 direction is a Quickshell notification server and native
SenomyOS UI, not a permanent SwayNC-backend/Quickshell-frontend split. The
standard notification interface includes replacement IDs, actions, urgency,
and timeout events, while Quickshell already owns the shell process and future
Senomy reactions. SwayNC's private client protocol would couple the new shell
to another UI daemon and preserve duplicate state ownership.

Switchover is gated on implementing and testing replacement semantics, action
callbacks, urgency policy, resident/transient timeout behavior, bounded
persistent history, DND/inhibition, and crash recovery on an isolated bus.
Only then may one transaction stop SwayNC, start the Quickshell server, verify
the DBus name, and roll back on failure. The broad notification UI remains out
of Milestone 2.

## Popup, display, and telemetry policies

Calendar and tray share one shell-wide popup token, so only one is requested
across all monitors. Opening stops the closing timer; closing stops the reveal
timer; loss of the source anchor clears the request; Escape and compositor
focus-grab clearing use the same close path. The `shell` IPC handler exposes a
small validated popup interface for deterministic QA and future shortcuts.

Every screen receives its own `PanelWindow`; no monitor index or 1920×1080
coordinate exists in QML. Below 1600 logical pixels the Rail drops secondary
identity density. Below 1180 it drops telemetry; below 800 it keeps a single
overflow-capable workspace chip and hides the clock, preserving the
controls/tray/power group at 640 logical pixels.

Telemetry tiers are:

1. Always on: a two-second in-process `/proc` sampler for CPU, RAM, and uptime,
   plus event-driven network, audio, battery, workspaces, clock, and tray.
2. Performance Dashboard open: faster charts, sensors, temperatures, GPU,
   process, storage, and network detail. Eww temporarily owns this surface.
3. Explicit action: benchmarks, scans, and curated diagnostics only.

The V2 runtime contains no path to `~/.config/eww` and no Eww process or script
dependency. The selector and fallback adapter intentionally depend on the
legacy runtime during migration; they are migration infrastructure, not V2
runtime dependencies. Old docs and migration maps are reference-only.

Measured CPU, memory, process, popup-cycle, restart, crash, and fallback results
are recorded in `shell/quickshell/docs/BENCHMARK.md`. The production native
modules retain low mean CPU but introduce a material memory regression from the
Milestone 1 proof; that regression is an explicit Milestone 3 watch item.

## Known limits before Milestone 3

- Control Centre, Performance Dashboard, Insights, companion, notification UI,
  power UI, and remaining flyouts still belong to Eww.
- SwayNC still owns notifications.
- Login-time startup still belongs to Eww by design.
- Native tray context-menu rendering is wired and runtime loaded; a registered
  item with a suitable exported menu is still needed for a full pointer-driven
  menu action acceptance pass.
- Physical multi-monitor, touch hardware, and non-T480 hardware remain untested;
  virtual hotplug/scale tests do not replace physical evidence.
- Outside-click and Escape paths are compositor-native and structurally shared,
  but automated pointer/key injection was unavailable for this milestone.
- Packaging and clean-machine installation are later product stages.
