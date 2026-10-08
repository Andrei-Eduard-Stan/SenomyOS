# Desktop defaults, autostart and portal capability status — 2026-10-08

Applications uses Gio registered MIME handlers for six supported roles. Saving a
reviewed default rechecks registry/application metadata and observes its result;
no app launch or arbitrary Exec replay. Autostart reads XDG precedence, preserves
comments/other groups and system originals, backs up user overrides privately,
protects named session infrastructure, and distinguishes metadata eligibility
from actual startup. All changes have Cancel-focused review and context/snapshot
revalidation. Enabling the future systemd autostart hook only creates the reviewed
user wants link; no daemon reload, target activation, start/stop or logout occurs.
The reviewed impact warns that eligible applications may run at a future login.

Settings reads three portal service states and eight advertised interfaces via
no-auto-start introspection. Installed/active/advertised are distinct; permission,
file chooser, camera, screenshot and screencast acceptance are not inferred.
Optional Flatpak absence is explicit. Dependency additions use portable package
names, not current-home defaults. The local OSK build remains separately recorded.

`python3 scripts/validate-desktop-settings.py`: 12 mocked application/autostart
backend cases, 4 mocked portal cases, 7 Qt review-controller cases, actual views
with 24 entries at 600/340px and query-disabled actual service guards. Mutations
are limited to private XDG roots; no real defaults, autostart files or manager
links were changed. Read-only native catalog: 6 default roles, 56 eligible app
choices and 4 protected system autostarts; future hook unconfigured. Portal
services active; seven interfaces advertised; Background unavailable; no Flatpak.

Warned source publication: Configuration Loaded 14:21:58; active/running PID1373
unchanged, compositor errors empty, existing stackAfter warning remains. Fresh
login, real file/link opening and portal permission/provider journeys remain
attended acceptance. Prefix-based protected identities are a conservative UI
policy, not a security boundary against user-created applications.

Integration patches are zero-context; verify before hashes then replay with
`git apply --unidiff-zero`. Dirty baseline consumers remain separately preserved;
this is not evidence of a reproducible clean checkout or release.
