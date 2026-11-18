# SenomyOS appearance workspace

This directory contains shared appearance sources and native toolkit projections.
The current accepted visual/interaction contract lives in
[DESIGN_SYSTEM](../docs/DESIGN_SYSTEM.md); current delivery/acceptance lives in
[PROJECT_STATE](../docs/PROJECT_STATE.md).

| Source | Ownership |
| --- | --- |
| `tokens.json` | Semantic colour, type, geometry, density, motion and authentication roles |
| `skins/default.json`, authored assets | Skin manifest, original frame/background/persona art and slicing rules |
| `shared/` | Shared brand/auth/fallback frame generation and asset provenance |
| `launcher/rofi/` | Explicit legacy Rofi configuration/projection; Command Lens defaults to native QML |
| `file-manager/gtk3/` | Namespaced native GTK file-workspace projections |
| `login/sddm/` | Pre-session authentication/greeter sources |
| `lock/` | Hyprlock projection at the separate lock authentication boundary |
| `boot/` | Inert GRUB/Plymouth sources, separate from boot activation |
| `wallpapers/`, `assets/backgrounds/` | Bounded wallpaper and per-surface background ownership |

`scripts/generate-appearance.py` owns supported generated projections. Edit their
semantic/token source rather than independently editing generated output. Native
component layout/behaviour remains in QML and toolkit-specific source. Preserve
hand-authored Island/utility corners; the historical shared-frame generator is
not an interchangeable replacement. See [skin authoring](../docs/reference/ART_SKINS.md).

From the repository root, build/check and inspect plans through the existing
appearance entry point. Read actual tool help before an apply:

```bash
./scripts/senomy-appearance.sh build
./scripts/senomy-appearance.sh check
./scripts/senomy-appearance.sh plan all
```

Build can write generated source projections; check/plan are the diagnostic paths.
Publishing watched QML or applying a running shell projection can briefly reload
the Rail. User/system deployment is transactional and receipt-based. Login/lock/
boot projection, installed files and current runtime state are distinct.

Profiles under `deploy/profiles/` supply portable defaults below explicit user
preferences. Keep user overrides private and separate from immutable artwork.
Do not promote a shell-local preview into a system-wide palette/authentication
change without its reviewed projection transaction.

SDDM deployment does not restart the display manager or log out. Staging boot
assets does not activate a theme, regenerate boot files or reboot. Read
[boot contracts](../docs/reference/BOOT_SEQUENCE.md) before boot work and
[recovery contracts](../docs/reference/RECOVERY.md) before password recovery or
its guarded SDDM integration. Preserve recovery confinement and private receipts.
