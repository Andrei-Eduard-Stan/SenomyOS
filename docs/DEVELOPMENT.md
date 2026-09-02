# SenomyOS Development Workflow

## Before changing anything

1. Confirm the workspace:

   ```bash
   pwd
   git rev-parse --show-toplevel
   ```

2. Inspect the branch and all local changes:

   ```bash
   git branch --show-current
   git status --short --branch
   git --no-pager diff
   ```

3. Read `AGENTS.md` and the relevant document under `docs/`.
4. Explain the intended change, files, runtime effect, and validation.
5. Warn before any action that may hide or restart the live bar.

Use `revival/live` for the revival unless a later feature branch is explicitly
chosen.

Quickshell migration work is the explicit later branch `quickshell-v2` in the
authoritative `/home/Duku/SenomyOS` worktree. Do not run Quickshell work from
the detached Eww fallback or the out-of-scope secondary clone.

## Quickshell Milestone 3 validation

Static source checks do not require a live restart:

```bash
./scripts/senomy-dev check
./scripts/validate-data-contracts.sh
./scripts/validate-quickshell-notifications.sh
qmllint -I shell/quickshell shell/quickshell/shell.qml
```

The notification validator runs on a private D-Bus session and never displaces
the live owner. Do not run `validate-interactions.sh` or
`validate-all-panels.sh` while Quickshell is selected: they are legacy live-Eww
acceptance harnesses and require the Eww daemon. The static aggregate already
checks their source contracts.

For a supervised live check, first warn that the Rail may briefly disappear,
then use only the selector:

```bash
senomy-shell use quickshell
senomy-shell status
senomy-shell doctor
qs ipc --path shell/quickshell show
```

Use `senomy-shell use eww` for rollback. Never start SwayNC manually while
Quickshell is selected; notification ownership is part of selector readiness.
Transient headless-output QA must use Hyprland's active Lua API on the current
0.56 runtime, remove the output in an EXIT trap, and verify the physical
monitor count/reserve afterward. `hyprctl keyword monitor` is a legacy-parser
path and does not apply to the active Lua provider.

## Live desktop boundaries

Editing files under `/home/Duku/.config/eww` changes files used by the live Eww
daemon, but does not necessarily reload the daemon.

The current legacy-session Hyprland file is outside the repository:

```text
/home/Duku/.config/hypr/hyprland.conf
```

The tracked migration reference is:

```text
/home/Duku/.config/eww/hyprland.conf
```

The reviewed next-session source is
`/home/Duku/.config/eww/hyprland.lua`; its user deployment target is
`${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprland.lua`. Applying that component
does not reload the running legacy `.conf` session.

When a Hyprland change is required:

1. show the proposed repository-source diff;
2. explain why Hyprland must change;
3. use the transactional `hyprland` component for the Lua deployment target;
4. run `Hyprland --verify-config --config hyprland.lua` before apply;
5. run `hyprctl configerrors` when the current session is affected;
6. report whether a reload or next-login effect is expected.

Do not modify the secondary clone at `/home/Duku/Projects/SenomyOS`.

## Change size

Prefer stages that can be reverted or diagnosed independently:

- one data collector;
- one shared state transition;
- one bar layout;
- one panel shell;
- one section;
- one action/confirmation flow.

Avoid mixing structural Yuck changes, a large SCSS redesign, data collectors,
and Hyprland startup changes in one commit.

## Portability gate

Before accepting a new path, monitor, device, or geometry assumption, ask:

1. Can it be discovered safely?
2. Can it be expressed relative to the current work area?
3. Is it a portable default or a hardware-profile override?
4. What happens when the device is absent?
5. Does the feature remain usable by keyboard, pointer, and touch?
6. Does it work in narrow or portrait geometry?

Machine-specific behavior needs a documented profile and fallback. The current
T480 configuration is reference data, not a reason to embed T480 identifiers in
shared code.

Changes that add a dependency must also update:

- `DATA_SOURCES.md`;
- the eventual package manifest;
- missing-dependency UI;
- installation and validation documentation.

