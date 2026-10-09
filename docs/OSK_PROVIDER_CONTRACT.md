# Native on-screen keyboard provider contract

Current checkpoint: 2026-10-09. The user-local wvkbd-mobintl provider is installed;
the user reported successful typing/open/close before the resizing extension.
Managed manual controls, Super+Ctrl+K and the pinned drag-resize extension now
have source and isolated native coverage. Physical touch/rotation/fractional-scale/
multi-output and post-extension real typing remain acceptance; see
qa/osk-resize-20261009/RESULTS.md. Historical investigation checkpoints follow.

## Evidence and candidate

The bounded candidate is wvkbd-mobintl or wvkbd-deskintl. Upstream documents
manual launch and SIGUSR1 hide / SIGUSR2 show. Automatic text-focus display uses
`--auto` and requires the compositor's input-method-v2 support; it is outside the
initial manual-control path. Source binds virtual-keyboard-v1 and layer-shell.

Primary references:

- https://github.com/jjsullivan5196/wvkbd
- https://github.com/jjsullivan5196/wvkbd/blob/master/main.c

Initial investigation (superseded by installation): neither checked wvkbd executable nor wayland-info is found
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

## Implementation checkpoint — 2026-10-08

`osk-capabilities.py` probes advertised interfaces through wayland-info with a
five-second timeout. Unknown/malformed/failed probes do not enable a candidate.
The conservative base requirements include wl_compositor v6, matching the current
upstream source inspected; older provider versions may have different needs and
are not inferred compatible. Provider installation and protocol advertisement
remain distinct, and integrated always remains false.

`OskController.qml` is a tested prototype with injected provider ownership,
serial-tagged callbacks, startup timeout, show/hide requests, confirmed stopping
and a primary-focus-release signal. It has no production provider adapter. Fake
providers test its state contract; no keyboard is started or signalled by tests.

Quickshell documents that a managed Process ends with configuration reload or
shell exit. A detached process would lose direct ownership. The launch adapter
must resolve this boundary and provide explicit lifecycle information before
wiring show/hide to a live provider. Hiding the Input route must not terminate it.
Reference: https://quickshell.org/docs/v0.3.0/types/Quickshell.Io/Process/ .

## Adapter and manual-controls checkpoint — 2026-10-08

The selected policy is a managed shell-session child. Starting previews that it
survives panel dismissal and ends with shell reload/exit, with Cancel focused by
default. Stop also requires confirmation. InputSettings owns the adapter outside
the route Loader, so leaving Input cancels an unconfirmed review without stopping
a running provider. Show requests close only the current Input primary surface;
a late callback never closes another route or Insights.

The launch helper rechecks advertised capabilities, executes an allowlisted
provider with fixed argv in the same owned PID, rejects privileged/file-capability
binaries, and establishes Linux PR_SET_PDEATHSIG(SIGTERM) with a parent-race check.
The readiness probe requires that PID's executable and both show/hide signals to
be blocked or handled before sending them. No arbitrary PID is signalled, no
process-name matching or detached instance is used, and no keys are logged.

A disposable no-input C stub verifies real Quickshell ownership/readiness,
show/hide, panel lifetime, observed confirmed exit, configuration reload and
abrupt shell exit. The abrupt-exit case failed before the parent-death guard was
added. Stub process exit is checked separately from zombie PID reaping. These
checks are not real Wayland/app-focus/text-entry acceptance. No real provider was
started and no package was installed.

Parent-death reference:
https://man7.org/linux/man-pages/man2/PR_SET_PDEATHSIG.2const.html . The older
prototype checkpoint above records the state before this adapter was connected.

## Shortcut and resize boundary — 2026-10-09

The dedicated shortcut is an explicit start/show/hide request and may launch an
available owned child directly. The Input UI still reviews Start/Stop. No shortcut
stops or restarts a provider. Provider-reported mapping/geometry is kept separate
from physical presentation acceptance and never includes typed keys. Native monitor
reservations, refreshed at most once per 32ms geometry burst, constrain primary
panels. Source watching still ends a managed child; session dimensions survive
hide/show but are not saved preferences.
