# SenomyOS boot appearance sources

This directory owns the native pre-login boot sequence. `sequence.json`
records stage ownership and capability limits; `grub/` owns the boot menu; and
`plymouth/` owns the early-userspace splash. The single editable OS mark is
`appearance/shared/brand/senomyos-mark.svg.in`. `assets/senomyos-mark.svg` and
`.png` are generated regular-file compatibility projections for the existing
boot deployment manifests, not independent artwork. SDDM and Hyprlock remain
in their own native directories under `appearance/` because they run at
different authentication boundaries.

Build shared/generated assets with:

```bash
./scripts/senomy-appearance.sh build
./scripts/senomy-appearance.sh check
```

Inspect or inertly stage the two boot themes with:

```bash
./scripts/senomy-bootctl status
./scripts/senomy-system-deploy.sh plan grub-staged
./scripts/senomy-system-deploy.sh plan plymouth-staged
```

Staging copies isolated files and creates a rollback receipt. It does not
select either theme, edit kernel parameters, regenerate `grub.cfg`, rebuild an
initramfs, or reboot. The detailed design and recovery procedure lives in
`docs/BOOT_SEQUENCE.md`.