## Shell validation

For every changed shell script:

```bash
bash -n path/to/script.sh
```

For JSON-producing scripts, execute the read-only status path and validate:

```bash
bash path/to/script.sh | jq -e .
```

If a script has mutating verbs, validate only a documented read-only or dry-run
path until the user approves the action.

Check executable modes deliberately. A script invoked directly requires an
executable bit; a script invoked through `bash` does not.

For the Command Lens, validate the repository source without opening Rofi:

```bash
./scripts/validate-command-lens.sh
./scripts/senomy-deploy.sh plan rofi
```

The validator uses a temporary home, mocked application launchers, hostile
filenames, and Rofi's dump-only parser paths. A successful source check does
not authorize deployment, a manual launch, or a `Super+R` binding change.

For deployment/profile/boot work, run the isolated acceptance paths before a
privileged apply:

```bash
./scripts/validate-profile-contract.sh
./scripts/validate-deployment.sh
./scripts/validate-bootstrap.sh
./scripts/validate-boot-themes.sh
```

The clean-root test is not a virtual-machine cold boot. Never convert its
success into a Plymouth or GRUB activation receipt.

For the Thunar action layer, validate the source and inspect the generated live
candidate without writing it:

```bash
./scripts/validate-thunar-contract.sh
./scripts/senomy-deploy.sh plan thunar
```

The contract uses temporary XML, fake clipboard/notification providers, and a
temporary deployment home. It verifies deterministic merging, preservation of
unrelated actions, fixed helper verbs, path validation, the Thunar-process
precondition, scoped workspace launches, FileManager1 reveal arguments,
single-window fresh selection, the user desktop entry, standard/touch density
selection, and exact rollback. Do not use `thunar
--select`: it is not supported by the installed Thunar 4.20 command line.
Never edit or replace live `uca.xml` while a Thunar process is running; it may
write its older in-memory state when exiting.

Validate the portable appearance registry and the namespaced GTK 3 source
without launching an application:

```bash
./scripts/validate-theme-contract.sh
./scripts/senomy-deploy.sh plan gtk3
```

The validator checks the Eww/Rofi/GTK token projections and asks GTK 3 to parse
the complete provider, including its Adwaita resource inheritance. Visual QA
still uses a temporary home and `GTK_THEME=SenomyOS`; do not write a global GTK
preference merely to test the source. GTK 3 and GTK 4 are separate theme
stacks, so record which toolkit each test application actually uses.

The standard and touch GTK providers must both parse. The touch provider
imports the canonical standard theme and changes only density-related values;
keep frequently used targets at least 44px and prefer the 48px token.

Test the deployed file-workspace entry point with a harmless temporary folder
or file. A fresh launch should put the selected namespaced `GTK_THEME` in the
daemon environment, expose the owned D-Bus name, and open one visible client;
a reveal should create one Thunar client, and closing it must not alter the
deployed `uca.xml`. If a user already has Thunar open, preserve that session
and its existing theme.
Also resolve `thunar.desktop` through Gio with a PATH that excludes
`~/.local/bin`. The user entry must remain eligible and must resolve ahead of
the distribution entry; do not add a PATH-dependent `TryExec` field.

## Unified appearance workflow

Edit visual sources under `appearance/` and use the single entry point from
the repository root:

```bash
./scripts/senomy-appearance.sh build
./scripts/senomy-appearance.sh check
./scripts/senomy-appearance.sh plan all
```

The generator owns the shared-token projections for SCSS, Rofi, GTK, QML, and
Hyprlock, the three-tier Luminous Reliquary SVG frame system, plus the boot mark
used by GRUB and Plymouth. Toolkit-specific layout remains in its native
source. User targets are applied through `senomy-deploy.sh`; SDDM and recovery
use the root-owned system manifest. Both deployers create backups and receipts
before mutation.

Frame-system work also runs:

```bash
python3 scripts/validate-frame-system.py \
  --artifacts-dir docs/design/frame-system/harness
```

