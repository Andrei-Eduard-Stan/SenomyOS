# Native on-screen keyboard provider contract

Dated investigation: 2026-10-08. This is a proposed implementation contract,
not delivered OSK support or a hardware acceptance result.

## Evidence and candidate

The bounded candidate is wvkbd-mobintl or wvkbd-deskintl. Upstream documents
manual launch and SIGUSR1 hide / SIGUSR2 show. Automatic text-focus display uses
`--auto` and requires the compositor's input-method-v2 support; it is outside the
initial manual-control path. Source binds virtual-keyboard-v1 and layer-shell.

Primary references:

- https://github.com/jjsullivan5196/wvkbd
- https://github.com/jjsullivan5196/wvkbd/blob/master/main.c

Reference machine: neither checked wvkbd executable nor wayland-info is found
on PATH. Protocol compatibility, surface readiness and real application input
are therefore unknown. No provider/package was installed or started.

## Required implementation boundary

- Detect installed allowlisted provider and required advertised compositor
  protocols with a bounded, read-only probe. Absent/failed probe is unknown,
  never compatible. Command installation alone is insufficient.
- Keep detection independent of XKB locale and Fcitx5 engine/editor status.
  Manual OSK and IME setup are distinct capabilities.
- Own exactly the child instance started by SenomyOS. Do not use pkill, pgrep
  matching, an arbitrary PID, stored stale PID, or affect a user-started keyboard.
- Visible keyboard/pointer/touch controls must support explicit show and hide.
  Launch with fixed argv; no widget text, custom shell command or user arguments.
- Track unavailable, stopped, starting, running, hide/show-requested and failed
  separately. Process running or a successful signal does not prove the surface
  is visible or text was entered. Do not label a request as observed visibility.
- Define ownership and shutdown behavior before launching from the live shell.
  Any destructive process stop follows the project's explicit confirmation rule.
- Showing from Control Centre must release primary-surface focus so application
  text entry is possible. Panel dismissal must not immediately destroy the OSK.
  Escape and provider-native hide remain usable when the panel is closed.
- Use runtime work areas, orientation and capability profiles. Do not inject a
  T480 monitor name, fixed desktop resolution or global input environment.
- Verify keyboard reservation and focus visibility at narrow/portrait geometry;
  lock screen must have a separately accepted path. No login/lock OSK claim.

## Required evidence

Fake providers: absence, unknown protocols, incompatible protocols, installed
provider disappearance, duplicate requests, launch failure, child exit, owned
signals, external instance isolation and panel focus release. Do not emit keys
or send signals to real desktop processes during automated tests.

Attended acceptance: pointer and touch show/hide; text entry in native Qt/GTK,
XWayland and terminal; modifier/layout behavior; multi-output placement;
portrait/narrow occlusion; close/reopen/reload ownership; lock/recovery behavior.
Source and mocked tests cannot close these acceptance items.
