# Release, preferences and maintenance contracts

This is a technical contract, not an activation approval or progress ledger.
Current delivery and remaining acceptance belong in [PROJECT_STATE](../PROJECT_STATE.md).
Use the actual tool help and freshly reviewed source, target ownership and receipts.

## One prepared payload and the existing deployment boundaries

`scripts/senomy-release-snapshot.py` extends the existing deterministic snapshot
entry point: `plan`, `create`, `install`, `activate-plan`, `activate`, `status`,
`rollback` and `recover`. Its transaction module is `scripts/senomy_release.py`.
`deploy/release.json` declares runtime bindings and command capabilities;
`deploy/packages.json` remains the package authority declaration. The existing
user/system component deployers retain their owned-file/merge/rollback guards.
No system component or package is installed by the release engine.

A candidate contains `source.tar.gz`, schema-2 `release.json` (every path, SHA256,
size and executable bit) and `SHA256SUMS`. Tar headers and gzip timestamps are
normalised. Internal symlinks are materialised; escaping symlinks are refused.
Only regular allowlisted archive paths are extracted, never archive symlinks,
hardlinks, devices or traversal paths. Required runtime files and binding sources
must exist. Hashes detect corruption/drift; they are **not a publisher signature**.
Only explicitly reviewed local candidates are trusted.

Default store: `${XDG_DATA_HOME:-~/.local/share}/senomyos/runtime`:

```
versions/<SHA256-of-release.json>/release.json
versions/<SHA256-of-release.json>/payload/{shell,scripts,appearance,assets,...}
current -> versions/<SHA256>/payload
transactions/<id>.json
```

Payload files are user-owned 0444/0555 (original executable bits preserved),
directories 0555. This is immutable deployment convention, not protection against
the owning user; explicit integrity checks detect edits. Source remains untouched.
Fonts are declared Arch dependencies, not copied from private font directories.
Artwork stays byte-for-byte authored. Redistribution/licensing review and native
version compatibility beyond the current Quickshell/Hyprland stack are release
qualification work, not guaranteed by a checksum. This is not an OS image.

Install extracts into a temporary sibling, verifies bytes/modes/owner and atomically
publishes an inactive version. Incomplete install directories are never selected.
Activation checks required commands and installed required Arch packages (read-only
`pacman -Qq`); missing optional commands remain explicitly listed. Calendar's
private, hash-locked Python runtime is separately set up by its existing tool;
release installation does not install Python dependencies or enable Calendar.

Activation accepts absent targets, its own current links, exact legacy checkout
links or byte/mode-identical legacy files. Explicit `--legacy-receipt` additionally
allows the exact previous applied component receipt's hash/mode, needed for the
copied application-lifetime adapter. Unmanaged/drifted files and linked ancestors
are refused. Calendar's existing target-wants link is migrated **only if present**;
no new enablement is introduced. `shell.json` preserves other keys and changes
only `source_root`. A durable preimage journal precedes changes; `current` changes
last by atomic rename. Startup uses resolved version paths, so existing processes
stay attached to their already-loaded release. There is no automatic restart.

`status` explicitly verifies the selected manifest, payload, modes, ownership and
public bindings. It is not a high-frequency background collector. A crash leaves
an inspectable prepared journal and blocks the next activation. `recover` restores
that exact journal; `rollback` restores an activated journal. Both refuse external
changes/newer selection and validate the prior release before restoring it. This
covers release files/bindings, not rollback of running processes or user data.

## User configuration and explicit migration

Existing domain stores stay in place: config `senomyos/{profile,preferences,audio,
wallpaper,input,display-manager,display-editor-draft}.json`, XDG input preview
state, battery-care receipts, application/default associations owned by GIO,
Calendar SQLite and notification history under XDG state. Their existing schemas
and hardware/draft ownership are unchanged. Power profiles remain TLP-owned;
there is no new persistent SenomyOS power override or all-settings migration.

The genuine source-owned exception was Skin's persona/background save. Skin now
reads immutable `appearance/tokens.json` and its skin manifest, then schema-1
`${XDG_CONFIG_HOME:-~/.config}/senomyos/appearance.json` overrides. Frames and
relative artwork resolution remain release-owned. Missing overrides use existing
defaults without writing; invalid overrides keep the last valid presentation and
show a failure. Explicit saves use the Python helper, lock, observed-version CAS,
validation and fsync/atomic replacement; no source manifest is written. Unknown
unrelated override keys and other surface values survive scoped changes.

`scripts/senomy-preferences.py read` returns merged registry and version. For an
explicit `save`, `migrate` or `reset`, supply one JSON line on stdin. `expected`
must be the exact read version (or `absent`). Migration also takes `legacy` as a
reviewed manifest path; existing user values win. Reset removes only persona and
background overrides, retaining other keys, and preserves an exact, hash-named
preimage beside the override. An explicitly version-checked reset can recover
malformed JSON. No implicit migration occurs on startup. Migrate legacy values
**before** selecting defaults from a different release if their values differ.
Do not copy all tracked compositor configuration over live user configuration.
Universal preference bundles and per-output wallpaper remain optional G37 work.

## Maintenance and separate rollback meanings

Official/AUR discovery retains the existing bounded cache, freshness and explicit
network-disclosure behaviour. Updates additionally shows release selection,
package transaction state, authentication and reboot evidence. `REVIEW OFFICIAL
UPGRADE IN TERMINAL` uses the existing independent application launcher with a
fixed maintenance tool; the terminal asks `UPGRADE OFFICIAL PACKAGES` before
normal `sudo /usr/bin/pacman -Syu` and pacman's transaction review. No arbitrary
arguments, new package DB, passwordless rule, AUR builder or root shell are added.
Progress/output/authentication stay on the terminal. Only fixed operation,
PID/start identity, timestamps and exit result enter the XDG state receipt.
Terminal handoff is `started`, never package success. Denial/nonzero is failure;
a vanished terminal is interrupted/unverified and is never automatically retried.
Successful exit means pacman reported success, not proof of running service health.

Reboot markers and absence of the running kernel's module tree provide explicit
evidence; otherwise reboot status is unknown. There is no universal Arch marker
for every required userspace restart. Review hooks and `.pacnew` files. The live
read-only observation currently recommends reboot because the running kernel's
modules are no longer installed; no reboot is performed or authorised here.

Source recovery restores only exact published source preimages. Release rollback
restores owned release bindings/selection. Preference reset/backup concerns only
its scoped user settings. Package/kernel/filesystem recovery belongs to native
package/boot/backup tooling and must not be represented by a release receipt.

## Review and lifecycle boundary

Prepare/create/install/activate-plan/activate/rollback/recover are separate actions.
Review exact current candidate bytes, legacy bindings/receipts, active source roots,
normal-account TTY administration, application ownership and recovery before live
activation. Optional independent password-reset login is not a release-engine
dependency. Do not infer application survival from a successful reboot/login.
No command example or archived checkpoint authorizes a service restart, preference
migration, system upgrade or real rollback. Keep lifecycle actions separately
reviewed and verify actual payload ownership afterward.

Use `--store` consistently for isolated transaction tests. Never substitute an old
candidate digest, private receipt or fixed home path from a historical example.
Current package/service manifests are authoritative. Domain settings, Calendar
state, notification history and hardware drafts retain their existing owners.
