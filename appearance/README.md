# SenomyOS appearance workspace

This directory is the single editable source tree for the SenomyOS visual
system. Toolkit files are still deployed to the locations their applications
actually read, but they are not separate development copies.

## Structure

- `tokens.json` is the portable color, type, radius, border, and density
  registry. Its `palettes` object is the canonical Cyan, Violet, and Amber
  accent definition; each palette has a distinct base, bright, soft, medium,
  and strong value.
- `shell/` owns Eww SCSS for the Obsidian Rail and its surfaces.
- `launcher/rofi/` owns the Command Lens Rofi configuration and theme.
- `file-manager/gtk3/` owns the namespaced GTK themes used by the Thunar
  workspace, including its touch-density projection.
- `login/sddm/` owns the pre-session SDDM theme. Its background is a static,
  privacy-safe blurred wallpaper because no desktop exists before login.
- `lock/` owns Hyprlock. It captures and blurs the real authenticated desktop
  at lock time.
- `shared/brand/senomyos-mark.svg.in` is the only editable OS-mark geometry.
  It defines the monochrome three-lancet motif; generation produces one SVG
  and 64px, 128px, and 256px PNG projections for native consumers.
- `shared/backgrounds/cathedral-reliquary-v1.png` is the selected desktop
  wallpaper artwork. Generation normalizes it to a deterministic 1920x1080
  desktop PNG and produces a privacy-safe blurred login projection.
  `desktop.svg.in` remains the editable tokenized vector fallback, but it is
  not the selected desktop raster.
- `shared/frames/frame-system.json` is the canonical Luminous Reliquary frame
  manifest. Generation emits separate Compact, Standard, and Large SVG corner
  and neutral-edge families plus fixed motifs and crests. Only Compact is
  currently deployed to the Rail; other surface migrations are explicit
  future stages.
- `boot/` owns inert Plymouth and GRUB theme sources. Staging these files is
  separate from selecting either theme or regenerating boot artifacts.

`scripts/generate-appearance.py` projects shared tokens into native Eww SCSS,
Quickshell QML, Rasi, GTK CSS, SDDM QML JavaScript, and Hyprlock syntax.
Generated files contain a header and should be changed through `tokens.json`,
not edited independently. Quickshell owns component layout and behavior, while
its shared colors, typography, Rail geometry, touch target, and popup timings
remain generated projections of the same appearance authority as Eww.
It also generates the brand-mark and wallpaper projections and installs the
blurred result and shared avatar into the SDDM source tree, so generated images
do not become second editable copies. The boot mark under `boot/assets/` is a
generated regular-file compatibility projection for the existing GRUB and
Plymouth manifests, not a second source. It also emits 35 transparent frame
modules from the canonical manifest and native path geometry; fixed optical
modules must not be resized to absorb consumer width. The lock deployment
installs the same avatar beneath the user's XDG data root.
Component-specific layout and interaction still belong in the native SCSS,
Rasi, CSS, QML, or Hyprlock source beside the projection.

The Control Centre accent selector is a live Eww preference, so Cyan, Violet,
and Amber can be previewed without regenerating or restarting the shell. Rofi,
GTK, SDDM, and Hyprlock use the stable product accent in `colors.accent`; a
future whole-system palette switch should promote one named palette into that
field and rebuild the projections. This keeps a live shell preview distinct
from a reviewed system-wide theme change.

## One entry point

From the repository root:

```bash
./scripts/senomy-appearance.sh build
./scripts/senomy-appearance.sh check
./scripts/senomy-appearance.sh plan all
./scripts/senomy-appearance.sh apply launcher
./scripts/senomy-appearance.sh apply file-manager
./scripts/senomy-appearance.sh apply lock
./scripts/senomy-appearance.sh preview login
./scripts/senomy-appearance.sh apply login
./scripts/senomy-appearance.sh apply recovery YOUR_USER_NAME
```

Portable behavior defaults live in `deploy/profiles/`. The selected profile
is deployed to `${XDG_CONFIG_HOME:-$HOME/.config}/senomyos/profile.json` and is
resolved beneath explicit user preferences. `automatic` is the safe generic
fallback; `desktop`, `touch`, and `narrow` provide reviewed density and layout
overrides without forking the visual sources.

The complete already-installed-Arch bootstrap surface is:

```bash
./scripts/senomy-bootstrap.sh audit
./scripts/senomy-bootstrap.sh plan automatic
./scripts/validate-bootstrap.sh
```

Package installation and first-boot apply are confirmed separately. Neither
path activates a Plymouth/GRUB theme, reloads Hyprland, restarts SDDM, logs
out, or reboots.

Apply `login` before `recovery`. Provisioning refuses to create or unlock the
recovery account until both root-owned SDDM session guards are installed and
selected.

User and system deployment are transactional and retain checksummed receipts
and backups. Rollback is routed through the same entry point:

```bash
./scripts/senomy-appearance.sh rollback user DEPLOYMENT_ID
./scripts/senomy-appearance.sh rollback system DEPLOYMENT_ID
```

An active recovery account must be disabled with
`sudo senomy-recoveryctl disable` before rolling back either the recovery
runtime or the SDDM session guards.

Applying `shell` is the only command that reloads a running visual component;
it warns and requires the exact phrase `RELOAD SHELL`. SDDM deployment never
restarts SDDM, logs out, or reboots. The installed login theme appears the next
time the greeter starts.

## Recovery boundary

Password recovery is not implemented as an unauthenticated QML callback. The
`RECOVER` action switches to a separately authenticated system account and an
allowlisted recovery session. Root-owned SDDM session guards reject ordinary
Wayland and all X11 sessions for that account, while its `/usr/bin/nologin`
shell denies TTY and SSH shell access. The recovery compositor defines no app
launcher, browser, terminal, or general-purpose command binding; its UI can
only submit two password lines to the exact root-owned reset helper or return
to the greeter.

This protects the graphical authentication paths; it is not a substitute for
data-at-rest encryption. A machine whose system disk is not encrypted remains
recoverable or modifiable by an attacker with sufficient physical access.
