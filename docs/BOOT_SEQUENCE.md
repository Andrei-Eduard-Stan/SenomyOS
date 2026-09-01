# SenomyOS boot-sequence customization

## What is centralized

All editable visual sources now begin in this repository. The pre-login boot
sources are under `appearance/boot/`, while the authenticated boundaries stay
beside the other appearance providers:

```text
appearance/
├── tokens.json                         shared palette, type and geometry
├── shared/
│   ├── brand/senomyos-mark.svg.in      only editable OS-mark geometry
│   └── backgrounds/                    generated wallpaper family
├── boot/
│   ├── sequence.json                   stage/capability contract
│   ├── assets/senomyos-mark.{svg,png}  generated compatibility projections
│   ├── grub/senomyos/theme.txt         boot-menu layout
│   └── plymouth/senomyos/              early-userspace splash
├── login/sddm/senomyos/                pre-session authentication
└── lock/hyprlock.conf.in               authenticated-session lock
```

The applications do not read this repository directly at boot. That would be
fragile because the user home may not be mounted yet. The repository is the
source; the transactional deployers copy reviewed outputs into the system
paths that GRUB, Plymouth, SDDM, Hyprlock, Rofi, GTK and Eww actually read.
Every apply records checksums and backups so source editing and live state do
not become the same thing.

## The real boot sequence

The visible startup path has separate owners and separate technical limits:

| Stage | Runs where | SenomyOS control | Suitable effects |
|---|---|---|---|
| Vendor firmware / UEFI | motherboard firmware, before the OS | normally none | vendor logo and firmware diagnostics only |
| GRUB | bootloader | static theme is staged | background, OS logo, fonts, menu, selected row, timeout text |
| Kernel + initramfs | early Linux userspace | Plymouth source is staged | logo, frame animation, progress, safe status and disk-unlock prompts |
| SDDM | system display-manager session | implemented and deployable | animated QML login surface, layout/session selection and guarded system actions |
| Hyprland + Eww | authenticated desktop | implemented and deployable | full shell, live data, rich animation and user interaction |
| Hyprlock | authenticated session | implemented and deployable | live screenshot blur, PAM unlock and bounded locked-session keys |

This separation matters. A visual effect that is easy in SDDM may be
impossible or unsafe in firmware or the initramfs.

## What can and cannot be customized

### Firmware and BIOS/UEFI logo

SenomyOS deliberately treats this as device-owned. On many UEFI systems the
logo is embedded in signed vendor firmware and exposed to the OS through BGRT.
Replacing it is not a normal theme operation: it can break firmware signature
checks, measured boot, warranty support, recovery, or the motherboard itself.
`sequence.json` therefore records `managed_by_senomyos: false`.

If a device is already running an explicitly supported open firmware such as
coreboot, its branding should live in a separate hardware-specific firmware
project with its own recovery programmer and test matrix—not in the portable
desktop theme. SenomyOS can begin its owned presentation at GRUB.

### GRUB

GRUB themes support images, labels, fonts, styled boxes, a boot menu and
timeout/progress components. Edit:

- `appearance/boot/grub/senomyos/theme.txt` for layout;
- `appearance/shared/brand/senomyos-mark.svg.in` for the mark;
- `appearance/shared/backgrounds/cathedral-reliquary-v1.png` for the selected
  shared background; `desktop.svg.in` remains the portable vector fallback.

GRUB is not a general video compositor. A shell-like text or ASCII intro can
be written as GRUB script output, but it delays boot, is difficult to make
resolution-independent, and must preserve the recovery menu and command line.
Keep it short and make it optional. Do not represent MP4/WebM playback as a
supported GRUB theme feature.

### Plymouth

Plymouth is the right stage for the branded transition between the bootloader
and SDDM. Its script plugin can render images/text and react to progress,
messages, password prompts and refresh callbacks. Edit
`appearance/boot/plymouth/senomyos/senomyos.script`.

For an ASCII animation, render a small fixed list of text frames or PNG frames
and advance them in the refresh callback. For an illustrated animation, use a
short PNG sequence at a conservative frame rate. The canonical contract caps
the intended rate at 12 fps because every frame may be copied into the
initramfs and decoded before the full system is available.

Arbitrary video playback is intentionally marked unsupported. Plymouth does
not provide the normal desktop media stack, codecs or predictable accelerated
video playback. Converting a very short clip into optimized image frames is
possible, but long/high-resolution sequences enlarge the initramfs and can
make boot slower rather than smoother.

