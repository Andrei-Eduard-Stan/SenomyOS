# SenomyOS Deployment

This directory defines how reviewed repository sources reach live user
configuration. Development stays in the SenomyOS repository; live Rofi,
Thunar, GTK, and Hyprland paths are deployment targets rather than additional
working directories.

The user deployer handles complete repository-owned files plus one explicit,
deterministic merge for Thunar custom actions. It does not deploy directory
trees, merge arbitrary formats, write privileged paths, reload Eww, restart
applications, or regenerate boot configuration.

## Commands

Run from the repository root:

```bash
./scripts/senomy-deploy.sh list
./scripts/senomy-deploy.sh plan hyprland
./scripts/senomy-deploy.sh apply hyprland
./scripts/senomy-deploy.sh plan rofi
./scripts/senomy-deploy.sh apply rofi
./scripts/senomy-deploy.sh plan thunar
./scripts/senomy-deploy.sh apply thunar
./scripts/senomy-deploy.sh history
./scripts/senomy-deploy.sh rollback DEPLOYMENT_ID
```

`list`, `plan`, and `history` are read-only. `apply` and `rollback` show the
resolved operation and require an exact confirmation phrase. `--yes` exists
for isolated automation and tests; ordinary interactive use should retain the
confirmation.

The unified visual entry point wraps both user and system manifests:

```bash
./scripts/senomy-appearance.sh plan all
./scripts/senomy-appearance.sh apply launcher
./scripts/senomy-appearance.sh apply file-manager
./scripts/senomy-appearance.sh apply lock
./scripts/senomy-appearance.sh apply login
./scripts/senomy-appearance.sh plan boot
./scripts/senomy-appearance.sh apply boot
./scripts/senomy-appearance.sh apply recovery YOUR_USER_NAME
```

The system layer can also be inspected directly with
`./scripts/senomy-system-deploy.sh plan sddm`, `plan recovery`,
`plan plymouth-staged`, and `plan grub-staged`. Its apply, history, and
rollback verbs require root. System receipts are private beneath
`/var/lib/senomyos/deployments`. The boot components install inert theme files
only; they never edit boot configuration or regenerate an initramfs.
`docs/BOOT_SEQUENCE.md` documents stage capabilities, firmware/video limits,
device-profile strategy, and the recovery gates required before activation.

## Packages, services, and first boot

`packages.json` declares official Arch dependencies and keeps the required AUR
Eww package in an explicit external-review tier. `services.json` records system
enablement policy and package-managed user presets. The orchestrator exposes
read-only audit/plan paths plus confirmed package installation and first boot:

```bash
./scripts/senomy-bootstrap.sh audit
./scripts/senomy-bootstrap.sh plan automatic
./scripts/senomy-bootstrap.sh install-packages --with-external
./scripts/senomy-bootstrap.sh apply automatic "$USER"
```

Profiles are complete schema-validated files under `profiles/`; deployment
precedence is portable defaults, selected profile, then bounded user
preferences. The bootstrap does not reload Hyprland, restart SDDM, regenerate
GRUB/initramfs, log out, or reboot. Recovery credential provisioning remains
an interactive root boundary.

`scripts/validate-bootstrap.sh` performs the clean acceptance currently
available without a disposable machine: it audits package/service fixtures,
applies the real user manifest into an empty home, stages the real system
manifest into an empty root, and runs native parsers. This is a clean-root
installation test, not cold-boot evidence. `scripts/senomy-bootctl` therefore
keeps Plymouth/GRUB activation blocked until a separately recorded disposable-
machine cold boot and recovery boot have passed.

An apply performs these steps:

1. Validate the manifest and every source and destination.
2. Compare content and permissions and stop when nothing would change.
3. Build and validate any allowlisted deterministic candidate.
4. Show the plan and run component preconditions.
5. Request confirmation and lock the user deployment path.
6. Recheck preconditions and source/target fingerprints.
7. Back up every affected target before changing any target.
8. Write a private `prepared` receipt.
9. Install each file through a same-directory temporary file and atomic rename.
10. Verify deployed checksums, permissions, and allowlisted post-apply checks.
11. Mark the receipt `applied`.

Ordinary command failures trigger an automatic restore from the prepared
receipt. If the process is externally terminated, the prepared receipt remains
available for explicit rollback.

## Backup and receipts

Deployment state defaults to:

```text
${XDG_STATE_HOME:-$HOME/.local/state}/senomyos/deployments/
```

Each timestamped deployment directory is private and contains:

```text
DEPLOYMENT_ID/
  backups/
  receipt.json
```

The receipt records component, source, destination, previous existence,
checksums, modes, manifest checksum, and lifecycle status. A target created by
SenomyOS is removed on rollback; a target that already existed is restored from
its backup.

Manual rollback refuses to overwrite a target whose contents have drifted away
from both the recorded pre-deployment and deployed versions. That condition
requires inspection rather than a force flag. Component-specific checks are
recorded in the receipt and run again after restoration.

## Manifest model

`manifest.json` is the allowlist. A ready user component may contain file
entries with:

- a unique entry ID;
- a source path relative to the repository;
- an allowlisted target root and relative path;
- `kind: "file"`;
- `strategy: "replace"` or the specifically validated
  `strategy: "thunar-uca-merge"`;
- an explicit mode.
- allowlisted component-level pre-apply and post-apply checks where required.

The Thunar merge entry also names the installed helper target. It parses the
existing `uca.xml`, preserves unrelated actions, replaces only SenomyOS-owned
unique IDs, capability-detects each action dependency, and emits a validated
mode-0600 candidate before backup or mutation. No other entry type receives
implicit merge behavior.

Supported user target roots are:

- `xdg_config` → `${XDG_CONFIG_HOME:-$HOME/.config}`;
- `xdg_data` → `${XDG_DATA_HOME:-$HOME/.local/share}`;
- `user_bin` → `$HOME/.local/bin`.

Absolute paths, parent traversal, symlink sources, symlink targets, directory
replacement, and destinations that resolve outside their declared root are
rejected. User target and state roots must also resolve beneath the current
user's home directory.

## Component policies

- **Eww:** managed directly in the current live repository for now.
- **Hyprland:** complete-file replacement is supported, but applying it remains
  an explicit reviewed action. The deployer installs `hyprland.lua`, the
  project wallpaper, and the bounded `swaybg` launcher for selection at the
  next compositor start; it does not reload or replace the current `.conf`
  session.
- **Rofi:** the Command Lens config, theme, wrapper, and bounded Files/Actions
  adapters are deployed and manually verified. The separately reviewed
  Hyprland transaction now routes `Super+R` to the wrapper.
- **Thunar:** the scoped file-workspace wrapper, action helper, and
  deterministic `uca.xml` merge are deployed. Fresh wrapper launches start a
  collected transient daemon with the installed SenomyOS theme, wait for its
  D-Bus name, and then open or reveal; the bounded fallback is a detached
  daemon. This does not change the global GTK setting. Existing Thunar sessions
  are reused without a restart, and file reveal uses the supported
  `org.freedesktop.FileManager1.ShowItems` interface. Apply and
  rollback refuse to run while Thunar is open because Thunar may write its
  in-memory action state when it exits. The transaction leaves `accels.scm`,
  Xfconf preferences, native file operations, and the global GTK preference
  untouched. The user desktop entry uses an explicit shell-expanded
  `~/.local/bin` wrapper path and omits PATH-dependent `TryExec`, so it remains
  eligible in display-manager sessions with a system-only PATH.
- **GTK 3:** the namespaced source passed GTK parsing plus isolated Thunar and
  Network Connection Editor visual QA and is installed beneath the user data
  root. A separate `SenomyOS-Touch` projection supplies 48px controls and is
  selected when file-workspace density resolves to touch. Notebook-dialog
  controls retain effective touch targets while fitting the validated 1080px
  screen. Installation does not select either theme globally.
- **SDDM and recovery:** remain outside the user deployer but are ready in
  `system-manifest.json`. The privileged deployer creates root-owned backups
  and receipts, validates the theme and restricted runtime, and never restarts
  SDDM, logs out, or reboots. Recovery account provisioning is an additional
  explicit credentialed step.
- **Plymouth and GRUB:** source themes and transactional staging are ready.
  Activation remains unavailable until a disposable-machine cold boot and
  recovery boot pass and a separate activation implementation is reviewed.

## Validation

Run the isolated transaction test with:

```bash
./scripts/validate-deployment.sh
./scripts/validate-command-lens.sh
./scripts/validate-thunar-contract.sh
./scripts/validate-theme-contract.sh
./scripts/validate-profile-contract.sh
./scripts/validate-bootstrap.sh
./scripts/validate-boot-themes.sh
```

It uses temporary source, configuration, and state roots. It does not read or
write the real live Hyprland, Thunar, Rofi, or GTK targets.
