# Functional acceptance through Senomy Insights — 2026-10-08

The autonomous source pass and bounded regression are recorded, including the
remaining Applications/Settings work and two final correctness fixes. This does
not mark whole-product or physical acceptance complete. Designs remain deferred.
The canonical backlog remains AUTOMATION_PROGRESS.md; validated command results
are in qa/final-regression-20261008/validation.json and dated stage evidence.

| Area | Implemented and automatically checked | Remaining acceptance or prerequisite |
|---|---|---|
| Session and power | Exclusive surfaces, screen-owner reconciliation, confirmation Cancel focus, editable idle/lid policy and recovery gates | Hypridle absent/unloaded; attended fresh login, real lock/DPMS, suspend/resume and fallback. Automatic suspend blocked until recovery passes. |
| Devices/displays/audio | Capability inventory, finite keyboard navigation, reviewed device/routing/display controls | Real docking/scaling/rollback, touchpad/touchscreen, pairing and audio routes. No universal hardware claim. |
| Input/accessibility | Persistent keyboard/repeat/pointer controls, first-run review, focus scrolling, detected Fcitx5 handoff and managed manual OSK | Fcitx5 absent; engine/session integration unresolved until installed and tested. Local wvkbd/protocol probe installed, no real launch/text entry yet. Touch/portrait/occlusion/lock-focus and full accessibility audit remain. |
| Networking | Secret-free profiles, reviewed disconnect/delete/autoconnect with snapshot checks; native VPN/DNS/PAC-proxy handoffs; observed failure/timeout states | Real scanning and secure terminal credential flow, editor saving, VPN plugins/connectivity and DNS/PAC application behavior. Link connection is separate from Internet access. |
| Applications | Six Gio registered default roles; reviewed preserved autostart overrides, user backups/protected identities, future-login framework link | Real file/link association opening and fresh-login startup. Current live future hook remains unconfigured; no defaults/autostarts were mutated. |
| Desktop integration | Read-only portal services/interfaces and unavailable providers; existing launcher/file workspace handoffs | File chooser/open URI, removable mounts, archives/shares, permission prompts, camera/screenshot/screencast in real apps. Advertised interfaces are not accepted journeys; Flatpak absent. |
| Performance | Process views and exact-identity termination boundary, allowlisted audio user-service restart, inline curated Diagnostics/Console/Reports, single global route owner | Attended service restart/process/provider actions and multi-output acceptance. Arbitrary process replay and arbitrary shell commands remain unsupported by design. |
| Insights | Briefing, Notifications, Timeline, Updates, Diagnostics, Console, Reports, Wiki; queued reads, freshness/error states, verified action results and bounded/redacted private reports | Real notification/provider/report viewing acceptance. Updates discover only; no install/rollback/recovery flow is claimed. |

All combined suites pass on this source tree. Compositor hosts are substituted in
route tests; mutations are private/fake, and process lifecycle tests own disposable
stubs. Native service remains active after warned source loads, PID1373 unchanged,
Hyprland configuration errors empty; existing QML warnings remain. Passing these
checks does not remove the last column.

## Next execution boundary

No unattended destructive or session-disruptive action closes these gates. Next
work is an attended acceptance session, beginning with the manual OSK text-entry
journey and idle-policy installation/deployment prerequisites, then fresh-login/
lock recovery before any automatic suspend. Use Control Centre > Input > Start
Keyboard > Start for Session for the installed manual OSK candidate. Its process
is session-owned and ends on shell reload/exit. Do not enable automatic suspend
merely because protocol checks or stub fixtures pass.

The large pre-existing dirty/untracked baseline is preserved. Own consumer patches
and hashes are dated under qa/; a clean-checkout/release claim still requires that
baseline to be reviewed and packaged. Versioned releases, update installation,
installer/recovery media, hardware tiers and aesthetic redesign are later work.
No push, background schedule or execution while the laptop is off is implied.