Boot messages should be sent through Plymouth's message interface or mapped
from a fixed allowlist. Never display secrets, raw kernel command lines,
filesystem keys, arbitrary journal lines or user-controlled strings.

### SDDM and the session lock

SDDM is the first stage with a full Qt Quick scene and pointer interaction.
It can animate the login rail, but it has no access to the authenticated live
desktop; its blurred background is a generated static asset. Hyprlock runs
inside the already authenticated Hyprland session, so it can blur a live
screenshot. These sources must remain separate even when they share tokens.

## Device and form-factor variants

Use capabilities rather than BIOS names or model strings. A future boot
profile may select among these bounded modes:

- `graphics-safe`: GRUB theme plus low-frame-rate Plymouth on KMS/framebuffer;
- `text-safe`: plain GRUB and kernel text when graphics initialization is not
  reliable;
- `quiet`: static logo and minimal messages for appliance/kiosk hardware;
- `diagnostic`: visible boot details for recovery media and test machines.

The selection belongs in a root-owned `/etc/senomyos/boot-profile.json`
generated during installation. Portable sources must not contain `eDP-1`, a
T480 model check, one framebuffer resolution, a username, or a home path.
Unknown hardware must fall back to a bootable text path.

The current `sequence.json` maps all user-facing form-factor profiles to
`graphics-safe`; this is a source contract, not a claim of tested hardware
support. Actual selection/generation remains gated on disposable-machine boot
tests.

## Editing and safe staging workflow

From the repository root:

```bash
./scripts/senomy-appearance.sh build
./scripts/senomy-appearance.sh check
./scripts/senomy-appearance.sh plan boot
./scripts/senomy-appearance.sh apply boot
```

`build` regenerates the mark and shared projected assets. `check` validates
JSON, generated files, Plymouth script constraints, GRUB structure, QML and
the deployment manifests. `plan boot` is read-only. `apply boot` installs the
GRUB and Plymouth files into isolated theme directories with two privileged,
recoverable transactions.

Crucially, `apply boot` only stages files. It does **not** select the GRUB or
Plymouth theme, add `quiet splash`, add a mkinitcpio/dracut hook, rebuild an
initramfs, regenerate `/boot/grub/grub.cfg`, change NVRAM entries, or reboot.

Inspect readiness at any time:

```bash
./scripts/senomy-bootctl status | jq
./scripts/senomy-bootctl plan grub | jq
./scripts/senomy-bootctl plan plymouth | jq
```

## Activation and recovery design

Activation is deliberately not implemented on this live machine yet. A bad
SDDM theme can be recovered from a TTY; a bad initramfs or bootloader change
can prevent the machine from reaching that TTY. Before activation exists, the
project requires:

1. a disposable VM with the same bootloader/initramfs family;
2. a retained known-good GRUB entry and initramfs image;
3. a bootable Arch/SenomyOS recovery USB;
4. successful graphical and text-fallback cold boots;
5. successful encrypted-volume/password-prompt testing where applicable;
6. a successful rollback from the recovery environment;
7. an acceptance receipt at `/var/lib/senomyos/acceptance/boot.json`.

After those gates, activation should be a separate root transaction that:

- backs up `/etc/default/grub`, initramfs configuration and generated boot
  artifacts before mutation;
- validates that the installed bootloader is actually GRUB;
- keeps a known-good menu entry and previous initramfs;
- selects Plymouth only when its package and renderer are available;
- regenerates into temporary outputs where the tools support it;
- validates the generated configuration before replacing anything;
- records exact hashes and a boot counter/health acknowledgement;
- never flashes firmware.

Until that work is implemented and tested, `senomy-bootctl activate` exits
with a refusal by design. That is the safety boundary, not a missing theme.

## Upstream references

- Hyprland monitor and lock behavior: <https://wiki.hypr.land/0.54.0/Configuring/Monitors/> and <https://wiki.hypr.land/Hypr-Ecosystem/hyprlock/>
- SDDM theme keyboard API: <https://github.com/sddm/sddm/wiki/Theming>
- GNU GRUB theme format: <https://www.gnu.org/software/grub/manual/grub/html_node/Theme-file-format.html>
- Plymouth integration overview: <https://wiki.freedesktop.org/www/Software/Plymouth/>
- Arch Plymouth package/integration guide: <https://wiki.archlinux.org/title/Plymouth>