This validates all 35 native-vector assets and renders the actual fixed-corner,
neutral-edge composition at Compact 68/120/200/280/397x44, Standard
160x88/240x120/420x180, and Large 240x120/480x320/1480x760. It also renders
the adaptive workspace bay and 1/2/3/4/+N app states. It rejects embedded
raster content, verifies fixed optical geometry and transparent safe centres,
and checks stable neutral-edge profiles. `validate-rail-frame-svg.py` remains a
compatibility wrapper for the same validator.

Preview SDDM without a real login or power action using:

```bash
./scripts/senomy-appearance.sh preview login
```

Before applying login or recovery, run
`./scripts/validate-sddm-contract.sh`. SDDM apply never restarts the display
manager, logs out, or reboots. Recovery provisioning is separate because it
creates an independently authenticated account and prompts interactively for
its credential. Never put a password-reset command, browser, URL handler,
terminal, or arbitrary process launcher in the greeter theme.

Boot appearance is sourced under `appearance/boot/` and documented in
`docs/BOOT_SEQUENCE.md`. The shared entry point can build, validate, plan, and
stage it:

```bash
./scripts/senomy-appearance.sh plan boot
./scripts/senomy-appearance.sh apply boot
```

The apply action stages isolated GRUB/Plymouth files only. It does not select a
theme, rebuild initramfs, regenerate `grub.cfg`, modify firmware, or reboot.

## Eww validation

Eww 0.5.0 is the current target.

Before a live reload:

1. inspect Yuck includes and references;
2. check that every custom widget/window name is defined exactly once;
3. validate script outputs;
4. inspect SCSS for obvious syntax and selector errors;
5. show the diff;
6. warn that the bar may briefly disappear if parsing fails.

Where practical, validate a copied configuration with an isolated Eww instance
rather than disturbing the live daemon. Do not claim that `eww debug` validates
unloaded on-disk edits; it primarily describes the running daemon state.

For an approved live reload:

```bash
~/.config/eww/scripts/reload-eww.sh
```

After the helper returns successfully:

```bash
eww active-windows
eww state
eww logs
```

Use `scripts/reload-eww.sh` instead of raw `eww reload` during normal
development. It captures validated state, closes the old windows, stops the
daemon, verifies the replacement `main-bar`, restores the dismiss layer and
remembered surface at responsive geometry, then restores active, section, and
Timeline state.

Do not use raw `eww reload` for this configuration. Eww 0.5.0 can reset
`defvar` state while retaining visible windows. If it was run accidentally and
the daemon remains reachable, reconcile the retained instances with the reset
state:

```bash
~/.config/eww/scripts/surface-state.sh reconcile
```

If IPC is no longer reachable, stop before starting another Eww command:
inspect the exact Eww process tree and recover one daemon deliberately. Do not
keep issuing `eww open`, because Eww may auto-start a second server.

Verify the bar visually and test repeated-click and cross-surface switching.

## Hyprland validation

After an approved live Hyprland change:

```bash
hyprctl configerrors
```

For the current next-session source and deployment target:

```bash
Hyprland --verify-config --config /home/Duku/.config/eww/hyprland.lua
./scripts/senomy-deploy.sh plan hyprland
```

An empty `hyprctl configerrors` response means no reported configuration
errors in the running session. The legacy `.conf` comparison remains relevant
only when deliberately maintaining that migration reference.

## Diff and commit gate

Before every commit:

```bash
git diff --check
git status --short
git --no-pager diff
```

Then report:

- files changed;
- user-visible effect;
- validation performed;
- limitations or planned follow-up;
- whether live state was reloaded.

Use small commit messages such as:

```text
docs: define SenomyOS shell architecture
fix(runtime): remove redundant update loop
feat(bar): add shared surface state
feat(insights): add truthful briefing shell
```

Do not push unless the user asks. Never push directly to `main`.

## Recovery

A recovery snapshot exists at:

```text
/home/Duku/SenomyOS-recovery/20260719-170831
```

Treat it as read-only unless the user explicitly asks to restore from it.
Before restoring anything, compare the exact target and explain what would be
overwritten.
