# Native on-screen keyboard contract

## Provider and ownership

OSK capability detection is independent of XKB locale, Fcitx5 setup and actual
text input acceptance. Probe installed allowlisted providers and advertised
compositor protocols with a bounded read; absent/failed/unknown is not compatible.
Version-specific provider/component requirements must be checked explicitly.

Own only the exact child started by SenomyOS with fixed argv. Do not use pkill,
process-name matching, arbitrary/stale PIDs or affect a manually started keyboard.
The adapter rejects privileged/file-capability binaries and establishes a
parent-death SIGTERM guard with a parent-race check. Signal readiness requires
that PID's expected executable and handled/blocked show/hide signals. No typed
keys or user text enter telemetry.

The selected managed child survives panel dismissal but ends with shell reload/
exit. Starting/stopping through Input uses the existing review and Cancel default.
The dedicated shortcut is visibility-only: it may explicitly start/show/hide an
available owned provider, but does not stop/restart it. Callback generations
prevent late focus requests from closing another route or Insights.

## State, automatic mode and geometry

Separate unavailable, stopped, starting, running, requested hide/show and failed.
A running process or successful signal does not establish displayed geometry or
successful text entry. Release primary focus for application input. OSK and lock/
login paths require their own acceptance.

Auto mode follows reported text focus only when a usable physical keyboard is
absent. Capability detection excludes virtual/power-button devices; unknown
physical-keyboard backends suppress automatic opening. Manual visibility and
persisted Manual mode override automatic display. An optional IME observer must
not take another IME's seat and releases its connection when inactive.

Use runtime geometry, orientation and touch profiles. The local exact-version
component can fit normal tiled clients around the keyboard rectangle while
preserving layout membership; FLOAT/REFIT, hide and exit restore the latest layout.
Floating/fullscreen clients and impossible minimum-size fits are excluded.
Whole-strip reservation is the unsupported-component fallback. Keep an explicit
visible alternative to dragging and preserve a usable minimum application area.

Caps Lock synchronization uses modifier-only listeners and an owned event bridge.
Missing/incompatible components leave manual OSK available and shared Caps
unavailable; do not claim portable universal key-state support. Shell panels and
the expanded island have their own free-region/layer policies.

## Verification

Use inert owned-provider stubs for missing protocols, duplicate requests, child
exit, parent death, readiness, signals, external-instance isolation and panel
lifetime. Never emit keys or signal real desktop processes in automated tests.
Physical Qt/GTK/XWayland/terminal typing, focus, modifiers, layout, touch, portrait,
fractional scaling, multiple outputs, lock and recovery remain separately scoped.

Source lives in the input component and native services; related historical
receipts remain under `docs/qa/osk-*`. Current acceptance is in
[PROJECT_STATE](../PROJECT_STATE.md).
